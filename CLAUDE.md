# CLAUDE.md — Liders CRM

## הפרויקט

**Liders CRM** — פלטפורמה חכמה שהופכת לידים לעסקאות.
מערכת SaaS מודולרית לעסקים: כל עסק בוחר את המודולים הרלוונטיים לו.

---

## Stack

- **Frontend**: (בפיתוח)
- **Database**: Supabase (PostgreSQL + RLS) — project: `liders-crm` (`scyfywvzoogfrlalgftv`)
- **Auth**: Supabase Auth
- **Automations**: Make.com
- **AI Agents**: Anthropic Claude API

---

## ארכיטקטורה — מודולים

Liders CRM בנויה ממודולים. כל לקוח/עסק מפעיל את המודולים שמתאימים לו:

| מודול | תיאור | סטטוס |
|-------|-------|-------|
| **Core** | חשבונות, משתמשים, auth, audit | בפיתוח |
| **Leads & Pipeline** | לידים, שלבי pipeline, המרות | בפיתוח |
| **Tasks & Activities** | משימות, פעילויות, follow-up | בפיתוח |
| **Real Estate** | נכסים, שוכרים, הצגות, חוזים | אופציונלי — לעסקי נדל"ן |
| **Invoicing** | חשבוניות, תשלומים | אופציונלי |
| **Automations** | Make.com webhooks, התראות | אופציונלי |

---

## Supabase — מצב נוכחי

**DB נקי** — מוכן לבנייה מאפס בארכיטקטורה הנכונה.
כל טבלה עתידית תכלול RLS מלא מהרגע הראשון.

---

## MCP Servers

| שרת | UUID prefix | שימוש |
|-----|-------------|-------|
| Supabase | `f474d5bb` | DB, migrations, RLS |
| Google Calendar | `6368118b` | לוח זמנים |
| Gmail | `4e93495e` | תקשורת |
| Make.com | `194941ca` | אוטומציות |
| Figma | `88a7dadd` | UI design |
| Canva | `3f33a9a8` | מרקטינג |
| Notion | `97537a26` | תיעוד |
| Airtable | `273af94e` | נתונים |
| Miro | `4a81aac9` | ארכיטקטורה |
| GitHub | `github` | version control |

---

## כללי עבודה

1. **RLS על כל טבלה** — אין יוצאים מהכלל
2. **Secrets** — לא ב-git, תמיד ב-.env.local
3. **Audit trail** — פעולות רגישות נרשמות ב-audit_log
4. **מודולריות** — כל feature נבנה כמודול עצמאי שניתן להפעיל/כבות
5. **Security review** לפני כל merge
