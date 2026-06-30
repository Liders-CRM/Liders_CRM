-- Migration 045: fix cross-tenant storage gaps + matview data leak
--
-- Found via Supabase security advisor + manual re-audit ahead of launch.
--
-- 1) property-images storage.objects policies checked only `bucket_id`,
--    never the tenant folder — despite being named "tenant upload/update/
--    delete" and despite the app uploading to `${tenant_id}/...` paths
--    (index.html _uploadOne, line ~12894). Any authenticated user on ANY
--    tenant could overwrite or delete another tenant's property photos.
--    Also two redundant unscoped policies existed (auth upload/delete vs
--    property-images tenant upload/delete) from earlier sessions.
--
-- 2) Both lead-documents (`lead_docs_read`) and property-images
--    (`property-images public read`) SELECT policies on storage.objects
--    allowed anon/public to LIST every file across every tenant. The app
--    only ever accesses files via getPublicUrl() (which bypasses RLS
--    entirely for public buckets), so this SELECT policy serves no
--    functional purpose — it only enables cross-tenant enumeration of
--    lead documents (potential PII/contracts) and property photos.
--
-- 3) public.lead_score_summary is a materialized view (no RLS support)
--    grouped by tenant_id, but was selectable by the `authenticated`
--    role — any signed-up tenant could read every other tenant's pipeline
--    value and lead-funnel stats via /rest/v1/lead_score_summary. It is
--    not referenced anywhere in index.html/admin.html, so access is
--    simply revoked.

-- --- property-images: drop redundant/unscoped policies ---
DROP POLICY IF EXISTS "auth upload property images" ON storage.objects;
DROP POLICY IF EXISTS "auth delete property images" ON storage.objects;
DROP POLICY IF EXISTS "property-images tenant upload" ON storage.objects;
DROP POLICY IF EXISTS "property-images tenant update" ON storage.objects;
DROP POLICY IF EXISTS "property-images tenant delete" ON storage.objects;
DROP POLICY IF EXISTS "property-images public read" ON storage.objects;

CREATE POLICY "property_images_tenant_upload" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'property-images'
    AND (storage.foldername(name))[1] = (
      SELECT agent_users.tenant_id::text FROM agent_users
      WHERE agent_users.auth_user_id = auth.uid() LIMIT 1)
  );

CREATE POLICY "property_images_tenant_update" ON storage.objects
  FOR UPDATE TO authenticated
  USING (
    bucket_id = 'property-images'
    AND (storage.foldername(name))[1] = (
      SELECT agent_users.tenant_id::text FROM agent_users
      WHERE agent_users.auth_user_id = auth.uid() LIMIT 1)
  );

CREATE POLICY "property_images_tenant_delete" ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id = 'property-images'
    AND (storage.foldername(name))[1] = (
      SELECT agent_users.tenant_id::text FROM agent_users
      WHERE agent_users.auth_user_id = auth.uid() LIMIT 1)
  );

CREATE POLICY "property_images_tenant_read" ON storage.objects
  FOR SELECT TO authenticated
  USING (
    bucket_id = 'property-images'
    AND (storage.foldername(name))[1] = (
      SELECT agent_users.tenant_id::text FROM agent_users
      WHERE agent_users.auth_user_id = auth.uid() LIMIT 1)
  );

-- --- lead-documents: remove anon/cross-tenant listing on SELECT ---
DROP POLICY IF EXISTS "lead_docs_read" ON storage.objects;

CREATE POLICY "lead_docs_read" ON storage.objects
  FOR SELECT TO authenticated
  USING (
    bucket_id = 'lead-documents'
    AND (storage.foldername(name))[1] = (
      SELECT agent_users.tenant_id::text FROM agent_users
      WHERE agent_users.auth_user_id = auth.uid() LIMIT 1)
  );

-- --- lead_score_summary: stop cross-tenant matview leak ---
REVOKE SELECT ON public.lead_score_summary FROM anon, authenticated;
