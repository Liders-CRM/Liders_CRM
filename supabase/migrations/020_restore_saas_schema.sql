-- ══════════════════════════════════════════════════════════════════════════════
-- Migration 020: restore_saas_schema
--
-- Drops the simple Liders CRM tables (leads/crm_settings/admin_auth) and
-- recreates the full SaaS schema: tenants, agent_users, pipeline_stages,
-- leads (multi-tenant), properties, tasks, showings, activities, audit_log.
-- Incorporates all hardening from migrations 011–019.
-- ══════════════════════════════════════════════════════════════════════════════

-- ── 0. Drop simple CRM artifacts ─────────────────────────────────────────────
DROP TABLE IF EXISTS leads        CASCADE;
DROP TABLE IF EXISTS crm_settings CASCADE;
DROP TABLE IF EXISTS admin_auth   CASCADE;
DROP SEQUENCE IF EXISTS leads_id_seq CASCADE;

DROP FUNCTION IF EXISTS public.verify_admin_pin(text)               CASCADE;
DROP FUNCTION IF EXISTS public.save_crm_settings(text,text,text,text) CASCADE;

-- ── 1. Extensions ─────────────────────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ── 2. TENANTS ────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS tenants (
  id                     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name                   text NOT NULL,
  slug                   text UNIQUE NOT NULL,
  logo_url               text,
  primary_color          text DEFAULT '#1C3E6B',
  phone                  text,
  whatsapp_number        text,
  make_webhook_url       text,
  plan                   text NOT NULL DEFAULT 'trial'
                         CHECK (plan IN ('trial','basic','pro','premium','cancelled')),
  plan_expires_at        timestamptz,
  trial_ends_at          timestamptz DEFAULT (now() + interval '30 days'),
  billing_email          text,
  stripe_customer_id     text,
  stripe_subscription_id text,
  industry               text DEFAULT 'real_estate'
                         CHECK (industry IN ('real_estate','sales','marketing','other')),
  city                   text,
  country                text DEFAULT 'IL',
  is_active              boolean NOT NULL DEFAULT true,
  created_at             timestamptz NOT NULL DEFAULT now(),
  updated_at             timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE tenants ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS tenants_updated_at ON tenants;
CREATE TRIGGER tenants_updated_at
  BEFORE UPDATE ON tenants FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP POLICY IF EXISTS "service role full access" ON tenants;
CREATE POLICY "service role full access" ON tenants
  FOR ALL TO service_role USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "anon no access" ON tenants;
CREATE POLICY "anon no access" ON tenants FOR ALL TO anon USING (false);

-- ── 3. AGENT_USERS ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS agent_users (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id    uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  auth_user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  name         text NOT NULL,
  email        text NOT NULL,
  phone        text,
  role         text NOT NULL DEFAULT 'agent'
               CHECK (role IN ('owner','admin','agent','viewer')),
  avatar_url   text,
  is_active    boolean NOT NULL DEFAULT true,
  last_login   timestamptz,
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, email)
);

CREATE INDEX IF NOT EXISTS idx_agent_users_tenant    ON agent_users(tenant_id);
CREATE INDEX IF NOT EXISTS idx_agent_users_auth_user ON agent_users(auth_user_id);
CREATE UNIQUE INDEX IF NOT EXISTS agent_users_auth_user_id_unique
  ON agent_users (auth_user_id) WHERE auth_user_id IS NOT NULL;

ALTER TABLE agent_users ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION get_my_tenant_id()
RETURNS uuid AS $$
  SELECT tenant_id FROM agent_users WHERE auth_user_id = auth.uid() LIMIT 1;
$$ LANGUAGE sql STABLE SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_my_agent_id()
RETURNS uuid AS $$
  SELECT id FROM agent_users WHERE auth_user_id = auth.uid() LIMIT 1;
$$ LANGUAGE sql STABLE SECURITY DEFINER;

DROP POLICY IF EXISTS "agents in same tenant" ON agent_users;
CREATE POLICY "agents in same tenant" ON agent_users
  FOR ALL
  USING (tenant_id = get_my_tenant_id())
  WITH CHECK (tenant_id = get_my_tenant_id());

