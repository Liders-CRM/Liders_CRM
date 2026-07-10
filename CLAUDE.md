# CLAUDE.md — PLTO

## 🗣️ שפת תקשורת — עברית בלבד, ללא יוצא מן הכלל

> כל הודעה לאו, כל סיכום עבודה, כל הסבר טכני, כל שאלת הבהרה — **בעברית בלבד**.
> זה כולל גם הודעות סיום עבודה ("הכל מוכן, מה הלאה?") וגם הסברים טכניים מורכבים.
> אסור לערבב אנגלית/עברית בתוך אותה הודעה (חוץ ממונחים טכניים שאין להם תרגום מקובל — שמות פונקציות, שמות קבצים, מונחי קוד).
> המשתמש כבר ביקש את זה כמה פעמים — אל תשכח שוב.

---

## ⚧ ניטרליות מגדרית — כלל קבוע לכל הסשנים (נקבע 3/7/2026)

> **כל טקסט UI במערכת חייב להיות ניטרלי מגדרית.** אסור לפנות למשתמש בלשון זכר בלבד.
> הכלל חל על: כותרות, כפתורים, הודעות toast, placeholders, מסרי שגיאה, מודלים, סיור מודרך,
> אונבורדינג, תבניות WhatsApp, ותוכן AI הנראה למשתמש.

