# CLAUDE.md — Liders CRM

## 📋 סיכום סשן אחרון — 15 יוני 2026 (ערב)

### מה בוצע
- **מיזוג** `claude/make-setup-instructions-3xuf7o` ← מוזג ל-main (PR #13) ✅
- **תיקון URL** ב-CLAUDE.md — `liders_crm` → `Liders_CRM` (אות גדולה) ✅
- **קובץ כפול ב-Drive** — נמחק, נשאר הגרסה החדשה ✅
- **אישור קישורים חיים** — CRM ואדמין עובדים ✅

### מצב נוכחי
| רכיב | סטטוס |
|------|-------|
| CRM ללקוחות | ✅ חי — https://liders-crm.github.io/Liders_CRM/ |
| פאנל אדמין | ✅ חי — https://liders-crm.github.io/Liders_CRM/admin.html |
| Make.com — Lead Notifications | ✅ פעיל |
| Make.com — Trial Expiry | ✅ פעיל (תוקן) |
| Supabase | ✅ פעיל — 2 טנאנטים: ארביטראז + Liders |
| Stripe | ❌ Test mode — ממתין למס עוסק (~19-20 יוני 2026) |

### משימות פתוחות לסשן הבא
1. **דומיין חדש דרך Starlink** (מנוי חינמי) — **עדיפות ראשונה**:
   - לרשום דומיין עסקי
   - לחבר ל-GitHub Pages (DNS records)
   - לעדכן ב: GitHub Pages settings, Supabase CORS, Make.com webhooks, `index.html`
2. **Stripe Live Mode** (כשיהיה מס עוסק):
   - להשלים אימות ב-Stripe
   - ליצור Payment Links חדשים (Live)
   - ליצור Webhook חדש (Live) ← לעדכן `STRIPE_WEBHOOK_SECRET` ב-Supabase
   - לשלוח 4 URLs לקלוד ← יעדכן `index.html`

---

## 🚨 LAUNCH BLOCKER — חובה להזכיר בכל שיחה

> **Stripe Live Mode ממתין לאישור עסקי**
> - מס עוסק מורשה — בתהליך פתיחה, צפוי **שבוע הבא (סביב 19–20 יוני 2026)**
> - חשבון בנק עסקי — נפתח במקביל
> - **עד שאלה מוכנים — לא ניתן לעבור ל-Live ולגבות כסף אמיתי**
>
> כשיהיו מוכנים — דרוש:
> 1. להשלים אימות Stripe (העלאת מסמכים)
> 2. ליצור Payment Links חדשים ב-Live mode (ללא `test_` prefix)
> 3. ליצור Webhook חדש ב-Live mode ← לעדכן `STRIPE_WEBHOOK_SECRET` ב-Supabase
> 4. לשלוח את 4 ה-URLs לקלוד ← יעדכן `index.html` ויעלה ל-main

---

## חזון הפרויקט

**Liders CRM** — הפלטפורמה שהופכת לידים לעסקאות.

מערכת CRM מודרנית, מובייל-ראשון, לניהול פייפליין מכירות.
דגש על **חווית משתמש** מעולה ו**אבטחה** מקסימלית.

---

## Stack

- **Frontend**: HTML + CSS + Vanilla JS (RTL, עברית)
- **Database**: Supabase (PostgreSQL + RLS)
- **Auth**: PIN-based admin (bcrypt hash)
- **Automations**: Make.com
- **Calendar**: Google Calendar MCP
- **Design**: Figma + Canva MCP
- **Architecture**: Miro MCP
- **Docs**: Notion MCP
- **Storage**: Airtable MCP
- **AI Agents**: Anthropic Claude API

---

## Entities

| Entity | תיאור |
|--------|-------|
| `Lead` | ליד: שם, חברה, טלפון, אימייל, ערך עסקה, שלב פייפליין |
| `CrmSettings` | הגדרות: שם חברה, tagline |
| `AdminAuth` | PIN hash — ללא גישה ישירה מה-API |

---

## Pipeline Stages

| ID | שם | צבע |
|----|-----|------|
| 1 | ליד חדש | אפור |
| 2 | יצרנו קשר | כחול |
| 3 | הצעה נשלחה | סגול |
| 4 | במשא ומתן | כתום |
| 5 | עסקה סגורה ✓ | ירוק |

---

## Design System

- **Palette**: Navy (#0F1F3D) + Blue (#2563EB) + Light gray (#F1F5F9)
- **Font**: Heebo
- **Direction**: RTL מלא
- **Mobile-first**: 390px viewport ראשוני

---

## Supabase Project

- **Project ID**: `scyfywvzoogfrlalgftv`
- **Region**: eu-central-1
- **URL**: `https://scyfywvzoogfrlalgftv.supabase.co`

### טבלאות

| טבלה | RLS | הערה |
|------|-----|------|
| `leads` | anon CRUD | פייפליין לידים |
| `crm_settings` | anon READ בלבד | עדכון דרך RPC |
| `admin_auth` | ללא גישה | PIN hash בלבד |

### RPCs

| פונקציה | תיאור |
|---------|-------|
| `verify_admin_pin(pin_input)` | אימות PIN — מחזיר boolean |
| `save_crm_settings(pin, name, tagline, new_pin?)` | שמירת הגדרות + שינוי PIN |

---

## MCP Servers

| שרת | UUID prefix | שימוש |
|-----|-------------|-------|
| Supabase | `f474d5bb` | DB, migrations, RLS |
| Google Calendar | `6368118b` | ניהול יומן |
| Gmail | `4e93495e` | תקשורת |
| Make.com | `194941ca` | אוטומציות |
| Figma | `88a7dadd` | UI design |
| Canva | `3f33a9a8` | Marketing |
| Notion | `97537a26` | תיעוד |
| Airtable | `273af94e` | דיווח |
| Miro | `4a81aac9` | ארכיטקטורה |
| GitHub | `github` | version control |

---

## Files

```
index.html     — האפליקציה המלאה (HTML + CSS + JS)
CLAUDE.md      — קובץ זה
.claude/
  settings.json
  skills/
```

---

## כללי עבודה

1. **עברית RTL** — כל טקסט UI בעברית
2. **Mobile-first** — תמיד בדוק ב-390px
3. **CSS variables** — אף פעם לא hardcoded colors
4. **RLS על כל טבלה** — אין יוצא מהכלל
5. **Secrets** — לעולם לא ב-git
6. **PIN** — מאוחסן כ-bcrypt, לא plaintext
7. **פנייה למשתמש** — תמיד בלשון זכר

---

## Quick Commands

```bash
open index.html              # הרץ לוקאל
python3 -m http.server 8080  # שרת לוקאל
```
