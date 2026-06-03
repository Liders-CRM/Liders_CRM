# Make.com + WhatsApp Automations — מלי יופי ועור

## פקודה: `/make-whatsapp`

Blueprints מלאים, message templates, webhook patterns לכל automations של הסלון.

---

## ארכיטקטורת ה-Automations

```
Booking Created (CRM)
    ↓
Make.com Webhook Trigger
    ↓
[WhatsApp Business API] → לקוחה מקבלת אישור
[Google Calendar] → אירוע נוצר
[Gmail] → אישור למלי
```

---

## Scenario 1 — אישור הזמנה (מיידי)

**Trigger:** Webhook POST מה-CRM לאחר הזמנה

```json
// Webhook payload שה-CRM שולח:
{
  "event": "booking_created",
  "booking": {
    "id": 123,
    "client_name": "שרה לוי",
    "phone": "0521234567",
    "service": "טיפול פנים קלאסי",
    "price": 220,
    "date": "2026-06-10",
    "time": "10:00",
    "notes": ""
  }
}
```

**WhatsApp Template — אישור:**
```
שלום {{client_name}} 😊

תורך אושר בהצלחה!

📅 {{date_hebrew}} בשעה {{time}}
💆 {{service}}
💰 ₪{{price}}

📍 מלי • יופי ועור, טבריה

לביטול/שינוי עד 24 שעות לפני:
📞 050-XXXXXXX

מחכה לך! 🌿
— מלי
```

**קוד CRM לשליחת Webhook:**
```javascript
async function triggerMakeWebhook(event, payload) {
  const MAKE_WEBHOOK_URL = process.env.MAKE_BOOKING_WEBHOOK;
  // לעולם אל תשים URL ב-code — תמיד מ-.env!

  const response = await fetch(MAKE_WEBHOOK_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ event, ...payload })
  });

  if (!response.ok) {
    console.error('Make.com webhook failed:', response.status);
    // אל תיכשל את ה-booking בגלל webhook — log בלבד
  }
}

// קריאה אחרי שמירת ה-booking:
await triggerMakeWebhook('booking_created', { booking: newBooking });
```

---

## Scenario 2 — תזכורת 24 שעות לפני

**Trigger:** Schedule (כל יום 10:00) + Supabase query

**Make.com flow:**
```
[Schedule: Daily 10:00]
    ↓
[Supabase: SELECT bookings WHERE date = tomorrow AND status = 'confirmed']
    ↓
[Iterator: for each booking]
    ↓
[WhatsApp: שלח תזכורת]
```

**WhatsApp Template — תזכורת:**
```
שלום {{client_name}} 👋

תזכורת לתורך מחר:

📅 {{date_hebrew}} בשעה {{time}}
💆 {{service}}
💰 ₪{{price}}

נתראה! 😊
לביטול: 📞 050-XXXXXXX

מלי • יופי ועור 🌿
```

**Supabase SQL ב-Make.com:**
```sql
SELECT
  client_name,
  phone,
  service,
  price,
  date,
  time
FROM bookings
WHERE date = CURRENT_DATE + INTERVAL '1 day'
  AND status = 'confirmed'
ORDER BY time;
```

---

## Scenario 3 — לאחר טיפול (Follow-up)

**Trigger:** Schedule (כל יום 19:00) + bookings שהיום

**WhatsApp Template — Follow-up:**
```
שלום {{client_name}} 🌟

תודה שביקרת היום במלי • יופי ועור!

מקווה שנהנית מה{{service}} ✨

מוזמנת לקבוע את התור הבא:
👉 [קישור להזמנה]

נשמח לראותך שוב! 💕
— מלי
```

---

## Scenario 4 — לקוחה לא חזרה 60+ יום

**Trigger:** Schedule (כל ראשון 09:00)

**Supabase Query:**
```sql
SELECT DISTINCT ON (phone)
  client_name, phone, service, date
FROM bookings
WHERE status = 'completed'
GROUP BY phone, client_name
HAVING MAX(date) < CURRENT_DATE - INTERVAL '60 days'
ORDER BY MAX(date) ASC;
```

**WhatsApp Template — Reactivation:**
```
שלום {{client_name}} 💫

הרבה זמן לא נראינו! 🌿

נשמח להכיר אותך שוב ב-
מלי • יופי ועור.

🎁 הטבה מיוחדת עבורך:
10% הנחה על הביקור הבא

לקביעת תור: 📞 050-XXXXXXX
```

---

## Scenario 5 — ביטול תור

**Trigger:** Webhook POST `event: "booking_cancelled"`

**WhatsApp Template — ביטול:**
```
שלום {{client_name}},

התור שלך בוטל:
📅 {{date_hebrew}} בשעה {{time}}

נשמח לתת לך תור חדש 😊
📞 050-XXXXXXX

מלי • יופי ועור
```

---

## סיכום שבועי למלי

**Trigger:** Schedule (כל שישי 14:00)

**Gmail Template:**
```
Subject: סיכום שבוע — מלי יופי ועור

שלום מלי! 🌿

סיכום השבוע שעבר:

📊 תורים שהושלמו: {{completed_count}}
💰 הכנסות: ₪{{total_revenue}}
⭐ שירות מבוקש: {{top_service}}
👥 לקוחות חדשות: {{new_clients}}

תורים הבאים השבוע:
{{next_week_bookings_list}}

שבת שלום 🌿
```

---

## .env.local — משתני סביבה נדרשים

```bash
# Make.com webhooks (לעולם לא ב-git!)
MAKE_BOOKING_CREATED_WEBHOOK=https://hook.eu1.make.com/...
MAKE_BOOKING_CANCELLED_WEBHOOK=https://hook.eu1.make.com/...
MAKE_REMINDER_WEBHOOK=https://hook.eu1.make.com/...
```

---

## בדיקת Health של Automations

```typescript
// מה-MCP של Make.com:
// mcp__194941ca__scenarios_list() — רשימת כל הסצנריות
// mcp__194941ca__executions_list({ limit: 10 }) — executions אחרונות

async function checkAutomationHealth() {
  // 1. רשימת scenarios פעילים
  // 2. בדיקת executions האחרונות
  // 3. דיווח על שגיאות
  const failing = executions.filter(e => e.status === 'error');
  if (failing.length > 0) {
    console.warn(`⚠️ ${failing.length} automations נכשלו`);
  }
}
```

---

## Make.com MCP — פקודות שימושיות

```
// בשיחה עם Claude:
mcp__194941ca__scenarios_list          // כל הסצנריות
mcp__194941ca__scenarios_get(id)       // פרטי סצנריה
mcp__194941ca__executions_list         // executions אחרונות
mcp__194941ca__scenarios_run(id)       // הרץ סצנריה ידנית
mcp__194941ca__hooks_list              // כל ה-webhooks
```

---

## Checklist — לפני Go Live

- [ ] Webhook URLs מוגדרים ב-.env.local (לא בקוד)
- [ ] WhatsApp Business account מאושר
- [ ] טמפלייטים מאושרים ב-WhatsApp (24h process)
- [ ] Test webhook ב-Make.com UI
- [ ] Error handling: webhook נכשל → log, לא fail booking
- [ ] Rate limit: לא יותר מ-5 הודעות לאותו מספר ביום
- [ ] Opt-out: לקוחה יכולה לבטל הודעות
