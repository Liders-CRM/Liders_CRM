# CRM Project Status — מלי יופי ועור

## פקודה: `/crm-status`

סקיל לשחזור הקשר מלא בכל שיחה חדשה: מה בנוי, מה בתהליך, מה הבא.
**הפעל תמיד בתחילת שיחה על המערכת.**

---

## מה בנוי כרגע (index.html — 1,296 שורות)

### ✅ בנוי ועובד

| Feature | תיאור | סטטוס |
|---------|-------|-------|
| **Booking Flow** | בחירת שירות → תאריך → שעה → טופס → אישור | ✅ מלא |
| **Service Catalog** | 8 שירותים עם מחיר, משך, קטגוריה | ✅ מלא |
| **Calendar UI** | לוח חודשי RTL עם סימון ימים סגורים | ✅ מלא |
| **Slot Generator** | חישוב slots דינמי לפי משך שירות | ✅ מלא |
| **Admin Panel** | ניהול תורים, שירותים, לוח עבודה, הגדרות | ✅ מלא |
| **PIN Auth** | נעילת admin עם PIN (לוקאל) | ✅ בסיסי |
| **Design System** | CSS variables, RTL, mobile-first | ✅ מלא |
| **Schedule Manager** | הגדרת שעות עבודה לכל יום | ✅ מלא |
| **Conflict Detection** | מניעת תורים כפולים | ✅ מלא |
| **Settings Panel** | שם סלון, tagline, slot_min | ✅ מלא |

### 🔄 בתהליך / חלקי

| Feature | סטטוס | הערה |
|---------|-------|------|
| **Supabase Integration** | ❌ לא מחובר | נתונים hardcoded ב-`const S` |
| **WhatsApp Automations** | ❌ לא פעיל | Make.com מוגדר אך webhook לא מחובר |
| **Google Calendar Sync** | ❌ לא פעיל | MCP זמין, קוד לא נכתב |
| **Client Profiles** | ⚠️ בסיסי | רק שם + טלפון, אין היסטוריה |
| **Email Confirmations** | ❌ לא פעיל | Gmail MCP מחובר, לא מוגדר |

### 📋 TODO — לפי עדיפות

**עדיפות 1 — Supabase Connection:**
- [ ] החלף `const S` בשאיבה מ-Supabase
- [ ] הגדר RLS policies (ראה `/supabase-security`)
- [ ] Authentication אמיתי (admin role)
- [ ] Persist bookings ב-DB

**עדיפות 2 — Automations:**
- [ ] Make.com webhook → WhatsApp אישור תור
- [ ] תזכורת 24h לפני תור
- [ ] Google Calendar sync (booking ↔ event)

**עדיפות 3 — Client Features:**
- [ ] פרופיל לקוחה מלא (skin_type, allergies, history)
- [ ] חיפוש לקוחות ב-admin
- [ ] דוח הכנסות + גרף

**עדיפות 4 — UX Improvements:**
- [ ] Email confirmation לאחר הזמנה
- [ ] לקוחה יכולה לבטל תור בעצמה
- [ ] SMS reminders דרך Make.com

---

## ארכיטקטורת הנתונים הנוכחית

```javascript
// כרגע — hardcoded בדפדפן (לא persistent):
const S = {
  salonName: 'מלי • יופי ועור',
  pin: '1234',
  slotMin: 30,
  services: [ /* 8 שירותים */ ],
  schedule: { 0:{ open,from,to }, ..., 6:{ open:false } },
  bookings: [ /* sample data */ ]
}
```

```
// יעד — Supabase:
Supabase DB ←→ index.html JS ←→ Make.com webhooks ←→ WhatsApp
                                ↓
                        Google Calendar
```

---

## פרטי הסלון

```
שם: מלי • יופי ועור
בעלים: מלי אלגרבלי
תפקיד: קוסמטיקאית רפואית מוסמכת
מיקום: טבריה
התמחות: KB Pure, עור רגיש, אקנה, פדיקור רפואי
שעות: א'-ה' 09:00-17:00 | ו' 09:00-13:30 | שבת — סגור
```

---

## מבנה קבצים

```
/home/user/-/
├── index.html          ← האפליקציה כולה (HTML + CSS + JS)
├── CLAUDE.md           ← הוראות פרויקט
└── .claude/
    ├── settings.json
    ├── SKILLSEXPORT.md
    └── skills/
        ├── crm-status.md       ← קובץ זה
        ├── liders-crm.md       ← entities + workflow
        ├── design-system.md    ← CSS tokens + components
        ├── supabase-security.md← RLS + auth + audit
        ├── crm-agents.md       ← AI agents
        ├── crm-live-data.md    ← שאיבת נתונים חיים
        ├── booking-flow.md     ← לוגיקת booking
        ├── make-whatsapp.md    ← Make.com automations
        ├── google-cal.md       ← Google Calendar
        ├── crm-components.md   ← UI components
        ├── mali-marketing.md   ← שיווק מלי
        └── liders-marketing.md ← שיווק כללי
```

---

## Git Branch הנוכחי

```bash
git branch    # בדוק branch נוכחי
git log --oneline -5  # commits אחרונים
```

---

## סביבת MCP — שרתים מחוברים

| שרת | UUID | סטטוס |
|-----|------|-------|
| Supabase | `f474d5bb` | ✅ מחובר |
| Google Calendar | `6368118b` | ✅ מחובר |
| Gmail | `4e93495e` | ✅ מחובר |
| Make.com | `194941ca` | ✅ מחובר |
| Figma | `88a7dadd` | ✅ מחובר |
| Canva | `3f33a9a8` | ✅ מחובר |
| Notion | `97537a26` | ✅ מחובר |
| Airtable | `273af94e` | ✅ מחובר |
| Miro | `4a81aac9` | ✅ מחובר |
| Mermaid | `faee5592` | ✅ מחובר |

---

## הוראות שימוש

```
/crm-status          — דוח מצב מלא
/crm-status db       — הדגש שינויים ל-Supabase
/crm-status next     — המשימה הבאה לפי עדיפות
/crm-status check    — בדיקת מה עבד בשיחה הנוכחית
```
