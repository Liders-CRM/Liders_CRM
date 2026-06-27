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
- `claude/onboarding-bonus-features-n12mqu` — שינויי סשן 26/6
- `claude/system-enhancements-roadmap-x1f9b4` — שינויי סשן 27/6

---

## מה בוצע — סשן 27/6/2026

### ✅ הושלם
1. **סוכן מוטיבציה** — כרטיס AI בראש הדשבורד, עד 5 מסרים/יום (`AiLimits` סוג `motivation`)
2. **מדריך הדרכה** — כפתור "ראה איך משתמשים במערכת" → מודל עם 6 שלבי הסבר (ללא סרטון — לא נדרש)
3. **Guided Tour** — סיור 6 שלבים עם spotlight + טולטיפ, מוצג פעם אחת אחרי אונבורדינג (`liders_tour_v1`)
4. **XP Store** — פרסים דיגיטליים/שירותיים בלבד (1,000–50,000 XP): ייעוץ שיווקי → דף נחיתה → תהליך מכירה → תוכן שיווקי → אתר תדמית → CRM מותאם → פרטנר אסטרטגי
5. **קונפטי** — 110 חתיכות + 🏀 סל בסגירת עסקה + 🏆 גביע במיילסטון + 🎯 מטרה בהתקדמות שלב
6. **מחירון AI** — חושב ומיושם (ראה טבלה למטה)
7. **סקר שוק** — בוצע (ראה טבלה למטה)

### 📋 נשאר לביצוע

#### 🔴 גבוה
| # | תכונה | תיאור | תלות |
|---|--------|--------|------|
| 3 | **ניהול מיילים AI** | Gmail MCP → AI מסנן ומגיב: סיווג חשיבות + חסימת ספאם + תגובה לתמיכה | Gmail MCP |

#### 🟢 נמוך
| # | תכונה | תיאור |
|---|--------|--------|
| 4b | **Tranzila webhook** | לאחר מס עוסק + חשבון בנק → לבנות `tranzila-webhook` ולחבר לחבילות AI |
| 6b | **חנות XP נוספת** | עוד מתנות — ה-API מוכן |

#### ⚪ בהמשך
- 20$ Anthropic API → שדרוג ל-Sonnet (ראה חישוב למטה)
- Tranzila live payments

---

## 💰 מחירון AI — חישוב עלות vs. מכסות

### מחיר API: Claude Haiku 4.5
| סוג | Input | Output |
|-----|-------|--------|
| תעריף | $0.80/1M tokens | $4.00/1M tokens |

### עלות ממוצעת לקריאה לפי סוג:
| סוג | Input | Output | עלות |
|-----|-------|--------|------|
| motivation (קצר) | 150 tokens | 120 tokens | ~$0.0006 |
| quicklog (בינוני) | 200 tokens | 200 tokens | ~$0.0010 |
| general (ניתוח) | 300 tokens | 250 tokens | ~$0.0012 |
| support (תמיכה) | 400 tokens | 400 tokens | ~$0.0019 |
| marketing (תוכן) | 500 tokens | 600 tokens | ~$0.0028 |
| **ממוצע משוקלל** | | | **~$0.0015/קריאה** |

### מכסות יומיות vs. עלות חודשית (30% ניצול בפועל):

| חבילה | מחיר | general | marketing | quicklog | support | motivation | עלות API/חודש | מרווח |
|--------|------|---------|-----------|----------|---------|------------|--------------|-------|
| trial | חינם | 2/יום | 3/יום | 3/יום | 2/יום | 3/יום | ~$0.13 | — |
| basic | ₪10 | 5/יום | 8/יום | 15/יום | 8/יום | 5/יום | ~$0.55 | **~80%** |
| pro | ₪20 | 10/יום | 15/יום | 30/יום | 15/יום | 5/יום | ~$1.01 | **~82%** |
| premium | ₪30 | 20/יום | 25/יום | 50/יום | 25/יום | 5/יום | ~$1.69 | **~77%** |

> ₪10 ≈ $2.74 | ₪20 ≈ $5.48 | ₪30 ≈ $8.22 (שער $1=₪3.65)

### בעתיד עם Claude Sonnet ($20 API budget):
Sonnet 4.6: $3/1M input + $15/1M output → **~$0.011/קריאה** (7× יותר יקר)
- basic ₪10: ~3 general, 4 marketing, 8 quicklog, 4 support, 3 motivation
- pro ₪20: ~5 general, 8 marketing, 15 quicklog, 8 support, 5 motivation
- premium ₪30: ~8 general, 12 marketing, 25 quicklog, 12 support, 5 motivation

---

## 🏆 סקר שוק — Liders CRM vs. מתחרות

### טבלת מחירים ($/user/month, מחירי 2025):

| CRM | Starter | Mid | Enterprise | עברית | Mobile | AI מובנה |
|-----|---------|-----|-----------|-------|--------|---------|
| **Liders** | **חינם 30י** | **₪49?** | **₪149?** | ✅ מלאה | ✅ first | ✅ Claude |
| Pipedrive | $14 | $29–49 | $64–99 | ❌ | ⚠️ | ❌ |
| monday CRM | $15 | $20–33 | custom | ⚠️ חלקית | ⚠️ | ⚠️ בסיסי |
| HubSpot | $20 | $100+ | $1,500+ | ❌ | ⚠️ | ✅ ChatGPT |
| Salesforce | $25 | $80 | $165+ | ❌ | ❌ | ✅ Einstein |
| Zoho CRM | $14 | $23–40 | $52+ | ❌ | ⚠️ | ⚠️ Zia |

### היתרונות הייחודיים של Liders:

| יתרון | מה זה אומר |
|--------|-----------|
| 🇮🇱 **עברית מלאה RTL** | היחיד שנבנה לישראלים מהיסוד — לא תרגום |
| 📱 **Mobile-first** | עובד מושלם בנייד — לא desktop שהותאם |
| 🎮 **Gamification** | XP, פרסים, הישגים — לא קיים אצל אף מתחרה |
| 🤖 **Claude AI מובנה** | שיווק, תמיכה, מוטיבציה — ב-Haiku כבר, Sonnet בדרך |
| 🔗 **Make + WhatsApp** | אינטגרציות ישראליות ספציפיות |
| 🏦 **מחשבון משכנתא** | כלי נדל"ן ייחודי — אין לאף אחד |
| 💸 **מחיר** | שליש עד עשירית ממחיר המתחרות |
| 🚀 **פשטות** | לוקח 5 דקות ללמוד — Salesforce לוקח חודשים |

### מסקנה
Liders מתחרה ב-Pipedrive ו-monday.com בתחום ה-SMB. הם גובים $14-33/user/month ואין להם עברית/נייד/AI ספציפי לישראל. **הייחוד שלנו הוא ברור ומשמעותי.** כשנוסיף Tranzila ונקבע מחירים סופיים, ₪49-149/חודש יהיה אטרקטיבי מאוד ביחס לשוק.

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
