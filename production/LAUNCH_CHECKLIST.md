# PLTO — רשימת משימות להשקה

> עודכן לאחרונה: 9/7/2026
> סטטוס: **כמעט מוכן** — ראה קטע "נשאר לביצוע ידני"

---

## ✅ הושלם (טכני)

| # | משימה | סטטוס |
|---|-------|--------|
| 1 | DNS — `plto.app` מוזנן ל-Cloudflare, `cf-ray` מוחזר | ✅ |
| 2 | קובץ `CNAME` עודכן ל-`plto.app` (PR #48) | ✅ |
| 3 | Edge Function `ai-proxy` — v27, כולל `plto.app` ב-ALLOWED_ORIGINS | ✅ |
| 4 | Edge Function `twilio-whatsapp` — v14, כולל `plto.app` ב-ALLOWED_ORIGINS | ✅ |
| 5 | Migration 074 — ריבראנד PLTO בפונקציות DB | ✅ |
| 6 | Migration 075 — crons שונמו ל-`plto-*` | ✅ |
| 7 | ריבראנד מלא HTML/JS (index, landing, admin, sign, privacy-policy) | ✅ |
| 8 | `manifest.json` → `"name": "PLTO"` | ✅ |
| 9 | `sw.js` → cache key `plto-v1` | ✅ |
| 10 | RLS מחוזק ל-`shared_leads` (migration 070) | ✅ |
| 11 | תיקון `inspiration_url` בטבלת leads (migration 071) | ✅ |
| 12 | תיקון שמירת `last_contact` ב-DB בשלושה מקומות | ✅ |
| 13 | `twilio-whatsapp` — תיקון PostgREST filter injection | ✅ |
| 14 | Cloudflare SSL mode — Full (Strict) + Always Use HTTPS | ✅ |
| 15 | meta CSP בכל דף (index, admin, landing) | ✅ |
| 16 | Frame-busting JS (index + admin) | ✅ |

---

## 🔴 נשאר לביצוע ידני (חובה לפני שיווק)

### 1. אימות שה-SSL של GitHub Pages עלה
אחרי שינוי CNAME (בוצע היום), GitHub Pages מפיק תעודת Let's Encrypt.
תהליך זה לוקח 2–10 דקות.

**איך לאמת** (דרך Supabase SQL Editor — לא curl):
```sql
SELECT net.http_get('https://plto.app/') AS req_id;
-- ואז:
SELECT status_code, headers->>'server' AS server
FROM net._http_response WHERE id = <req_id>;
-- מצפים: status_code = 200, server = 'cloudflare'
```

### 2. Supabase Auth — שם השולח במיילים
- Supabase Dashboard → Authentication → Email Templates
- שנה שם השולח מ-"Liders CRM" ל-**"PLTO"**
- חל על: Confirm signup, Magic Link, Password Reset

### 3. Make.com — עדכון 2 סצנריות
- https://eu1.make.com/1851801/scenarios/6083347/edit (Lead Notifications)
- https://eu1.make.com/1851801/scenarios/6185659/edit (Trial Expiry Notifications)
- **שנה**: שם + נמען → `info@plto.app`

---

## 🟡 לביצוע אחרי אימות שה-site עולה

| משימה | הסבר |
|-------|-------|
| הסר `liders-crm.com` מ-ALLOWED_ORIGINS | בשתי Edge Functions (ai-proxy, twilio-whatsapp) — רק אחרי שplto.app מאושר |
| מחק `assets/screenshots/` מהריפו | 3MB שלא נטענים לשום משתמש — ראה הסבר למטה |
| החלף `icons/icon-192.png` ו-`icons/icon-512.png` | הלוגו עדיין ישן — להחליף עם PLTO branding |
| החלף `icons/og-image.jpg` | תמונת שיתוף ברשתות חברתיות — צריכה לשקף מיתוג PLTO |

---

## 🟢 עתידי (לא חוסם השקה)

| משימה | מתי |
|-------|-----|
| GitHub repo rename → `plto-crm` | אחרי שהכל יציב |
| Supabase project rename | אחרי שהכל יציב |
| הסר `stripe-webhook` Edge Function | לאחר הטמעת Grow/PayMe |
| Grow/PayMe API keys → `PAYMENTS_LIVE: true` | כשמפתחות מגיעים |

---

## 🏗️ מבנה הפרויקט — מה נטען למשתמש

### קבצים שנטענים לדפדפן (GitHub Pages)
| קובץ | גודל | תפקיד |
|------|------|--------|
| `index.html` | 1.1MB | כל אפליקציית ה-CRM |
| `landing.html` | 148K | דף שיווק |
| `admin.html` | 88K | פאנל ניהול SaaS |
| `sign.html` | 24K | חתימה דיגיטלית |
| `privacy-policy.html` | ~12K | מדיניות פרטיות |
| `sw.js` | 4K | Service Worker (PWA) |
| `manifest.json` | 4K | PWA manifest |
| `icons/favicon.svg` | 4K | אייקון טאב |
| `icons/logo.svg` | 4K | לוגו |
| `icons/icon-192.png` | 4K | PWA icon |
| `icons/icon-512.png` | 8K | PWA icon גדול |
| `icons/og-image.jpg` | 48K | OG image |
| `robots.txt` | <1K | SEO |
| `sitemap.xml` | <1K | SEO |
| `CNAME` | <1K | GitHub Pages domain |

### קבצים שאינם נטענים לדפדפן (רק בריפו)
| קובץ/תיקייה | הערה |
|--------------|------|
| `supabase/` | Edge Functions + מיגרציות DB |
| `.claude/` | כלי פיתוח |
| `.github/` | CI/CD GitHub Actions |
| `assets/screenshots/` | **3MB שלא בשימוש** — למחיקה |
| `demo_leads.csv` | נתוני פיתוח בלבד |
| `insert_demo_leads.sql` | נתוני פיתוח בלבד |
| `make_blueprint.json` | קונפיגורציית Make.com |
| `_headers` | **GitHub Pages מתעלם** — Netlify בלבד |
| `CLAUDE.md` | הוראות AI |
| `FEATURE_PLANS.md` | רודמאפ |
| `WHATSAPP_ARCHITECTURE.md` | תיעוד ארכיטקטורה |

---

## ⚠️ `assets/screenshots/` — למה למחוק

```
dashboard-desktop.png    1.4MB
prohub-desktop.png       656K
pipeline-desktop.png     352K
lead-detail-tall.png     476K
calendar-desktop.png      84K
סה"כ:                   ~3MB
```

**לא** מוזכרים ב-`manifest.json` (screenshots: []).
**לא** מוזכרים בשום HTML, JS, או JSON.
**לא** נטענים לשום משתמש.

למחיקה:
```bash
git rm -r assets/screenshots/
git commit -m "chore: remove unused PWA screenshots (3MB saved)"
git push
```

---

## 🔑 משתני סביבה ב-Supabase (כולם מוגדרים)

| מפתח | סטטוס | Edge Function |
|------|--------|---------------|
| `ANTHROPIC_API_KEY` | ✅ מוגדר | ai-proxy |
| `SUPABASE_URL` | ✅ אוטומטי | שתיהן |
| `SUPABASE_ANON_KEY` | ✅ אוטומטי | שתיהן |
| `TWILIO_ACCOUNT_SID` | ✅ מוגדר | twilio-whatsapp |
| `TWILIO_AUTH_TOKEN` | ✅ מוגדר | twilio-whatsapp |
| `TWILIO_WHATSAPP_FROM` | ✅ מוגדר | twilio-whatsapp |

---

## 🔒 אבטחה — סטטוס נוכחי

| שכבה | מצב |
|------|-----|
| Cloudflare Proxy | ✅ פעיל |
| SSL Full (Strict) | ✅ מופעל |
| HTTPS Redirect | ✅ Always Use HTTPS |
| CSP (meta per-page) | ✅ בכל דף |
| Frame-busting JS | ✅ index + admin |
| RLS Supabase | ✅ כל הטבלאות |
| Webhook HMAC | ✅ stripe-webhook (constant-time) |
| Tenant isolation WA | ✅ twilio-whatsapp (`.in()`) |
| Security Headers (Cloudflare Transform) | ⚠️ לאמת שה-Rule פעיל |

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
