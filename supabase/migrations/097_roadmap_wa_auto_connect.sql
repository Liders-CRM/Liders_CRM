-- Migration 097: seed a roadmap idea for automatic WhatsApp Business connect.
--
-- The dashboard/settings used to show a "connect WhatsApp in 2 minutes" flow
-- that never did anything but simulate progress and end in "coming soon" -
-- decided 18/7/2026 that nothing shown to users should look live when it
-- isn't. The button now jumps straight to the real, working manual Twilio
-- number field in Settings instead. The one-click OAuth-style auto-connect
-- experience that was promised becomes a real roadmap item here, so it only
-- gets built if real customer demand shows up through voting, same pattern
-- as the four ideas seeded in 091.

INSERT INTO roadmap_items (title, description, category, source, order_idx) VALUES
  ('חיבור WhatsApp עסקי אוטומטי בלי הזנת מספר ידנית', 'התחברות ישירה לחשבון ה-WhatsApp Business בכמה קליקים, בלי להזין מספר Twilio ידנית ובלי שום הגדרה טכנית. כרגע מתחברים ידנית דרך הגדרות עם מספר Twilio קיים.', 'integration', 'internal', 80);
