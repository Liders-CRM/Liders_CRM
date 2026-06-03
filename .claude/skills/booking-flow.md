# Booking Flow — לוגיקה מלאה

## פקודה: `/booking-flow`

לוגיקת ה-booking המלאה: חישוב slots, ניהול conflicts, validation, flow steps.

---

## ה-Flow — 4 שלבים

```
Step 1: בחירת שירות
    ↓
Step 2: בחירת תאריך (לוח חודשי)
    ↓
Step 3: בחירת שעה (slots זמינים)
    ↓
Step 4: פרטי לקוחה + שליחה
    ↓
    אישור ✅
```

---

## Step 1 — בחירת שירות

```javascript
// ה-state של booking נשמר ב:
let bk = { service: null, date: null, time: null };

// בחירת שירות:
function selectSvc(id) {
  bk.service = S.services.find(s => s.id === id);
  bk.date = null;  // reset date/time כשמשנים שירות
  bk.time = null;
  renderServices();
  renderCal();
  checkNext();
}

// כלל: לא ניתן להמשיך ל-Step 2 ללא שירות נבחר
function checkNext() {
  document.getElementById('btn-next-svc').disabled = !bk.service;
  document.getElementById('btn-next-date').disabled = !bk.date;
  document.getElementById('btn-next-time').disabled = !bk.time;
}
```

---

## Step 2 — לוח שנה

### כללי זמינות תאריך:
```javascript
function isDateAvailable(dateStr) {
  const dt = new Date(dateStr + 'T00:00:00');
  const today = new Date(); today.setHours(0,0,0,0);
  const dow = dt.getDay();  // 0=ראשון, 6=שבת

  if (dt < today) return false;                    // עבר
  if (!S.schedule[dow]?.open) return false;        // יום סגור
  if (hasNoAvailableSlots(dateStr)) return false;  // כל slots תפוסים

  return true;
}

// בדיקת slots פנויים לתאריך:
function hasNoAvailableSlots(dateStr) {
  const dow = new Date(dateStr + 'T00:00:00').getDay();
  const sc = S.schedule[dow];
  const dur = bk.service?.duration || S.slotMin;
  const allSlots = slots(sc.from, sc.to, dur);
  return allSlots.every(t => isBooked(dateStr, t));
}
```

### Navigation לוח שנה:
```javascript
let calMonth = new Date();  // global: החודש המוצג

function changeMonth(dir) {
  calMonth.setMonth(calMonth.getMonth() + dir);
  renderCal();
}

// מניעת ניווט לחודש עבר:
function canGoBack() {
  const now = new Date();
  return calMonth.getFullYear() > now.getFullYear() ||
         calMonth.getMonth() > now.getMonth();
}
```

---

## Step 3 — חישוב Slots

### אלגוריתם חישוב:
```javascript
function slots(from, to, dur) {
  const result = [];
  let [fh, fm] = from.split(':').map(Number);
  const [th, tm] = to.split(':').map(Number);
  const endMin = th * 60 + tm;

  while (true) {
    const startMin = fh * 60 + fm;
    const endSlot = startMin + dur;
    if (endSlot > endMin) break;  // חורג מסוף יום

    result.push(`${String(fh).padStart(2,'0')}:${String(fm).padStart(2,'0')}`);
    fm += dur;
    fh += Math.floor(fm / 60);
    fm = fm % 60;
  }
  return result;
}

// דוגמה: slots('09:00','17:00',60) → ['09:00','10:00','11:00','12:00','13:00','14:00','15:00','16:00']
```

### בדיקת תפיסות:
```javascript
// נוכחי (hardcoded):
function isBooked(date, time) {
  return S.bookings.some(b => b.date === date && b.time === time);
}

// עם Supabase (עתידי):
async function isBookedDB(date, time) {
  const { data } = await supabase
    .from('bookings')
    .select('id')
    .eq('date', date)
    .eq('time', time)
    .not('status', 'in', '("cancelled","no_show")')
    .limit(1);
  return data?.length > 0;
}
```

