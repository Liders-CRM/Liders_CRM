# Google Calendar Integration — מלי יופי ועור

## פקודה: `/google-cal`

Integration מלא בין מערכת ה-CRM לבין Google Calendar:
יצירת events, סנכרון, conflict detection, שימוש ב-MCP.

---

## ארכיטקטורה

```
CRM Booking Created/Updated/Cancelled
    ↓
Google Calendar MCP (mcp__6368118b__)
    ↓
Google Calendar Event (לוח שנה של מלי)
    ↓
מלי רואה את כל התורים בלוח השנה שלה
```

---

## Format של Event בלוח שנה

```typescript
interface CalendarEvent {
  summary: string;          // "שרה לוי — טיפול פנים קלאסי"
  description: string;      // פרטים מלאים
  start: {
    dateTime: string;       // "2026-06-10T10:00:00"
    timeZone: "Asia/Jerusalem";
  };
  end: {
    dateTime: string;       // "2026-06-10T11:00:00" (start + duration)
    timeZone: "Asia/Jerusalem";
  };
  colorId: string;         // לפי קטגוריית שירות
  reminders: {
    useDefault: false;
    overrides: [
      { method: "popup", minutes: 30 }
    ];
  };
}
```

### מיפוי צבעים לקטגוריות:
```javascript
const CALENDAR_COLORS = {
  'פנים':   '3',   // sage green
  'פרמיום': '9',   // blueberry (blue-ish)
  'רפואי':  '11',  // tomato (red)
  'רגליים': '6',   // tangerine (orange)
  'הסרה':   '2',   // basil (dark green)
};

function getColorForService(serviceTag) {
  return CALENDAR_COLORS[serviceTag] ?? '1';  // default: lavender
}
```

---

## יצירת Event לאחר הזמנה

```typescript
async function createCalendarEvent(booking: Booking, service: Service) {
  // חשב שעת סיום:
  const [h, m] = booking.time.split(':').map(Number);
  const endMin = h * 60 + m + service.duration;
  const endTime = `${String(Math.floor(endMin/60)).padStart(2,'0')}:${String(endMin%60).padStart(2,'0')}`;

  // בנה description:
  const description = [
    `👤 ${booking.client_name}`,
    `📞 ${booking.phone}`,
    `💆 ${booking.service}`,
    `💰 ₪${booking.price}`,
    booking.notes ? `📝 ${booking.notes}` : '',
    `🆔 תור מס' ${booking.id}`,
  ].filter(Boolean).join('\n');

  // mcp__6368118b__create_event:
  const event = {
    calendarId: 'primary',  // לוח ראשי של מלי
    summary: `${booking.client_name} — ${booking.service}`,
    description,
    start: {
      dateTime: `${booking.date}T${booking.time}:00`,
      timeZone: 'Asia/Jerusalem'
    },
    end: {
      dateTime: `${booking.date}T${endTime}:00`,
      timeZone: 'Asia/Jerusalem'
    },
    colorId: getColorForService(service.tag),
    reminders: {
      useDefault: false,
      overrides: [{ method: 'popup', minutes: 30 }]
    }
  };

  // IMPORTANT: שמור את eventId ב-Supabase לסנכרון עתידי
  // const { eventId } = await mcp__6368118b__create_event(event);
  // await supabase.from('bookings').update({ calendar_event_id: eventId }).eq('id', booking.id);
}
```

---

## עדכון Event (שינוי תור)

```typescript
async function updateCalendarEvent(booking: Booking, service: Service) {
  if (!booking.calendar_event_id) {
    // אם אין event_id — צור חדש
    return createCalendarEvent(booking, service);
  }

  // mcp__6368118b__update_event:
  // עדכן summary + start/end לפי הנתונים החדשים
}
```

---

## מחיקת Event (ביטול תור)

```typescript
async function deleteCalendarEvent(booking: Booking) {
  if (!booking.calendar_event_id) return;

  // mcp__6368118b__delete_event({
  //   calendarId: 'primary',
  //   eventId: booking.calendar_event_id
  // });

  // נקה את calendar_event_id מ-Supabase:
  // await supabase.from('bookings').update({ calendar_event_id: null }).eq('id', booking.id);
}
```

---

## שליפת תורים מהלוח שנה

```typescript
async function getCalendarBookings(dateFrom: string, dateTo: string) {
  // mcp__6368118b__list_events({
  //   calendarId: 'primary',
  //   timeMin: `${dateFrom}T00:00:00+03:00`,
  //   timeMax: `${dateTo}T23:59:59+03:00`,
  //   singleEvents: true,
  //   orderBy: 'startTime'
  // });
}
```

---

## Conflict Detection

```typescript
async function checkCalendarConflict(date: string, time: string, duration: number) {
  const [h, m] = time.split(':').map(Number);
  const startMin = h * 60 + m;
  const endMin = startMin + duration;

  // שלוף events באותו יום:
  const events = await getCalendarBookings(date, date);

  for (const event of events) {
    const evStart = parseTime(event.start.dateTime);  // דקות מתחילת יום
    const evEnd = parseTime(event.end.dateTime);

    // בדוק חפיפה:
    const overlap = startMin < evEnd && endMin > evStart;
    if (overlap) return { conflict: true, event };
  }
  return { conflict: false };
}

function parseTime(dateTimeStr: string): number {
  const dt = new Date(dateTimeStr);
  return dt.getHours() * 60 + dt.getMinutes();
}
```

---

## שעות חסומות בלוח שנה

```typescript
// ימים חסומים (חגים, חופשה) — מלי מוסיפה ידנית ללוח שנה
// הסקריפט בודק לפני הצגת slots:

async function getBlockedSlots(date: string) {
  const events = await getCalendarBookings(date, date);
  return events
    .filter(e => e.summary?.includes('[חסום]') || e.summary?.includes('[חופשה]'))
    .map(e => ({
      from: parseTime(e.start.dateTime),
      to: parseTime(e.end.dateTime)
    }));
}
```

---

## MCP Commands — בשיחה עם Claude

```
// רשימת לוחות שנה:
mcp__6368118b__list_calendars()

// תורים לשבוע הבא:
mcp__6368118b__list_events({
  calendarId: 'primary',
  timeMin: '2026-06-08T00:00:00+03:00',
  timeMax: '2026-06-14T23:59:59+03:00'
})

// יצירת תור בלוח:
mcp__6368118b__create_event({ ... })

// הצעת זמן:
mcp__6368118b__suggest_time({
  attendees: ['mali@gmail.com'],
  duration: 60,
  timeRange: { start: '2026-06-10', end: '2026-06-10' }
})
```

---

## שדה חדש ב-Supabase — calendar_event_id

```sql
-- Migration: הוסף עמודה לשמירת Google Calendar event ID
ALTER TABLE bookings
  ADD COLUMN IF NOT EXISTS calendar_event_id text;

-- Index לחיפוש מהיר:
CREATE INDEX IF NOT EXISTS idx_bookings_calendar_event_id
  ON bookings(calendar_event_id);
```

---

## Checklist — Google Calendar Integration

- [ ] Calendar ID מזוהה (primary / ספציפי)
- [ ] Event נוצר אוטומטית אחרי booking
- [ ] calendar_event_id נשמר ב-Supabase
- [ ] Event מתעדכן כשתור משתנה
- [ ] Event נמחק כשתור מבוטל
- [ ] Conflict detection לפני יצירת slot
- [ ] צבעי events לפי קטגוריה
- [ ] Reminder 30 דקות לפני כל תור
