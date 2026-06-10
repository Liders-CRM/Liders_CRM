# Liders CRM — SaaS Architecture Skill

## פקודה: `/liders-crm`

סקיל זה מספק ארכיטקטורה, entities ו-workflow לבניית features במערכת **Liders CRM** — פלטפורמת SaaS מולטי-טנאנט לניהול לידים ומכירות נדל"ן.

---

## Entities ראשיים

```typescript
interface Tenant {
  id: uuid;
  name: string;           // שם הסוכנות
  slug: string;           // מזהה ייחודי
  plan: 'trial' | 'basic' | 'pro' | 'premium' | 'cancelled';
  trial_ends_at: timestamptz;
  industry: 'real_estate' | 'sales' | 'marketing' | 'other';
  city: string;
  is_active: boolean;
}

interface AgentUser {
  id: uuid;
  tenant_id: uuid;
  auth_user_id: uuid;     // Google OAuth UID
  name: string;
  email: string;
  role: 'owner' | 'admin' | 'agent' | 'viewer';
  is_active: boolean;
}

interface Lead {
  id: uuid;
  tenant_id: uuid;
  agent_id: uuid;
  pipeline_stage_id: uuid;
  name: string;
  phone: string;
  email?: string;
  source: 'yad2' | 'madlan' | 'facebook' | 'instagram' | 'referral' |
          'website' | 'call' | 'whatsapp' | 'email' | 'ad' | 'other';
  status: 'new' | 'contacted' | 'qualified' | 'showing' |
          'offer' | 'closed_won' | 'closed_lost' | 'frozen';
  budget_min?: number;
  budget_max?: number;
  desired_area?: string;
  rooms_min?: number;
  rooms_max?: number;
  urgency: 'low' | 'medium' | 'high' | 'immediate';
  score: number;          // 0–100, AI scoring
  score_reason?: string;
  next_followup?: timestamptz;
  notes: string;
  tags: string[];
}

interface PipelineStage {
  id: uuid;
  tenant_id: uuid;
  name: string;
  color: string;
  order_idx: number;
  is_terminal: boolean;
  is_won: boolean;
}

interface Property {
  id: uuid;
  tenant_id: uuid;
  agent_id: uuid;
  title: string;
  type: 'apartment' | 'house' | 'penthouse' | 'villa' | 'commercial' | 'office' | 'land' | 'other';
  status: 'available' | 'under_offer' | 'sold' | 'rented' | 'off_market' | 'coming_soon';
  price: number;
  area_sqm?: number;
  rooms?: number;
  address: string;
  city: string;
}

interface Task {
  id: uuid;
  tenant_id: uuid;
  agent_id: uuid;
  lead_id?: uuid;
  property_id?: uuid;
  title: string;
  type: 'call' | 'whatsapp' | 'email' | 'showing' | 'offer' | 'meeting' | 'document' | 'other';
  priority: 'low' | 'medium' | 'high' | 'urgent';
  due_date?: timestamptz;
  done: boolean;
}
```

---

## Workflow לבניית Feature חדש

### 1. ניתוח הדרישה
```
- מה ה-entity המרכזי?
- האם נדרשת DB migration?
- האם יש RLS policies עם tenant isolation?
- האם יש automation (Make.com / WhatsApp)?
- האם feature חוצה tenants? (אסור!)
```

### 2. Schema Supabase
```sql
-- כל טבלה חייבת tenant_id + RLS
CREATE TABLE new_feature (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id   uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  agent_id    uuid REFERENCES agent_users(id) ON DELETE SET NULL,
  -- ... שאר הקולומנות
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE new_feature ENABLE ROW LEVEL SECURITY;
CREATE POLICY "tenant isolation" ON new_feature
  FOR ALL
  USING (tenant_id = get_my_tenant_id() AND tenant_access_active())
  WITH CHECK (tenant_id = get_my_tenant_id() AND tenant_access_active());
```

### 3. Auth Flow
```
[Google OAuth] → [Supabase Auth] → [ensure_agent_and_tenant()]
                                    ↓
                            {agent_id, tenant_id, is_new}
                                    ↓
                         [אם is_new → Onboarding wizard]
                         [אם !is_new → Dashboard]
```

### 4. צינור נתונים
```
[דפדפן] → [Supabase JS client + JWT] → [RLS: get_my_tenant_id()]
                                         → [PostgreSQL — רק נתוני הטנאנט]
                 ↓
          [Make.com Webhook] → [WhatsApp / Gmail automations]
```

### 5. Component HTML Pattern
```html
<!-- כל component — RTL, עברית, design tokens -->
<div class="section-block">
  <div class="section-header">
    <h2>כותרת</h2>
    <button class="btn-primary">פעולה</button>
  </div>
  <!-- תוכן -->
</div>
```

---

## Checklist לפני Push

- [ ] tenant_id על כל INSERT
- [ ] RLS policy עם `get_my_tenant_id() AND tenant_access_active()`
- [ ] RTL/עברית תקין
- [ ] Mobile responsive (390px)
- [ ] Supabase migration נכתבה
- [ ] Make.com automation מוגדרת (אם נדרש)
- [ ] Google Auth מוגן (לא PIN)

---

## RPCs ראשיים

| פונקציה | תיאור |
|---------|-------|
| `ensure_agent_and_tenant()` | bootstrap בהתחברות — יוצר tenant חדש אם לא קיים |
| `update_tenant_profile(name, phone, city)` | עדכון פרופיל סוכנות (owner/admin בלבד) |
| `get_my_tenant_id()` | מחזיר tenant_id של המשתמש המחובר |
| `get_my_agent_id()` | מחזיר agent_id של המשתמש המחובר |
| `tenant_access_active()` | בודק האם הטנאנט פעיל (trial/billing) |

---

## Pipeline ברירת מחדל (per new tenant)

| # | שם | צבע |
|---|----|-----|
| 1 | ליד חדש | #94A3B8 אפור |
| 2 | בקשר | #3B82F6 כחול |
| 3 | ביקור נקבע | #8B5CF6 סגול |
| 4 | הצעה הוגשה | #F59E0B כתום |
| 5 | סגירה ✓ | #10B981 ירוק |
