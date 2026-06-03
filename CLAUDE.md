# CLAUDE.md — מלי • יופי ועור CRM

## חזון הפרויקט

**המטרה הסופית:** לבנות מערכת CRM חדשנית, יוקרתית ואיכותית לעסקים —
משהו טוב יותר מכל המתחרים הקיימים, שיתן מענה אמיתי ללקוח.

המערכת תאפשר לעסקים לנהל את עצמם בצורה קלה ופשוטה,
עם דגש עיקרי על **חווית משתמש** מעולה.

בנוסף — דגש מרכזי על **אבטחת המוצר**: לבנות את המערכת בצורה מאובטחת לחלוטין,
מפורטת ועשירה במידע.

---

## מה הפרויקט הזה

מערכת CRM + Booking לסלון יופי **מלי אלגרבלי** — קוסמטיקאית רפואית מוסמכת בטבריה.
מתמחה בטיפולי KB Pure, עור רגיש, אקנה, פדיקור רפואי.

---

## Stack

- **Frontend**: HTML + CSS + Vanilla JS (RTL, עברית)
- **Database**: Supabase (PostgreSQL + RLS)
- **Auth**: PIN-based admin + Supabase Auth
- **Automations**: Make.com (WhatsApp, Gmail)
- **Calendar**: Google Calendar MCP
- **Design**: Figma + Canva MCP
- **Architecture**: Miro MCP
- **Docs**: Notion MCP
- **Storage**: Airtable MCP
- **AI Agents**: Anthropic Claude API

---

## Entities הראשיים

| Entity | תיאור |
|--------|-------|
| `Service` | טיפולים: שם, מחיר, משך, קטגוריה |
| `Booking` | תורים: לקוח, טיפול, תאריך, שעה |
| `Client` | לקוחות: פרופיל, היסטוריה, סוג עור |
| `Schedule` | שעות עבודה לכל יום בשבוע |
| `SalonSettings` | הגדרות: שם, PIN, tagline |

---

## Design System

- **Palette**: Espresso (#3A2318) + Terracotta (#B06A4A) + Sand/Blush
- **Fonts**: Cormorant Garamond (display) + Heebo (body)
- **Direction**: RTL מלא
- **Mobile-first**: 390px viewport ראשוני

---

## סקילים זמינים

### מותאמים אישית (`.claude/skills/`)

| פקודה | קובץ | תיאור |
|-------|------|-------|
| `/liders-crm` | `liders-crm.md` | ארכיטקטורה, entities, workflow |
| `/playwright-crm` | `playwright-crm.md` | בדיקות E2E + CI |
| `/figma-crm-ui` | `figma-crm-ui.md` | עיצוב Figma + Canva, RTL |
| `/supabase-security` | `supabase-security.md` | RLS, auth, secrets, audit |
| `/crm-agents` | `crm-agents.md` | AI: booking, reminders, insights |
| `/competitor-research` | `competitor-research.md` | מחקר שוק + בידולים |
| `/security-guardian` | `security-guardian.md` | data protection, incident response |
| `/design-system` | `design-system.md` | tokens, components, RTL specs |
| `/crm-live-data` | `crm-live-data.md` | ⭐ שאיבת נתונים חיים מכל MCPs |
| `/crm-status` | `crm-status.md` | ⭐ מצב פרויקט + roadmap — הפעל בתחילת שיחה |
| `/booking-flow` | `booking-flow.md` | לוגיקת booking מלאה: slots, conflicts, validation |
| `/make-whatsapp` | `make-whatsapp.md` | Make.com automations + WhatsApp templates |
| `/google-cal` | `google-cal.md` | Google Calendar sync + MCP integration |
| `/crm-components` | `crm-components.md` | UI components: toast, modal, loading, forms |
| `/mali-marketing` | `mali-marketing.md` | שיווק דיגיטלי — אסטרטגיה, תוכן, Canva |
| `/liders-marketing` | `liders-marketing.md` | שיווק אוניברסלי לכל עסק ב-Liders |
| `/rtl-hebrew` | `rtl-hebrew.md` | כתיבה עברית RTL מלאה עם Unicode markers |

### מובנים ב-Claude Code (תמיד זמינים)

| פקודה | תיאור |
|-------|-------|
| `/code-review` | ביקורת קוד |
| `/security-review` | ביקורת אבטחה |
| `/deep-research` | מחקר עם web search |
| `/verify` | אימות שינוי עובד |
| `/run` | הרצת האפליקציה |

---

## MCP Servers מחוברים

| שרת | UUID prefix | שימוש |
|-----|-------------|-------|
| Supabase | `f474d5bb` | DB, migrations, RLS, logs |
| Google Calendar | `6368118b` | ניהול תורים בלוח שנה |
| Gmail | `4e93495e` | תקשורת לקוחות |
| Make.com | `194941ca` | WhatsApp, SMS automations |
| Figma | `88a7dadd` | UI design, components |
| Canva | `3f33a9a8` | Marketing materials |
| Notion | `97537a26` | תיעוד, dashboard |
| Airtable | `273af94e` | נתוני לקוחות, reporting |
| Miro | `4a81aac9` | ארכיטקטורה, diagrams |
| Mermaid | `faee5592` | ERD, flowcharts |
| GitHub | `github` | version control |

---

## Files

```
index.html          — האפליקציה המלאה (HTML + CSS + JS)
CLAUDE.md           — קובץ זה
.claude/
  settings.json     — permissions, env vars
  skills/
    liders-crm.md
    playwright-crm.md
    figma-crm-ui.md
    supabase-security.md
    crm-agents.md
    competitor-research.md
    security-guardian.md
    design-system.md
    crm-live-data.md  ← חדש
```

---

## כללי עבודה

### UX / עיצוב
1. **עברית RTL** — כל טקסט UI בעברית, `dir="rtl"`
2. **Mobile-first** — תמיד בדוק ב-390px
3. **Design tokens** — השתמש תמיד ב-CSS variables, לא hardcoded colors
4. **חווית משתמש קודמת לכל** — כל feature חדש חייב להיות פשוט ואינטואיטיבי

### אבטחה (Security First)
5. **RLS** — כל טבלת Supabase חייבת RLS — אין יוצאים מהכלל
6. **Secrets** — לעולם לא ב-git, תמיד ב-.env.local
7. **PIN** — לא לשנות default 1234 בלי hash
8. **בדיקת אבטחה** — כל feature חדש עובר `/security-review` לפני merge
9. **Audit trail** — כל פעולה רגישה (מחיקה, עדכון מחיר, שינוי PIN) נרשמת ב-audit_log

### קוד ואיכות
10. **תיעוד ב-GitHub** — כל שינוי משמעותי מגיע עם commit message ברור
11. **נתונים פתוחים** — APIs ונתוני דוגמה זמינים ב-GitHub לצורך פיתוח ובדיקות

---

## Quick Commands

```bash
# הרץ לוקאל
open index.html  # או: python3 -m http.server 8080

# בדיקות E2E
npx playwright test

# Supabase types
npx supabase gen types typescript --project-id [id] > types/supabase.ts
```
