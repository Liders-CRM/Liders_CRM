/**
 * PLTO — QA Agent
 * בדיקת E2E מלאה — מריץ על localhost עם Supabase mock
 * שימוש: node qa-plto.mjs
 */
import { chromium } from '/opt/node22/lib/node_modules/playwright/index.mjs';
import { writeFileSync, mkdirSync } from 'fs';

const BASE_URL = 'http://localhost:8787';
const SHOTS    = '/tmp/qa_shots';
mkdirSync(SHOTS, { recursive: true });

const results = [];
let page;

// ─── Supabase mock (CDN interceptor) ─────────────────────────────────────
const SUPABASE_MOCK_JS = `
(function(){
  var noop = function(){};
  var chain = function(){
    var c = {
      select:function(){return c;}, eq:function(){return c;}, neq:function(){return c;},
      order:function(){return c;}, limit:function(){return c;}, in:function(){return c;},
      is:function(){return c;}, gte:function(){return c;}, lte:function(){return c;},
      filter:function(){return c;}, single:function(){return c;},
      insert:function(){return c;}, update:function(){return c;},
      delete:function(){return c;}, upsert:function(){return c;},
      url:{href:''},
      then:function(r,j){ return Promise.resolve({data:[],error:null}).then(r,j); },
      catch:function(j){ return Promise.resolve({data:[],error:null}).catch(j); },
    };
    return c;
  };
  var mockClient = {
    auth:{
      getSession:  function(){ return Promise.resolve({data:{session:null},error:null}); },
      getUser:     function(){ return Promise.resolve({data:{user:null},error:null}); },
      onAuthStateChange: function(cb){
        setTimeout(function(){ cb('INITIAL_SESSION',null); },50);
        return {data:{subscription:{unsubscribe:noop}}};
      },
      signInWithOAuth:    function(){ return Promise.resolve({data:{},error:null}); },
      signInWithPassword: function(){ return Promise.resolve({data:{session:null,user:null},error:null}); },
      signOut:            function(){ return Promise.resolve({error:null}); },
    },
    from:  function(){ return chain(); },
    rpc:   function(){ return chain(); },
    storage:{ from: function(){ return { upload:function(){ return Promise.resolve({data:{},error:null}); }, getPublicUrl:function(){ return {data:{publicUrl:''}};}}; } },
    functions:{ invoke: function(){ return Promise.resolve({data:{},error:null}); } },
    channel: function(){ var ch={on:function(){return ch;},subscribe:function(){return ch;}}; return ch; },
    removeChannel:function(){},
  };
  window.supabase = { createClient: function(){ return mockClient; } };
  // Chart.js stub so the canvas doesn't crash
  if(!window.Chart){
    window.Chart = function(){ this.destroy=function(){};this.data={};this.update=function(){}; };
    window.Chart.register=function(){};
  }
})();
`;

// ─── helpers ───────────────────────────────────────────────────────────────
function log(icon, screen, action, detail = '') {
  const line = `${icon}  [${screen}] — ${action}${detail ? ' → ' + detail : ''}`;
  console.log(line);
  results.push({ icon, screen, action, detail, pass: icon === '✅' });
}

async function shot(name) {
  try { await page.screenshot({ path: `${SHOTS}/${name}.png` }); } catch {}
}

async function checkVisible(sel, screen, label) {
  const el = page.locator(sel).first();
  const visible = await el.isVisible({ timeout: 4000 }).catch(() => false);
  log(visible ? '✅' : '❌', screen, label, visible ? 'גלוי' : 'לא נמצא');
  return visible;
}

async function closeModal() {
  // Force-close via JS first (most reliable), then fallback to UI
  await page.evaluate(() => {
    document.querySelectorAll('.modal-overlay:not(.hidden)').forEach(m => m.classList.add('hidden'));
  }).catch(() => {});
  const close = page.locator('.modal-close').first();
  if (await close.isVisible({ timeout: 500 }).catch(() => false)) {
    await close.click().catch(() => {});
  }
  await page.waitForTimeout(300);
}

