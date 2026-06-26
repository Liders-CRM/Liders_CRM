# CLAUDE.md — Liders CRM

## 🔒 כשמעדכנים חבילות CDN — חובה לעדכן SRI

כאשר מעדכנים את Supabase או Chart.js:
1. `cd /tmp/sri_work && npm install @supabase/supabase-js@<VER> chart.js@<VER>`
2. חשב hash: `cat node_modules/@supabase/supabase-js/dist/umd/supabase.js | openssl dgst -sha384 -binary | openssl base64 -A`
3. עדכן את `integrity="sha384-..."` ב-index.html (שתי שורות בתחילת ה-`<body>` תחת CSS)

גרסאות נוכחיות: supabase-js@**2.108.2**, chart.js@**4.5.1**

---

## 🚨 LAUNCH BLOCKER — חובה להזכיר בכל שיחה

> **ספק התשלום הוא Tranzila (ישראלי) — לא Stripe**
> - Stripe קיים בקוד כ-**demo בלבד** (edge function `stripe-webhook`) — אל תבנה/תשנה עליו
> - ממתינים לפתיחת מס עוסק מורשה + חשבון בנק עסקי (~יוני 2026)
> - כשיהיו מוכנים: לבנות `tranzila-webhook` edge function בפורמט Tranzila ולחבר
>
> 🔑 **לא גובים כסף אמיתי עד שהוגדר Tranzila live**

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

## קישורים חיים

| | URL |
|-|-----|
| CRM (לקוחות) | https://liders-crm.com/ |
| פאנל אדמין | https://liders-crm.com/admin.html |

> האדמין מחובר לאותה Supabase. כניסה: אימייל + סיסמה. קישור אליו גם מתוך הגדרות ה-CRM.

---

## Make.com

- **Team ID**: `1851801`
- **Zone**: `eu1.make.com`
- **Webhook URL**: `https://hook.eu1.make.com/f0nzngm6gdokri5naqu7enbay538ay8i`

### סצנריות פעילות

| סצנריו | ID | קישור | טריגר |
|--------|-----|-------|-------|
| Lead Notifications | 6083347 | https://eu1.make.com/1851801/scenarios/6083347/edit | Webhook |
| Trial Expiry Notifications | 6185659 | https://eu1.make.com/1851801/scenarios/6185659/edit | Scheduled (24h) |

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
admin.html     — פאנל SaaS admin (ניהול tenants)
CLAUDE.md      — קובץ זה
supabase/
  functions/
    ai-proxy/         — Edge Function: ממשק ל-Claude Haiku (ANTHROPIC_API_KEY)
    stripe-webhook/   — Edge Function: demo בלבד — אל תפעיל ב-production
.claude/
  settings.json
  skills/
```

### Supabase Edge Functions

| Function | תיאור | סטטוס |
|----------|-------|-------|
| `ai-proxy` | קריאה ל-Claude Haiku 4.5 | פעיל ✅ |
| `stripe-webhook` | demo/test בלבד | demo ⚠️ |

**ANTHROPIC_API_KEY** מוגדר ב-Supabase Secrets. מודל נוכחי: `claude-haiku-4-5-20251001`.
מדרג עלויות: Haiku → Sonnet כשיש הכנסות.

---

## Marketing Addon

| נושא | פרטים |
|------|--------|
| State | `State.tenant.marketing_addon === true` |
| הפעלה ידנית | Admin → modal ניהול tenant → checkbox שיווק |
| הפעלה אוטומטית | Tranzila webhook → `marketing_addon: true` (עתידי) |
| כלים | `Marketing.genOffer()`, `genPost()`, `genCampaign()` — Claude Haiku |
| מחיר | ₪100/חודש לתוסף |
| Payment Link URL | `Marketing._STRIPE_MARKETING_URL` ב-index.html — ריק עד שיוגדר Tranzila |

---

## מה בוצע — סשן 26/6/2026

### ✅ הושלם
1. **Onboarding Step 2** — שדות שם/טלפון/אימייל/עסק ריקים עם placeholder
2. **Onboarding Step 4** — קישור "אפשר לדלג" מתחת לשדה Webhook
3. **Onboarding Step 5** — 3 כפתורי פעולה, כפתור 🚀 מוסתר בשלב האחרון
4. **PIN lock** — הגדרת PIN + מסך נעילה אחרי setup (תוקן: `lock()` נקרא אוטומטית)
5. **admin.html** — עמודת שיווק בטבלה, modal ניהול tenant עם checkbox/הארכת ניסיון/הערות
6. **Claude AI בשיווק** — genOffer/genPost/genCampaign קוראים ל-ai-proxy (לא עוד תבניות)
7. **auto-activate marketing addon** — stripe-webhook מטפל ב-`addon: marketing` (demo)

### 📋 ממתין לפעולה חיצונית
- פתיחת מס עוסק + חשבון בנק → לאחר מכן: Tranzila live + `tranzila-webhook`
- Deploy של `stripe-webhook` לאחר שינויים (Supabase Dashboard → Functions)
- הגדרת `Marketing._STRIPE_MARKETING_URL` כשיהיה Payment Link

### 🔧 ענף עבודה
- `claude/onboarding-bonus-features-n12mqu` — כל השינויים מהסשן

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
