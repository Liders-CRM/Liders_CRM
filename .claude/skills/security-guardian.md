# Security Guardian — Liders CRM

## פקודה: `/security-guardian`

הגנת data, checklist אבטחה, incident response.

---

## Data Classification

| נתון | רמת רגישות | הגנה נדרשת |
|------|-----------|-----------|
| שמות לקוחות / ליד | רגיש | RLS + לא מוצג בלוגים |
| מספרי טלפון | גבוה מאוד | RLS + masking בלוגים |
| ערך עסקה / תקציב | גבוה | RLS + tenant isolation |
| הערות פנימיות על ליד | רגיש | RLS — tenant בלבד |
| PIN admin | קריטי | bcrypt hash + rate limit |
| API keys | קריטי | .env only, לעולם לא ב-git |
| shared_leads PIN | קריטי | bcrypt + max 5 attempts |

---

## Security Checklist — Daily

```
□ אין API keys ב-git history (git log --all -p | grep "sk-")
□ .env.local ב-.gitignore
□ Supabase advisors scan נקי (mcp: get_advisors)
□ PIN לא '1234' (default)
□ Admin session expires
```

## Security Checklist — Pre-Deploy

```
□ RLS enabled על כל הטבלאות (leads, shared_leads, agent_users, tenants)
□ service_role_key לא נחשף לצד הלקוח
□ Input sanitization (XSS prevention)
□ HTTPS בלבד
□ Rate limiting על RPCs
□ CORS מוגדר
□ Secrets ב-Supabase Vault (לא ב-DB)
□ Webhook secret validation
□ Error messages לא חושפים stack traces
□ Shared leads — כל RPC מוגדר SECURITY DEFINER
□ get_my_tenant_id() נקרא בכל RPC לפני פעולה
```

---

## Threat Model — Liders CRM

### Attack Vectors

#### 1. Cross-Tenant Data Leak
```
ריסק: טנאנט A רואה לידים של טנאנט B
מניעה:
- RLS על כל טבלה עם get_my_tenant_id()
- כל RPC מוגדר SECURITY DEFINER עם בדיקת tenant
- אין direct table write — הכל דרך RPCs
```

#### 2. Shared Lead PIN Brute Force
```
ריסק: ניחוש PIN של שיתוף ליד
מניעה:
- max 5 ניסיונות → share נעול אוטומטית
- PIN מאוחסן כ-bcrypt hash (לא plaintext)
- בעל השיתוף חייב ליצור share חדש לאחר נעילה
```

#### 3. Unauthorized Admin Access
```
ריסק: גישה לפאנל אדמין SaaS
מניעה:
- אימות אימייל בלבד (liders.crm@gmail.com / elgrablidudu@gmail.com)
- RPCs מגבילים גישה ל-2 כתובות
- Session timeout
```

#### 4. XSS via Notes Field
```
ריסק: הזרקת script בהערות ליד
מניעה:
- Sanitize הערות לפני הצגה
- innerHTML → textContent
- CSP headers ב-_headers
```

---

## Incident Response

### ליד נמחק בטעות
```bash
# 1. בדוק Supabase Dashboard → Database → Backups
# Point-in-time recovery
# 2. שחזר מ-backup לפי timestamp
```

### חשד לפריצה
```bash
# 1. נעל מיידית
# Supabase Dashboard → Auth → Disable signups

# 2. בדוק לוגים
# mcp: get_logs (service='auth')

# 3. שנה כל הסיסמאות/keys
# Supabase → Settings → API → Regenerate keys

# 4. בדוק shared_leads עם status='active' חשוד
SELECT * FROM shared_leads WHERE created_at > now() - interval '24 hours';
```

### API Key נחשף
```bash
# 1. מיידי — revoke ב-Supabase Dashboard
# 2. Generate key חדש
# 3. Update .env.local ועדכן deploy
# 4. git log בדיקה: git log --all -p | grep "eyJhbGci"
# 5. אם ב-git history: BFG Repo Cleaner
```

---

## Privacy (חוק הגנת הפרטיות הישראלי)

```
□ יידוע לקוחות על שמירת נתונים בליד
□ זכות למחיקה — tenant יכול למחוק לידים
□ לא שומרים נתונים מעבר לנדרש
□ מספרי טלפון לא מועברים לצד שלישי ללא הסכמה
□ shared_leads — רק snapshot ספציפי, לא גישה לכלל הנתונים
```
