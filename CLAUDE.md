# CLAUDE.md — Liders CRM

## חזון הפרויקט

**המטרה הסופית:** לבנות מערכת CRM חדשנית, יוקרתית ואיכותית לסוכני נדל"ן —
משהו טוב יותר מכל המתחרים הקיימים (Monday, Salesforce, WinCRM).

המערכת תאפשר לסוכנויות לנהל לידים, נכסים, משימות ותורים — בצורה פשוטה ומהירה,
עם דגש עיקרי על **חווית משתמש** מובייל-ראשית ו**אבטחה מלאה**.

**מודל עסקי:** SaaS — חודש ניסיון חינם, לאחר מכן מנוי חודשי עם חיוב אוטומטי.

---

## מה הפרויקט הזה

מערכת CRM לסוכני נדל"ן בישראל — פיתוח כ-SaaS מולטי-טנאנט.
לקוח דמו ראשון: **לידרס נדל"ן — תל אביב**.

---

## Stack

- **Frontend**: HTML + CSS + Vanilla JS (RTL, עברית, mobile-first)
- **Database**: Supabase (PostgreSQL + RLS) — `scyfywvzoogfrlalgftv`
- **Auth**: Supabase Auth (email + password, auto-signup)
- **Payments**: Stripe (Phase 2) — מנויים, ניסיון חינם, חיוב אוטומטי
- **Automations**: Make.com (WhatsApp, Gmail, SMS)
- **Calendar**: Google Calendar MCP
- **Design**: Figma + Canva MCP
- **Architecture**: Miro MCP
- **Docs**: Notion MCP
- **Storage**: Airtable MCP
- **AI Agents**: Anthropic Claude API

---

## Supabase Project

| פרמטר | ערך |
|-------|-----|
| Project ID | `scyfywvzoogfrlalgftv` |
| Region | `eu-central-1` (Frankfurt) |
| URL | `https://scyfywvzoogfrlalgftv.supabase.co` |
| Org | `jqnktmbbdkjnslyhaqrx` (Liders) |
| Demo Tenant ID | `00000000-0000-0000-0000-000000000001` |

**⚠️ חשוב:** כבה Email Confirmation ב-Supabase Dashboard רק לסביבת דמו פנימית.
לקוחות אמיתיים — השאר פעיל.

---

## Entities הראשיים

| Entity | טבלה | תיאור |
|--------|------|-------|
| `Tenant` | `tenants` | סוכנות/עסק — מולטי-טנאנט |
| `AgentUser` | `agent_users` | סוכנים, מנהלים, צופים |
| `PipelineStage` | `pipeline_stages` | שלבי הפייפליין |
| `Lead` | `leads` | לידים: קונים/מוכרים פוטנציאליים |
| `Property` | `properties` | נכסים: דירות, בתים, פנטהאוזים |
| `Task` | `tasks` | משימות ותזכורות |
| `Showing` | `showings` | ביקורים בנכסים |
| `Activity` | `activities` | לוג פעילות מלא |
| `AuditLog` | `audit_log` | audit trail לפעולות רגישות |

---

## Design System

- **Palette**: Navy (#1C3E6B) + Gold (#C49A2A) + Gray scale
- **Font**: Heebo (Hebrew-first)
- **Direction**: RTL מלא
- **Mobile-first**: 390px viewport ראשוני

---

## 🗺️ Roadmap — מה בוצע ומה נשאר

### ✅ Phase 0 — SPA + DB Schema (הושלם)
- index.html — SPA מלאה: dashboard, pipeline, לידים, נכסים, משימות, הגדרות
- 9 migrations לכל הטבלאות עם RLS מלא
- Seed data: 8 לידים, 7 משימות, 4 נכסים, 5 שלבי pipeline

### ✅ Phase 1 — Backend Connection (הושלם 3.6.2026)
- Supabase project נוצר (`scyfywvzoogfrlalgftv`, eu-central-1)
- Supabase JS client מחובר ל-index.html
- שכבת `DB` מלאה: signIn, loadAll, addLead, addTask, addActivity, updateTask, moveLead
- `register_demo_agent()` — SECURITY DEFINER fn לפתרון RLS bootstrap
- Login אמיתי עם Supabase Auth (auto-signup בכניסה ראשונה)
- כל ה-CRUD כותב ל-Supabase + מעדכן State מקומי

### ✅ Phase 2 — Stripe Billing (הושלם 4.6.2026)

**מה נבנה:**
- [x] Migration 011: עמודות billing בטבלת tenants (stripe_customer_id, subscription_id, trial_ends_at)
- [x] `Billing` module: `isExpired()`, `daysLeft()`, `isPaid()`, `openCheckout()`, `openPortal()`
- [x] Trial Banner — רצועה בראש האפליקציה עם ספירה לאחור
- [x] Paywall Screen — מסך חסימה כשהניסיון פג, עם 2 תוכניות (Basic ₪149 / Pro ₪299)
- [x] Billing Gate — בדיקה אוטומטית בכניסה לאפליקציה
- [x] Settings Billing Section — מצב מנוי + כפתורי שדרוג / Customer Portal

**🔧 מה נשאר להגדיר (ידנית ב-Stripe Dashboard):**
1. צור מוצר + מחיר ב-Stripe → קבל Checkout URL
2. עדכן `Billing.CHECKOUT_URLS` ב-index.html:
   ```js
   basic: 'https://buy.stripe.com/REAL_LINK_HERE',
   pro:   'https://buy.stripe.com/REAL_LINK_HERE',
   ```
3. צור Customer Portal ב-Stripe → עדכן `Billing.PORTAL_URL`
4. Make.com Webhook: `checkout.session.completed` → UPDATE tenants SET plan='pro'

**כשמוכן לבנות Phase 3 — AI Features, כתוב:**
> "בנה Phase 3 — AI Features"

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
| `/crm-live-data` | `crm-live-data.md` | שאיבת נתונים חיים מכל MCPs |

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
liders-crm/
  index.html              — SPA מלאה (HTML + CSS + JS + Supabase client)
  supabase/
    migrations/
      001_tenants.sql
      002_agent_users.sql
      003_pipeline_stages.sql
      004_leads.sql
      005_properties.sql
      006_tasks.sql
      007_showings.sql
      008_activities.sql
      009_rls_policies.sql
      010_register_demo_agent_fn.sql
    seed.sql
CLAUDE.md                 — קובץ זה (roadmap + הוראות)
.claude/
  settings.json
  skills/
    liders-crm.md
    playwright-crm.md
    figma-crm-ui.md
    supabase-security.md
    crm-agents.md
    competitor-research.md
    security-guardian.md
    design-system.md
    crm-live-data.md
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
7. **בדיקת אבטחה** — כל feature חדש עובר `/security-review` לפני merge
8. **Audit trail** — כל פעולה רגישה נרשמת ב-audit_log

### קוד ואיכות
9. **תיעוד ב-GitHub** — כל שינוי משמעותי מגיע עם commit message ברור
10. **Branch** — תמיד `claude/liders-crm-build-gTzqi`

---

## Quick Commands

```bash
# הרץ לוקאל
cd liders-crm && python3 -m http.server 8080
# פתח: http://localhost:8080

# כניסת דמו
# email: demo@liders.co.il
# password: demo1234
```