### Break Time:
```javascript
// אם יש הפסקה מוגדרת ביום:
function isInBreak(time, sc) {
  if (!sc.break_from || !sc.break_to) return false;
  const [bfh, bfm] = sc.break_from.split(':').map(Number);
  const [bth, btm] = sc.break_to.split(':').map(Number);
  const [th, tm] = time.split(':').map(Number);
  const t = th * 60 + tm;
  return t >= bfh * 60 + bfm && t < bth * 60 + btm;
}
```

---

## Step 4 — טופס פרטי לקוחה

### Validation Rules:
```javascript
const VALIDATIONS = {
  name: {
    required: true,
    minLength: 2,
    pattern: /^[֐-׿\s'"-]{2,50}$/,  // עברית + תווים בסיסיים
    error: 'שם חייב להכיל לפחות 2 תווים בעברית'
  },
  phone: {
    required: true,
    pattern: /^0[5-9]\d{8}$|^0[5-9]\d-\d{7}$/,  // ישראל: 05X-XXXXXXX
    normalize: (v) => v.replace(/[-\s]/g, ''),
    error: 'מספר טלפון לא תקין (דוגמה: 050-1234567)'
  },
  notes: {
    required: false,
    maxLength: 300
  }
};

function validateBookingForm(data) {
  const errors = {};
  if (!data.name || data.name.trim().length < 2)
    errors.name = VALIDATIONS.name.error;
  if (!VALIDATIONS.phone.pattern.test(VALIDATIONS.phone.normalize(data.phone)))
    errors.phone = VALIDATIONS.phone.error;
  return errors;
}
```

---

## Confirmation Flow

```javascript
async function submitBooking(formData) {
  const newBooking = {
    id: Date.now(),
    client_name: formData.name.trim(),
    phone: formData.phone.replace(/[-\s]/g, ''),
    service: bk.service.name,
    service_id: bk.service.id,
    price: bk.service.price,
    date: bk.date,
    time: bk.time,
    notes: formData.notes || '',
    status: 'confirmed',
    created_at: new Date().toISOString()
  };

  // 1. שמור (לוקאל / Supabase)
  S.bookings.push(newBooking);
  // await saveToSupabase(newBooking);  ← עתידי

  // 2. הצג אישור
  showConfirmation(newBooking);

  // 3. Trigger automations
  // await triggerWhatsAppConfirmation(newBooking);  ← Make.com webhook
  // await syncToGoogleCalendar(newBooking);         ← Calendar MCP

  // 4. Reset state
  bk = { service: null, date: null, time: null };
}
```

---

## Edge Cases — טיפול

| מקרה | טיפול |
|------|-------|
| תור כפול (race condition) | בדוק שוב מ-DB לפני שמירה, הצג שגיאה |
| יום שנסגר אחרי שנבחר | validate ב-submit |
| שירות שמחקו תוך כדי | validate service קיים ב-submit |
| תאריך עבר | אל תציג slots, נווט ליום הבא |
| שם/טלפון ריק | הצג error באדום מתחת לשדה |
| פלאפון ישן (< iOS 14) | fallback לdate input סטנדרטי |

---

## Reset Flow לאחר אישור

```javascript
function resetBookingFlow() {
  bk = { service: null, date: null, time: null };
  calMonth = new Date();

  // חזור ל-step 1:
  document.querySelectorAll('.step').forEach(s => s.classList.remove('active'));
  document.getElementById('step-1').classList.add('active');

  renderServices();
  renderCal();
}
```

---

## Supabase — מעבר מ-hardcoded

```javascript
// לפני (hardcoded):
function isBooked(date, time) {
  return S.bookings.some(b => b.date === date && b.time === time);
}

// אחרי (Supabase):
const { createClient } = supabase;
const db = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function loadBookings(dateFrom, dateTo) {
  const { data, error } = await db
    .from('bookings')
    .select('date, time, status')
    .gte('date', dateFrom)
    .lte('date', dateTo)
    .not('status', 'in', '("cancelled","no_show")');

  if (error) console.error('Supabase error:', error);
  return data ?? [];
}
```
