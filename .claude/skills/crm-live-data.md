# CRM Live Data — שאיבת נתונים חיים

## פקודה: `/crm-live-data`

סקיל לשאיבה, סנכרון וניתוח נתונים חיים מכל מערכות ה-MCP המחוברות:
Supabase, Google Calendar, Gmail, Make.com, Airtable, Notion.

---

## מה הסקיל הזה עושה

כשמפעילים `/crm-live-data` Claude:
1. **שולף נתונים עדכניים** מ-Supabase (לידים, נכסים, משימות, tenants)
2. **מסנכרן עם Google Calendar** (ביקורים, conflicts)
3. **מושך דואר מ-Gmail** (לידים נכנסים, עדכונים)
4. **בודק Make.com** (automations שפועלות/נכשלות)
5. **מעדכן Notion** (דשבורד, דוחות)
6. **מנתח ומסכם** את מצב המערכת

---

## Supabase — שאיבת נתונים

```typescript
// פונקציות שאיבה ראשיות

async function getActiveLeads(tenantId: string) {
  // mcp: mcp__Supabase__execute_sql
  const sql = `
    SELECT l.*, ps.name as stage_name, au.name as agent_name
    FROM leads l
    LEFT JOIN pipeline_stages ps ON ps.id = l.pipeline_stage_id
    LEFT JOIN agent_users au ON au.id = l.agent_id
    WHERE l.tenant_id = '${tenantId}'
      AND l.status NOT IN ('closed_won','closed_lost','frozen')
    ORDER BY l.score DESC, l.updated_at DESC
    LIMIT 50
  `;
}

async function getOverdueTasks(tenantId: string) {
  const sql = `
    SELECT t.*, l.name as lead_name, l.phone as lead_phone
    FROM tasks t
    LEFT JOIN leads l ON l.id = t.lead_id
    WHERE t.tenant_id = '${tenantId}'
      AND t.done = false
      AND t.due_date < now()
    ORDER BY t.due_date ASC
  `;
}

async function getPipelineStats(tenantId: string) {
  const sql = `
    SELECT
      ps.name as stage,
      COUNT(l.id) as lead_count,
      COALESCE(SUM(l.budget_max), 0) as total_value,
      AVG(l.score)::numeric(5,1) as avg_score
    FROM pipeline_stages ps
    LEFT JOIN leads l ON l.pipeline_stage_id = ps.id
      AND l.status NOT IN ('closed_won','closed_lost')
    WHERE ps.tenant_id = '${tenantId}'
    GROUP BY ps.id, ps.name, ps.order_idx
    ORDER BY ps.order_idx
  `;
}
```

---

## Google Calendar — סנכרון ביקורים

```typescript
// mcp: mcp__Google_Calendar__list_events

async function syncShowingsWithCalendar() {
  // 1. שלוף ביקורים מ-Supabase
  const showings = await getUpcomingShowings();

  // 2. שלוף events מ-Google Calendar
  // mcp__Google_Calendar__list_events({
  //   calendarId: 'primary',
  //   timeMin: new Date().toISOString(),
  //   maxResults: 50
  // })

  // 3. מצא conflicts ודיווח
}

async function addShowingToCalendar(showing: Showing) {
  // mcp__Google_Calendar__create_event({
  //   summary: `ביקור — ${lead.name} | ${property.address}`,
  //   description: `ליד: ${lead.phone}\nנכס: ${property.title}`,
  //   start: { dateTime: showing.scheduled_at, timeZone: 'Asia/Jerusalem' },
  //   end: { dateTime: addMinutes(showing.scheduled_at, showing.duration_min), timeZone: 'Asia/Jerusalem' }
  // })
}
```

---

## Gmail — לידים ועדכונים

```typescript
// mcp: mcp__Gmail__search_threads

async function checkIncomingLeads() {
  // חפש לידים שהגיעו דרך אימייל
  // mcp__Gmail__search_threads({
  //   query: 'subject:(ליד OR lead OR inquiry) is:unread'
  // })
}

async function checkBillingEmails() {
  // mcp__Gmail__search_threads({
  //   query: 'subject:(stripe OR billing OR payment) newer_than:1d'
  // })
}
```

---

## Make.com — בדיקת Automations

```typescript
// mcp: mcp__Make__scenarios_list + mcp__Make__executions_list

async function checkAutomationHealth() {
  // 1. רשימת כל הסצנריות
  // mcp__Make__scenarios_list()

  // 2. בדוק executions אחרונות
  // mcp__Make__executions_list({ limit: 20 })

  // 3. דווח על כשלים
  const failedExecutions = executions.filter(e => e.status === 'error');
  return failedExecutions;
}
```

---

## Notion — עדכון Dashboard

```typescript
// mcp: mcp__Notion__notion-update-page

async function updateNotionDashboard(stats: PipelineStats) {
  // mcp__Notion__notion-search({ query: 'Liders CRM Dashboard' })
  // מצא pageId
  // mcp__Notion__notion-update-page({
  //   pageId,
  //   properties: {
  //     'לידים פעילים': { number: stats.active_leads },
  //     'ערך פייפליין': { number: stats.pipeline_value },
  //     'עדכון אחרון': { date: new Date().toISOString() }
  //   }
  // })
}
```

---

## Airtable — דיווח ואנליטיקס

```typescript
// mcp: mcp__Airtable__list_records_for_table

async function syncLeadsToAirtable() {
  // 1. שלוף לידים מ-Supabase
  const leads = await getActiveLeads(tenantId);

  // 2. עדכן/צור ב-Airtable
  // mcp__Airtable__search_bases({ query: 'Liders CRM' })
  // mcp__Airtable__update_records_for_table(...)
}
```

---

## Live Status Report — `/crm-live-data status`

```
📊 דוח מערכת — Liders CRM
═══════════════════════════════
📅 תאריך: [היום]

👥 לידים פעילים: X
   🔥 חם (score ≥80): X
   🌤 פושר (60–79): X
   🧊 קר (<40): X

📋 משימות באיחור: X
   הבאה: [כותרת] — [ליד]

🏠 נכסים זמינים: X

⚙️  Make.com: X automations פעילות | X כשלים
📧  Gmail: X הודעות לא נקראו

🔴 דורש תשומת לב:
   - [רשימת בעיות אם יש]
```

---

## הוראות הפעלה

```bash
/crm-live-data                   # שאיבה כללית
/crm-live-data status            # דוח מלא
/crm-live-data leads             # לידים פעילים בלבד
/crm-live-data tasks             # משימות באיחור
/crm-live-data sync-calendar     # סנכרון עם Google Calendar
/crm-live-data check-automations # בדיקת Make.com
/crm-live-data lead [phone]      # היסטוריית ליד ספציפי
```
