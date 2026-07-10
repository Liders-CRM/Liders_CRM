-- 076_add_lead_tracking_fields.sql
-- תאריך חידוש עמלה וניהול מסמכים בתוך כרטיס הליד

ALTER TABLE leads
  ADD COLUMN IF NOT EXISTS commission_renewal_date date,
  ADD COLUMN IF NOT EXISTS commission_renewal_notes text DEFAULT '';

COMMENT ON COLUMN leads.commission_renewal_date IS 'תאריך חידוש עמלה / חוזה — מוצג בדשבורד 30 יום מראש';
COMMENT ON COLUMN leads.commission_renewal_notes IS 'הערות לחידוש עמלה';