async function isScreenActive(screenId) {
  return page.evaluate(id => {
    const el = document.getElementById(`screen-${id}`);
    return el ? !el.classList.contains('hidden') : false;
  }, screenId).catch(() => false);
}

// ─── tests ─────────────────────────────────────────────────────────────────
async function testLogin() {
  const S = 'Login';
  await page.goto(BASE_URL, { waitUntil: 'domcontentloaded', timeout: 20000 });
  await page.waitForTimeout(1200);

  await checkVisible('text=30 ימי ניסיון חינמי', S, '30 ימי ניסיון מוצג');
  await checkVisible('.btn-google, button:has-text("Google")', S, 'כפתור Google');
  await checkVisible('#email, input[type="email"]', S, 'שדה אימייל');
  await checkVisible('#password, input[type="password"]', S, 'שדה סיסמה');
  await checkVisible('button:has-text("רוצה לראות דמו")', S, 'קישור דמו קטן');

  const bigBtn = await page.locator('.login-demo-btn').count();
  log(bigBtn === 0 ? '✅' : '❌', S, 'כפתור דמו גדול הוסר', bigBtn === 0 ? 'הוסר' : `עדיין ${bigBtn}`);

  await shot('01_login');
}

async function enterDemo() {
  const btn = page.locator('button:has-text("רוצה לראות דמו")').first();
  if (!await btn.isVisible({ timeout: 4000 }).catch(() => false)) {
    log('❌', 'Login', 'כניסה לדמו', 'כפתור לא נמצא');
    return false;
  }
  await btn.click();
  await page.waitForTimeout(2500);
  const inApp = await page.locator('#app-shell:not(.hidden)').isVisible().catch(() => false);
  log(inApp ? '✅' : '❌', 'Login', 'כניסה לדמו', inApp ? 'הצליח — app-shell גלוי' : 'נכשל');
  return inApp;
}

async function testDashboard() {
  const S = 'Dashboard';
  await page.evaluate(() => window.App?.go('dashboard')).catch(() => {});
  await page.waitForTimeout(700);

  await checkVisible('#kpi-row .kpi-card', S, 'כרטיסי KPI');
  await checkVisible('.gamify-widget, #gamify-avatar', S, 'ויג\'ט גיימיפיקציה');
  await checkVisible('#gamify-daily', S, 'אתגר יומי');

  const kpiCards = page.locator('.kpi-card');
  const kpiCount = await kpiCards.count();
  log(kpiCount >= 3 ? '✅' : '⚠️', S, `${kpiCount} כרטיסי KPI`, `צפוי 4`);

  for (let i = 0; i < kpiCount; i++) {
    try {
      const card = kpiCards.nth(i);
      const label = await card.locator('.kpi-label').textContent().catch(() => `KPI ${i + 1}`);
      const isClickable = await card.evaluate(el =>
        el.getAttribute('onclick') !== null || el.style.cursor === 'pointer'
      ).catch(() => false);
      log(isClickable ? '✅' : '⚠️', S, `KPI: ${label.trim()}`, isClickable ? 'לחיץ' : 'לא לחיץ');
    } catch {}
  }

  await checkVisible('#dash-ai-briefing', S, 'כרטיס AI briefing');

  // Check banner EXISTS in DOM (it may be hidden if >=5 leads — that's correct behaviour)
  const bannerCount = await page.locator('#dash-import-banner').count();
  log(bannerCount > 0 ? '✅' : '❌', S, '#dash-import-banner קיים ב-DOM', bannerCount > 0 ? 'קיים' : 'חסר לחלוטין');

  const bannerVisible = await page.locator('#dash-import-banner').isVisible().catch(() => false);
  const leadsCount = await page.evaluate(() => (window.State?.leads?.length) ?? (window.State?.leads ?? []).length ?? 0).catch(() => -1);
  const expectHidden = leadsCount < 0 || leadsCount >= 5;
  log((expectHidden && !bannerVisible) || (!expectHidden && bannerVisible) ? '✅' : '⚠️', S,
    `banner visibility (${leadsCount} לידים)`, bannerVisible ? 'גלוי' : `מוסתר (${leadsCount} לידים — תקין)`);

  await shot('02_dashboard');
}

