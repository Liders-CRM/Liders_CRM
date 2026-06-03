# 📦 CRM Skills Pack — ייצוא לפרויקטים חדשים

> **גרסה: v2.0.0** — עודכן 2026-06-03
> קובץ זה מסכם את כל הסקילים הזמינים. העתק את תיקיית `.claude/skills/` לכל repo חדש.
> עדכן את CLAUDE.md בפרויקט החדש בהתאם לדומיין (נדל"ן / יופי / אחר).
> **קובץ זה מתעדכן אוטומטית בכל הוספת סקיל חדש.**

---

## התקנה בפרויקט חדש — פקודה אחת

```bash
# הרץ בתיקיית הפרויקט החדש:
curl -fsSL https://raw.githubusercontent.com/elgrablidudu-prog/-/main/install-skills.sh | bash
```

או אם רוצה לציין תיקייה ספציפית:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/elgrablidudu-prog/-/main/install-skills.sh) /path/to/project
```

הסקריפט מושך אוטומטית את **כל הסקילים העדכניים** מ-GitHub — תמיד הגרסה האחרונה.

### לאחר ההתקנה:
```bash
# התקן סקיל Supabase מnpm:
npx skills add supabase/agent-skills

# עדכן CLAUDE.md בפרויקט החדש
```

---

## רשימת כל הסקילים

### 🏗️ סקילים מותאמים (`.claude/skills/`)

| סקיל | פקודה | תיאור | נוצר |
|------|-------|-------|------|
| **CRM Workflow** | `/liders-crm` | ארכיטקטורה, entities, workflow לבניית features | 2026-06-02 |
| **Playwright E2E** | `/playwright-crm` | בדיקות אוטומטיות + CI integration | 2026-06-02 |
| **Figma UI/UX** | `/figma-crm-ui` | עיצוב עם Figma + Canva MCP, RTL | 2026-06-02 |
| **Supabase Security** | `/supabase-security` | RLS policies, auth, secrets, audit | 2026-06-02 |
| **CRM Agents** | `/crm-agents` | סוכני AI: booking, reminders, insights | 2026-06-02 |
| **Competitor Research** | `/competitor-research` | מחקר מתחרים + מציאת בידולים | 2026-06-02 |
| **Security Guardian** | `/security-guardian` | הגנת data, checklist, incident response | 2026-06-02 |
| **Design System Pro** | `/design-system` | tokens מדויקים, components, RTL specs | 2026-06-02 |
| **CRM Live Data** ⭐ | `/crm-live-data` | שאיבת נתונים חיים מכל MCPs (Supabase, Calendar, Gmail, Make, Notion, Airtable) | 2026-06-02 |
| **Mali Marketing** | `/mali-marketing` | מנהל שיווק דיגיטלי מלא — אסטרטגיה, תוכן, קופי, עיצוב, ניתוח (Instagram, Facebook, WhatsApp) | 2026-06-03 |
| **Liders Marketing** | `/liders-marketing` | מנהל שיווק דיגיטלי אוניברסלי לכל עסק ב-Liders CRM — אסטרטגיה, תוכן, קופי, עיצוב, ניתוח | 2026-06-03 |
| **CRM Status** ⭐ | `/crm-status` | מצב הפרויקט: מה בנוי, מה TODO, roadmap — הפעל בתחילת כל שיחה לשחזור הקשר | 2026-06-03 |
| **Booking Flow** | `/booking-flow` | לוגיקת booking מלאה: slot calculation, conflict detection, validation, Supabase migration | 2026-06-03 |
| **Make + WhatsApp** | `/make-whatsapp` | Make.com automations: blueprints, message templates, webhook patterns, health check | 2026-06-03 |
| **Google Calendar** | `/google-cal` | Google Calendar sync: event format, create/update/delete, conflict detection, MCP commands | 2026-06-03 |
| **CRM Components** | `/crm-components` | Vanilla JS+CSS UI components: toast, modal, loading, confirm dialog, form validation, badges | 2026-06-03 |
| **Security Agent** | `/security-agent` | סוכן AI אקטיבי לאבטחה: סריקת secrets, RLS audit, PII protection, brute-force, דוח ציון A-F | 2026-06-03 |

### 📦 סקילים מ-npm (`.agents/skills/`)

| סקיל | פקודה | תיאור |
|------|-------|-------|
| **Supabase** | `/supabase` | Best practices מלאים לכל Supabase |
| **Postgres Best Practices** | `/supabase-postgres-best-practices` | אופטימיזציה, indexing, RLS performance |

### 🔧 סקילים מובנים ב-Claude Code (תמיד זמינים)

| פקודה | תיאור |
|-------|-------|
| `/code-review` | ביקורת קוד |
| `/security-review` | ביקורת אבטחה מלאה |
| `/deep-research` | מחקר מעמיק עם web search |
| `/claude-api` | Anthropic SDK integration |
| `/verify` | אימות שינוי עובד |
| `/run` | הרצת האפליקציה |
| `/init` | יצירת CLAUDE.md |
| `/update-config` | עדכון settings.json |

---

## MCP Servers — בדוק שמחוברים

| שרת | UUID prefix | שימוש |
|-----|-------------|-------|
| **Supabase** | `f474d5bb` | DB, migrations, RLS, edge functions |
| **Figma** | `88a7dadd` | UI design, components, tokens |
| **Canva** | `3f33a9a8` | Marketing materials, mockups |
| **Miro** | `4a81aac9` | Architecture diagrams |
| **Make.com** | `194941ca` | Automations (WhatsApp, SMS, email) |
| **Notion** | `97537a26` | Documentation |
| **Google Calendar** | `6368118b` | Appointment management |
| **Gmail** | `4e93495e` | Client communications |
| **Airtable** | `273af94e` | Data storage, reporting |
| **Mermaid** | `faee5592` | ERD + flow diagrams |

---

## התאמה לפרויקט נדל"ן (מתווכים)

עדכן את הקבצים הבאים כשמשכפלים לCRM נדל"ן:

### `liders-crm.md` — החלף entities:
```
במקום: clients, appointments, services, staff, payments
שים:   leads, properties, viewings, agents, deals/commissions
```

### `competitor-research.md` — החלף מתחרים:
```
ישראל: Nadlan-cloud, Real+, יד2 CRM, Madlan Pro, Homesale
עולם:  kvCORE, Follow Up Boss, Salesforce RE, LionDesk, Chime
```

### `design-system.md` — שנה צבעים לנדל"ן:
```css
/* Professional Blue/Navy palette for real estate */
--color-primary-800: #1E3A5F;   /* navy deep */
--color-primary-600: #2E5F9E;   /* royal blue */
--color-accent-500:  #C8A028;   /* gold (luxury) */
```

### CRM Entities לנדל"ן:
```typescript
interface Lead {
  id: string;
  full_name: string;
  phone: string;
  budget: { min: number; max: number };
  requirements: PropertyRequirements;
  status: 'new' | 'contacted' | 'viewing' | 'negotiating' | 'closed' | 'lost';
  agent_id: string;
  source: 'yad2' | 'facebook' | 'referral' | 'website' | 'cold';
}

