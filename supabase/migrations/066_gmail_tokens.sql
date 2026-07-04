-- Gmail OAuth tokens — accessible only via service_role (Edge Functions)
CREATE TABLE IF NOT EXISTS gmail_tokens (
  id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  account      text        UNIQUE NOT NULL,
  refresh_token text       NOT NULL,
  access_token  text,
  expires_at   timestamptz,
  created_at   timestamptz DEFAULT now(),
  updated_at   timestamptz DEFAULT now()
);

ALTER TABLE gmail_tokens ENABLE ROW LEVEL SECURITY;
-- No policies = blocked for all roles except service_role

CREATE OR REPLACE FUNCTION update_gmail_tokens_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END;
$$;

CREATE TRIGGER trg_gmail_tokens_updated_at
  BEFORE UPDATE ON gmail_tokens
  FOR EACH ROW EXECUTE FUNCTION update_gmail_tokens_updated_at();

COMMENT ON TABLE gmail_tokens IS
  'Stores Gmail OAuth refresh/access tokens. Service-role only — no RLS policies.';
