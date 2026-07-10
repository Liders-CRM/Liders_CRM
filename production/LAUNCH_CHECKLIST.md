# PLTO — רשימת משימות להשקה

> עודכן לאחרונה: 10/7/2026 (בדיקת טרום-השקה מקיפה)
> סטטוס: **מוכן ברובו** — נשארו 2 פעולות ידניות בלבד, ראה קטע "נשאר לביצוע ידני"

---

## ✅ אומת חי היום (10/7) — הכל תקין

| # | בדיקה | תוצאה |
|---|-------|--------|
| 1 | `plto.app` עולה בדפדפן | ✅ status 200, `server: cloudflare`, תוכן PLTO אמיתי |
| 2 | `www.plto.app` עולה | ✅ status 200 |
| 3 | `admin.html` חי | ✅ status 200, אין "Liders" בתוכן |
| 4 | `landing.html` חי | ✅ status 200, אין "Liders" בתוכן |
| 5 | `sign.html` חי | ✅ status 200, אין "Liders" בתוכן |
| 6 | Edge Function `ai-proxy` | ✅ ACTIVE, `ALLOWED_ORIGINS` כולל **רק** plto.app + localhost — **liders-crm.com כבר הוסר ונפרס בפועל** (10/7 07:53) |
| 7 | Edge Function `twilio-whatsapp` | ✅ ACTIVE, אותו דבר — כבר הוסר ונפרס |
| 8 | Make.com — שתי הסצנריות | ✅ שמות "PLTO — Lead Notifications" / "PLTO — Trial Expiry Notifications", שתיהן פעילות |
| 9 | מיגרציית 076 (שדות מעקב ליד) | ✅ מוחלת על ה-DB החי |
| 10 | סכימת `leads`/`properties` מול קוד השמירה ב-index.html | ✅ כל שדה שנשמר קיים בפועל בטבלה — `inspiration_url`, `last_contact`, `commission_renewal_date/notes` כולם תואמים |
| 11 | תקינות JS (syntax) ב-index/landing/admin/sign | ✅ `node --check` עבר נקי בכל הקבצים |
| 12 | חיפוש "Liders"/"לידרס" גלוי למשתמש בכל קובצי ה-HTML | ✅ אפס תוצאות (הנותר הוא רק localStorage keys פנימיים ו-ADMIN_EMAILS guard — מתועד ומכוון) |
| 13 | חיפוש שגיאות כתיב ב-"PLTO" (OPLT/PLOT/PTLO וכו') | ✅ אפס תוצאות בכל הריפו |
| 14 | title/meta/OG tags בכל 5 דפי ה-HTML | ✅ כולם "PLTO" נכון, ללא שגיאת כתיב |
| 15 | `assets/screenshots/` (3MB לא בשימוש) | ✅ כבר נמחק |
| 16 | `icons/icon-192.png`, `icon-512.png`, `og-image.jpg` | ✅ כבר הוחלפו למיתוג PLTO |

---

## 🔧 תוקן היום (10/7) — 5 הפרות כלל "ניקוי סימנים רובוטיים"

נמצאו ותוקנו בסקירה הזו (היו קיימים מסשנים קודמים, לא נבדקו עד היום):

| קובץ | מיקום | הבעיה | התיקון |
|------|-------|--------|---------|
| `index.html` | "ראה הכל ←" (widget פרסים) | חץ על span לחיץ | הוסר החץ |
| `index.html` | "מה אנחנו בונים עכשיו ←" (PRO hub) | חץ על div לחיץ | הוסר החץ |
| `index.html` | "לרשימה המלאה ←" (מודל רעיונות) | חץ על span לחיץ | הוסר החץ |
| `index.html` | "לצפייה בדף המדיניות המלא ←" (מודל פרטיות) | חץ על קישור `<a>` | הוסר החץ |
| `landing.html` | סקשן "כאב הליד" | מקף רגיל " - " כסימן עיצובי בטקסט שיווקי | הוחלף בפסיק |

כל 5 התיקונים בוצעו ונדחפו ל-branch זה (`claude/system-testing-pre-launch-3zo30r`).

---

## ⚠️ נמצא ועדיין פתוח — לא תוקן (דורש החלטה/פעולה ידנית)

### 1. כותרות אבטחה (Cloudflare Transform Rule) — עדיין לא פעילות
בדיקה חיה של ה-headers שחוזרים מ-`plto.app` הראתה `strict-transport-security`,
`x-frame-options`, `content-security-policy`, `x-content-type-options` — **כולם ריקים (null)**.
המשמעות: ה-meta CSP וה-frame-busting JS ב-HTML הם עדיין ההגנה **היחידה** בפועל (כמתועד ב-CLAUDE.md).
**פעולה**: לבדוק ב-Cloudflare Dashboard → Rules → Transform Rules שה-rule "Security Headers" אכן
Deployed (לא Draft) ושהוא Modify **Response** Header (לא Request).

### 2. Supabase Auth — leaked password protection כבוי
`get_advisors` (security) מדווח ש-HaveIBeenPwned check לא מופעל להרשמות חדשות.
**פעולה**: Supabase Dashboard → Authentication → Policies → הפעל "Leaked password protection".
לא חוסם השקה, אבל שיפור אבטחה זול וזריז.

### 3. `search_path` לא מוגדר מפורש ב-6 פונקציות DB
`_seat_config`, `_build_referral_agreement_text` (×2), `_commission_label_he`,
`_is_disposable_email`, `_vertical_label_he`, `update_gmail_tokens_updated_at`.
סיכון תיאורטי נמוך (לא ניתן לניצול בפועל ללא הרשאת כתיבה בסכמה), לא חוסם השקה.
**פעולה עתידית**: להוסיף `SET search_path = public` לכל פונקציה.

### 4. Migration 075 (שינוי שמות cron jobs) — עדיין לא הוחלה בפועל
נבדק ישירות מול רשימת המיגרציות החיה ב-DB: יש קפיצה מ-074 ישר ל-076, **075 חסרה**.
תואם למה שכבר תועד ב-CLAUDE.md כ"טרם בוצע" — לא רגרסיה חדשה, רק תזכורת שעדיין פתוחה.
**פעולה**: להריץ את `075_post_domain_rename_crons.sql` ב-SQL Editor.

### 5. הערה קוסמטית בלבד — טבלת `liders_invoices`
שם הטבלה ב-DB עדיין `public.liders_invoices` (לא גלוי למשתמש כלל — רק שם טבלה פנימי ב-schema).
לא דורש פעולה לפני השקה; שינוי שם טבלה חי הוא פעולה מסוכנת שלא כדאי לבצע בלי סיבה עסקית.

---

## 🔴 נשאר לביצוע ידני (לא טכני / לא ניתן לבדיקה מהסשן)

### 1. Supabase Auth — שם השולח במיילים
מתועד ב-CLAUDE.md כבר בוצע בסשן 9/7(ב) ("Sender name עודכן ל-PLTO"). **לא ניתן לאמת מחדש
דרך MCP tools** (אין קריאה ישירה ל-Auth Email Templates) — מומלץ בדיקה ידנית חד-פעמית
בדפדפן: להירשם עם מייל בדיקה ולוודא שם השולח בפועל.

### 2. בדיקה אינטראקטיבית מלאה בדפדפן (E2E)
**מגבלת סביבה**: לסשן הזה אין גישת רשת ישירה לאתרים חיצוניים (רק דרך `pg_net` מ-Supabase,
שמחזיר רק HTML גולמי — לא יכול ללחוץ כפתורים או להריץ JS בדפדפן אמיתי). לכן **לא בוצעה** בדיקת
קליק-דרך אמיתית (הרשמה → אונבורדינג → הוספת ליד → רענון → פייפליין) בסשן הזה.

**המלצה לפני יום ראשון**: לפתוח את `https://plto.app` בדפדפן רגיל ולעבור ידנית על:
- [ ] הרשמה חדשה (מייל + Google OAuth) עד סוף אונבורדינג
- [ ] הוספת ליד → רענון דף → הליד עדיין שם
- [ ] גרירת ליד בין שלבי הפייפליין
- [ ] הוספת נכס/תיק/פרויקט (בדוק גם עם תחום עו"ד ומעצב פנים, לא רק נדל"ן)
- [ ] מודל "הפניה לקולגה" + מודל "לוח ההזדמנויות"
- [ ] מסך שירותי שיווק (genOffer/genPost/genCampaign) — ודא תשובת AI תקינה
- [ ] מצב דמו (`Demo.enter()` / כפתור "צפה בדמו") — טוען נתונים לדוגמה בלי לגעת ב-DB האמיתי
- [ ] כניסה עם סיסמה שגויה לחשבון קיים — לוודא שלא נוצר טננט כפול (מתועד כ-backlog לא-מאומת)

---

## 🟢 עתידי (לא חוסם השקה)

| משימה | מתי |
|-------|-----|
| GitHub repo rename → `plto-crm` | אחרי שהכל יציב |
| Supabase project rename | אחרי שהכל יציב |
| הסר `stripe-webhook` Edge Function | לאחר הטמעת Grow/PayMe |
| Grow/PayMe API keys → `PAYMENTS_LIVE: true` | כשמפתחות מגיעים |
| `search_path` מפורש ב-6 פונקציות DB | ניקיון טכני |
| Leaked password protection ב-Supabase Auth | שיפור אבטחה זול |

---

## 🏗️ מבנה הפרויקט — מה נטען למשתמש

### קבצים שנטענים לדפדפן (GitHub Pages, מאחורי Cloudflare)
| קובץ | תפקיד |
|------|--------|
| `index.html` | כל אפליקציית ה-CRM |
| `landing.html` | דף שיווק |
| `admin.html` | פאנל ניהול SaaS |
| `sign.html` | חתימה דיגיטלית על הסכמי עמלה |
| `privacy-policy.html` | מדיניות פרטיות |
| `sw.js`, `manifest.json` | PWA |
| `icons/` | לוגו + אייקוני PWA + OG image |
| `robots.txt`, `sitemap.xml` | SEO |
| `CNAME` | דומיין GitHub Pages — כרגע `plto.app` |

### Edge Functions פעילים (Supabase)
| Function | תפקיד | סטטוס |
|----------|-------|--------|
| `ai-proxy` | קריאות Claude Haiku | ACTIVE, plto.app בלבד ב-CORS |
| `twilio-whatsapp` | שליחת WhatsApp | ACTIVE, plto.app בלבד ב-CORS, tenant isolation |
| `admin-ops` | פעולות אדמין | ACTIVE — **לא מתועד ב-CLAUDE.md, לבדוק בסשן הבא מה תפקידו** |
| `gmail-oauth-callback` | OAuth Gmail | ACTIVE — **לא מתועד ב-CLAUDE.md** |
| `gmail-proxy` | Gmail API proxy | ACTIVE — **לא מתועד ב-CLAUDE.md** |
| `stripe-webhook` | demo בלבד | ACTIVE — לא ל-production |

> ⚠️ שלוש הפונקציות `admin-ops`, `gmail-oauth-callback`, `gmail-proxy` פעילות ב-production
> אבל **אינן מתועדות בקובץ `CLAUDE.md`** תחת "Supabase Edge Functions". כדאי שהמשתמש יוודא
> שאלו פיצ'רים מכוונים (כנראה תיבת דואר AI שתוכננה ברודמאפ) ולא שאריות בדיקה, ולעדכן תיעוד.

---

## 🔑 משתני סביבה ב-Supabase

| מפתח | סטטוס |
|------|--------|
| `ANTHROPIC_API_KEY` | ✅ מוגדר (ai-proxy) |
| `TWILIO_ACCOUNT_SID` / `TWILIO_AUTH_TOKEN` / `TWILIO_WHATSAPP_FROM` | ✅ מוגדרים |

---

## 🛡️ סקירת אבטחה ממוקדת — הופעלה 10/7 (סוכן, אישור מפורש)

בוצעה סקירה ממוקדת (לא כללית) על הפריט שתועד מאז 4/7 כ"ממתין": RLS/RPCs על טבלאות
ההפניות/הסכמות החדשות, `get_my_tenant_id()`, prompt injection ב-`ai-proxy`, XSS ב-`index.html`.

**תוצאה: אין ממצאים קריטיים או גבוהים.** הזרימות בטוחות להשקה. 2 ממצאים ברמת נמוך בלבד,
לא חוסמי-השקה (over-provisioning עצמי בהזמנת סוכנים, prompt injection מוגבל לפלט AI של
המפנה עצמו) — פירוט מלא ב-CLAUDE.md תחת "סשן 10/7(ב)".

---

## 🔒 אבטחה — סטטוס נוכחי (10/7)

| שכבה | מצב |
|------|-----|
| Cloudflare Proxy | ✅ פעיל, `server: cloudflare` מאומת חי |
| meta CSP (per-page) | ✅ בכל דף |
| Frame-busting JS | ✅ index + admin |
| RLS Supabase | ✅ כל הטבלאות (`rls_enabled: true` על כל 27 הטבלאות) |
| Edge Function CORS | ✅ plto.app בלבד, liders-crm.com הוסר בפועל |
| Cloudflare Transform Rule (headers אמיתיים) | ⚠️ עדיין לא פעיל בפועל — ראה סעיף "נמצא ועדיין פתוח" #1 |
| Leaked password protection | ⚠️ כבוי — ראה סעיף #2 |

---

## 💳 תשלומים (PAYMENTS_LIVE: false)

> **לא גובים כסף אמיתי** עד שמוגדר Grow/PayMe.
> ספק: **Grow (PayMe API)** — מפתחות מגיעים בקרוב.
> Stripe קיים בקוד כ-demo בלבד.

---

## 📧 מיילים

| שימוש | כתובת |
|-------|--------|
| הודעות אוטומטיות / Make.com | `info@plto.app` |
| Auth Supabase (login) | `elgrablidudu@gmail.com` |
| Gmail Forwarding → info@plto.app | `liders.crm@gmail.com` |