interface Property {
  id: string;
  address: string;
  price: number;
  type: 'apartment' | 'house' | 'commercial' | 'land';
  rooms: number;
  area_sqm: number;
  status: 'available' | 'under_offer' | 'sold';
  agent_id: string;
  images: string[];
}

interface Viewing {
  id: string;
  lead_id: string;
  property_id: string;
  agent_id: string;
  scheduled_at: string;
  status: 'scheduled' | 'completed' | 'cancelled';
  feedback?: string;
  interest_level?: 1 | 2 | 3 | 4 | 5;
}

interface Deal {
  id: string;
  lead_id: string;
  property_id: string;
  agent_id: string;
  sale_price: number;
  commission_rate: number;  /* % */
  commission_amount: number;
  status: 'negotiating' | 'signed' | 'registered';
  signed_at?: string;
}
```

---

## Quick Start — פרויקט חדש ב-5 דקות

```bash
# 1. Clone / Init repo
git init my-crm-project && cd my-crm-project

# 2. צור Next.js app
npx create-next-app@latest . --typescript --tailwind --app

# 3. התקן תלויות
npm install @supabase/ssr @supabase/supabase-js @anthropic-ai/sdk

# 4. shadcn/ui
npx shadcn-ui@latest init
npx shadcn-ui@latest add button card input table badge calendar select dialog

# 5. העתק skills
mkdir -p .claude/skills
cp -r /path/to/source/.claude/skills/* .claude/skills/
cp /path/to/source/.claude/settings.json .claude/settings.json
cp /path/to/source/.claude/SKILLSEXPORT.md .claude/SKILLSEXPORT.md

# 6. התקן Supabase skill
npx skills add supabase/agent-skills

# 7. צור .env.local
echo "NEXT_PUBLIC_SUPABASE_URL=
NEXT_PUBLIC_SUPABASE_ANON_KEY=
SUPABASE_SERVICE_ROLE_KEY=
ANTHROPIC_API_KEY=" > .env.local

# 8. הרץ /init ליצירת CLAUDE.md מותאם
```

---

## הוספת סקיל חדש — נוהל

```bash
# 1. צור קובץ:
touch .claude/skills/my-new-skill.md

# 2. SKILLSEXPORT.md יתעדכן אוטומטית (hook פעיל)

# 3. עדכן CLAUDE.md manually אם צריך
```