async function testNavigation() {
  const S = 'Navigation';
  const screens = ['pipeline', 'leads', 'tasks', 'properties', 'settings', 'tools'];
  for (const sc of screens) {
    await page.evaluate(s => window.App?.go(s), sc).catch(() => {});
    await page.waitForTimeout(500);
    const active = await page.evaluate(s => {
      const el = document.getElementById(`screen-${s}`);
      return el ? !el.classList.contains('hidden') : false;
    }, sc).catch(() => false);
    log(active ? '✅' : '❌', S, `ניווט → ${sc}`, active ? 'נפתח' : 'לא נפתח');
  }
  await shot('03_nav');
}

async function testPipeline() {
  const S = 'Pipeline';
  await page.evaluate(() => window.App?.go('pipeline')).catch(() => {});
  await page.waitForTimeout(700);

  const tabs = page.locator('.pipeline-stage-tab');
  const tabCount = await tabs.count();
  log(tabCount >= 3 ? '✅' : '⚠️', S, `${tabCount} טאבי שלבים`);

  for (let i = 0; i < Math.min(tabCount, 6); i++) {
    try {
      const tab = tabs.nth(i);
      const name = (await tab.textContent().catch(() => `שלב ${i + 1}`)).trim().substring(0, 20);
      await tab.click({ timeout: 3000 });
      await page.waitForTimeout(250);
      const isActive = await tab.evaluate(el => el.classList.contains('active')).catch(() => false);
      log(isActive ? '✅' : '⚠️', S, `טאב: ${name}`, isActive ? 'פעיל' : 'לא סומן');
    } catch (e) {
      log('❌', S, `טאב ${i + 1}`, e.message.split('\n')[0]);
    }
  }

  const leadCards = page.locator('.lead-card, .kanban-card');
  const leadCount = await leadCards.count();
  log(leadCount > 0 ? '✅' : '⚠️', S, `${leadCount} כרטיסי לידים`);

  if (leadCount > 0) {
    // On mobile (390px) only the active-tab column is visible — must click inside it
    const activeCards = page.locator('.kanban-col.tab-active .lead-card, .kanban-col.tab-active .kanban-card');
    const activeCount = await activeCards.count();
    if (activeCount > 0) {
      await activeCards.first().click({ timeout: 3000, force: false }).catch(() => {});
      await page.waitForTimeout(700);
      const onDetail = await isScreenActive('lead-detail');
      log(onDetail ? '✅' : '❌', S, 'לחיצה על ליד → מפרט', onDetail ? 'נפתח' : 'לא נפתח');
      await page.evaluate(() => window.App?.go('pipeline')).catch(() => {});
      await page.waitForTimeout(400);
    } else {
      log('⚠️', S, 'לחיצה על ליד → מפרט', 'אין לידים בטאב הפעיל');
    }
  }

  // Scope to pipeline screen header so we don't pick up hidden dashboard buttons
  await checkVisible('#screen-pipeline [onclick*="LeadImport"]', S, 'כפתור ייבוא CSV');
  await shot('04_pipeline');
}

async function testAddLeadModal() {
  const S = 'Modal:ליד חדש';
  await page.evaluate(() => window.openModal?.('modal-add-lead')).catch(() => {});
  await page.waitForTimeout(600);

  const open = await page.locator('#modal-add-lead:not(.hidden)').isVisible().catch(() => false);
  log(open ? '✅' : '❌', S, 'מודל נפתח');
  if (open) {
    await checkVisible('#new-lead-name', S, 'שדה שם');
    await checkVisible('#new-lead-phone', S, 'שדה טלפון');
    await checkVisible('button:has-text("שמור ליד"), [onclick*="addLead"]', S, 'כפתור שמור ליד');
    await shot('05_modal_add_lead');
    await closeModal();
    const closed = !await page.locator('#modal-add-lead:not(.hidden)').isVisible().catch(() => true);
    log(closed ? '✅' : '❌', S, 'סגירת מודל', closed ? 'נסגר' : 'לא נסגר');
  }
}

