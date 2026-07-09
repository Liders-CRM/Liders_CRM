# PLTO — סוכן בדיקות QA

## פקודה: `/qa-liders`

בדיקת E2E מלאה של כל הממשק — כל כפתור, טאב, מודל וטופס.

---

## הרצה

```bash
# בדמו-מוד (ללא קרדנשיאלים)
node /home/user/Liders_CRM/.claude/tests/qa-liders.mjs --url https://plto.app

# עם כניסה (מייל + סיסמה מ-env)
QA_EMAIL=xxx QA_PASS=yyy node /home/user/Liders_CRM/.claude/tests/qa-liders.mjs --url https://plto.app --login
```

---

## מה הסוכן בודק

| מסך | בדיקות |
|-----|---------|
| Login | 30-day trial text, demo link, Google button visible |
| Dashboard | כל KPI cards לחיצים, gamify widget, import banner, AI briefing |
| Pipeline | טאבי שלבים, כרטיסי לידים לחיצים, כפתור + ליד |
| Lead Detail | פתיחת ליד, עריכה, סגירת מודל |
| Tasks | פתיחת מסך, הוספת משימה, סימון הושלם |
| Settings | פתיחת מסך, שמירת הגדרות |
| Tools | פתיחת כל 5 כרטיסי הכלים, מחשבון עמלה |
| Navigation | כל פריטי navbar תחתון ו-sidebar |

---

## פורמט דוח

כל שורה: `✅/❌/⚠️  [מסך] — [פעולה] → [תוצאה]`

בסוף: סיכום passed/failed/warnings.
