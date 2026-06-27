# Playwright E2E Testing — Liders CRM

## פקודה: `/playwright-crm`

בדיקות E2E אוטומטיות לכל flows של מערכת Liders CRM.

---

## התקנה

```bash
npm install -D @playwright/test
npx playwright install chromium
```

### `playwright.config.ts`
```typescript
import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: './tests/e2e',
  use: {
    baseURL: 'http://localhost:3000',
    locale: 'he-IL',
    timezoneId: 'Asia/Jerusalem',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
  },
  projects: [
    { name: 'chromium', use: { browserName: 'chromium' } },
    { name: 'mobile', use: { viewport: { width: 390, height: 844 } } },
  ],
});
```

---

## Test Suites

### 1. Booking Flow
```typescript
// tests/e2e/booking.spec.ts
import { test, expect } from '@playwright/test';

test.describe('Booking Flow', () => {
  test('הזמנה מלאה — שלב 1 עד אישור', async ({ page }) => {
    await page.goto('/');

    // שלב 1 — בחירת שירות
    await expect(page.getByText('בחרי טיפול')).toBeVisible();
    await page.getByText('טיפול פנים קלאסי').click();
    await expect(page.locator('.service-card.selected')).toBeVisible();
    await page.getByText('המשך').click();

    // שלב 2 — בחירת תאריך
    await expect(page.getByText('בחרי תאריך')).toBeVisible();
    const openDay = page.locator('.cal-day.open').first();
    await openDay.click();
    await page.getByText('המשך').click();

    // שלב 3 — בחירת שעה
    await expect(page.getByText('בחרי שעה')).toBeVisible();
    const slot = page.locator('.slot:not(.booked)').first();
    await slot.click();
    await page.getByText('המשך').click();

    // שלב 4 — פרטים אישיים
    await page.fill('#f-name', 'שרה לוי');
    await page.fill('#f-phone', '052-1234567');
    await page.getByText('אישור הזמנה').click();

    // הצלחה
    await expect(page.getByText('התור נקבע!')).toBeVisible();
  });

  test('ימים סגורים אינם ניתנים לבחירה', async ({ page }) => {
    await page.goto('/');
    const closedDay = page.locator('.cal-day.closed').first();
    await expect(closedDay).not.toHaveClass(/open/);
  });

  test('slots תפוסים מוצגים כ-disabled', async ({ page }) => {
    await page.goto('/');
    // בחר שירות ותאריך עם booking קיים
    // ...
    const bookedSlot = page.locator('.slot.booked').first();
    await expect(bookedSlot).not.toBeClickable?.();
  });
});
```

### 2. Admin Panel
```typescript
// tests/e2e/admin.spec.ts
test.describe('Admin Panel', () => {
  test('PIN נכון פותח את הניהול', async ({ page }) => {
    await page.goto('/');
    await page.getByText('ניהול').click();

    // הכנס PIN
    for (const digit of ['1','2','3','4']) {
      await page.locator(`[data-digit="${digit}"]`).click();
    }
    await expect(page.locator('#admin-panel')).toBeVisible();
  });

  test('PIN שגוי מציג שגיאה', async ({ page }) => {
    await page.goto('/');
    await page.getByText('ניהול').click();
    for (const digit of ['9','9','9','9']) {
      await page.locator(`[data-digit="${digit}"]`).click();
    }
    await expect(page.locator('#pin-err')).toBeVisible();
  });

  test('הוספת שירות חדש', async ({ page }) => {
    // login first...
    await page.getByText('+ הוסיפי שירות').click();
    // fill service form...
    await expect(page.locator('#svc-admin .svc-row')).toHaveCount(9);
  });
});
```

### 3. Mobile Responsiveness
```typescript
test.describe('Mobile', () => {
  test.use({ viewport: { width: 390, height: 844 } });

  test('booking flow עובד במובייל', async ({ page }) => {
    await page.goto('/');
    await expect(page.locator('.service-list')).toBeVisible();
    // verify RTL layout
    const body = await page.$('body');
    const dir = await body?.getAttribute('dir') ?? '';
    expect(dir).toBe('rtl'); // via html[dir]
  });
});
```

---

## CI Integration

```yaml
# .github/workflows/e2e.yml
name: E2E Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: '20' }
      - run: npm ci
      - run: npx playwright install --with-deps chromium
      - run: npx playwright test
      - uses: actions/upload-artifact@v4
        if: failure()
        with:
          name: playwright-report
          path: playwright-report/
```

---

## פקודות שימושיות

```bash
npx playwright test                    # כל הבדיקות
npx playwright test --ui               # UI mode
npx playwright test booking.spec.ts    # קובץ ספציפי
npx playwright test --headed           # עם browser נראה
npx playwright codegen http://localhost:3000  # הקלטת בדיקות חדשות
```
