# WhatsApp Integration — Architecture Specification

**גרסה:** 1.0 | **תאריך:** יוני 2026 | **עבור:** PLTO

> ⚠️ **הערה (נוספה 12/7/2026, סשן ניקוי קוד)**: המסמך הזה הוא **תכנון עתידי בלבד**,
> לא תיאור של מה שקיים היום. בפועל נבנה פתרון פשוט בהרבה: חיבור ישיר ויחיד ל-Twilio
> (Edge Function `twilio-whatsapp`) בלי שכבת הפשטה, בלי `tenant_whatsapp`/
> `whatsapp_messages`, בלי `whatsapp-connect`/`whatsapp-webhook`. אף אחד מהאלמנטים
> המתוארים למטה (ריבוי ספקים Twilio/Meta/GreenAPI, שכבת Provider) לא קיים בקוד.
> **נשאר בכוונה** כרעיון להרחבה עתידית — לפי החלטת המשתמש, ייבנה רק אם יהיה ביקוש
> אמיתי ממשתמשים (ולא באופן יזום מראש).

---

## 1. Product Specification

### מטרה
חיבור WhatsApp Business לCRM — ללא מונחים טכניים, ללא הגדרות מסובכות.
המשתמש רואה כפתור אחד בלבד: **"חיבור לוואטסאפ"**.

### חוק UX בלעדי
- אסור להציג: Twilio, Meta, Webhook, API Token, Sandbox
- כל מה שרואה המשתמש: שם המערכת, זרימת חיבור פשוטה, כפתור אחד
- ביטול בכל עת ← כפתור "נתק WhatsApp" זמין תמיד בהגדרות

### מחירון (עתידי)
- כלול בחבילת Pro ומעלה
- חבילת Solo: +₪29/חודש לתוסף

---

## 2. UX Specification — Onboarding Flow

```
┌─────────────────────────────────────────┐
│  חיבור ה-WhatsApp שלך ב-2 דקות         │
│  ─────────────────────────────────      │
│                                         │
│     📱 ────── 🔒 ────── 🏆             │
│  WhatsApp  מאובטח    PLTO              │
│                                         │
│  ✅ קבל התראה על כל ליד חדש            │
│  ✅ שלח הודעות אוטומטיות              │
│  ✅ ניתוק בכל עת                       │
│                                         │
│  ☐ אני מאשר כי השימוש תואם למדיניות   │
│    WhatsApp ושהאחריות עליי בלבד        │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │   📲  חיבור לוואטסאפ           │   │
│  └─────────────────────────────────┘   │
│                                         │
│  ללא הגדרה טכנית. הכל מתבצע אוטומטית │
│  * תומך בחשבונות WhatsApp Business    │
└─────────────────────────────────────────┘
```

**שלב 2 — הצלחה:**
```
     📲
  בקרוב זמין!

  תכונת ה-WhatsApp מתפתחת ותהיה
  זמינה בשבועות הקרובים.
  נודיע לך ברגע שפתוח!
```

**הודעת הצלחה (כשיהיה live):**
> "היי, כאן סוכן ה-AI שלך — החיבור הצליח! מהיום אני אעדכן אותך על כל ליד חדש ישירות בוואטסאפ 🚀"

---

## 3. Technical Architecture

### Provider Abstraction Layer

```typescript
// packages/whatsapp/providers.ts

interface WhatsAppProvider {
  sendMessage(to: string, body: string): Promise<{ success: boolean; sid?: string }>;
  getStatus(): Promise<'connected' | 'disconnected' | 'error'>;
}

class TwilioProvider implements WhatsAppProvider { ... }
class MetaCloudProvider implements WhatsAppProvider { ... }
class GreenApiProvider implements WhatsAppProvider { ... }

// Factory — returns the correct provider based on config
function getProvider(config: ProviderConfig): WhatsAppProvider {
  switch (config.provider) {
    case 'twilio':     return new TwilioProvider(config);
    case 'meta':       return new MetaCloudProvider(config);
    case 'green_api':  return new GreenApiProvider(config);
    default:           return new TwilioProvider(config); // fallback
  }
}
```

**Dynamic routing:** provider configuration stored in `tenant_integrations.whatsapp_provider`.
Frontend never knows which provider is active — it calls a single internal API.

---

## 4. Database Design

```sql
-- Tenant WhatsApp integration
CREATE TABLE tenant_whatsapp (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID REFERENCES tenants(id) ON DELETE CASCADE,
  provider        TEXT DEFAULT 'twilio',  -- 'twilio' | 'meta' | 'green_api'
  phone_number    TEXT,                   -- E.164 format: +972501234567
  account_sid     TEXT,                   -- Twilio Account SID (encrypted)
  auth_token      TEXT,                   -- Twilio Auth Token (encrypted)
  meta_token      TEXT,                   -- Meta Cloud API token (encrypted)
  status          TEXT DEFAULT 'pending', -- 'pending' | 'connected' | 'disconnected'
  connected_at    TIMESTAMPTZ,
  last_message_at TIMESTAMPTZ,
  created_at      TIMESTAMPTZ DEFAULT now(),
  updated_at      TIMESTAMPTZ DEFAULT now()
);

-- RLS: tenant can only see their own row
ALTER TABLE tenant_whatsapp ENABLE ROW LEVEL SECURITY;
CREATE POLICY "tenant_own" ON tenant_whatsapp
  USING (tenant_id = auth.uid()::uuid);

-- Message log (for debugging + analytics)
CREATE TABLE whatsapp_messages (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id   UUID REFERENCES tenants(id),
  to_number   TEXT NOT NULL,
  body        TEXT NOT NULL,
  provider    TEXT,
  status      TEXT DEFAULT 'sent',  -- 'sent' | 'delivered' | 'failed'
  provider_id TEXT,                 -- Twilio SID / Meta message ID
  created_at  TIMESTAMPTZ DEFAULT now()
);
```