### ✅ פניות ניטרליות מועדפות:
> **כלל מעודכן (סשן 3/7/2026 לילה):** אסור גם צורות סלאש (`מעצב/ת`, `שלח/י`, `את/ה` וכו').
> יש לנסח מחדש את המשפט כולו במקום להוסיף סלאש.

| במקום | השתמש ב |
|--------|----------|
| `אתה`, `הינך` | הסר/שנה מבנה המשפט |
| `ברוך הבא` | `ברוכים הבאים` |
| `בוא נתחיל` | `נתחיל` / `קדימה` |
| `הכנס`, `הזן` (פקודה) | `יש להזין` / `נא להזין` |
| `הירשם` | `הרשמה` / `להרשמה` |
| `מעצב פנים` / `מעצב/ת פנים` (UI) | `עיצוב פנים` |
| `שלח/י`, `תאר/י`, `בחר/י` (פקודות) | ניסוח מחדש: שם הפועל / `ניתן ל...` / `יש ל...` |
| `ראיתי שאתה מחפש` / `ראיתי שאת/ה מחפש/ת` | `ראיתי שיש עניין ב...` |
| `את/ה הראשון/ה` | `אני פונה אליך לפני כולם` |
| `מסכים/ה` (כפתור הסכמה) | הסר — `הבנתי, נתחיל` |
| `מתי תהיה פנוי` | `מתי יהיה נוח לך` |
| `שתבחר`, `תרצה` | שנה מבנה — `הנבחר`, `שצריך` |

### ❌ לא לשנות (שמור כמו שהוא):
- טקסט בתוך AI system prompts (כגון `אתה עוזר AI`, `אתה ${role}`) — הוא מיועד ל-Claude ולא למשתמש
- `_industryRole()` — שם התפקיד לפרומפט AI (לא לשנות ל"מעצב/ת")

---

## 📐 היררכיית גדלים יחסית לפונטים — כלל קבוע לכל הסשנים (נקבע 5/7/2026)

> חל על כל דף, מסך, קומפוננטה ו-UI שנבנה. חובה לשמור על היררכייה יחסית:
> - **כותרת ראשית (H1/section-title)** — הגדולה ביותר בסקשן
> - **כותרת משנית (H2/subtitle)** — קטנה מעט מהראשית (יחס ~85%, לדוגמה אם ראשית 26px אז משנית 22–23px)
> - **סאב טקסט/תיאור** — קריא ונקי, קטן יותר מהמשנית (לדוגמה 16–17px)
>
> המספרים הם **להמחשה בלבד**. הכלל: כל שכבה ויזואלית נמוכה חייבת להיות קטנה יותר,
> מאוזנת ויזואלית, ונראית מעולה ב-mobile ו-desktop כאחד. אין להתעצל ולשים אותו גודל לכולם.

---

## ✏️ ניקוי סימנים רובוטיים — כלל קבוע לכל הסשנים (נקבע 5/7/2026)

> **חל איסור מוחלט להשתמש בסימני מקף רגיל (-) או חצים (→, ←, <, >) על גבי כפתורים**,
> ללא שום יוצא מן הכלל (כולל דף נחיתה, index, admin, toast, placeholder).
> - **בכפתורים**: מוחקים לחלוטין, ללא תחליף.
> - **בטקסטים שיווקיים** (כותרות, sub-text, תיאורים): להימנע ממקף/חץ כסימן עיצובי. להשתמש בפסיק בלבד.
> - **בנתוני UI** (כמו flows, diagrams, כיווני הפניה): מותר להשמיט לגמרי — אין להחליף ב-•.
> - מקף em/en (— ו–) מותרים כסימן פיסוק לשוני תקני בלבד.
> - חיבורי מקף דקדוקיים בעברית עם מילים זרות (כגון "ב-CRM", "מה-AI") — **מותרים**, זה דקדוק ולא עיצוב.

---

## ⚙️ יעילות טוקנים — כללי עבודה קבועים בכל סשן

> נקבע 2/7/2026 אחרי סשן שהתארך והתייקר יותר מדי. חל כברירת מחדל על **כל סשן חדש**,
> אלא אם המשתמש מבקש אחרת במפורש (למשל "בדיקה מקיפה"/"בדוק הכל"/"high effort").

1. **Code-review/security-review**: ברירת מחדל לרמת **medium**, לא high/xhigh. עולים
   ל-high רק לשינוי גדול/רגיש במיוחד (תשלומים, אבטחה, מיגרציית DB משמעותית) או אם
   המשתמש מבקש זאת מפורשות.
2. **QA ויזואלי**: לבדוק/לצלם רק את המסך שהשתנה בפועל, לא מטריצה מלאה של כל
   התחומים/viewports — אלא אם המשתמש אמר "בדוק הכל" או שווה ערך.
3. **סוכני משנה (agents) במקביל**: להימנע מהרצת כמה agents כשבדיקה ישירה עם
   Grep/Read מספיקה. Agents שמורים למקרים שבאמת דורשים חקירה מקבילה/רחבה בקוד גדול
   ולא מוכר.
4. **TaskOutput**: אף פעם לא עם `block=false` על agent שעדיין רץ — זה מחזיר JSONL גולמי
   של כל תמליל הסוכן (בזבוז טוקנים אדיר). לחכות ל-task-notification או להשתמש
   ב-SendMessage כדי לבקש סיכום נקי.
5. לפני פעולה שצפויה להיות יקרה (כמה agents במקביל, סבב screenshots מלא) — לעצור
   ולשאול את המשתמש אם רוצה את הגרסה המלאה או ממוקדת, במקום לבחור אוטומטית ביקרה.
6. **חוזק 3/7/2026 אחרי שסשן הפעיל 5 code-review agents במקביל בלי לשאול קודם וזה
   שרף למשתמש מכסת שימוש שלמה**: כלל #5 הוא לא המלצה — **אסור להפעיל Agent tool
   (כולל `/code-review`, `liders-ui-reviewer`, כל תהליך multi-agent) בלי לשאול את
   המשתמש קודם ולקבל אישור מפורש**, גם אם התהליך המתועד באותו סשן (למשל תהליך
   העבודה ב"סוכני משנה ותהליך עבודה מקצועי" למטה) ממליץ להריץ אותו. במקום זאת: לתאר
   בקצרה מה מתוכנן (כמה agents, על מה) ולחכות לאישור. בנוסף הוגדר אכיפה טכנית:
   `.claude/settings.local.json` (לא ב-git) עם `permissions.ask: ["Agent"]` —
   כל קריאה ל-Agent tool תבקש אישור מהמשתמש ברמת ה-harness, לא רק ברמת ההנחיה כאן.

---

## 🤖 סוכני משנה ותהליך עבודה מקצועי — הוגדר 3/7/2026

> המשתמש ביקש להטמיע תהליך עבודה מרובה-סוכנים (בהשראת "6 סוכנים" מסרטון הדרכה).
> רוב היכולות כבר קיימות מובנות ב-Claude Code; מה שהיה חסר הוגדר כסוכני פרויקט
> ב-`.claude/agents/`. **כללי יעילות הטוקנים למעלה גוברים תמיד** — הסוכנים מופעלים
> רק כשהשינוי מצדיק זאת, לא על כל עריכה קטנה.

### סוכן הפרויקט היחיד (ב-`.claude/agents/`)

| סוכן | מתי להפעיל |
|------|-------------|
| `liders-ui-reviewer` | שינוי מסך או קומפוננטה — התאמה למערכת העיצוב, RTL, mobile-first (רק המסך שהשתנה) |

> הוחלט 3/7/2026 (לבקשת המשתמש): **סוכן אחד בלבד, בלי כפילויות.** נמחקו
> `liders-code-reviewer` ו-`liders-security-reviewer` כי הם שכפלו יכולות קיימות —
> ראה טבלה למטה. אין ליצור סוכני פרויקט חדשים שחופפים ל-skills קיימים או ליכולות מובנות.

### יכולות שכבר קיימות (לא להתקין/לשכפל)

| מהסרטון | הפתרון אצלנו |
|---------|----------------|
| "Superpowers" (תכנון לפני קוד + אימות) | Plan mode מובנה + skill‏ `/verify` |
| "Claude Code Workflows" (סקירה מקבילה) | skill‏ `/code-review` מובנה — ברמת medium! |
| "Security Review" | skill‏ `/security-review` מובנה + skills פרויקט `security-guardian`/`supabase-security` (threat model מלא) |
| "Claude MEM" (זיכרון בין סשנים) | קובץ CLAUDE.md הזה — **חובה לעדכן אותו בסוף כל סשן עם החלטות ושינויים** |
| "Frontend Design" | מערכת העיצוב המתועדת כאן + `liders-ui-reviewer` + skill‏ `figma-crm-ui` |
| QA פונקציונלי E2E | skill פרויקט `qa-liders` (סקריפט Playwright מוכן) |
| "gstack" (היררכיית CEO/מנהלים) | **לא אומץ בכוונה** — משחק תפקידים שמנפח טוקנים בלי ערך הנדסי, מנוגד לכללי היעילות |

### תהליך עבודה לשינוי משמעותי
1. **תכנון** — מיפוי קצר של הצעדים לפני כתיבת קוד (בשינוי גדול: Plan mode).
2. **מימוש** — לפי דפוסי הקוד הקיימים ומערכת העיצוב.
3. **סקירה** — `/code-review` ברמת medium; על מסכים — `liders-ui-reviewer`.
4. **אבטחה** — `/security-review` (עם ה-checklist של `security-guardian`) רק כשהשינוי
   נוגע ב-auth / RLS / תשלומים / edge functions / קלט משתמש.
5. **תיעוד** — עדכון CLAUDE.md אם השתנו החלטות/מחירים/סכמה, ואז commit + push.

בתיקונים קטנים (טקסט, צבע, באג נקודתי) — מדלגים על שלבים 3–4 ועובדים ישירות.

---

## 🛡️ כותרות אבטחה — GitHub Pages לא תומך ב-`_headers`! (הובן 3/7/2026)

> האתר מתארח ב-**GitHub Pages** (קובץ CNAME). קובץ `_headers` שבריפו הוא פורמט של
> Netlify/Cloudflare Pages — **GitHub Pages מתעלם ממנו לחלוטין.** ההגנות בפועל:
> 1. **meta CSP** בכל דף (index / admin / landing) — נאכף ע"י הדפדפן. כשמוסיפים דף
>    חדש או משאב חיצוני חדש — חובה לעדכן את ה-CSP של אותו דף.
> 2. **Frame-busting JS** (סגנון OWASP: `<style id="antiCJ">` + בדיקת `self===top`)
>    ב-index וב-admin — כי `X-Frame-Options`/`frame-ancestors` לא נאכפים מ-meta.
> 3. `_headers` נשאר בריפו למקרה של מעבר פלטפורמה, אבל **אין לסמוך עליו**.
>
### ☁️ סטטוס Cloudflare (עדכון 3/7/2026 ערב)
- ✅ **הדומיין מחובר ל-Cloudflare** — Nameservers הוחלפו ב-Namecheap, ה-proxy פעיל
  (אומת מבחוץ: `server: cloudflare` + `cf-ray` בתגובה של liders-crm.com).
- ❌ **ה-Transform Rule עוד לא עובד** — בבדיקה האחרונה אף כותרת אבטחה לא הופיעה
  בתגובה. המשתמש הוסיף rule אבל כנראה: לא עבר Deploy (נשאר Draft) / נוצר כ-Modify
  **Request** Header במקום **Response** / תנאי hostname שגוי. ממתין לתיקון משתמש
  ואז לבדוק שוב.
- 🔬 **איך בודקים מבחוץ** (ה-sandbox חסום לרשת! curl/WebFetch מחזירים 403): דרך
  pg_net ב-DB — ‏`select net.http_get('https://liders-crm.com/')` ואז
  `select status_code, headers from net._http_response where id = <req_id>` עם
  execute_sql. לבדוק גם את www אחרי שהכל עולה.
- 📋 **ה-headers שסוכמו** (Rules → Transform Rules → Modify Response Header,
  rule אחד "Security Headers" על All incoming requests, הכל Set static):
  `Strict-Transport-Security: max-age=63072000; includeSubDomains; preload`,
  `X-Frame-Options: DENY`, `X-Content-Type-Options: nosniff`,
  `Referrer-Policy: strict-origin-when-cross-origin`,
  `Permissions-Policy: camera=(), microphone=(), geolocation=()`,
  `Content-Security-Policy: frame-ancestors 'none'` (רק frame-ancestors! ה-CSP
  המלא נשאר ב-meta פר-דף — header מלא היה נאכף כחיתוך ועלול לשבור דפים).
  **לא** להוסיף COOP: same-origin (שובר Google OAuth בפופאפ). בנוסף: SSL/TLS
  ב-Full (Strict) + Always Use HTTPS.
- עד שה-rule יעבוד — **ה-meta CSP הוא עדיין ההגנה היחידה בפועל.** כשיאומת שהכל
  חי: לעדכן סעיף זה + לשקול הסרת ה-frame-busting JS (לא לפני!).

---

## 🔒 כשמעדכנים חבילות CDN — חובה לעדכן SRI

כאשר מעדכנים את Supabase או Chart.js:
1. `cd /tmp/sri_work && npm install @supabase/supabase-js@<VER> chart.js@<VER>`
2. חשב hash: `cat node_modules/@supabase/supabase-js/dist/umd/supabase.js | openssl dgst -sha384 -binary | openssl base64 -A`
3. עדכן את `integrity="sha384-..."` ב-index.html (שתי שורות בתחילת ה-`<body>` תחת CSS)

גרסאות נוכחיות: supabase-js@**2.108.2**, chart.js@**4.5.1**

---

## 🚨 LAUNCH BLOCKER — חובה להזכיר בכל שיחה

> **ספק התשלום הוא Grow (PayMe API) — לא Stripe/Tranzila**
> - Stripe קיים בקוד כ-**demo בלבד** (edge function `stripe-webhook`) — אל תבנה/תשנה עליו
> - Grow רכשה את משולם — עובדים על מסלול "לא סלקת לא שילמת" (עמלה בלבד)
> - מפתחות PayMe API מגיעים בקרוב → לבנות `grow-webhook` edge function ולחבר
> - `PAYMENTS_LIVE: false` בקוד — כשיהיו מפתחות: לשנות ל-`true` + למלא `CHECKOUT_URLS`
>
> 🔑 **לא גובים כסף אמיתי עד שהוגדר Grow/PayMe live**

---

## חזון הפרויקט

**Liders CRM** — הפלטפורמה שהופכת לידים לעסקאות.

מערכת CRM מודרנית, מובייל-ראשון, לניהול פייפליין מכירות.
דגש על **חווית משתמש** מעולה ו**אבטחה** מקסימלית.

---

## 🎯 תחומי יעד (Verticals) — הוחלט 2/7/2026

> **המערכת ממוקדת ב-3 תחומים בלבד: סוכן נדל"ן, עו"ד נדל"ן, מעצב פנים.**
> אלו שלושת בעלי המקצוע שמלווים עסקת נדל"ן מקצה לקצה ומקבלים לידים ממשפך שיווקי אמיתי
> (לא מהפניות/הזמנות מוסדיות בלבד). קיים ביניהם רשת הפניות טבעית (Partners/שיתוף לידים).

| תחום | מזוהה ב-`liders_industry`/`tenants.industry` | פיצ'רים ייחודיים |
|------|---|---|
| סוכן נדל"ן | `realestate` | יד2/מדלן (קיצורי דרך+ייבוא), מחשבון משכנתא, AI שיווקי לנכסים, מקורות: יד2/מדלן/פייסבוק/אינסטגרם |
| עו"ד נדל"ן | `realestate_lawyer` | תיקים/בדיקת נאותות/ניסוח חוזה, מקור "הפניית סוכן נדל\"ן" |
| מעצב פנים | `interior` | שדה השראה (Pinterest), מקור "הפניית סוכן נדל\"ן" |
| אחר | `other` | דלת אחורית טכנית בלבד — לא משווק, לא נבחר באונבורדינג חדש |

**הוסרו** (היו נתמכים בעבר, נמחקו מהאונבורדינג/הגדרות/שיווק): קבלן (`construction`),
צלם נכסים (`photography`), יועץ משכנתאות (`mortgage`), שמאי (`appraiser`), אדריכל (`architect`).
הסיבה: כולם עובדים בעיקר מהפניות/הזמנות מוסדיות (בנק, עו"ד, לקוח קודם) ולא ממשפך
שיווק-לידים בנפח גדול — כפי שאישרה גם יועצת משכנתאות שבדקה את המערכת בפועל ("מעולה
אבל לא תואמת צרכים של יועצי משכנתאות" — הם צריכים ממשק בנקים/כתבי הסמכה/סימולטור
תמהיל, לא פייפליין מכירה).

**Tenants קיימים** (סטטוס 2/7/2026): טופל במלואו. לא היו tenants אמיתיים במערכת (רק
4 חשבונות בדיקה טרום-השקה) — הם אופסו ל-`other` ישירות ב-DB, ובנוסף תוקן CHECK
constraint שבור על `tenants.industry` (ראה בהמשך).

### 🚀 רודמאפ פיצ'רים ייעודיים לפי תחום
לכל תחום שנשאר יתווספו פיצ'רים ספציפיים בהדרגה (לא כולם בבת אחת). ברשימת ההמתנה:

| תחום | פיצ'ר מבוקש | סטטוס |
|------|--------------|-------|
| כל התחומים | **לולאת הפניות** — הפניית ליד לקולגה בוואטסאפ + גיוס ויראלי | ✅ MVP בוצע 3/7 (מיגרציה 061 + UI, ראה סשן 3/7 ערב). נותר: מסך סטטיסטיקות, converted‏ + ‏500 XP |
| עו"ד נדל"ן | **ציר זמן תיק ללקוח** — קישור צפייה בלבד לסטטוס התיק | 📐 תוכנן 3/7 — `FEATURE_PLANS.md` (עדיפות 2, תשתית לחתימה דיגיטלית) |
| מעצב פנים | **סיכום תיק השראה ב-AI** — קונספט + פלטה מהשראת Pinterest | 📐 תוכנן 3/7 — `FEATURE_PLANS.md` (עדיפות 3, חלק מתוסף השיווק) |
| סוכן נדל"ן | **התאמת נכס ↔ לידים ב-AI** — "3 לידים מחפשים בדיוק את זה" | 📐 תוכנן 3/7 — `FEATURE_PLANS.md` (עדיפות 4) |
| עו"ד נדל"ן | **חתימה דיגיטלית על חוזים** — יצירת טופס/מסמך ושליחה ללקוח לחתימה מרחוק | 💡 רעיון, פיצ'ר "פגז" לפי המשתמש, טרם תוכנן טכנית |
| עו"ד נדל"ן | תוכן שיווק AI הותאם (ראה "תוסף שיווק" למטה) | ✅ בוצע 2/7 |
| — | עוד פיצ'רים per-vertical | 💭 ימשיכו להיאסף ולהתווסף בהמשך |

### 📣 תוסף שיווק — גלוי לכולם, גישה בתשלום
מסך "שירותי שיווק" (`Marketing.render`) **מוצג לכל המשתמשים** (גם בלי תוסף/אחרי תום
ניסיון) כדי שיראו בדיוק מה קיים לפני שמחליטים לרכוש — לא מסך נעילה חסום. הכפתורים
בפועל (`genOffer`/`genPost`/`genCampaign`, גם `SmartWA`) חסומים ב-`_requireAccess()`
(דורש `marketing_addon=true` או ניסיון פעיל) ומציגים toast להפעלת התוסף בלחיצה.
תוכן ה-AI מותאם לפי תחום: עו"ד נדל"ן מקבל "פוסט תוכן מקצועי" (טיפ משפטי כללי, לא
צמוד ללקוח/תיק ספציפי, בהתאם לכללי פרסומת של לשכת עורכי הדין) במקום "פוסט על נכס",
וטופסי הצעה/קמפיין WhatsApp מקבלים ניסוחים מקצועיים במקום מבצעי מכירה.

### 🌎 רעיון עתידי (לא בתכנון פעיל) — CRM נפרד לקבלני שיפוצים במיאמי
יתכן מוצר **נפרד לגמרי** (לא Liders העברי) לקהל אמריקאי-היספני בפלורידה (שיפוצים/בנייה),
מרובה-שפות (אנגלית, ספרדית, פורטוגזית), כיוון LTR, מטבע דולר, מיתוג ושיווק משלו.
זה לא קשור לקוד/לתיעוד של Liders CRM — רק תיעוד לזיכרון, לא לפעולה.

---

## Stack

- **Frontend**: HTML + CSS + Vanilla JS (RTL, עברית)
- **Database**: Supabase (PostgreSQL + RLS)
- **Auth**: PIN-based admin (bcrypt hash)
- **Automations**: Make.com
- **Calendar**: Google Calendar MCP
- **Design**: Figma + Canva MCP
- **Architecture**: Miro MCP
- **Docs**: Notion MCP
- **Storage**: Airtable MCP
- **AI Agents**: Anthropic Claude API

---

## Entities

| Entity | תיאור |
|--------|-------|
| `Lead` | ליד: שם, חברה, טלפון, אימייל, ערך עסקה, שלב פייפליין |
| `CrmSettings` | הגדרות: שם חברה, tagline |
| `AdminAuth` | PIN hash — ללא גישה ישירה מה-API |

---

## Pipeline Stages

| ID | שם | צבע |
|----|-----|------|
| 1 | ליד חדש | אפור |
| 2 | יצרנו קשר | כחול |
| 3 | הצעה נשלחה | סגול |
| 4 | במשא ומתן | כתום |
| 5 | עסקה סגורה ✓ | ירוק |

---

## Design System

- **Palette**: Navy (#0F1F3D) + Blue (#2563EB) + Light gray (#F1F5F9)
- **Font**: Heebo
- **Direction**: RTL מלא
- **Mobile-first**: 390px viewport ראשוני

---

## Supabase Project

- **Project ID**: `scyfywvzoogfrlalgftv`
- **Region**: eu-central-1
- **URL**: `https://scyfywvzoogfrlalgftv.supabase.co`

### טבלאות

| טבלה | RLS | הערה |
|------|-----|------|
| `leads` | anon CRUD | פייפליין לידים |
| `crm_settings` | anon READ בלבד | עדכון דרך RPC |
| `admin_auth` | ללא גישה | PIN hash בלבד |

### RPCs

| פונקציה | תיאור |
|---------|-------|
| `verify_admin_pin(pin_input)` | אימות PIN — מחזיר boolean |
| `save_crm_settings(pin, name, tagline, new_pin?)` | שמירת הגדרות + שינוי PIN |

---

## קישורים חיים

| | URL |
|-|-----|
| CRM (לקוחות) | https://liders-crm.com/ |
| פאנל אדמין | https://liders-crm.com/admin.html |

> האדמין מחובר לאותה Supabase. כניסה: אימייל + סיסמה. קישור אליו גם מתוך הגדרות ה-CRM.

### 📧 מיילים של הבעלים
| שימוש | כתובת |
|-------|--------|
| **עסקי ראשי (Google Workspace PLTO)** | `info@plto.app` |
| **Gmail מתווך (forwarding → info@plto.app)** | `liders.crm@gmail.com` |
| Supabase auth + GitHub (כניסה) | `elgrablidudu@gmail.com` |

> **כל דוח אוטומטי, התראה, Make.com webhook שנשלח למייל — תמיד ל-`info@plto.app`**
>
> `liders.crm@gmail.com` מגדיר forwarding ל-`info@plto.app` — אין צורך לשנות את Supabase auth.
> מיילים עתידיים שיצטרפו: `support@plto.app`, `admin@plto.app` וכו' (כל אחד בעת יצירת האוטומציה)

---

## Make.com

- **Team ID**: `1851801`
- **Zone**: `eu1.make.com`
- **Webhook URL**: `https://hook.eu1.make.com/f0nzngm6gdokri5naqu7enbay538ay8i`

### סצנריות פעילות

| סצנריו | ID | קישור | טריגר |
|--------|-----|-------|-------|
| Lead Notifications | 6083347 | https://eu1.make.com/1851801/scenarios/6083347/edit | Webhook |
| Trial Expiry Notifications | 6185659 | https://eu1.make.com/1851801/scenarios/6185659/edit | Scheduled (24h) |

---

## MCP Servers

| שרת | UUID prefix | שימוש |
|-----|-------------|-------|
| Supabase | `f474d5bb` | DB, migrations, RLS |
| Google Calendar | `6368118b` | ניהול יומן |
| Gmail | `4e93495e` | תקשורת |
| Make.com | `194941ca` | אוטומציות |
| Figma | `88a7dadd` | UI design |
| Canva | `3f33a9a8` | Marketing |
| Notion | `97537a26` | תיעוד |
| Airtable | `273af94e` | דיווח |
| Miro | `4a81aac9` | ארכיטקטורה |
| GitHub | `github` | version control |

---

## Files

```
index.html     — האפליקציה המלאה (HTML + CSS + JS)
admin.html     — פאנל SaaS admin (ניהול tenants)
CLAUDE.md      — קובץ זה
supabase/
  functions/
    ai-proxy/         — Edge Function: ממשק ל-Claude Haiku (ANTHROPIC_API_KEY)
    stripe-webhook/   — Edge Function: demo בלבד — אל תפעיל ב-production
.claude/
  settings.json
  skills/
```

### Supabase Edge Functions

| Function | תיאור | סטטוס |
|----------|-------|-------|
| `ai-proxy` | קריאה ל-Claude Haiku 4.5 | פעיל ✅ |
| `stripe-webhook` | demo/test בלבד | demo ⚠️ |

**ANTHROPIC_API_KEY** מוגדר ב-Supabase Secrets. מודל נוכחי: `claude-haiku-4-5-20251001`.
מדרג עלויות: Haiku → Sonnet כשיש הכנסות.

---

## Marketing Addon

| נושא | פרטים |
|------|--------|
| State | `State.tenant.marketing_addon === true` |
| הפעלה ידנית | Admin → modal ניהול tenant → checkbox שיווק |
| הפעלה אוטומטית | Tranzila webhook → `marketing_addon: true` (עתידי) |
| כלים | `Marketing.genOffer()`, `genPost()`, `genCampaign()` — Claude Haiku |
| מחיר | ₪100/חודש לתוסף |
| Payment Link URL | `Marketing._STRIPE_MARKETING_URL` ב-index.html — ריק עד שיוגדר Tranzila |

---

## מה בוצע — סשן 26/6/2026

### ✅ הושלם
1. **Onboarding Step 2** — שדות שם/טלפון/אימייל/עסק ריקים עם placeholder
2. **Onboarding Step 4** — קישור "אפשר לדלג" מתחת לשדה Webhook
3. **Onboarding Step 5** — 3 כפתורי פעולה, כפתור 🚀 מוסתר בשלב האחרון
4. **PIN lock** — הגדרת PIN + מסך נעילה אחרי setup (תוקן: `lock()` נקרא אוטומטית)
5. **admin.html** — עמודת שיווק בטבלה, modal ניהול tenant עם checkbox/הארכת ניסיון/הערות
6. **Claude AI בשיווק** — genOffer/genPost/genCampaign קוראים ל-ai-proxy (לא עוד תבניות)
7. **auto-activate marketing addon** — stripe-webhook מטפל ב-`addon: marketing` (demo)

### 📋 ממתין לפעולה חיצונית
- פתיחת מס עוסק + חשבון בנק → לאחר מכן: Tranzila live + `tranzila-webhook`
- Deploy של `stripe-webhook` לאחר שינויים (Supabase Dashboard → Functions)
- הגדרת `Marketing._STRIPE_MARKETING_URL` כשיהיה Payment Link

### 🔧 ענף עבודה
- `claude/onboarding-bonus-features-n12mqu` — שינויי סשן 26/6
- `claude/system-enhancements-roadmap-x1f9b4` — שינויי סשן 27/6

---

## מה בוצע — סשן 28/6/2026

### ✅ הושלם
1. **עדכון מחירים** — Solo ₪179 / Pro ₪349 / סוכנות ₪549 (חודשי)
2. **מחירי שנתי** — Solo ₪124/חודש (₪1,490) / Pro ₪249 (₪2,990) / סוכנות ₪399 (₪4,790)
3. **שיווק תוספת** — ₪100/חודש נשאר; משולב במחיר השנתי (₪279 → ₪124 = חיסכון ₪1,858)
4. **הצגת מחירי השקה** — badge "🚀 מחיר השקה — יעלה בהמשך" על כל קלף חבילה בפייפלין
5. **Annual teaser בקלפים** — כל קלף מציג "₪XXX/חודש שנתי · חיסכון ₪X,XXX" בירוק
6. **Grow/PayMe** — עדכון CLAUDE.md + תיעוד PAYMENTS_LIVE flag
7. **7 תיקוני באגים מסשן 27** — commit + push

### 📋 ממתין לפעולה חיצונית
- קבלת מפתחות PayMe API מ-Grow → `PAYMENTS_LIVE: true` + `CHECKOUT_URLS` אמיתיים
- הורדת GitHub recovery codes ידנית

---

## מה בוצע — סשן 2/7/2026

### ✅ הושלם
1. **צמצום תחומי יעד מ-9 ל-3** — סוכן נדל"ן, עו"ד נדל"ן, מעצב פנים בלבד (ראה סעיף
   "🎯 תחומי יעד" למעלה להסבר המלא ולנימוק)
2. **הוסרו מהקוד** (onboarding picker, `INDUSTRY_LABELS`, `INDUSTRY_SOURCES`,
   `AI._industryRole`, טיפים בפייפליין/אונבורדינג, הגדרות): קבלן, צלם נכסים, יועץ
   משכנתאות, שמאי, אדריכל
3. **תוקן באג** — הודעות AI של quicklog ו-motivation תמיד כתבו "סוכן נדל\"ן" בקוד קשיח,
   בלי קשר לתחום האמיתי של ה-tenant. עכשיו קוראות ל-`AI._industryRole()`
4. **מקורות לידים חדשים** — נוסף מקור "הפניית סוכן נדל\"ן" לעו"ד נדל"ן ולמעצב פנים,
   משקף את רשת ההפניות הטבעית בין שלושת התחומים
5. **יד2/מדלן** — קיצורי הדרך בדשבורד מוצגים רק לסוכן נדל"ן (הוסרו מ-4 תחומים אחרים
   שהוצגו להם קודם בטעות)
6. **landing.html** — עודכנו meta description, hero badge וקטע "עלינו" לשקף 3 תחומים
   בלבד (במקום 6)
7. **הוסר קוד מת** — לוגיקת "construction → אנגלית ללקוח" ב-`Settings.getClientLang/
   setIndustry` (שריד מתכנון ישן, לא רלוונטי יותר)
8. **תוקן CHECK constraint שבור** על `tenants.industry` ב-DB החי (היה מכיל רשימת ערכים
   ישנה שהשתרבבה ידנית בעבר ולא תאמה לקוד כלל) + מיגרציה `060_fix_tenant_industry_
   check_constraint.sql`. אופסו 4 חשבונות הבדיקה הקיימים ל-`other`
9. **מחשבון משכנתא** — מוסתר עכשיו ממעצבי פנים ב"מרכז כלים" (רלוונטי רק לסוכן ולעו"ד)
10. **תוסף שיווק (AI content)** — מסך "שירותי שיווק" עכשיו **גלוי לכולם** (במקום מסך
    נעילה חסום כשאין גישה) כדי שכל משתמש יראה מה קיים ויחליט אם לרכוש; הגישה בפועל
    (`genOffer`/`genPost`/`genCampaign`) חסומה ב-`_requireAccess()` חדש. תוכן ה-AI
    הותאם לעו"ד נדל"ן: "פוסט תוכן מקצועי" (טיפ משפטי כללי, לא צמוד ללקוח/תיק, תואם
    לכללי פרסומת של לשכת עורכי הדין) במקום "פוסט על נכס למכירה"; גם ה"הצעה מיוחדת
    ללקוח" וקמפיין ה-WhatsApp קיבלו ניסוחים מקצועיים במקום מבצעי מכירה עם לחץ זמן

### 📋 ממתין לפעולה עתידית
- **חתימה דיגיטלית על חוזים לעו"ד נדל"ן** — פיצ'ר מבוקש בעדיפות גבוהה, טרם תוכנן טכנית
- עוד פיצ'רים ייעודיים per-vertical ימשיכו להיאסף בהמשך
- רעיון "CRM נפרד לקבלני שיפוצים במיאמי" — תועד כרעיון עתידי בלבד, לא בתכנון פעיל

---

## מה בוצע — סשן 3/7/2026 (ערב) — שדרוג דף נחיתה + לולאת הפניות MVP

### ✅ דף נחיתה (landing.html)
1. **פונט** — הוחלף מ-Heebo ל-**Rubik** (Heebo כ-fallback) + הגדלה כללית של כותרות
   וטקסטים בכל הסקשנים
2. **אנימציות נדל"ן** — עגורן CSS מעל ה-CTA הראשי שמוריד משקולת "30 יום 🎁" על
   הכפתור (squash + ענן אבק, כל 7 שניות; כבוי במובייל צר וב-reduced-motion); רצועת
   "אתר בנייה" לפני התמחור (טרקטור 🚜, משאית 🚚, פועל 👷 חופר, קונוסים); רצועות
   מעבר צבע רכות (`sect-blend-light/dark`) בין סקשנים כהים לבהירים
3. **תוקן באג הגלילה** — רכיב ה-reveal (sticky 220vh שהציג מסך ריק) הוסר לחלוטין יחד
   עם הלייטבוקס; הוחלף בגלריית "טעימה" חתוכה (150px + fade) עם CTA כניסה למערכת —
   בכוונה לא מראים הכל בדף הנחיתה
4. **תמחור** — chip מושבים בצוות ("עד 8 סה\"כ · ₪40/חודש לסוכן נוסף") ובסוכנות
   ("עד 25 סה\"כ · ₪40"); badge על Solo "כולל 30 יום ניסיון חינם"; הערה: **הניסיון
   תקף לחבילת הבסיס בלבד**; רצועת "צריך חבילה גדולה יותר? דברו איתנו"; עודכנו FAQ
5. **דיוק טקסטים** — תיאורי חבילות ל-3 התחומים, פוסט סושיאל פר-תחום, כרטיס פיצ'ר
   חדש "לולאת הפניות בין קולגות"
6. ✅ **פער המחירים נסגר (3/7)**: הוחלט — סוכן נוסף עולה **₪40 בכל חבילה**. מיגרציה
   `062_seat_price_40_all_plans.sql` הוחלה על ה-DB (pro: 30→40), ועודכן גם
   `agentLimit` ב-index.html. אין יותר אזכורי ₪30 למושבים.

### ✅ לולאת הפניות (Referral Loop) — MVP שלבים 1-2 מ-FEATURE_PLANS.md
1. **מיגרציה 061** (`061_lead_referral_loop.sql`, הוחלה על ה-DB החי): טבלת
   `lead_referrals` (RLS בלי policies — גישה רק דרך RPCs, בדפוס 040/046) + RPCs:
   `create_lead_referral` (snapshot מסונן: שם/טלפון/אזור/הקשר בלבד, token אקראי
   128-bit, תפוגה 14 יום, rate limit ‏10/יום), `get_lead_referral_preview` (anon —
   שם מפנה/תחום/שם פרטי בלבד), `accept_lead_referral` (יוצר ליד אצל המקבל, חד-פעמי,
   חוסם הפניה עצמית), `pull_lead_referral_xp` (‏+250 XP למפנה), `list_my_lead_referrals`
2. **UI ב-index.html**: כפתור "🔗 הפנה לקולגה" בכרטיס ליד → מודל (תחום/שם/טלפון/
   משפט הקשר + checkbox הסכמת לקוח) → הודעת וואטסאפ עם `?lref={token}`; צד מקבל:
   הטוקן נשמר ב-localStorage (שורד הרשמה/אונבורדינג), אחרי התחברות מודל "קיבלת
   הפניית לקוח!" → הליד נכנס לפייפליין; זיכוי XP למפנה בכניסה הבאה (`LeadReferral`)
3. **נותר לשלבים הבאים**: מסך סטטיסטיקות, converted‏ + ‏500 XP, הישג "מלך ההפניות",
   התראת Make למפנה, דף נחיתה ייעודי לקולגה לא-רשום

---

## מה בוצע — סשן 27/6/2026

### ✅ הושלם
1. **סוכן מוטיבציה** — כרטיס AI בראש הדשבורד, עד 5 מסרים/יום (`AiLimits` סוג `motivation`)
2. **מדריך הדרכה** — כפתור "ראה איך משתמשים במערכת" → מודל עם 6 שלבי הסבר (ללא סרטון — לא נדרש)
3. **Guided Tour** — סיור 6 שלבים עם spotlight + טולטיפ, מוצג פעם אחת אחרי אונבורדינג (`liders_tour_v1`)
4. **XP Store** — פרסים דיגיטליים/שירותיים בלבד (1,000–50,000 XP): ייעוץ שיווקי → דף נחיתה → תהליך מכירה → תוכן שיווקי → אתר תדמית → CRM מותאם → פרטנר אסטרטגי
5. **קונפטי** — 110 חתיכות + 🏀 סל בסגירת עסקה + 🏆 גביע במיילסטון + 🎯 מטרה בהתקדמות שלב
6. **מחירון AI** — חושב ומיושם (ראה טבלה למטה)
7. **סקר שוק** — בוצע (ראה טבלה למטה)

### 📋 נשאר לביצוע

#### 🔴 גבוה
| # | תכונה | תיאור | תלות |
|---|--------|--------|------|
| 3 | **ניהול מיילים AI** | Gmail MCP → AI מסנן ומגיב: סיווג חשיבות + חסימת ספאם + תגובה לתמיכה | Gmail MCP |

#### 🟢 נמוך
| # | תכונה | תיאור |
|---|--------|--------|
| 4b | **Tranzila webhook** | לאחר מס עוסק + חשבון בנק → לבנות `tranzila-webhook` ולחבר לחבילות AI |
| 6b | **חנות XP נוספת** | עוד מתנות — ה-API מוכן |

#### ⚪ בהמשך
- 20$ Anthropic API → שדרוג ל-Sonnet (ראה חישוב למטה)
- Tranzila live payments

---

## 💰 מחירון AI — חישוב עלות vs. מכסות

### מחיר API: Claude Haiku 4.5
| סוג | Input | Output |
|-----|-------|--------|
| תעריף | $0.80/1M tokens | $4.00/1M tokens |

### עלות ממוצעת לקריאה לפי סוג:
| סוג | Input | Output | עלות |
|-----|-------|--------|------|
| motivation (קצר) | 150 tokens | 120 tokens | ~$0.0006 |
| quicklog (בינוני) | 200 tokens | 200 tokens | ~$0.0010 |
| general (ניתוח) | 300 tokens | 250 tokens | ~$0.0012 |
| support (תמיכה) | 400 tokens | 400 tokens | ~$0.0019 |
| marketing (תוכן) | 500 tokens | 600 tokens | ~$0.0028 |
| **ממוצע משוקלל** | | | **~$0.0015/קריאה** |

### מכסות יומיות — **לכל סוכן (agent) בנפרד, לא לכל tenant!**
המכסה נאכפת ב-`check_and_increment_ai_usage()` RPC לפי `auth.uid()` (טבלת `ai_usage`,
PK=`user_id,usage_date`). כל סוכן שמתחבר לחשבון מקבל את המכסה המלאה, בנפרד מסוכנים
אחרים באותו tenant. המספרים למטה הם המכסות החיות בפועל (סשן 1/7/2026, לא ₪10/₪20/₪30
הישנים ששויכו כאן פעם — אלה הוחלפו במחירי Solo/צוות/סוכנות למטה):

| תוכנית | general | marketing | quicklog | support | motivation | עלות API/חודש/סוכן (30% ניצול) |
|--------|---------|-----------|----------|---------|------------|-----------------------------------|
| trial | 2/יום | 3/יום | 3/יום | 2/יום | 2/יום | ~$0.17 |
| basic (Solo) | 5/יום | 8/יום | 15/יום | 8/יום | 3/יום | ~$0.55 |
| pro (צוות) | 10/יום | 15/יום | 30/יום | 15/יום | 3/יום | ~$1.01 |
| premium (סוכנות) | 20/יום | 25/יום | 50/יום | 25/יום | 3/יום | ~$1.69 |

### מחיר המנוי בפועל היום (לא ₪10/₪20/₪30!): **Solo ₪179 / צוות ₪349 / סוכנות ₪549 לחודש**

מרווח AI אמיתי (עלות/סוכן × מספר מושבים מובטח, מול הכנסת המנוי):
- Solo (1 סוכן): $0.55 (~₪2) מול ₪179 → **מרווח ~99%**
- צוות (3 סוכנים כלולים, עד 8 בתוספת ₪40/סוכן — מיגרציה 062): $3.03 (~₪11) מול ₪349 →
  **מרווח ~97%**, גם ב-8 מושבים מלאים ($8.08≈₪29.5 מול ₪549 הכנסה: 3 כלולים+5×₪40) →
  **מרווח ~95%**
- סוכנות (10 סוכנים כלולים, ₪40/סוכן נוסף, מקסימום 25 סוכנים — לא ללא הגבלה): $16.9
  (~₪62) מול ₪549 → **מרווח ~89%**. כל מושב נוסף: $1.69 (~₪6.2) עלות מול ₪40 הכנסה →
  **~84.5% מרווח למושב**. ב-25 מושבים מלאים (10 כלולים+15×₪40=₪600 נוסף, סה"כ ₪1,149):
  עלות AI $42.25≈₪154 → **מרווח ~86.6%**.
- **מעבר ל-25 מושבים בסוכנות — לא זמין בהזמנה עצמית.** סוכנות בגודל כזה זו שיחת מכירות
  אמיתית (הצעה מותאמת אישית), לא תוספת לינארית זולה — ה-RPC חוסם ומפנה אוטומטית
  לפניית תמיכה עם הודעה מוכנה ("מעוניין בהצעת Liders Enterprise").

### מנגנון מושבים (סוכן ↔ tenant)
מיושם ב-`supabase/migrations/048_agent_invites.sql` + `049_ensure_agent_invite_aware.sql`
+ `050_seat_pricing_update.sql`: טבלת `agent_invites`, RPCs
`invite_agent`/`list_agent_invites`/`revoke_agent_invite`, ו-`admin_list_tenant_seats()`
לצפייה באדמין. מספרי המושבים לכל תוכנית קבועים ב-SQL (פונקציית `_seat_config`), לא בקוד
ה-JS — מקור אמת יחיד. **גבייה על מושבים נוספים היא ידנית כרגע** (דרך חשבוניות באדמין)
עד ש-Grow/PayMe יהיה חי (`PAYMENTS_LIVE: false`).

---

## 🏆 סקר שוק — Liders CRM vs. מתחרות

### טבלת מחירים ($/user/month, מחירי 2025):

| CRM | Starter | Mid | Enterprise | עברית | Mobile | AI מובנה |
|-----|---------|-----|-----------|-------|--------|---------|
| **Liders** | **חינם 30י** | **₪179** | **₪349–549** | ✅ מלאה | ✅ first | ✅ Claude |
| Pipedrive | $14 | $29–49 | $64–99 | ❌ | ⚠️ | ❌ |
| monday CRM | $15 | $20–33 | custom | ⚠️ חלקית | ⚠️ | ⚠️ בסיסי |
| HubSpot | $20 | $100+ | $1,500+ | ❌ | ⚠️ | ✅ ChatGPT |
| Salesforce | $25 | $80 | $165+ | ❌ | ❌ | ✅ Einstein |
| Zoho CRM | $14 | $23–40 | $52+ | ❌ | ⚠️ | ⚠️ Zia |

### היתרונות הייחודיים של Liders:

| יתרון | מה זה אומר |
|--------|-----------|
| 🇮🇱 **עברית מלאה RTL** | היחיד שנבנה לישראלים מהיסוד — לא תרגום |
| 📱 **Mobile-first** | עובד מושלם בנייד — לא desktop שהותאם |
| 🎮 **Gamification** | XP, פרסים, הישגים — לא קיים אצל אף מתחרה |
| 🤖 **Claude AI מובנה** | שיווק, תמיכה, מוטיבציה — ב-Haiku כבר, Sonnet בדרך |
| 🔗 **Make + WhatsApp** | אינטגרציות ישראליות ספציפיות |
| 🏦 **מחשבון משכנתא** | כלי נדל"ן ייחודי — אין לאף אחד |
| 💸 **מחיר** | שליש עד עשירית ממחיר המתחרות |
| 🚀 **פשטות** | לוקח 5 דקות ללמוד — Salesforce לוקח חודשים |

### מסקנה
Liders מתחרה ב-Pipedrive ו-monday.com בתחום ה-SMB. הם גובים $14-33/user/month ואין להם עברית/נייד/AI ספציפי לישראל. **הייחוד שלנו הוא ברור ומשמעותי.** מחירים: Solo ₪179 / Pro ₪349 / סוכנות ₪549 — שליש עד עשירית ממחיר המתחרות, עם יתרונות ייחודיים לשוק הישראלי.

---

## מה בוצע — סשן 3/7/2026 (לילה) — תיקוני UI לולאת הפניות ולוח ההזדמנויות

> ענף: `claude/migrations-ui-build-fixes-3t08np` (בנוי על `claude/migrations-ui-build-991h15`)

### ✅ תיקוני באגים בעדיפות גבוהה
1. **ReferralsList._cardHTML** — הוספת כפתורי "💬 שלח לקולגה" / "🔗 העתק" לכרטיסי
   הפניות עם `direction==='sent'` ו-status `sent`/`opened`. הכפתורים קוראים לשתי
   מתודות חדשות: `sendToColleague(token)` ו-`copyColleagueLink(token)` שמחפשות
   את הפריט ב-`_items` לפי token ובונות הודעת וואטסאפ מתאימה.
2. **LeadReferral.copyLink()** — הוסף `id="lref-copy-btn"` לכפתור ה-HTML, ו-`create()`
   מסתיר אותו (`classList.toggle('hidden', requireConsent)`) כשנבחר אישור פורמלי,
   מונע שליחת קישור `?lref=` לפני שהלקוח אישר.

### ✅ תיקוני באגים בעדיפות בינונית
3. **ולידציית תקרת עמלה** — הוסף בדיקת `commValue > 1000000` עם הודעה בעברית
   `"סכום העמלה המקסימלי הוא ₪1,000,000"` גם ב-`LeadReferral.create()` וגם
   ב-`OppBoard.publish()`.
4. **OppBoard._renderOpen()** — מעביר `State.tenant?.industry` כ-`p_vertical` ל-
   `list_open_opportunities`, כך שרק הזדמנויות בתחום הרלוונטי מוצגות.
5. **ביטול מועמדות** — הוסף כפתור "🚫 בטל מועמדות" ב-`_renderOpen()` כשסטטוס
   `pending` + מתודת `withdraw(oppId)` חדשה שקוראת ל-`withdraw_my_application`.

### ✅ תיקוני עדיפות נמוכה
6. **escapeHtml לאזור** — `viewApplications()`: הפולבק `a.applicant_region` עטוף
   ב-`escapeHtml()` לעקביות הגנת XSS.
7. **agreement_required** — הוסף case ב-`accept()` catch שקורא ל-`openAgreementModal()`
   כרשת ביטחון, אם מנגנון `_inboundLocked` לא יסונכרן נכון.

### 📋 נשאר לביצוע עתידי
- `/security-review` על הזרימות החדשות (RPCs אנונימיים: `get_client_consent_preview`,
  `respond_client_consent`, `get_lead_referral_preview`) — דורש אישור מפורש מהמשתמש
  לפני הפעלה.
- מסך סטטיסטיקות הפניות, converted+500 XP, התראת Make למפנה.
- דף נחיתה ייעודי לקולגה לא-רשום.

---

## מה בוצע — סשן 3/7/2026 (לילה מאוחר שני) — ניטרליות מגדרית ב-index.html

> ענף: `claude/system-fixes-updates-nujroa`

### ✅ הושלם
1. **ניטרליות מגדרית מלאה ב-`index.html`** — כל הביטויים הזכריים בממשק הוחלפו:
   - `ברוך הבא` → `ברוכים הבאים` (כותרת אונבורדינג + toast)
   - `בוא נתחיל` → `נתחיל` (כפתורי onboarding ו-GuidedTour)
   - `הכנס`/`הזן` (פקודות) → `יש להזין`/`נא להזין` (כל validations)
   - `הירשם` → `הרשמה`/`להרשמה` (כל CTA הרשמה)
   - `אתה X` → מבנה ניטרלי (מגדיר/מאשר/מסכים/מכיר/בונה/שולח)
   - `מעצב פנים` בתוויות UI → `מעצב/ת פנים` (options, labels, VERTICALS)
   - תבניות WA ללידים: `אתה האדם הראשון` → `את/ה הראשון/ה`
   - סיסטם פרומפט מוטיבציה: `גוף שני זכר` → `ניטרלי מגדרית ככל האפשר`
2. **כלל קבוע ב-CLAUDE.md** — נוסף סעיף `⚧ ניטרליות מגדרית` עם טבלת עזר לכל הסשנים

### 📋 הערות
- `_industryRole()` נשאר `'מעצב פנים'` (בלי "/ת") — הוא מיועד ל-AI prompt, לא לממשק
- ניטרליות מגדרית ב-`landing.html` ו-`admin.html` — בוצעה בסשנים קודמים

---

## מה בוצע — סשן 3/7/2026 (לילה מאוחר) — קיצורי דרך לפי תחום + תיקון העלאת CSV

> ענף: `claude/hand2-buttons-homepage-pl4d29`

### ✅ הושלם
1. **קיצורי דרך לפי תחום** — שורת הכפתורים בדשבורד עכשיו מותאמת לכל אחד מ-3 התחומים:
   - **סוכן נדל"ן** (`realestate`): יד2 · מדלן · WhatsApp · רעיון (ללא שינוי)
   - **עו"ד נדל"ן** (`realestate_lawyer`): 🏛 טאבו (aris.justice.gov.il) · 📚 נבו (nevo.co.il) · 💰 מיסוי מקרקעין (taxes.gov.il) · WhatsApp · רעיון
   - **מעצב פנים** (`interior`): 📌 Pinterest · 🛋 Houzz · WhatsApp · רעיון
   - מימוש: 3 divs נפרדים (`realestate-shortcuts`, `lawyer-shortcuts`, `interior-shortcuts`),
     JS מציג רק את הרלוונטי לפי `ind` ב-`Dashboard._applyIndustryLabels()`
2. **CSS חדש** — classes לכפתורים חדשים: `re-nevo` (כחול), `re-tabo` (navy), `re-misim` (סגול),
   `re-pinterest` (אדום), `re-houzz` (ירוק)
3. **תיקון העלאת קבצים מגוגל דרייב** — שינוי ה-`accept` ב-file input מ-`.csv,.txt,text/csv`
   ל-רשימה שכוללת גם `.xlsx,.xls` + MIME types של Excel → קבצים אינם עוד חסומים בבחירה
4. **זיהוי Excel ב-`LeadImport.handleFile()`** — אם נבחר קובץ `.xlsx`/`.xls`, מוצג toast
   כחול עם הנחיה: "פתח ב-Google Sheets ← קובץ ← הורד ← CSV, ואז העלה את ה-CSV"
5. **`toast()` עודכן** — תומך כעת ב-`duration` כפרמטר שלישי (ברירת מחדל 3200ms)
6. **`toast-info` CSS** — נוסף class כחול (`--blue-600`) לצד `toast-success` ו-`toast-error`

---

## מה בוצע — סשן 3/7/2026 (לילה שלישי) — הסרת כל צורות הסלאש + עדכון CLAUDE.md

> ענף: `claude/system-fixes-updates-nujroa`

### ✅ הושלם
1. **הוסרו כל צורות הסלאש מ-`index.html`** — 12 מופעים ב-12 מיקומים שונים:
   - `מעצב/ת פנים` ← `עיצוב פנים` (5 מקומות: שתי `<option>`, VERTICALS, label ב-onboarding,
     label ב-OppBoard) — כולל שלושת התחומים: כל תיוג "עיצוב פנים" עקבי ואחיד
   - `שלח/י אותה לקולגה בוואטסאפ` ← `שליחת הקישור לקולגה בוואטסאפ` (HTML + JS)
   - `הבנתי ומסכים/ה, בואו נתחיל!` ← `הבנתי, בואו נתחיל!` (כפתור הסכמת שיווק)
   - `ראיתי שאת/ה מחפש/ת [נושא]` ← `ראיתי שיש עניין ב[נושא]` (תבנית WA כללית)
   - `תאר/י בקצרה מה צריך לבנות...` ← `תיאור קצר של מה שצריך לבנות...` (placeholder)
   - `ואת/ה בין הראשונים שאני פונה אליהם` ← `ואני פונה אליך לפני כולם` (תבנית WA הצעה)
   - `את/ה הראשון/ה שאני פונה אליך` ← `אני פונה אליך לפני כולם בקשר לנכס` (תבנית WA ראשון)
2. **עדכון `CLAUDE.md`**:
   - טבלת ניטרליות מגדרית עודכנה: אסור גם סלאש, הוספו דוגמאות מהסשן הזה
   - `מעצב פנים` (UI) ← `עיצוב פנים` בטבלה (הייתה שם `מעצב/ת פנים` בטעות)
   - כלל עבודה #7 תוקן: "תמיד בלשון זכר" ← "ניטרלית מגדרית תמיד"

### 📋 הערות
- כלל הסלאש חל על **ממשק בלבד** — AI system prompts (`_industryRole()` = `'מעצב פנים'`) לא משתנים
- כל שלושת התחומים (סוכן נדל"ן, עו"ד נדל"ן, עיצוב פנים) מכוסים — כל הטקסטים הם ברמת מערכת משותפת

---

## מה בוצע — סשן 4/7/2026 — סקירת אבטחה: 3 וקטורים מתקדמים

> ענף: `claude/security-vectors-review-rb6rbl` (מוזג ל-main)

### ✅ הושלם
1. **`stripe-webhook/index.ts`** — הוחלפה השוואת `computed === v1` בלולאת XOR constant-time
   למניעת timing side-channel attack על HMAC-SHA256
2. **`twilio-whatsapp/index.ts`** — נוסף בדיקת tenant isolation לפני שליחת WhatsApp:
   מוודא שמספר ה-`to` קיים בטבלת leads של ה-tenant המאומת (RLS אוטומטי).
   תומך בשני פורמטים: `+9725X` ו-`05X`. מחזיר 403 אם לא נמצא.
3. **`index.html`** — טוקן הפניה (`liders_inbound_lref`) הועבר מ-`localStorage` ל-
   `sessionStorage` — הוא קצר-חיים ורלוונטי לאותו tab (flow הרשמה)
4. **`063_referral_commission_agreements.sql` + `064_client_consents.sql`** — IP לביקורת
   (`signer_ip` / `response_ip`) משתמש כעת ב-`cf-connecting-ip` (Cloudflare, לא ניתן לזייף)
   כ-primary, `x-real-ip` כ-secondary, `x-forwarded-for` רק כ-fallback
5. **`privacy-policy.html`** — נוסף כרטיס אבטחה "אימות Webhooks וחתימות דיגיטליות";
   עדכון סעיף 8 לתיאור מדויק של localStorage ו-8h session ceiling
6. **`landing.html`** — תשובת FAQ אבטחה עודכנה לכלול אימות חתימות ובידוד tenant

### 📋 לביצוע בסשן הבא — סקירת אבטחה מקיפה עם Sonnet 5

> **הוחלט 4/7/2026**: לבצע `/security-review` ב-`high effort` עם Sonnet 5 על אזורים
> שלא כוסו בסשן זה. הנחיות לסוכן:

#### מוקד הסקירה — **RLS policies ו-DB schema**:
- לקרוא את **כל** מיגרציות `supabase/migrations/` (040 ומעלה) ולוודא:
  - כל טבלה חדשה: `ENABLE ROW LEVEL SECURITY` + policies מתאימות **או** הסבר מפורש
    ב-comment למה הגישה דרך SECURITY DEFINER RPCs בלבד (דפוס 040/046/061)
  - `leads`, `pipeline_stages`, `tenants`, `agent_invites`, `ai_usage`,
    `lead_referrals`, `referral_agreements`, `client_consents`, `opp_board_listings` —
    לוודא שכל אחת מוגנת ואין גישה ישירה שעוקפת RLS
- לבדוק את ה-RPCs: האם `get_my_tenant_id()` יכולה להחזיר NULL במצבים לא צפויים?
  האם כל RPC שמתחיל ב-`SECURITY DEFINER` מטפל ב-NULL tenant_id?

#### מוקד הסקירה — **Edge Functions**:
- `ai-proxy`: לוודא שה-sanitization לא ניתן לעקוף (prompt injection דרך system prompt)
- `twilio-whatsapp`: לוודא שה-phone filter החדש (`.or(phoneFilter)`) לא פגיע
  ל-PostgREST filter injection אם מספר הטלפון מכיל תווים מיוחדים (`,`, `.`, `(`, `)`)
- `stripe-webhook`: (כוסה בסשן זה — OK)

#### מוקד הסקירה — **Frontend (index.html)**:
- לחפש `innerHTML` עם ערכים שמגיעים מ-DB/user input — לוודא `escapeHtml()` בכל מקום
- לבדוק את `Make.trigger()`: האם ה-payload מכיל נתוני tenant שמגיעים מ-localStorage
  ויכולים להיות מזויפים ע"י משתמש זדוני?
- לבדוק את `_create_lead_referral_core` — האם ה-`p_context` עובר עם `escapeHtml`
  בצד ה-frontend לפני שנשלח ל-RPC?

#### מה **לא** לבדוק (כוסה/ידוע):
- timing-safe HMAC ב-stripe-webhook ✅
- tenant isolation ב-twilio-whatsapp ✅
- x-forwarded-for spoofing ✅
- HttpOnly cookies (בלתי אפשרי ב-GitHub Pages — ידוע ומתועד)

---

## מה בוצע — סשן 5/7/2026 — שדרוג מערכת מקיף (13 משימות)

> ענף: `claude/system-upgrade-plan-whekhk` (מוזג ל-main)

### ✅ שלב א' — Quick Wins
1. **ניקוי חצים מכפתורים** — הוסרו `→`, `->`, `>` מכל כפתורי index, admin, landing
2. **הסרת מיתוג AI גלוי** — class `.sh-ai` הוסר, prefix "AI:" הוסר מ-toast/תוצאות
3. **Admin: Eye icon + Forgot Password** — כפתור 👁 לשדה סיסמה + שיפור UX Forgot Password
4. **תיקון הזמנת סוכנים** — error handling מפורט ב-`Team.invite()` + הצגת שגיאות ברורות
5. **הגדרות תחום עסקי** — הוסר ה-`<select>` מ-Settings UI, נוסף notice "לשינוי צרו קשר עם תמיכה" + disclaimer בידוד נתונים

### ✅ שלב ב' — שיפורי קלט
6. **ולידציית איכות ליד** — `addLead(bypassQuality)` + `modal-lead-quality` מופיע כשאין הערות
7. **שחזור dropzone ייבוא Excel** — CSS classes חדשים: `import-dropzone`, `import-dropzone-icon/title/sub`, dropzone גדול עם drag-and-drop
8. **Google Drive לייבוא** — `LeadImport.fetchFromDrive()`: URL → fileId → fetch → CSV; CORS fallback עם הוראות ידניות; toast כחול לקובצי xlsx

### ✅ שלב ג' — Gamification UX
9. **Onboarding לוקליזציה לפי תחום** — `Onboarding._VERTICAL_COPY` עם 3 verticals; Step 0 מציג feedback תוך כדי בחירה; Step 1 subtitle דינמי + hint box מותאם לתחום
10. **Activity Ticker + Recent Activity** — `ActivityTicker` (רצועה fixed bottom:58px עם scroll animation); `RecentActivity` עם סינון לפי סוג; ניווט "🕐 פעילות אחרונה" ב-sidebar; `Dashboard.render()` קורא ל-`ActivityTicker.render()`

### ✅ שלב ד' — לוגיקה מורכבת
11. **Hot/Cold Leads Widgets**:
    - Hot: carousel עם gradient כתום-צהוב, auto-advance 5s, `_nextAction()` מחשבת פעולה מומלצת, dots navigation
    - Cold: gradient כחול, ❄️ ימים ללא מגע, כפתור "🔥 חמם ליד" → `App.go('lead-detail') + SmartWA.open()`
12. **FeatureGate — שערי נעילה**: `FeatureGate.isUnlocked()` (10 לידים OR 7 ימים); `applyOverlay(containerId)` עם live countdown + progress bar; חל על `screen-marketing` ו-`ptab-content-board`
13. **Madlan + WhatsApp ישיר**:
    - כפתור "📞 שלוף ממדלן" (רק לתחום `realestate`) → `modal-madlan-phone` עם הוראות copy-paste + ולידציית מספר ישראלי `/^0[2-9]\d{7,8}$/` + שמירה ב-DB
    - כפתור "💬 WhatsApp" → `LeadDetail.openDirectWA()`: בודק `lead.last_contact` → ישיר אם קיים, אחרת `modal-wa-consent` לאישור הסכמה לפני שליחה
    - **גארד אבטחה:** אין automated scraping. כל שליפת טלפון היא copy-paste ידני. WA ישיר ללא קשר קודם חסום עד לאישור מפורש.

### 📋 לסשן הבא
- עדכון CLAUDE.md בסיכום `/security-review` על זרימות חדשות (RPCs אנונימיים)
- בדיקה ב-`liders-crm.com` אחרי deploy (אם מנגנון GitHub Pages CI אוטומטי)
- המשך per-vertical features (ראה טבלת רודמאפ למעלה)

---

## מה בוצע — סשן 5/7/2026 (ב') — סקשן כאב הפניות בדף הנחיתה

> ענף: `claude/landing-page-referrals-epqxb6` (מוזג ל-main)

### ✅ הושלם
1. **סקשן "כאב הפניות" ב-`landing.html`** — נוסף בין `industry-section` (המשולש הקדוש —
   הצגת 3 התחומים) לבין `holy-triangle-section` (פתרון — לוח ההזדמנויות). יוצר זרימה
   שיווקית קלאסית: **כאב → פתרון**.
   - כותרת משנית (`rp-heading`): `clamp(21px, 3.2vw, 28px)`, קטנה מ-`section-title` ✓
   - סאב טקסט (`rp-body`): `clamp(16px, 1.9vw, 17px)` — עמידה בהיררכיית פונטים ✓
   - מעבר גרדיאנט רך (`sect-blend-light`) מהרקע הכהה של `industry-section` לבן ✓
   - ניטרליות מגדרית: "תוכלו" בלשון רבים; אין ביטויים זכריים מפורשים ✓
   - אין כפתורים ← אין בעיית מקף/חץ ✓

---

## מה בוצע — סשן 7/7/2026 — בדיקת טרום-השקה (Pre-Launch Audit), סיבוב ראשון

> ענף: `claude/pre-launch-audit-qa-1vpygn`. נעשה בהתאם לבקשת המשתמש לצמצם קריאות
> Agent tool למינימום (2 בסה"כ, שני סוכני Explore על מסלול המשתמש והבקאנד) ולתעדף
> את המסלול הקריטי (כניסה → הוספת ליד מהר → שימוש בפיצ'רים) לפני השקה, עם השאר
> כ-backlog מפורש לאחרי.

### ✅ תוקן ואומת (4 פריטים, מיגרציות הוחלו על ה-DB החי)
1. **`twilio-whatsapp`** — תוקנה עקיפת סינון טלפון (PostgREST filter injection):
   `to` מהלקוח הוזרק גולמי ל-`.or()`, ערך מתוכנן אפשר לעקוף את בדיקת "הטלפון שייך
   ללקוח של הטננט" ולשלוח WhatsApp דרך הטוויליו של החברה לכל מספר. הוחלף ל-`.in()`
   בטוח + ולידציית פורמט טלפון.
2. **`shared_leads` RLS** (מיגרציה `070_fix_shared_leads_rls.sql`) — מדיניות
   `FOR ALL` ישנה (ממיגרציה 040) אפשרה INSERT/UPDATE ישיר מול REST שעוקף לגמרי את
   מנגנון ה-PIN + 5 נסיונות. צומצמה ל-SELECT בלבד; כתיבה רק דרך ה-RPCs הקיימים
   (`create_shared_lead`/`accept_shared_lead`/וכו') — עכשיו תואם בדיוק את דפוס
   ה-grants/policies הבטוח של `lead_referrals`.
3. **`inspiration_url`** (מיגרציה `071_add_lead_inspiration_url.sql`) — התגלה
   שהעמודה **לא הייתה קיימת בכלל** בטבלת `leads` (לא רק "לא נשמר בפועל" — לא הייתה
   לה עמודה). שדה "לוח השראה" של מעצבי פנים נעלם בכל רענון. נוספה העמודה + חוזק
   הקוד ב-4 מקומות (`DB.addLead`, `DB.loadAll`, `addLead()`, `saveEditLead()`).
4. **`last_contact`** — 3 מקומות (`CallLog.log`, `addActivity()`, AI quick-log)
   עדכנו רק את הזיכרון המקומי ולא שמרו ל-DB בכלל; השדה חזר ל-NULL אחרי רענון,
   ופגע בזיהוי "ליד קר". נוספה שמירה אמיתית (`DB.updateLead`) בכל שלושת המקומות.
5. **מודל נכס/תיק/פרויקט לא היה מותאם לעו"ד נדל"ן ומעצב פנים** — ה-nav/FAB כבר
   הבטיחו "תיק חדש"/"פרויקט חדש" (`getLabel()`), אבל מודל ההוספה/עריכה בפועל
   (`modal-add-property`/`modal-edit-property`) נשאר קשיח לגמרי לנדל"ן: כותרת
   "נכס חדש", סוג נכס (דירה/בית/פנטהאוז), מחיר חובה, חדרים/קומה/תמונות. נוסף
   `PROPERTY_CONFIG` פר-תחום (סוגי תיק/פרויקט רלוונטיים, סטטוסים, "תקציב"/"שכר
   טרחה" לא-חובה במקום "מחיר" חובה, הסתרת חדרים/קומה/תמונות לעו"ד) + עודכנו
   `applyIndustryToPropertyForm()`, `PropertiesScreen.render()`,
   `sharePropertyWhatsApp()` וכל הודעות ה-toast הרלוונטיות.

### 📋 Backlog מפורש לאחר השקה (לא תוקן בכוונה — לא רפקטור ליל ההשקה)
- **`'s5'` מקודד קשיח כ"שלב סגור"** בכ-13 מקומות בסטטיסטיקות/גיימיפיקציה, בזמן
  שהאונבורדינג/הגדרות מאפשרים לטננט לשנות פייפליין בחופשיות — טננט עם פחות/יותר
  מ-5 שלבים יקבל סטטיסטיקות "עסקאות סגורות" שגויות. תיקון אמיתי דורש שימוש בדגל
  `is_won` הקיים בסכימה (כרגע write-only) — שינוי רוחבי, נדחה לסבב הבא.
- אין זיהוי כפילויות בייבוא CSV.
- התחברות עם סיסמה שגויה בחשבון קיים נכשלת בשקט ל"הרשמה" חדשה — טרם אומת חי אם
  זה יוצר טננט כפול בפועל.
- PIN lock הוא UI מקומי בלבד (לא גבול אבטחה) — מתועד ומכוון, לא באג.

### ⏸️ לא הושלם בסיבוב הזה
- **בדיקה חיה מקצה לקצה** (הרשמה→אונבורדינג→הוספת ליד→רענון→פייפליין) לא בוצעה —
  כלי השאלה/אישור האינטראקטיביים נכשלו טכנית באמצע הסשן ("tool permission stream
  closed"), ומנגנון ההרשאות חסם בצדק ניסיון לבדוק מול production בלי אישור אמיתי.
  הצעה לסבב הבא: להשתמש ב-Supabase branching (`create_branch`) לבדיקה על עותק
  מבודד במקום production ישירות.
- Regression check חי על 3 ה-`admin_*` RPCs (תיקון 044) וה-REST הישיר מול
  `shared_leads`/`twilio-whatsapp` אחרי התיקון — טרם בוצע.

---

## מה בוצע — סשן 7/7/2026 (ב') — גיוס סוכנים עם קישור מותאם (Recruitment Invite Link)

> ענף: `main` (ישירות)

### ✅ מיגרציה DB — `073_agent_invite_token.sql` (הוחלה על ה-DB החי)
- עמודת `invite_token text UNIQUE` נוספה ל-`agent_invites`; `email` הפך nullable
- אינדקס email מחודש עם `AND email IS NOT NULL`; אינדקס חדש על `invite_token`
- RPC `create_invite_link(p_role)` — authenticated, בדיקת seat limit, מחזיר token 32-hex
- RPC `get_invite_preview(p_token)` — anon-accessible, מחזיר `{valid, agency_name, industry}` בלבד
- `ensure_agent_and_tenant` עודכן לקבל `p_ainvite_token`: token check לפני email check

### ✅ שינויים ב-`index.html`
1. **`AgentInvite` module** — שמירת token ב-sessionStorage, `checkInbound()` בטעינת דף,
   `_fetchAndShowBanner()` קורא ל-`get_invite_preview`, מנקה `?ainvite=` מה-URL
2. **כרטיס קבלת פנים** (`#agency-invite-banner`) — מוצג לפני מסך ההתחברות עם שם הסוכנות
3. **Team modal** — כפתור "🔗 צור קישור גיוס" + `#team-invite-link-result` עם העתק+WA
4. **`Team.generateInviteLink/copyInviteLink/shareInviteLinkWA`** — יצירת URL, העתק ללוח,
   תבנית WhatsApp בעברית עם שם הסוכנות
5. **`DB.ensureAgent`** — מעביר `p_ainvite_token` ל-RPC; מנקה sessionStorage אחרי הצטרפות
6. **toast ברכה** — "🎉 ברוכים הבאים! הצטרפת לסוכנות X" + "המערכת כבר מוגדרת עבורך"
7. **גייט 20 ימים** — `Team._applyInviteLinkGate()` מחשב ימי שימוש מ-`trial_ends_at`;
   מסתיר כפתור ומציג "🔒 קישור גיוס יהיה זמין בעוד X ימים" בתקופת ניסיון קצרה מ-20 יום;
   בחבילות בתשלום — תמיד פתוח

---

## מה בוצע — סשן 7/7/2026 (ג') — שדרוג עמוד הכניסה לרמת SaaS פרמיום

> ענף: `claude/login-page-design-b9qm78` (מוזג ל-main)

### ✅ שינויים ב-`index.html` (203 שורות הוספה, 46 מחיקה)

**A — השפעה גבוהה:**
1. **Badge חדש** — `"⚡ נבנה עבור שוק הנדל"ן הישראלי"` (ניטרלי-תחומי, כולל 3 תחומים מבלי לדיר)
2. **Tagline חדש** — `"לידים שמגיעים. עסקאות שנסגרות."` (קצר, ריתמי, ללא קלישאות)
3. **Logo** — הקטנה: 66px → 58px, letter-spacing -5px → -3.5px
4. **Hero padding** — 44px → 28px (תיקון mobile — הכרטיס לא נדחק מתחת ל-fold)
5. **login-scene** — גובה 130px → 112px; כיתוב `"עסקה נסגרה ✓"` מופיע ב-73% מהאנימציה
6. **Login Card Glass** — `backdrop-filter: blur(24px) saturate(160%)`, border שקוף, box-shadow 3 שכבות קל יותר, padding 24→28px
7. **Trial badge** — class `login-trial-badge` + `@keyframes trial-shine` (sweep אור כל 4 שניות), font-size 12→13px, padding גדול יותר
8. **Google button** — הוחלף `g-bounce` → `@keyframes g-glow-pulse` (3s ambient glow כחול); ripple effect ב-JS על mousedown/touchstart

**B — השפעה בינונית:**
9. **כרטיסי רקע** — 4 כרטיסים, כל אחד מייצג תחום שונה: 🏠 נדל"ן, ⚖️ עו"ד, 🎨 עיצוב פנים, 📅 תזכורת. הוסרו חצים (כלל CLAUDE.md).
10. **Pills** — הוחלפו 4 feature-pills → 3 vertical-pills: `🏠 סוכני נדל"ן` / `🎨 מעצבי פנים` / `⚖️ עורכי דין`. hover + `pill-float` animation.
11. **Stars social proof** — `<div class="login-stars-section">` עם 12 `✦` עולים ב-CSS בלבד + `"נבנה במיוחד עבור אנשי מקצוע בישראל"` + שמות 3 התחומים. (**אין** דירוג כוכבים / מספרי משתמשים מזויפים)
12. **Input focus state** — `border-color: var(--blue-400)` + `box-shadow: 0 0 0 3px rgba(37,99,235,.16)` ב-`#screen-login .form-input:focus`
13. **Demo button** — ניקוי: הוסרו 2 פסקאות noise; נשאר רק "👀 צפייה בדמו קצרה קודם" + שורה "הדמו מציג חלק מהיכולות בלבד."

**C — פוליש:**
14. **Orbs** — opacity גבוה יותר (.18/.11/.13), `filter: blur(40px)`, timing: `cubic-bezier(0.4, 0, 0.6, 1)`
15. **CTA primary** — gradient + hover lift + glow כחול (סקופ `#screen-login` בלבד)
16. **Reduced motion** — כל האנימציות החדשות מכוסות ב-`@media (prefers-reduced-motion: reduce)`

### 📋 לסשנים הבאים
- `liders-ui-reviewer` על עמוד הכניסה — טרם הופעל (ידרוש אישור מפורש)
- כפתור "פרטים →" ב-Billing modal — מפר כלל חץ, אך מחוץ לסקופ הסשן הנוכחי

---

## כללי עבודה

1. **עברית RTL** — כל טקסט UI בעברית
2. **Mobile-first** — תמיד בדוק ב-390px
3. **CSS variables** — אף פעם לא hardcoded colors
4. **RLS על כל טבלה** — אין יוצא מהכלל
5. **Secrets** — לעולם לא ב-git
6. **PIN** — מאוחסן כ-bcrypt, לא plaintext
7. **פנייה למשתמש** — ניטרלית מגדרית תמיד (ראה סעיף ⚧ למעלה)
8. **תקשורת עם המשתמש** — עברית בלבד, גם בהודעות סיכום/סיום שיחה — ראה סעיף למעלה

---

## מה בוצע — סשן 7/7/2026 (ד') — שדרוגי דף נחיתה (landing.html)

> ענף: `claude/landing-page-refinements-yluzna` (PRs #39–#43, כולם מוזגו ל-main)

### ✅ הושלם (5 PR נפרדים)
1. **PR #39 — שלוש התאמות טקסט**:
   - שלב 3 (סקשן "איך זה עובד"): `נשאר לך רק להגיע לפגישה.` → `נשאר לך רק להגיע לפגישה ולסגור עסקה.`
   - "✓ מעקב מלא אחרי כל עסקה" — הועבר מתחת לכפתור ה-CTA (ולא מעליו)
   - נמחקה שורת `✓ יצירת הצעות שיווק מיוחדות` מסקשן השיווק

2. **PR #40 — כפתור hero + עגורן + טעימה**:
   - כפתור: טקסט `מתחילים 30 יום בחינם 🚀` → `קח אותי למערכת`
   - כפתור: צבע גרדיאנט בורדו (`#C41E3A → #8B1A2B`), pulse ו-glow בצבע מותאם
   - עגורן: מטען `30 יום 🎁` → `עסקה` (נחת + squash animation)
   - סקשן "טעימה קטנה": סאב-טקסט → "קצת מתוך ״לב״ המערכת / את כל שאר ההפתעות חושפים בפנים."

3. **PR #41 — הקטנת כותרת hero**:
   - `clamp(38px, 6.5vw, 66px)` → `clamp(28px, 4.8vw, 50px)` (כ-24% קטן)
   - `margin-bottom` מ-20px ל-16px — מקום לאנימציית העגורן

4. **PR #42 — כפתור hero בורדו זכוכית (שיפור)**:
   - הוחלף הגרדיאנט הבוהק לאפקט זכוכית frosted: `rgba(100,14,28,0.68)` + `backdrop-filter:blur(8px)`
   - גבול עדין `1.5px solid rgba(210,65,80,0.36)` + shadow פנימי
   - padding: `18px 46px`, font-size: `18px` (מעט גדול יותר)
   - glow ו-pulse מעומעמים (לא בוהקים)

5. **PR #43 — הסרת משולש 🔺 מכותרת**:
   - `🔺 המשולש הקדוש` → `המשולש הקדוש` (ללא אמוג'י)

### 📋 מצב landing.html לאחר הסשן
- כפתור ה-hero: **בורדו זכוכית**, טקסט "קח אותי למערכת", עגורן מוריד "עסקה"
- כותרת H1 hero: גודל מוקטן, מותאם לנייד ודסקטופ
- כל 5 PRs מוזגו ל-main ✅

---

---

## מה בוצע — סשן 8/7/2026 — Rebrand מלא Liders → PLTO + מעבר דומיין (ענף: `claude/system-name-change-kyc9tn`)

### ✅ Rebrand טקסטואלי מלא (אפס "Liders"/"לידרס" גלוי ללקוח)
- **כל 4 קבצי HTML** — לוגואים, כותרות, meta, כפתורים, toast, תבניות WA, מוקאפים, watermarks
- **manifest.json** → `"name": "PLTO"`, **sw.js** → `'plto-v1'`
- **make_blueprint.json** — שם סצנריו, webhook, נמען → `info@plto.app`
- **migrations/001–019** — comment headers
- **migrations/040, 061, 063, 064, 074** — fallback strings ב-SQL: `'משתמש PLTO'`, `'שותף PLTO'`, `'הסכם עמלת הפניה — PLTO'`
- **`.claude/skills/`** (9 קבצים) + agents + tests
- **SVG** — `icons/favicon.svg` ו-`icons/logo.svg` נוצרו מחדש (PLTO branding)

### ✅ מה נשמר בכוונה (security/compat)
- `ADMIN_EMAILS = ['liders.crm@gmail.com', 'elgrablidudu@gmail.com']` — auth guard ב-admin.html + index.html
- `liders_*` localStorage keys — תאימות לאחור למשתמשים קיימים
- `liders.crm@gmail.com` בכל SQL RPC guards — זיהוי Supabase auth

### ✅ מעבר דומיין (צעד ביניים — liders-crm.com עדיין חי)
**Edge Functions** (ALLOWED_ORIGINS) — `plto.app` + `www.plto.app` נוספו לצד `liders-crm.com`:
- `supabase/functions/ai-proxy/index.ts`
- `supabase/functions/twilio-whatsapp/index.ts`

**כל קישורי HTML** → `https://plto.app` (כולל OG tags, redirectTo auth, referral/consent/lref links):
- `index.html`, `landing.html`, `admin.html`, `sign.html`, `privacy-policy.html`

**SEO/config** → `plto.app`:
- `robots.txt` (Sitemap URL)
- `sitemap.xml` (כל ה-URLs + נוסף `landing.html`, עדכון תאריכים ל-2026-07-08)

**מיגרציה 075** (`075_post_domain_rename_crons.sql`) — מוכנה להרצה אחרי מעבר DNS:
- מחליפה cron names: `liders-support-daily-digest` → `plto-support-daily-digest`
- `liders-leads-daily-digest` → `plto-leads-daily-digest`
- `liders-cro-weekly-digest` → `plto-cro-weekly-digest`

### ⚠️ CNAME file — שינוי ידני חובה (טרם בוצע!)

> **קובץ `CNAME` בשורש הריפו עדיין מכיל `liders-crm.com`** — זה מכוון ונכון לעכשיו.
> **אסור לשנות אותו לפני שה-DNS של `plto.app` חי ומאומת** — אחרת האתר יירד לגמרי.
>
> **מה לעשות (בסדר הזה בלבד):**
> 1. ראשית: הוסף CNAME record ב-DNS (Namecheap/Cloudflare): `plto.app` → `liders-crm.github.io`
> 2. המתן לפחות 5–10 דקות ואמת שהדומיין עולה
> 3. רק אז: ערוך את קובץ `CNAME` → שנה את התוכן מ-`liders-crm.com` ל-`plto.app` → commit + push
>
> **⛔ הסיכון:** שינוי CNAME file לפני שה-DNS מוגדר גורם ל-GitHub Pages לנתק את הדומיין הישן
> (liders-crm.com יפסיק לעבוד) מבלי שהחדש (plto.app) כלל פועל — downtime מיותר.

### 🔴 נותר לביצוע ידני (לפני יום ראשון)

| עדיפות | משימה | היכן |
|--------|-------|------|
| 🔴 **חייב** | Merge PR `claude/system-name-change-kyc9tn` → main | GitHub |
| 🔴 **חייב** | הרץ migration 074 בשלמות ב-Supabase SQL Editor | Supabase Dashboard → SQL Editor |
| 🔴 **חייב** | Deploy שתי Edge Functions: `ai-proxy` + `twilio-whatsapp` | `supabase functions deploy ai-proxy && supabase functions deploy twilio-whatsapp` |
| 🔴 **חייב** | DNS — הפנה `plto.app` → `liders-crm.github.io` (CNAME record) | Namecheap/Cloudflare |
| 🔴 **חייב** | CNAME file — שנה מ-`liders-crm.com` ל-`plto.app` (עושים **אחרי** DNS חי) | קובץ `CNAME` בריפו, commit + push |
| 🟡 **חשוב** | Gmail — הגדר forwarding מ-`liders.crm@gmail.com` → `info@plto.app` | Gmail Settings |
| 🟡 **חשוב** | Supabase Auth — שנה sender name בתבניות אימייל מ-"Liders CRM" → "PLTO" | Supabase Dashboard → Auth → Email Templates |
| 🟡 **חשוב** | Make.com — עדכן 2 סצנריות (שמות + נמענים → `info@plto.app`) | eu1.make.com |
| 🟢 **אחרי** | הרץ migration 075 (rename crons) | Supabase SQL Editor |
| 🟢 **אחרי** | הסר `liders-crm.com` מ-ALLOWED_ORIGINS בשתי Edge Functions | קוד + deploy |
| 🟢 **אחרי** | החלף תמונות: `icon-192.png`, `icon-512.png`, `og-image.jpg` | icons/ folder |
| 🟢 **אחרי** | GitHub repo rename + Supabase project rename | הגדרות |

### 📌 סדר ביצוע מומלץ ליום ראשון
1. Merge PR → GitHub Pages מתעדכן
2. Deploy Edge Functions (Supabase CLI)
3. הרץ migration 074 (SQL Editor)
4. DNS: CNAME record `plto.app` → `liders-crm.github.io`
5. **המתן** עד שה-DNS מתפשט (5–30 דקות)
6. עדכן CNAME file → `plto.app` → commit + push
7. אמת: https://plto.app עולה ✅
8. הרץ migration 075 (rename crons)
9. הסר `liders-crm.com` מ-ALLOWED_ORIGINS → deploy Edge Functions שוב

---

## מה בוצע — סשן 9/7/2026 — DNS, אייקונים, ניקוי טרום-השקה (ענף: `claude/dns-approval-plto-launch-3pxl30`)

### ✅ הושלם אוטומטית (ללא צורך בפעולה ידנית)

1. **CNAME file** — שונה מ-`liders-crm.com` ל-`plto.app` (הסיבה המרכזית ל-525 לפני כן)
2. **`icons/icon-192.png`** — הופק מחדש מ-`favicon.svg` עם branding PLTO (cairosvg, 192×192)
3. **`icons/icon-512.png`** — הופק מחדש (512×512)
4. **`icons/og-image.jpg`** — תמונת OG חדשה לגמרי: 1200×630, רקע navy, לוגו PLTO, tagline בעברית, plto.app (46KB)
5. **`assets/screenshots/`** — נמחקה התיקייה כולה (~3MB שלא הייתה בשימוש: 5 קבצי PNG שלא הוזכרו בשום מקום)
6. **`index.html` — UTM tracking** — הוסר `liders-crm.com` מבדיקת ה-referrer (שריד ישן)
7. **`production/LAUNCH_CHECKLIST.md`** — נוצר קובץ מקיף עם כל סטטוס ההשקה, משימות ידניות, מבנה קבצים, ואבטחה

### 🔍 בדיקת סטטוס DNS שבוצעה בסשן זה

- **ה-nameservers של `plto.app` כבר עלו** (בוצע יום קודם עם Gemini ב-Namecheap → Cloudflare)
- **אומת דרך pg_net**: `plto.app` מחזיר 525 עם `server: cloudflare` + `cf-ray` — כלומר Cloudflare מקבל את הבקשות תקין
- **סיבת ה-525**: Cloudflare על "Full (Strict)" אבל GitHub Pages עוד לא הספיק להפיק תעודת Let's Encrypt ל-`plto.app`

### 🔴 נשאר לביצוע ידני (סשן הבא)

| פעולה | היכן | הערה |
|-------|------|------|
| **Cloudflare SSL → "Full"** (זמנית) | Cloudflare → plto.app → SSL/TLS → Overview | מפתור 525 מיד; לחזור ל-"Full (Strict)" אחרי שהאתר עולה |
| **אמת plto.app עולה** | pg_net או דפדפן | `status_code = 200`, `server = cloudflare` |
| **Supabase Auth email** | Supabase Dashboard → Auth → Email Templates | שנה sender מ-"Liders CRM" ל-"PLTO" |
| **Make.com — 2 סצנריות** | eu1.make.com/1851801/scenarios/ | שמות + נמען → `info@plto.app` |
| **הסר `liders-crm.com` מ-ALLOWED_ORIGINS** | `ai-proxy` + `twilio-whatsapp` | רק אחרי שplto.app מאושר! → deploy שתי functions |
| **חזור ל-"Full (Strict)"** | Cloudflare SSL/TLS | אחרי שהאתר עולה תקין |

---

## מה בוצע — סשן 9/7/2026 (ב') — השלמת הגדרות תשתית Rebrand PLTO

### ✅ הושלם (ידני + אוטומטי)

**ידני (בוצע על ידי המשתמש):**
1. **Cloudflare** — שני ה-CNAMEs הוחזרו למצב Proxied 🟠
2. **Supabase Auth** — Sender name עודכן ל-"PLTO", sender email ל-`info@plto.app`
   (custom SMTP כובה — Supabase משתמש בתבניות ברירת מחדל שלו, לא הכילו "Liders" מלכתחילה)

**אוטומטי (דרך Make MCP API):**
3. **Make.com — שתי הסצנריות עודכנו במלואן:**
   - שמות: `Liders CRM — Lead Notifications` → `PLTO — Lead Notifications`
   - שמות: `Liders CRM — Trial Expiry Notifications` → `PLTO — Trial Expiry Notifications`
   - כל 11 ה-subjects שהכילו "Liders CRM" → "PLTO"
   - כל הקישורים: `liders-crm.github.io/liders_crm/` → `https://plto.app`
   - דוח CRO: `liders-crm.com/admin.html` → `plto.app/admin.html`, הוסר `←`
   - מייל יום 10 (midtrial): "Liders CRM" → "PLTO", "11 ימים" → "20 ימים", הוסר `→` מכפתור
   - Connection של Trial Expiry עודכן ל-PLTO (info@plto.app) ידנית על ידי המשתמש

### 📋 עתידי — מיילים נוספים ב-Google Workspace
כשיגיע הזמן: `support@plto.app`, `noreply@plto.app` — כל אחד כ-connection נפרד ב-Make.com,
ויחובר ל-route הרלוונטי (תמיכה, אוטומציות, פניות כלליות).

---

## מה בוצע — סשן 10/7/2026 — 5 כאבי רון לנדסמן + התאמות per-vertical

> ענף: `claude/ron-realestate-issues-jol4j1` (מוזג ל-main). מיגרציה `076` הוחלה על ה-DB החי.

### ✅ 5 כאבי סוכן נדל"ן — פתרונות (ביצוע מלא)

1. **❄️ לידים קרים — פילוסופיית שגריר** — widget "לידים שדורשים חיזור מחדש" עודכן:
   - tip "💡 ליד קר שמרגיש מכובד הופך למפרסם — שמרו על קשר חם, הסוכן ינסח אוטומטית"
   - ימים צבועים לפי חומרה: amber (14–30) / orange (30–60) / red (60+)
   - כפתור: "🔥 חמם ליד" → "💬 שלח חיזור חכם"

2. **📍 מעקב נכסים שהוצגו ללקוח** — module חדש `PropertyShown`:
   - מודל "נכס שהוצג ללקוח": כתובת, מחיר, תגובה (💚 מעוניין / 💛 אולי / ❌ לא מתאים), הערות
   - שמור כ-activity עם `type: 'showing'` (ללא מיגרציה — שימוש בתשתית קיימת)
   - מוצג בtab "התאמה" בכרטיס הליד — **רק לסוכן נדל"ן** (מוסתר מעו"ד ומעצב)

3. **📋 חידוש עמלה** — מיגרציה `076_add_lead_tracking_fields.sql`:
   - שדות: `commission_renewal_date date`, `commission_renewal_notes text`
   - modal עריכת ליד: שדות חדשים + populate ב-openEditLead
   - info tab: badge צבעוני (ירוק/amber/orange/אדום) לפי מרחק מתאריך החידוש
   - דשבורד: widget "📋 חידוש עמלה — בקרוב" (טווח: -7 עד +30 יום מהיום)

4. **🤖 AI הפניה + חיזור** — `AI.writeRescue()` + תבנית `cold_referral`:
   - prompt מותאם לתחום: "עדכון שוק" / "עדכון משפטי" / "טרנד עיצובי"
   - שורת הפניה מותאמת: "מחפש לקנות/למכור" / "ייעוץ משפטי בנדל"ן" / "פרויקט עיצוב"
   - תבנית WA `cold_referral` מגיבה לתחום דינמית בזמן-אמת

5. **🌐 landing.html** — סקשן חדש "הכאבים שסוכן נדל"ן מכיר מאוד" (4 כרטיסים: לידים קרים,
   נכסים שהוצגו, חידוש עמלה, מסמכים) + 2 feature cards חדשים בtab הפייפליין

### ✅ התאמות per-vertical (בוצע לאחר הmerge)
- `PropertyShown` — `${ind === 'realestate' ? ... : ''}` בtab-match
- `AI.writeRescue()` — קריאה ל-`_ind` מ-localStorage, prompt מסועף ל-3 תחומים
- `cold_referral` template — פונקציה (לא ב-arrow string) שקוראת industry בזמן-אמת

### 📋 לסשן הבא — ראה `NEXT_SESSION_VERTICAL_ADAPTATIONS.md`
שינויים טקסטואליים בלבד (ללא מיגרציות):
1. תווית "עמלה" → "שכ"ט" (עו"ד) / "סיום פרויקט" (מעצב) — **עדיפות גבוהה**
2. טקסטים בtab match לפי תחום ("נכסים תואמים" / "תיקים רלוונטיים" / "פרויקטים")
3. placeholders בשדה "אזור" לפי תחום

---

## מה בוצע — סשן 10/7/2026 (ב') — בדיקת מוכנות להשקה: פרצת gmail-proxy + ניקוי הרשאות

> ענף: `claude/readiness-check-kubqfi` (מוזג ל-main)

### 🔴 נמצא ותוקן — קריטי
1. **`gmail-proxy` היה חשוף לגמרי לאינטרנט ללא שום אימות** (`verify_jwt:false`
   ברמת הפלטפורמה + אין בדיקת `Authorization`/`auth.getUser()` בקוד הפונקציה
   עצמה, בניגוד ל-`ai-proxy`/`twilio-whatsapp`). כל אחד היה יכול לקרוא ולשלוח
   מיילים בשם `liders.crm@gmail.com` בלי להתחבר למערכת בכלל. **תוקן**: נוספה
   בדיקת `Authorization: Bearer` + `auth.getUser()` + הגבלה ל-`ADMIN_EMAILS`
   (אותה רשימה כמו ב-`index.html`), ותוקן `ALLOWED_ORIGINS` ל-`plto.app`.
   אומת בפועל: קריאה לא-מאומתת מקבלת `401`, וקריאה עם JWT תקין של
   `liders.crm@gmail.com` מצליחה (`200`, שרשור מייל אמיתי הוחזר).
2. **`index.html` — `GmailInbox._proxy()`** הוחלף מ-`fetch()` גולמי (שולח רק
   `apikey`) ל-`sbClient.functions.invoke()` (שולח את ה-JWT האמיתי של הסשן
   המחובר) — כדי שהתיקון הנ"ל לא ישבור את מסך המייל בממשק.
3. **6 RPCs נוספות היו ניתנות להפעלה ע"י `anon`/`authenticated` בלי אימות**
   בפועל (`send_daily_lead_digest`, `send_cro_weekly_digest`,
   `auto_approve_daily_jokes`, `admin_list_ab_tests`, `admin_upsert_ab_test`,
   `get_funnel_summary`) — כי `GRANT ... TO postgres` לא מספיק ב-Supabase:
   יש GRANT ברירת מחדל ישיר ל-`anon`/`authenticated` על כל פונקציה חדשה
   בסכימת public, בנוסף ל-PUBLIC הרגיל. שלוש הראשונות (ab_tests/funnel_summary)
   היו מוגנות גם ב-runtime guard (`current_role`) so לא הייתה חשיפה בפועל;
   שלוש האחרונות (הדיגסטים + אישור בדיחות) **לא** היה להן שום guard פנימי.
   **תוקן**: `REVOKE EXECUTE ... FROM anon, authenticated` על כל השש, מיגרציה
   `077_revoke_public_exec_admin_cron_rpcs.sql`.

### 📎 תיעוד רטרואקטיבי (drift בין DB לגיט)
התגלה ש-3 Edge Functions (`admin-ops`, `gmail-proxy`, `gmail-oauth-callback`)
ו-2 טבלאות DB (`gmail_tokens`, `community_jokes` + כל ה-RPCs שלהן) רצו
בפרודקשן בלי שום קובץ מיגרציה/מקור בריפו — נוצרו ישירות מול Supabase בסשן
קודם. `admin-ops` כבר מחזירה `Gone (410)` — לא בשימוש, לא נגעתי בה. הוספתי
לריפו: קוד המקור של `gmail-proxy`/`gmail-oauth-callback`, ומיגרציות
רטרואקטיביות `078_gmail_tokens_retroactive.sql` ו-
`079_community_jokes_retroactive.sql` (עם `IF NOT EXISTS` — לא משנות דבר אם
מורצות, רק מתעדות את המצב החי).

### ⚠️ `community_jokes` — פיצ'ר שלם ב-backend, אין לו UI בכלל
טבלה + RPCs מלאים (שליחת בדיחה, אישור אדמין דרך PIN, אישור אוטומטי יומי
ב-cron, XP) — אבל **0 references בכל הקוד** (`index.html`/`admin.html`) ו-0
בדיחות אושרו אי פעם. נראה כמו פיצ'ר שנבנה באמצע ולא הושלם. **לא הוסר** —
מחכה להחלטה: להשלים את ה-UI, או להסיר את התשתית (טבלה + RPCs + cron job
`auto-approve-daily-jokes`).

### ✅ אומת כתקין (ללא שינוי נדרש)
- `plto.app` חי (200, cloudflare), כל המיגרציות עד 079 מיושמות.
- שתי סצנריות Make.com (`PLTO — Lead Notifications`, `PLTO — Trial Expiry
  Notifications`) פעילות עם מיתוג PLTO נכון.
- `gmail_tokens.access_token` היה פג תוקף (מ-5/7) — ה-refresh flow עבד כצפוי
  ורענן אוטומטית, לא נדרשת פעולה.

### 📋 לסשן הבא / פעולה ידנית
- **`auth_leaked_password_protection`** כבוי ב-Supabase Auth — טוגל דקה
  בדשבורד (Authentication → Policies), אין לו כלי MCP.
- **החלטה על `community_jokes`** (למעלה) — טרם התקבלה.
- לא בוצעה בדיקת קצה-לקצה חיה מלאה (הרשמה חדשה → אונבורדינג → ליד →
  רענון → פייפליין) — עדיין פתוח מסשן 7/7.

---

## מה בוצע — סשן 10/7/2026 (ג') — תיקון עיצוב לוגו O (החץ בעיגול)

> ענף: `claude/circle-arrow-styling-c2j2yg`

### ✅ הושלם
תוקן עיצוב ה-"O" בלוגו PLTO (מסך כניסה `index.html`, `icons/logo.svg`,
`icons/favicon.svg` + `icon-192.png`/`icon-512.png` שנוצרו מחדש ממנו):
1. **הוסר העיגול הקטן הפנימי** (טבעת מטרה) — נשאר רק החץ בתוך העיגול החיצוני
2. **החץ הופך כיוון** — השפיץ פוגע כלפי פנים (למרכז העיגול) במקום להצביע החוצה
3. **גודל העיגול הותאם לגובה הטקסט** — הוקטן כך שיהיה מאוזן ויזואלית מול אותיות
   PLT ולא יבלוט כגדול מדי (למשל ב-index.html: רדיוס 27→20, stroke 8→7)
4. **דיוק נוסף** — קו החץ (ה"מקל") הוקטן משמעותית (index.html: stroke-width
   3.2→1.7) כי בעובי הקודם הוא נראה כמו מחוג שעון ולא כמו חץ; ראש החץ (המשולש)
   נשאר בולט וברור למראה "חץ" נקי בכל שלושת המקומות (index.html/logo.svg/favicon.svg)
5. **יישור + נוצה** — ציר החץ יושר לאלכסון 45° נקי, הזנב הוצא מעט מחוץ לטבעת
   העיגול (במקום סגור בפנים), ונוספה נוצה (V קטן) בקצה הזנב ב-index.html
   וב-logo.svg למראה חץ אמיתי; ב-favicon.svg (32x32) נשארה גרסה פשוטה בלי נוצה
   כי בקנה מידה כזה קטן זה נראה כמריחה — רק היישור וההבלטה מהעיגול יושמו שם

## Quick Commands

```bash
open index.html              # הרץ לוקאל
python3 -m http.server 8080  # שרת לוקאל
```
