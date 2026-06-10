# Figma UI/UX Skill — Liders CRM

## פקודה: `/figma-crm-ui`

עיצוב UI/UX עם Figma MCP + Canva MCP, RTL מלא, design tokens של Liders CRM.

---

## Design Tokens — Liders CRM

```css
/* פלטת צבעים */
--navy-900: #060F1C;
--navy-800: #0A1A2E;
--navy-700: #0F2440;
--navy-600: #152F52;
--navy-500: #1C3E6B;    /* primary brand */
--blue-600: #2563EB;    /* accent / CTA */
--blue-500: #3B82F6;    /* links, highlights */
--blue-100: #DBEAFE;    /* backgrounds */
--slate-100: #F1F5F9;   /* page background */
--slate-50:  #F8FAFC;   /* cards */
--white:     #FFFFFF;
--green-500: #10B981;   /* success / won */
--amber-500: #F59E0B;   /* warning / negotiation */
--red-500:   #EF4444;   /* error / lost */
--purple-500: #8B5CF6;  /* proposal */
--gray-400:  #94A3B8;   /* new lead */

/* Typography */
--font-main: 'Heebo', sans-serif;

/* Radius */
--radius-sm: 8px;
--radius-md: 12px;
--radius-lg: 16px;
--radius-xl: 20px;

/* Shadows */
--shadow-card: 0 2px 8px rgba(15,31,61,0.08);
--shadow-modal: 0 8px 32px rgba(15,31,61,0.16);
```

---

## עבודה עם Figma MCP

### שליפת design context
```
// השתמש ב: mcp__Figma__get_design_context
// לקבלת tokens, components וספריות מ-Figma
```

### יצירת component חדש
```
1. get_libraries()      — ראה ספריות זמינות
2. get_design_context() — שלוף tokens קיימים
3. use_figma()          — פתח עורך Figma
4. generate_diagram()   — צור ERD / flow ב-FigJam
```

---

## RTL Guidelines

### כללים קריטיים
```css
html { direction: rtl; font-family: 'Heebo', sans-serif; }

/* Flexbox RTL */
.row { display: flex; flex-direction: row; }
/* ימין = ראשוני, שמאל = סוף */

/* טלפון תמיד LTR */
input[type="tel"] { direction: ltr; text-align: right; }
```

### Component Patterns
```html
<!-- כרטיס ליד — RTL -->
<div class="lead-card" dir="rtl">
  <div class="lead-header">
    <div class="lead-score">85</div>
    <div class="lead-name">ישראל ישראלי</div>
  </div>
  <div class="lead-meta">
    <span class="stage-badge">ביקור נקבע</span>
    <span class="budget">₪1.2M–₪1.8M</span>
  </div>
</div>

<!-- form field — טלפון LTR -->
<div class="form-field">
  <label>טלפון</label>
  <input type="tel" dir="ltr" placeholder="05X-XXXXXXX">
</div>
```

---

## Canva MCP — Marketing Materials

```
// mcp__Canva__generate-design
// מתאים ל:
- פוסטים לרשתות חברתיות (LinkedIn, Instagram, Facebook)
- banner לאתר
- מצגת למשקיעים

// פרמטרים:
{
  brand_colors: ['#1C3E6B', '#2563EB', '#F1F5F9'],
  font: 'Heebo',
  language: 'he',
  direction: 'rtl'
}
```

---

## Screen Inventory

| מסך | תיאור | Status |
|-----|-------|--------|
| Landing / Login | Google OAuth | ✅ |
| Onboarding | שם סוכנות, תחום | ✅ |
| Dashboard | KPIs, pipeline, tasks | ✅ |
| Pipeline Board | Kanban לידים | ✅ |
| Lead Detail | פרטי ליד, פעילות, משימות | ✅ |
| Properties | ניהול נכסים | ✅ |
| Calendar | ביקורים ו-Google Calendar | ✅ |
| Settings | פרופיל סוכנות, pipeline | ✅ |
| Billing | תוכניות, Stripe | ✅ |
| Admin Panel | ניהול tenant-level | ✅ |

---

## Figma File Structure (מומלץ)

```
📁 Liders CRM — Design System
  📄 Design Tokens
  📄 Components Library
    🔲 Lead Card
    🔲 Pipeline Stage Column
    🔲 Score Badge
    🔲 Task Item
    🔲 Property Card
    🔲 Modal / Drawer
  📄 Screens — Mobile (390px)
    📱 Dashboard
    📱 Pipeline
    📱 Lead Detail
  📄 Screens — Desktop
  📄 Admin Panel
```