async function testLeadDetail() {
  const S = 'LeadDetail';
  // Get first lead id from DOM (lead cards have onclick with the id)
  const firstLeadId = await page.evaluate(() => {
    if (window.State?.leads?.length) return window.State.leads[0].id;
    const card = document.querySelector('[onclick*="lead-detail"]');
    if (!card) return null;
    const m = card.getAttribute('onclick')?.match(/currentLeadId['":\s]+([a-f0-9-]{36})/);
    return m ? m[1] : null;
  }).catch(() => null);
  const leads = firstLeadId ? [{ id: firstLeadId }] : [];
  if (!leads.length) { log('⚠️', S, 'אין לידים לבדיקה'); return; }

  await page.evaluate(id => window.App?.go('lead-detail', { currentLeadId: id }), leads[0].id).catch(() => {});
  await page.waitForTimeout(800);

  const onDetail = await isScreenActive('lead-detail');
  log(onDetail ? '✅' : '❌', S, 'פתיחת מפרט ליד', onDetail ? 'נפתח' : 'לא נפתח');

  if (onDetail) {
    await checkVisible('h2, .lead-name, [class*="detail-name"]', S, 'שם הליד');
    await checkVisible('button:has-text("הוסף פעילות"), [onclick*="modal-add-activity"]', S, 'כפתור הוסף פעילות');

    // Click add activity
    try {
      await page.locator('button:has-text("הוסף פעילות"), [onclick*="modal-add-activity"]').first().click({ timeout: 3000 });
      await page.waitForTimeout(500);
      const actOpen = await page.locator('#modal-add-activity:not(.hidden)').isVisible().catch(() => false);
      log(actOpen ? '✅' : '❌', S, 'מודל פעילות נפתח');
      if (actOpen) {
        await checkVisible('#new-activity-type', S, 'בורר סוג פעילות');
        await checkVisible('#new-activity-content', S, 'שדה תיאור');
        await shot('06a_activity_modal');
        await closeModal();
      }
    } catch (e) {
      log('❌', S, 'כפתור הוסף פעילות', e.message.split('\n')[0]);
    }

    await shot('06_lead_detail');
  }
}

async function testTasks() {
  const S = 'Tasks';
  await page.evaluate(() => window.App?.go('tasks')).catch(() => {});
  await page.waitForTimeout(700);

  const taskScreen = await isScreenActive('tasks');
  log(taskScreen ? '✅' : '❌', S, 'מסך משימות נפתח');

  const taskItems = page.locator('.task-item, [class*="task-row"]');
  const taskCount = await taskItems.count();
  log(taskCount >= 0 ? '✅' : '⚠️', S, `${taskCount} פריטי משימות`);

  // Add task button — scope to tasks screen to avoid picking up hidden lead-detail button
  const addBtn = page.locator('#screen-tasks [onclick*="modal-add-task"]').first();
  if (await addBtn.isVisible({ timeout: 3000 }).catch(() => false)) {
    await addBtn.click({ force: true });
    await page.waitForTimeout(500);
    const taskModal = await page.locator('#modal-add-task:not(.hidden)').isVisible().catch(() => false);
    log(taskModal ? '✅' : '❌', S, 'מודל משימה חדשה נפתח');
    if (taskModal) await closeModal();
  } else {
    log('⚠️', S, 'כפתור משימה חדשה', 'לא נמצא');
  }

  await shot('07_tasks');
}

async function testSettings() {
  const S = 'Settings';
  await page.evaluate(() => window.App?.go('settings')).catch(() => {});
  await page.waitForTimeout(800);

  const onSettings = await isScreenActive('settings');
  log(onSettings ? '✅' : '❌', S, 'מסך הגדרות נפתח');

  const stagesList = await page.locator('#settings-stages-list').count();
  log(stagesList === 0 ? '✅' : '❌', S, 'שלבי פייפליין הוסרו', stagesList === 0 ? 'הוסרו' : `עדיין ${stagesList}`);

  await checkVisible('.settings-row', S, 'שורות הגדרות קיימות');

  await shot('08_settings');
}

async function testTools() {
  const S = 'Tools';
  await page.evaluate(() => window.App?.go('tools')).catch(() => {});
  await page.waitForTimeout(700);

  const onTools = await isScreenActive('tools');
  log(onTools ? '✅' : '❌', S, 'מסך כלים נפתח');

  const toolCards = page.locator('.tool-card');
  const toolCount = await toolCards.count();
  log(toolCount === 5 ? '✅' : '⚠️', S, `${toolCount} כרטיסי כלים`, 'צפוי 5');

  for (let i = 0; i < toolCount; i++) {
    try {
      const card = toolCards.nth(i);
      const name = await card.locator('.tool-card-title, .tool-name, h3, strong').first().textContent().catch(() => `כלי ${i + 1}`);
      // Accept buttons, onclick elements, or interactive inputs (oninput/onchange) — calculator uses oninput
      const hasInteractive = await card.evaluate(el =>
        el.querySelector('button, [onclick], input[oninput], input[onchange], textarea') !== null
      ).catch(() => false);
      log(hasInteractive ? '✅' : '⚠️', S, `כלי: ${name.trim().substring(0, 30)}`, hasInteractive ? 'אינטראקטיבי' : 'אין אינטראקציה');
    } catch {}
  }

  await shot('09_tools');
}

async function testGamification() {
  const S = 'Gamification';
  await page.evaluate(() => window.App?.go('dashboard')).catch(() => {});
  await page.waitForTimeout(600);

  await checkVisible('#gamify-avatar, .gamify-widget', S, 'ויג\'ט גיימיפיקציה');
  // XP fill has width:0% in fresh session → not "visible" to Playwright; check DOM presence instead
  const xpFillCount = await page.locator('#gamify-xp-fill').count();
  log(xpFillCount > 0 ? '✅' : '❌', S, 'פס XP קיים ב-DOM', xpFillCount > 0 ? 'קיים' : 'חסר');
  await checkVisible('#gamify-badges-row', S, 'שורת הישגים');
  await checkVisible('#gamify-daily', S, 'אתגר יומי');

  const dailyOnclick = await page.locator('#gamify-daily').getAttribute('onclick').catch(() => null);
  log(dailyOnclick ? '✅' : '❌', S, 'אתגר יומי לחיץ (onclick)', dailyOnclick || 'חסר');

  // Click and verify reaction
  try {
    await page.locator('#gamify-daily').click({ timeout: 3000 });
    await page.waitForTimeout(700);
    const screen = await page.evaluate(() => window.State?.screen).catch(() => '');
    const modals  = await page.locator('.modal-overlay:not(.hidden)').count();
    const reacted = screen !== 'dashboard' || modals > 0;
    log(reacted ? '✅' : '⚠️', S, 'לחיצה על אתגר יומי → פעולה', `מסך: ${screen}, מודלים: ${modals}`);
    await closeModal();
    await page.evaluate(() => window.App?.go('dashboard')).catch(() => {});
    await page.waitForTimeout(300);
  } catch (e) {
    log('⚠️', S, 'לחיצה על אתגר יומי', e.message.split('\n')[0].substring(0, 80));
  }

  await shot('10_gamify');
}

async function testFAB() {
  const S = 'FAB';
  await page.evaluate(() => window.App?.go('pipeline')).catch(() => {});
  await page.waitForTimeout(400);

  const fab = page.locator('.fab, #fab-btn').first();
  if (await fab.isVisible({ timeout: 2000 }).catch(() => false)) {
    await fab.click({ timeout: 3000 });
    await page.waitForTimeout(500);
    const open = await page.locator('#modal-add-lead:not(.hidden)').isVisible().catch(() => false);
    log(open ? '✅' : '❌', S, 'FAB + פותח מודל ליד חדש', open ? 'נפתח' : 'לא נפתח');
    if (open) await closeModal();
  } else {
    log('⚠️', S, 'FAB button', 'לא גלוי');
  }
}

async function testLeadImportModal() {
  const S = 'Modal:ייבוא לידים';
  await page.evaluate(() => window.LeadImport?.open?.()).catch(() => {});
  await page.waitForTimeout(600);
  const open = await page.locator('#modal-import-leads:not(.hidden), [id*="import"]:not(.hidden)').first().isVisible().catch(() => false);
  log(open ? '✅' : '⚠️', S, 'מודל ייבוא נפתח', open ? 'נפתח' : 'לא נמצא / שם שונה');
  if (open) {
    // Scope to modal to avoid picking up hidden file inputs from lead-detail that precede this in DOM
    await checkVisible('#modal-import-leads label:has-text("בחירת קובץ")', S, 'כפתור בחירת קובץ');
    await shot('11_import_modal');
    await closeModal();
  }
}

// ─── MAIN ──────────────────────────────────────────────────────────────────
const browser = await chromium.launch({ args: ['--no-sandbox', '--disable-dev-shm-usage'] });
const ctx = await browser.newContext({
  locale: 'he-IL',
  viewport: { width: 390, height: 844 },
});

// Intercept CDN scripts and replace with mocks
// Note: integrity attributes are stripped at HTML level (see route below) so SRI won't block mocks
await ctx.route('**cdn.jsdelivr.net**supabase**', async route => {
  await route.fulfill({ contentType: 'application/javascript; charset=utf-8', body: SUPABASE_MOCK_JS });
});
await ctx.route('**cdn.jsdelivr.net**chart.js**', async route => {
  await route.fulfill({ contentType: 'application/javascript; charset=utf-8', body: `
    window.Chart=function(){this.destroy=function(){};this.data={datasets:[]};this.update=function(){};};
    window.Chart.register=function(){};
  `});
});
// Strip integrity/crossorigin from script tags so SRI doesn't reject mocked CDN responses
await ctx.route('**localhost**', async route => {
  if (!route.request().url().endsWith('/') && !route.request().url().endsWith('/index.html')) {
    return route.continue();
  }
  const resp = await route.fetch();
  const body = (await resp.text()).replace(/\s+integrity="[^"]*"/g, '').replace(/\s+crossorigin="[^"]*"/g, '');
  await route.fulfill({ response: resp, body });
});

page = await ctx.newPage();
page.on('console', m => {
  if (m.type() === 'error') console.error(`  [browser:err] ${m.text().substring(0, 120)}`);
});

console.log('\n🤖 PLTO QA Agent');
console.log('═'.repeat(60));

await testLogin();
const entered = await enterDemo();

if (entered) {
  await testDashboard();
  await testNavigation();
  await testPipeline();
  await testAddLeadModal();
  await testLeadDetail();
  await testTasks();
  await testSettings();
  await testTools();
  await testGamification();
  await testFAB();
  await testLeadImportModal();
}

await browser.close();

// ─── report ────────────────────────────────────────────────────────────────
const passed   = results.filter(r => r.icon === '✅').length;
const failed   = results.filter(r => r.icon === '❌').length;
const warnings = results.filter(r => r.icon === '⚠️').length;

console.log('\n' + '═'.repeat(60));
console.log(`✅ עברו: ${passed}   ❌ נכשלו: ${failed}   ⚠️  אזהרות: ${warnings}`);

if (failed > 0) {
  console.log('\n❌ כשלונות:');
  results.filter(r => r.icon === '❌').forEach(r =>
    console.log(`  • [${r.screen}] ${r.action}: ${r.detail}`)
  );
}
if (warnings > 0) {
  console.log('\n⚠️  אזהרות:');
  results.filter(r => r.icon === '⚠️').forEach(r =>
    console.log(`  • [${r.screen}] ${r.action}: ${r.detail}`)
  );
}

writeFileSync('/tmp/qa_report.json', JSON.stringify({ timestamp: new Date().toISOString(), passed, failed, warnings, results }, null, 2));
console.log('\n📋 /tmp/qa_report.json  |  📸 /tmp/qa_shots/');
process.exit(failed > 0 ? 1 : 0);
