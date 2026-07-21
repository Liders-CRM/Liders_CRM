-- PLTO — Migration 099: Rename liders_invoices table to plto_invoices
--
-- Last live database object still carrying the old "Liders" brand name in its
-- literal identifier (not just historical migration-file text). RENAME keeps
-- the table's oid, data, indexes, RLS policies and triggers intact — this is
-- a metadata-only rename, no data is touched. The two RPCs that reference the
-- table (admin_save_invoice, admin_get_invoices) are recreated to point at
-- the new name; their auth guards already use info@plto.app (fixed by
-- migration 081) and are otherwise unchanged.

ALTER TABLE liders_invoices RENAME TO plto_invoices;

CREATE OR REPLACE FUNCTION public.admin_save_invoice(p_id uuid, p_tenant_id uuid, p_amount numeric, p_status text, p_notes text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_caller text := auth.email();
BEGIN
  IF v_caller NOT IN ('info@plto.app','elgrablidudu@gmail.com') THEN
    RAISE EXCEPTION 'admin access required';
  END IF;
  IF p_status NOT IN ('pending','paid','overdue','cancelled') THEN
    RAISE EXCEPTION 'invalid status';
  END IF;
  IF coalesce(p_amount,0) < 0 THEN RAISE EXCEPTION 'amount must be non-negative'; END IF;

  IF p_id IS NOT NULL THEN
    UPDATE plto_invoices
    SET tenant_id = p_tenant_id, amount = p_amount, status = p_status, notes = p_notes
    WHERE id = p_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'invoice not found'; END IF;
  ELSE
    INSERT INTO plto_invoices (tenant_id, amount, status, notes)
    VALUES (p_tenant_id, coalesce(p_amount,0), p_status, p_notes);
  END IF;
END;
$function$;

CREATE OR REPLACE FUNCTION public.admin_get_invoices()
 RETURNS TABLE(id uuid, tenant_id uuid, tenant_name text, invoice_number text, amount numeric, status text, notes text, created_at timestamp with time zone)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_caller text := auth.email();
BEGIN
  IF v_caller NOT IN ('info@plto.app','elgrablidudu@gmail.com') THEN
    RAISE EXCEPTION 'admin access required';
  END IF;
  RETURN QUERY
    SELECT i.id, i.tenant_id, t.name, i.invoice_number, i.amount,
           i.status, i.notes, i.created_at
    FROM plto_invoices i
    LEFT JOIN tenants t ON t.id = i.tenant_id
    ORDER BY i.created_at DESC LIMIT 500;
END;
$function$;
