-- Migration 047: roadmap_items — public "in progress" feature list + admin management

CREATE TABLE IF NOT EXISTS roadmap_items (
  id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  title        text        NOT NULL,
  description  text,
  category     text        NOT NULL DEFAULT 'other'
                           CHECK (category IN ('feature','improvement','integration','other')),
  source       text        NOT NULL DEFAULT 'internal'
                           CHECK (source IN ('internal','user_idea')),
  is_published boolean     NOT NULL DEFAULT true,
  order_idx    integer     NOT NULL DEFAULT 0,
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE roadmap_items ENABLE ROW LEVEL SECURITY;

-- Everyone (any tenant, any agent, even anon) can read published items
CREATE POLICY "roadmap_public_read" ON roadmap_items
  FOR SELECT TO anon, authenticated
  USING (is_published = true);

-- Admin RPC: list all items (incl. unpublished) for admin.html management
CREATE OR REPLACE FUNCTION public.admin_list_roadmap_items()
RETURNS SETOF roadmap_items
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_email text := auth.email();
BEGIN
  IF v_email NOT IN ('liders.crm@gmail.com','elgrablidudu@gmail.com') THEN
    RAISE EXCEPTION 'admin access required';
  END IF;
  RETURN QUERY SELECT * FROM roadmap_items ORDER BY order_idx, created_at DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.admin_list_roadmap_items() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.admin_list_roadmap_items() FROM anon;
GRANT  EXECUTE ON FUNCTION public.admin_list_roadmap_items() TO authenticated;

-- Admin RPC: upsert an item (p_id NULL => insert new row)
CREATE OR REPLACE FUNCTION public.admin_save_roadmap_item(
  p_id           uuid,
  p_title        text,
  p_description  text,
  p_category     text,
  p_source       text,
  p_is_published boolean,
  p_order_idx    integer
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_email text := auth.email();
  v_id    uuid;
BEGIN
  IF v_email NOT IN ('liders.crm@gmail.com','elgrablidudu@gmail.com') THEN
    RAISE EXCEPTION 'admin access required';
  END IF;

  IF p_id IS NULL THEN
    INSERT INTO roadmap_items (title, description, category, source, is_published, order_idx)
    VALUES (p_title, p_description, p_category, p_source, p_is_published, p_order_idx)
    RETURNING id INTO v_id;
  ELSE
    UPDATE roadmap_items SET
      title        = p_title,
      description  = p_description,
      category     = p_category,
      source       = p_source,
      is_published = p_is_published,
      order_idx    = p_order_idx,
      updated_at   = now()
    WHERE id = p_id
    RETURNING id INTO v_id;
  END IF;

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.admin_save_roadmap_item(uuid,text,text,text,text,boolean,integer) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.admin_save_roadmap_item(uuid,text,text,text,text,boolean,integer) FROM anon;
GRANT  EXECUTE ON FUNCTION public.admin_save_roadmap_item(uuid,text,text,text,text,boolean,integer) TO authenticated;

-- Admin RPC: delete an item
CREATE OR REPLACE FUNCTION public.admin_delete_roadmap_item(p_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_email text := auth.email();
BEGIN
  IF v_email NOT IN ('liders.crm@gmail.com','elgrablidudu@gmail.com') THEN
    RAISE EXCEPTION 'admin access required';
  END IF;
  DELETE FROM roadmap_items WHERE id = p_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.admin_delete_roadmap_item(uuid) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.admin_delete_roadmap_item(uuid) FROM anon;
GRANT  EXECUTE ON FUNCTION public.admin_delete_roadmap_item(uuid) TO authenticated;

-- Seed a few real backlog items so the list isn't empty on first load
INSERT INTO roadmap_items (title, description, category, source, order_idx) VALUES
  ('חתימה דיגיטלית לחוזים', 'שליחת חוזה ללקוח וחתימה אלקטרונית חוקית ישירות מהטלפון', 'integration', 'internal', 10),
  ('ניהול מיילים AI', 'סינון וסיווג אוטומטי של מיילים נכנסים, כולל תגובה אוטומטית לפניות תמיכה', 'feature', 'internal', 20),
  ('ייבוא לידים אוטומטי מ-Facebook Ads', 'חיבור ישיר לטופסי Lead Ads בפייסבוק, ליד נכנס לפייפליין תוך שניות', 'integration', 'internal', 30)
ON CONFLICT DO NOTHING;