DROP TRIGGER IF EXISTS agent_users_updated_at ON agent_users;
CREATE TRIGGER agent_users_updated_at
  BEFORE UPDATE ON agent_users FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ── 4. PIPELINE_STAGES ────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS pipeline_stages (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id   uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  name        text NOT NULL,
  color       text NOT NULL DEFAULT '#94A3B8',
  order_idx   integer NOT NULL DEFAULT 1,
  is_terminal boolean NOT NULL DEFAULT false,
  is_won      boolean NOT NULL DEFAULT false,
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_pipeline_stages_tenant ON pipeline_stages(tenant_id, order_idx);
ALTER TABLE pipeline_stages ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION tenant_access_active()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = 'public' AS $$
  SELECT CASE
    WHEN t.plan = 'cancelled' THEN false
    WHEN t.plan = 'trial'     THEN (t.trial_ends_at IS NULL OR now() <= t.trial_ends_at)
    ELSE true
  END
  FROM tenants t WHERE t.id = get_my_tenant_id();
$$;
REVOKE EXECUTE ON FUNCTION public.tenant_access_active() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.tenant_access_active() FROM anon;
GRANT  EXECUTE ON FUNCTION public.tenant_access_active() TO authenticated;

DROP POLICY IF EXISTS "tenant isolation" ON pipeline_stages;
CREATE POLICY "tenant isolation" ON pipeline_stages
  FOR ALL
  USING (tenant_id = get_my_tenant_id() AND tenant_access_active())
  WITH CHECK (tenant_id = get_my_tenant_id() AND tenant_access_active());

-- ── 5. LEADS (multi-tenant) ───────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS leads (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id         uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  agent_id          uuid REFERENCES agent_users(id) ON DELETE SET NULL,
  pipeline_stage_id uuid REFERENCES pipeline_stages(id) ON DELETE SET NULL,
  name              text NOT NULL,
  phone             text NOT NULL,
  email             text,
  source            text NOT NULL DEFAULT 'other'
                    CHECK (source IN ('yad2','madlan','facebook','instagram','referral',
                                      'website','call','whatsapp','email','ad','other')),
  status            text NOT NULL DEFAULT 'new'
                    CHECK (status IN ('new','contacted','qualified','showing',
                                      'offer','closed_won','closed_lost','frozen')),
  budget_min        numeric(14,2),
  budget_max        numeric(14,2),
  desired_area      text,
  rooms_min         numeric(3,1),
  rooms_max         numeric(3,1),
  property_type     text,
  urgency           text DEFAULT 'medium'
                    CHECK (urgency IN ('low','medium','high','immediate')),
  score             integer NOT NULL DEFAULT 50 CHECK (score BETWEEN 0 AND 100),
  score_reason      text,
  last_contact      timestamptz,
  next_followup     timestamptz,
  followup_count    integer NOT NULL DEFAULT 0,
  notes             text DEFAULT '',
  tags              text[] DEFAULT '{}',
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_leads_tenant        ON leads(tenant_id);
CREATE INDEX IF NOT EXISTS idx_leads_agent         ON leads(agent_id);
CREATE INDEX IF NOT EXISTS idx_leads_stage         ON leads(pipeline_stage_id);
CREATE INDEX IF NOT EXISTS idx_leads_status        ON leads(tenant_id, status);
CREATE INDEX IF NOT EXISTS idx_leads_next_followup ON leads(tenant_id, next_followup)
  WHERE status NOT IN ('closed_won','closed_lost');

ALTER TABLE leads ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "tenant isolation" ON leads;
CREATE POLICY "tenant isolation" ON leads
  FOR ALL
  USING (tenant_id = get_my_tenant_id() AND tenant_access_active())
  WITH CHECK (tenant_id = get_my_tenant_id() AND tenant_access_active());

DROP TRIGGER IF EXISTS leads_updated_at ON leads;
CREATE TRIGGER leads_updated_at
  BEFORE UPDATE ON leads FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ── 6. PROPERTIES ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS properties (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id        uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  agent_id         uuid REFERENCES agent_users(id) ON DELETE SET NULL,
  title            text NOT NULL,
  type             text NOT NULL DEFAULT 'apartment'
                   CHECK (type IN ('apartment','house','penthouse','villa',
                                   'commercial','office','land','other')),
  status           text NOT NULL DEFAULT 'available'
                   CHECK (status IN ('available','under_offer','sold','rented',
                                     'off_market','coming_soon')),
  price            numeric(14,2) NOT NULL,
  price_negotiable boolean DEFAULT true,
  area_sqm         numeric(8,2),
  rooms            numeric(3,1),
  bathrooms        integer,
  floor            integer,
  total_floors     integer,
  parking          integer DEFAULT 0,
  storage          boolean DEFAULT false,
  address          text NOT NULL,
  city             text NOT NULL,
  neighborhood     text,
  zip_code         text,
  lat              numeric(10,7),
  lng              numeric(10,7),
  description      text DEFAULT '',
  amenities        text[] DEFAULT '{}',
  photos           text[] DEFAULT '{}',
  virtual_tour_url text,
  yad2_url         text,
  madlan_url       text,
  listed_at        date DEFAULT CURRENT_DATE,
  sold_at          date,
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_properties_tenant ON properties(tenant_id);
CREATE INDEX IF NOT EXISTS idx_properties_status ON properties(tenant_id, status);
CREATE INDEX IF NOT EXISTS idx_properties_city   ON properties(tenant_id, city);
CREATE INDEX IF NOT EXISTS idx_properties_price  ON properties(tenant_id, price);

ALTER TABLE properties ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "tenant isolation" ON properties;
CREATE POLICY "tenant isolation" ON properties
  FOR ALL
  USING (tenant_id = get_my_tenant_id() AND tenant_access_active())
  WITH CHECK (tenant_id = get_my_tenant_id() AND tenant_access_active());

DROP TRIGGER IF EXISTS properties_updated_at ON properties;
CREATE TRIGGER properties_updated_at
  BEFORE UPDATE ON properties FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ── 7. TASKS ──────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS tasks (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id   uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  agent_id    uuid REFERENCES agent_users(id) ON DELETE SET NULL,
  lead_id     uuid REFERENCES leads(id) ON DELETE CASCADE,
  property_id uuid REFERENCES properties(id) ON DELETE SET NULL,
  title       text NOT NULL,
  type        text NOT NULL DEFAULT 'other'
              CHECK (type IN ('call','whatsapp','email','showing',
                              'offer','meeting','document','other')),
  priority    text NOT NULL DEFAULT 'medium'
              CHECK (priority IN ('low','medium','high','urgent')),
  due_date    timestamptz,
  done        boolean NOT NULL DEFAULT false,
  done_at     timestamptz,
  notes       text DEFAULT '',
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_tasks_tenant ON tasks(tenant_id);
CREATE INDEX IF NOT EXISTS idx_tasks_agent  ON tasks(agent_id);
CREATE INDEX IF NOT EXISTS idx_tasks_lead   ON tasks(lead_id);
CREATE INDEX IF NOT EXISTS idx_tasks_due    ON tasks(tenant_id, due_date) WHERE done = false;

ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "tenant isolation" ON tasks;
CREATE POLICY "tenant isolation" ON tasks
  FOR ALL
  USING (tenant_id = get_my_tenant_id() AND tenant_access_active())
  WITH CHECK (tenant_id = get_my_tenant_id() AND tenant_access_active());

DROP TRIGGER IF EXISTS tasks_updated_at ON tasks;
CREATE TRIGGER tasks_updated_at
  BEFORE UPDATE ON tasks FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ── 8. SHOWINGS ───────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS showings (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  agent_id        uuid REFERENCES agent_users(id) ON DELETE SET NULL,
  lead_id         uuid NOT NULL REFERENCES leads(id) ON DELETE CASCADE,
  property_id     uuid NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
  scheduled_at    timestamptz NOT NULL,
  duration_min    integer DEFAULT 30,
  status          text NOT NULL DEFAULT 'scheduled'
                  CHECK (status IN ('scheduled','completed','cancelled','no_show','rescheduled')),
  feedback        text,
  interest_level  integer CHECK (interest_level BETWEEN 1 AND 5),
  next_action     text,
  google_event_id text,
  notes           text DEFAULT '',
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_showings_tenant   ON showings(tenant_id);
CREATE INDEX IF NOT EXISTS idx_showings_lead     ON showings(lead_id);
CREATE INDEX IF NOT EXISTS idx_showings_property ON showings(property_id);
CREATE INDEX IF NOT EXISTS idx_showings_date     ON showings(tenant_id, scheduled_at);

ALTER TABLE showings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "tenant isolation" ON showings;
CREATE POLICY "tenant isolation" ON showings
  FOR ALL
  USING (tenant_id = get_my_tenant_id() AND tenant_access_active())
  WITH CHECK (tenant_id = get_my_tenant_id() AND tenant_access_active());

DROP TRIGGER IF EXISTS showings_updated_at ON showings;
CREATE TRIGGER showings_updated_at
  BEFORE UPDATE ON showings FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ── 9. ACTIVITIES ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS activities (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id   uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  agent_id    uuid REFERENCES agent_users(id) ON DELETE SET NULL,
  lead_id     uuid REFERENCES leads(id) ON DELETE CASCADE,
  property_id uuid REFERENCES properties(id) ON DELETE SET NULL,
  showing_id  uuid REFERENCES showings(id) ON DELETE SET NULL,
  task_id     uuid REFERENCES tasks(id) ON DELETE SET NULL,
  type        text NOT NULL
              CHECK (type IN ('call','whatsapp','email','showing','note',
                              'stage_change','task_done','deal_closed',
                              'lead_created','ai_score','other')),
  content     text NOT NULL,
  metadata    jsonb DEFAULT '{}',
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_activities_tenant ON activities(tenant_id);
CREATE INDEX IF NOT EXISTS idx_activities_lead   ON activities(lead_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_activities_agent  ON activities(agent_id);
CREATE INDEX IF NOT EXISTS idx_activities_type   ON activities(tenant_id, type, created_at DESC);

ALTER TABLE activities ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "tenant isolation" ON activities;
CREATE POLICY "tenant isolation" ON activities
  FOR ALL
  USING (tenant_id = get_my_tenant_id() AND tenant_access_active())
  WITH CHECK (tenant_id = get_my_tenant_id() AND tenant_access_active());

CREATE OR REPLACE FUNCTION log_lead_stage_change()
RETURNS TRIGGER AS $$
BEGIN
  IF OLD.pipeline_stage_id IS DISTINCT FROM NEW.pipeline_stage_id THEN
    INSERT INTO activities (tenant_id, agent_id, lead_id, type, content, metadata)
    VALUES (NEW.tenant_id, NEW.agent_id, NEW.id, 'stage_change', 'שלב הועבר',
            jsonb_build_object('old_stage', OLD.pipeline_stage_id, 'new_stage', NEW.pipeline_stage_id));
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS lead_stage_change_log ON leads;
CREATE TRIGGER lead_stage_change_log
  AFTER UPDATE ON leads FOR EACH ROW EXECUTE FUNCTION log_lead_stage_change();

-- ── 10. AUDIT_LOG ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS audit_log (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id   uuid,
  agent_id    uuid,
  action      text NOT NULL,
  entity_type text,
  entity_id   uuid,
  old_value   jsonb,
  new_value   jsonb,
  ip_address  inet,
  user_agent  text,
  created_at  timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE audit_log ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "service role only" ON audit_log;
CREATE POLICY "service role only" ON audit_log
  FOR ALL TO service_role USING (true) WITH CHECK (true);

-- ── 11. Permissions ───────────────────────────────────────────────────────────
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM anon;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- ── 12. Views ─────────────────────────────────────────────────────────────────
DROP MATERIALIZED VIEW IF EXISTS lead_score_summary;
CREATE MATERIALIZED VIEW lead_score_summary AS
SELECT
  tenant_id,
  COUNT(*) FILTER (WHERE score >= 80)             AS hot_leads,
  COUNT(*) FILTER (WHERE score BETWEEN 60 AND 79) AS warm_leads,
  COUNT(*) FILTER (WHERE score BETWEEN 40 AND 59) AS cool_leads,
  COUNT(*) FILTER (WHERE score < 40)              AS cold_leads,
  AVG(score)::numeric(5,1)                        AS avg_score,
  COUNT(*) FILTER (WHERE status NOT IN ('closed_won','closed_lost')) AS active_leads,
  COUNT(*) FILTER (WHERE status = 'closed_won')   AS won_deals,
  SUM(budget_max) FILTER (WHERE status NOT IN ('closed_won','closed_lost')) AS pipeline_value
FROM leads GROUP BY tenant_id;

CREATE OR REPLACE VIEW overdue_tasks AS
SELECT t.*, l.name AS lead_name, l.phone AS lead_phone, au.name AS agent_name
FROM tasks t
LEFT JOIN leads l ON l.id = t.lead_id
LEFT JOIN agent_users au ON au.id = t.agent_id
WHERE t.done = false AND t.due_date < now();

CREATE OR REPLACE VIEW pipeline_summary AS
SELECT l.tenant_id, ps.id AS stage_id, ps.name AS stage_name,
  ps.color, ps.order_idx,
  COUNT(l.id) AS lead_count,
  COALESCE(SUM(l.budget_max), 0) AS total_value,
  AVG(l.score)::numeric(5,1) AS avg_score
FROM pipeline_stages ps
LEFT JOIN leads l ON l.pipeline_stage_id = ps.id
  AND l.status NOT IN ('closed_won','closed_lost')
GROUP BY l.tenant_id, ps.id, ps.name, ps.color, ps.order_idx
ORDER BY ps.order_idx;

-- ── 13. Tenants: authenticated can read own row (safe columns only) ───────────
DROP POLICY IF EXISTS "agents read own tenant" ON tenants;
CREATE POLICY "agents read own tenant" ON tenants
  FOR SELECT TO authenticated USING (id = get_my_tenant_id());

REVOKE SELECT ON tenants FROM authenticated;
GRANT SELECT (
  id, name, slug, logo_url, primary_color, phone, whatsapp_number,
  plan, plan_expires_at, industry, city, country,
  is_active, created_at, updated_at, trial_ends_at
) ON tenants TO authenticated;

-- ── 14. ensure_agent_and_tenant (race-safe) ────────────────────────────────────
CREATE OR REPLACE FUNCTION public.ensure_agent_and_tenant(
  p_agency_name text DEFAULT NULL,
  p_name        text DEFAULT NULL
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $fn$
DECLARE
  v_uid          uuid := auth.uid();
  v_email        text := auth.email();
  v_agent_id     uuid;
  v_tenant_id    uuid;
  v_slug         text;
  v_display_name text;
  v_agency_name  text;
BEGIN
  IF v_uid IS NULL OR v_email IS NULL THEN RAISE EXCEPTION 'authentication required'; END IF;
  SELECT id, tenant_id INTO v_agent_id, v_tenant_id
    FROM agent_users WHERE auth_user_id = v_uid LIMIT 1;
  IF v_agent_id IS NOT NULL THEN
    RETURN jsonb_build_object('agent_id', v_agent_id, 'tenant_id', v_tenant_id, 'is_new', false);
  END IF;
  v_display_name := coalesce(nullif(trim(p_name),''), split_part(v_email,'@',1));
  v_agency_name  := coalesce(nullif(trim(p_agency_name),''), 'הסוכנות של ' || v_display_name);
  v_slug := 'agency-' || substr(md5(random()::text || clock_timestamp()::text),1,12);
  BEGIN
    INSERT INTO tenants (name, slug, plan, trial_ends_at, billing_email)
    VALUES (v_agency_name, v_slug, 'trial', now() + interval '30 days', v_email)
    RETURNING id INTO v_tenant_id;
    INSERT INTO pipeline_stages (tenant_id, name, color, order_idx, is_terminal, is_won) VALUES
      (v_tenant_id, 'ליד חדש',     '#94A3B8', 1, false, false),
      (v_tenant_id, 'בקשר',        '#3B82F6', 2, false, false),
      (v_tenant_id, 'ביקור נקבע', '#8B5CF6', 3, false, false),
      (v_tenant_id, 'הצעה הוגשה', '#F59E0B', 4, false, false),
      (v_tenant_id, 'סגירה ✓',     '#10B981', 5, true,  true);
    INSERT INTO agent_users (tenant_id, auth_user_id, name, email, role)
    VALUES (v_tenant_id, v_uid, v_display_name, v_email, 'owner')
    RETURNING id INTO v_agent_id;
  EXCEPTION WHEN unique_violation THEN
    SELECT id, tenant_id INTO v_agent_id, v_tenant_id
      FROM agent_users WHERE auth_user_id = v_uid LIMIT 1;
    IF v_agent_id IS NULL THEN RAISE; END IF;
    RETURN jsonb_build_object('agent_id', v_agent_id, 'tenant_id', v_tenant_id, 'is_new', false);
  END;
  RETURN jsonb_build_object('agent_id', v_agent_id, 'tenant_id', v_tenant_id, 'is_new', true);
END;
$fn$;
REVOKE EXECUTE ON FUNCTION public.ensure_agent_and_tenant(text,text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.ensure_agent_and_tenant(text,text) FROM anon;
GRANT  EXECUTE ON FUNCTION public.ensure_agent_and_tenant(text,text) TO authenticated;

-- ── 15. update_tenant_profile ─────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.update_tenant_profile(
  p_name  text,
  p_phone text DEFAULT NULL,
  p_city  text DEFAULT NULL
)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $fn$
DECLARE v_tenant_id uuid; v_role text;
BEGIN
  SELECT tenant_id, role INTO v_tenant_id, v_role
    FROM agent_users WHERE auth_user_id = auth.uid() LIMIT 1;
  IF v_tenant_id IS NULL THEN RAISE EXCEPTION 'no tenant for current user'; END IF;
  IF v_role NOT IN ('owner','admin') THEN RAISE EXCEPTION 'insufficient permissions'; END IF;
  IF p_name IS NULL OR trim(p_name) = '' THEN RAISE EXCEPTION 'agency name is required'; END IF;
  UPDATE tenants SET
    name  = trim(p_name),
    phone = nullif(trim(coalesce(p_phone,'')), ''),
    city  = nullif(trim(coalesce(p_city,'')), '')
  WHERE id = v_tenant_id;
END;
$fn$;
REVOKE EXECUTE ON FUNCTION public.update_tenant_profile(text,text,text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.update_tenant_profile(text,text,text) FROM anon;
GRANT  EXECUTE ON FUNCTION public.update_tenant_profile(text,text,text) TO authenticated;

-- ── 16. Lock down register_demo_agent (fully retired) ─────────────────────────
DO $$ BEGIN
  REVOKE EXECUTE ON FUNCTION public.register_demo_agent(text,text) FROM PUBLIC;
  REVOKE EXECUTE ON FUNCTION public.register_demo_agent(text,text) FROM anon;
  REVOKE EXECUTE ON FUNCTION public.register_demo_agent(text,text) FROM authenticated;
EXCEPTION WHEN undefined_function THEN NULL;
END $$;

-- ── 17. Unique indexes ────────────────────────────────────────────────────────
CREATE UNIQUE INDEX IF NOT EXISTS tenants_billing_email_unique
  ON tenants (billing_email) WHERE billing_email IS NOT NULL;

-- ── 18. Backfill billing_email for owner rows ─────────────────────────────────
UPDATE tenants t SET billing_email = au.email
FROM agent_users au
WHERE au.tenant_id = t.id AND au.role = 'owner'
  AND t.billing_email IS NULL AND au.email IS NOT NULL;