---

## 5. API Design — Supabase Edge Functions

### `whatsapp-send` (existing Twilio → refactor)
```typescript
// POST /functions/v1/whatsapp-send
// Body: { to: string, body: string }

import { getProvider } from '../_shared/whatsapp/providers.ts';

serve(async (req) => {
  const { tenant_id } = await verifyJWT(req);
  const { to, body } = await req.json();
  
  // Load tenant's provider config from DB (encrypted)
  const config = await getProviderConfig(tenant_id);
  const provider = getProvider(config);
  
  const result = await provider.sendMessage(to, body);
  return Response.json(result);
});
```

### `whatsapp-connect` (new)
```typescript
// POST /functions/v1/whatsapp-connect
// Body: { phone_number: string, provider?: 'twilio' | 'meta' }
// Returns: { success: boolean, setup_url?: string }

// Saves phone to tenant_whatsapp table
// Initiates provider-specific auth flow
// Triggers welcome message when connected
```

### `whatsapp-webhook` (new, replaces twilio-whatsapp)
```typescript
// POST /functions/v1/whatsapp-webhook
// Handles incoming messages from all providers
// Routes to correct tenant based on to_number
```

---

## 6. State Machine

```
DISCONNECTED
    │
    ▼ [click "חיבור לוואטסאפ"]
TERMS_ACCEPTED
    │
    ▼ [checkbox checked + click]
CONNECTING
    │
    ├── [Twilio sandbox] → SANDBOX_PENDING → [join code sent] → CONNECTED
    │
    ├── [Meta Business] → META_AUTH_URL → [OAuth flow] → CONNECTED
    │
    └── [error] → ERROR → [retry] → CONNECTING

CONNECTED
    │
    ├── [user clicks disconnect] → DISCONNECTED
    └── [token expired] → RECONNECT_NEEDED → [auto-refresh] → CONNECTED
```

---

## 7. Security Plan

| Risk | Mitigation |
|------|------------|
| Token storage | Encrypted at rest (Supabase Vault / AES-256) |
| Message privacy | Tenant isolation via RLS — cross-tenant impossible |
| Rate limiting | Max 100 messages/hour per tenant |
| Spam prevention | Consent checkbox required before connect |
| Provider keys | Never exposed to frontend, only via Edge Functions |
| Webhook validation | HMAC signature verification (Twilio / Meta) |
| Terms compliance | User explicitly accepts WhatsApp ToS in UI |
| Audit trail | All messages logged in `whatsapp_messages` |

---

## 8. Development Checklist

### Phase 1 — Infrastructure
- [ ] Create `tenant_whatsapp` table + RLS policies
- [ ] Create `whatsapp_messages` table
- [ ] Implement `WhatsAppProvider` interface + factory
- [ ] Add encryption utilities for credentials (Supabase Vault)
- [ ] Create `whatsapp-connect` Edge Function
- [ ] Refactor existing `twilio-whatsapp` → use Provider abstraction

### Phase 2 — Frontend
- [ ] WhatsApp connect modal (already implemented in index.html)
- [ ] Settings: disconnect button when connected
- [ ] Settings: show connection status badge (🟢/🔴)
- [ ] Toast notification on successful connection
- [ ] AI welcome message trigger on first connect

### Phase 3 — Provider Integration
- [ ] Twilio Sandbox setup guide
- [ ] Twilio Business API (production)
- [ ] Meta Cloud API (fallback / scale)

### Phase 4 — Automation
- [ ] New lead → WhatsApp notification (already in `Twilio.notifyNewLead`)
- [ ] Stage change → notification (already in `Twilio.notifyStageChanged`)
- [ ] AI welcome message on connect
- [ ] Daily morning briefing (optional, opt-in)

---

## 9. QA Checklist

- [ ] Connect flow works end-to-end (dev environment)
- [ ] Welcome message arrives within 30 seconds of connect
- [ ] New lead notification arrives within 5 seconds
- [ ] Stage change notification works for all 5 stages
- [ ] Disconnect clears all stored credentials
- [ ] Cross-tenant isolation: tenant A cannot trigger messages to tenant B's number
- [ ] Rate limit: 101st message in an hour returns 429
- [ ] Mobile: connect flow is fully usable on 390px viewport
- [ ] Accessibility: all form elements have labels
- [ ] Terms checkbox required: connect fails without it

---

## 10. Future: Advanced Features

| Feature | Priority | Notes |
|---------|----------|-------|
| Two-way messaging (receive WA from clients) | High | Requires webhook + UI thread view |
| Template messages (approved by Meta) | Medium | For marketing broadcasts |
| AI auto-reply to incoming WA | Medium | Route through `ai-proxy` |
| WhatsApp broadcast to all leads | Low | Compliance risk, needs consent tracking |
| WA → CRM activity sync | Low | Log WA conversations in lead activities |

---

*דוקומנטציה זו מכסה את מלוא הארכיטקטורה. Implementation phases TBD עם Grow/PayMe live.*
