# Supabase Security — Liders CRM

## פקודה: `/supabase-security`

RLS policies, auth, secrets, audit לכל טבלאות המערכת.

---

## RLS Policies — טבלאות CRM

### bookings
```sql
-- Enable RLS
ALTER TABLE bookings ENABLE ROW LEVEL SECURITY;

-- לקוחות רואים רק את התורים שלהם (לפי phone)
CREATE POLICY "clients_own_bookings" ON bookings
  FOR SELECT USING (
    phone = current_setting('app.current_phone', true)
  );

-- כתיבה פתוחה לכולם (יצירת תור)
CREATE POLICY "anyone_can_book" ON bookings
  FOR INSERT WITH CHECK (true);

-- admin בלבד יכול לעדכן/מחוק
CREATE POLICY "admin_full_access" ON bookings
  FOR ALL USING (
    auth.jwt() ->> 'role' = 'admin'
  );
```

### services
```sql
ALTER TABLE services ENABLE ROW LEVEL SECURITY;

-- כולם יכולים לקרוא שירותים פעילים
CREATE POLICY "public_read_active_services" ON services
  FOR SELECT USING (active = true);

-- admin בלבד יכול לנהל
CREATE POLICY "admin_manage_services" ON services
  FOR ALL USING (auth.jwt() ->> 'role' = 'admin');
```

### clients
```sql
ALTER TABLE clients ENABLE ROW LEVEL SECURITY;

-- admin only
CREATE POLICY "admin_only_clients" ON clients
  FOR ALL USING (auth.jwt() ->> 'role' = 'admin');
```

---

## Auth Setup

### Admin Authentication
```typescript
// Supabase Auth — admin login
import { createClient } from '@supabase/supabase-js';

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
);

async function adminLogin(pin: string) {
  // hash PIN before comparing
  const { data, error } = await supabase.auth.signInWithPassword({
    email: 'admin@liders.co.il',
    password: pin,
  });
  return { data, error };
}
```

### PIN Security (current implementation)
```javascript
// ⚠️ PIN הנוכחי מאוחסן בלוקל — לשדרוג ל-Supabase Auth
// hash PIN locally before storing
async function hashPin(pin) {
  const encoder = new TextEncoder();
  const data = encoder.encode(pin + 'liders-salt-2025');
  const hash = await crypto.subtle.digest('SHA-256', data);
  return btoa(String.fromCharCode(...new Uint8Array(hash)));
}
```

---

## Secrets Management

### .env.local (לעולם לא commit!)
```bash
NEXT_PUBLIC_SUPABASE_URL=https://xxx.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJhbGci...
SUPABASE_SERVICE_ROLE_KEY=eyJhbGci...  # server-side only
ANTHROPIC_API_KEY=sk-ant-...
MAKE_WEBHOOK_URL=https://hook.eu1.make.com/...
```

### .gitignore חובה
```
.env.local
.env.production
*.key
```

---

## Security Checklist

```
אימות:
□ PIN מוגן עם hash (לא plaintext)
□ Brute force protection (lockout אחרי 5 ניסיונות)
□ Session timeout לאחר 30 דקות

נתונים:
□ RLS פועל על כל הטבלאות
□ אין service_role_key בצד הלקוח
□ Phone numbers masked בלוגים
□ PII fields מוצפנים במנוחה

API:
□ Rate limiting על booking endpoint
□ CORS מוגבל ל-domain הרלוונטי
□ Input validation (phone format, date sanity)

Supabase:
□ Advisors scan עבר ב-get_advisors
□ Extensions מינימליות
□ Webhooks עם secret validation
```

---

## Audit Trail

```sql
-- טבלת audit
CREATE TABLE audit_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  table_name text NOT NULL,
  action text NOT NULL,  -- INSERT, UPDATE, DELETE
  record_id uuid,
  old_data jsonb,
  new_data jsonb,
  user_role text,
  created_at timestamptz DEFAULT now()
);

-- Trigger אוטומטי
CREATE OR REPLACE FUNCTION audit_trigger()
RETURNS trigger AS $$
BEGIN
  INSERT INTO audit_log(table_name, action, record_id, old_data, new_data)
  VALUES (TG_TABLE_NAME, TG_OP, NEW.id, row_to_json(OLD), row_to_json(NEW));
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER bookings_audit
  AFTER INSERT OR UPDATE OR DELETE ON bookings
  FOR EACH ROW EXECUTE FUNCTION audit_trigger();
```
