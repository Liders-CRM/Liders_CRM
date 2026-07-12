-- Migration 080: Drop legacy "Liders CRM"-branded overloads of the lead-referral
-- functions. These were superseded by newer overloads (with p_external_profession)
-- when the "other"/external-profession referral flow was added, but the old
-- overloads were never dropped. The current frontend always calls the new
-- overload (it passes p_external_profession explicitly), so the old ones are
-- dead code - but they still contain literal "Liders CRM" text in the referral
-- agreement document that would be signed by a real external colleague if any
-- caller ever invoked them without that parameter. Removing them entirely so no
-- code path can ever produce an "Liders CRM"-branded agreement again.

DROP FUNCTION IF EXISTS public.create_lead_referral(
  uuid, text, text, text, text, text, numeric, boolean
);

DROP FUNCTION IF EXISTS public._create_lead_referral_core(
  uuid, uuid, uuid, text, text, text, text, text, numeric, boolean, uuid, uuid
);

DROP FUNCTION IF EXISTS public._build_referral_agreement_text(
  text, text, text, text, numeric
);
