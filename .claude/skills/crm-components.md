# CRM UI Components — Vanilla JS + CSS

## פקודה: `/crm-components`

קומפוננטים מוכנים לשימוש: modal, toast, loading, form patterns, empty states.
כולם תואמים את design system הקיים, RTL, mobile-first.

---

## Toast Notifications

```javascript
// ─── Toast System ───
function showToast(message, type = 'success', duration = 3500) {
  // type: 'success' | 'error' | 'warning' | 'info'
  const existing = document.getElementById('crm-toast');
  if (existing) existing.remove();

  const icons = { success: '✓', error: '✕', warning: '⚠', info: 'ℹ' };
  const toast = document.createElement('div');
  toast.id = 'crm-toast';
  toast.className = `crm-toast crm-toast--${type}`;
  toast.innerHTML = `<span class="toast-icon">${icons[type]}</span><span>${message}</span>`;

  document.body.appendChild(toast);
  requestAnimationFrame(() => toast.classList.add('crm-toast--show'));

  setTimeout(() => {
    toast.classList.remove('crm-toast--show');
    setTimeout(() => toast.remove(), 300);
  }, duration);
}

// שימוש:
showToast('התור נקבע בהצלחה!');
showToast('שגיאה בשמירה', 'error');
showToast('שים לב — יום קצר', 'warning');
```

```css
.crm-toast {
  position: fixed;
  bottom: 24px;
  right: 50%;
  transform: translateX(50%) translateY(80px);
  background: var(--espresso);
  color: var(--ivory);
  padding: 14px 20px;
  border-radius: var(--radius-full);
  display: flex;
  align-items: center;
  gap: 10px;
  font-family: var(--font-body);
  font-size: 0.9rem;
  box-shadow: 0 8px 32px rgba(28,20,16,0.25);
  z-index: 10000;
  transition: transform 0.3s cubic-bezier(0.34,1.56,0.64,1), opacity 0.3s;
  opacity: 0;
  max-width: 340px;
}
.crm-toast--show { transform: translateX(50%) translateY(0); opacity: 1; }
.crm-toast--success { background: var(--sage); }
.crm-toast--error   { background: var(--error); }
.crm-toast--warning { background: var(--color-warning, #C8A028); }
.toast-icon { font-weight: 700; font-size: 1rem; }
```

---

## Modal Dialog

```javascript
// ─── Modal System ───
function openModal(id) {
  const modal = document.getElementById(id);
  if (!modal) return;
  modal.style.display = 'flex';
  requestAnimationFrame(() => modal.classList.add('modal--open'));
  document.body.style.overflow = 'hidden';

  // סגור בלחיצה על backdrop:
  modal.addEventListener('click', (e) => {
    if (e.target === modal) closeModal(id);
  });
}

function closeModal(id) {
  const modal = document.getElementById(id);
  if (!modal) return;
  modal.classList.remove('modal--open');
  document.body.style.overflow = '';
  setTimeout(() => { modal.style.display = 'none'; }, 280);
}

// סגור עם ESC:
document.addEventListener('keydown', (e) => {
  if (e.key === 'Escape') {
    document.querySelectorAll('.modal--open').forEach(m => closeModal(m.id));
  }
});
```

```html
<!-- Modal Template -->
<div class="crm-modal" id="modal-example" style="display:none">
  <div class="crm-modal__box">
    <div class="crm-modal__head">
      <h3>כותרת Modal</h3>
      <button class="modal-close" onclick="closeModal('modal-example')">✕</button>
    </div>
    <div class="crm-modal__body">
      <!-- תוכן -->
    </div>
    <div class="crm-modal__foot">
      <button class="btn-ghost" onclick="closeModal('modal-example')">ביטול</button>
      <button class="btn-main" onclick="confirmAction()">אישור</button>
    </div>
  </div>
</div>
```

```css
.crm-modal {
  position: fixed; inset: 0;
  background: rgba(28,20,16,0.5);
  backdrop-filter: blur(4px);
  display: flex; align-items: center; justify-content: center;
  z-index: 9000; padding: 20px;
  opacity: 0; transition: opacity 0.28s;
}
.crm-modal--open { opacity: 1; }
.crm-modal__box {
  background: var(--ivory);
  border-radius: var(--radius-lg);
  width: 100%; max-width: 420px;
  box-shadow: 0 24px 80px rgba(28,20,16,0.2);
  transform: scale(0.95); transition: transform 0.28s cubic-bezier(0.34,1.56,0.64,1);
}
.crm-modal--open .crm-modal__box { transform: scale(1); }
.crm-modal__head {
  display: flex; justify-content: space-between; align-items: center;
  padding: 20px 20px 0;
}
.crm-modal__head h3 { font-family: var(--font-display); color: var(--espresso); font-size: 1.3rem; }
.modal-close {
  background: none; border: none; font-size: 1.2rem;
  color: var(--text-muted, #B89A8A); cursor: pointer; padding: 4px 8px;
}
.crm-modal__body { padding: 16px 20px; }
.crm-modal__foot {
  padding: 0 20px 20px;
  display: flex; gap: 10px; justify-content: flex-start;
}
```

---

## Loading States

```javascript
// ─── Loading Spinner ───
function setLoading(elementId, isLoading, originalContent = '') {
  const el = document.getElementById(elementId);
  if (!el) return;

  if (isLoading) {
    el.dataset.originalContent = el.innerHTML;
    el.innerHTML = `<span class="crm-spinner"></span>`;
    el.disabled = true;
  } else {
    el.innerHTML = el.dataset.originalContent || originalContent;
    el.disabled = false;
  }
}

// שימוש:
setLoading('btn-submit', true);
await saveBooking(data);
setLoading('btn-submit', false);
```

```javascript
// ─── Skeleton Loader ───
function renderSkeleton(containerId, rows = 3) {
  document.getElementById(containerId).innerHTML = Array(rows).fill(`
    <div class="skeleton-row">
      <div class="skeleton skeleton-line" style="width:60%"></div>
      <div class="skeleton skeleton-line" style="width:40%"></div>
    </div>
  `).join('');
}
```

```css
.crm-spinner {
  display: inline-block;
  width: 18px; height: 18px;
  border: 2px solid rgba(255,255,255,0.3);
  border-top-color: white;
  border-radius: 50%;
  animation: spin 0.7s linear infinite;
}
@keyframes spin { to { transform: rotate(360deg); } }

.skeleton {
  background: linear-gradient(90deg, var(--blush) 25%, var(--parch) 50%, var(--blush) 75%);
  background-size: 200% 100%;
  animation: shimmer 1.4s infinite;
  border-radius: var(--radius-sm);
}
.skeleton-line { height: 14px; margin-bottom: 8px; }
.skeleton-row { margin-bottom: 16px; }
@keyframes shimmer { to { background-position: -200% 0; } }
```

---

## Confirm Dialog (מחיקה / פעולה הרסנית)

```javascript
function confirmAction(message, onConfirm) {
  const overlay = document.createElement('div');
  overlay.className = 'crm-confirm-overlay';
  overlay.innerHTML = `
    <div class="crm-confirm-box">
      <p class="crm-confirm-msg">${message}</p>
      <div class="crm-confirm-btns">
        <button class="btn-ghost" id="conf-cancel">ביטול</button>
        <button class="btn-danger" id="conf-ok">אישור</button>
      </div>
    </div>
  `;
  document.body.appendChild(overlay);
  document.getElementById('conf-cancel').onclick = () => overlay.remove();
  document.getElementById('conf-ok').onclick = () => { overlay.remove(); onConfirm(); };
}

// שימוש:
confirmAction('למחוק את התור של שרה?', () => deleteBooking(id));
```

```css
.crm-confirm-overlay {
  position: fixed; inset: 0;
  background: rgba(28,20,16,0.5); backdrop-filter: blur(4px);
  display: flex; align-items: center; justify-content: center;
  z-index: 10001; padding: 20px;
}
.crm-confirm-box {
  background: var(--ivory); border-radius: var(--radius-lg);
  padding: 28px 24px; max-width: 340px; width: 100%;
  text-align: center; box-shadow: 0 16px 60px rgba(28,20,16,0.2);
}
.crm-confirm-msg { font-size: 1rem; color: var(--ink); margin-bottom: 20px; }
.crm-confirm-btns { display: flex; gap: 10px; justify-content: center; }
.btn-danger {
  background: var(--error); color: white;
  border: none; border-radius: var(--radius-full);
  padding: 12px 24px; cursor: pointer; font-family: var(--font-body);
}
```

---

## Empty State

```javascript
function renderEmptyState(containerId, message = 'אין נתונים להצגה', icon = '📋') {
  document.getElementById(containerId).innerHTML = `
    <div class="empty-state">
      <div class="empty-icon">${icon}</div>
      <p class="empty-msg">${message}</p>
    </div>
  `;
}

// שימוש:
renderEmptyState('bookings-list', 'אין תורים היום', '📅');
renderEmptyState('clients-list', 'עדיין אין לקוחות', '👥');
```

```css
.empty-state {
  text-align: center; padding: 48px 24px;
  color: var(--text-secondary, #9A7E6F);
}
.empty-icon { font-size: 2.5rem; margin-bottom: 12px; opacity: 0.7; }
.empty-msg { font-size: 0.9rem; font-family: var(--font-body); }
```

---

## Form Field עם Validation

```javascript
function validateField(input) {
  const name = input.dataset.validate;
  const value = input.value.trim();
  const errEl = document.getElementById(`err-${input.id}`);

  let error = '';
  if (input.required && !value) error = 'שדה חובה';
  else if (name === 'phone' && !/^0[5-9]\d{8}$/.test(value.replace(/[-\s]/g, '')))
    error = 'מספר טלפון לא תקין';
  else if (name === 'name' && value.length < 2)
    error = 'שם חייב להכיל לפחות 2 תווים';

  input.classList.toggle('input-error', !!error);
  if (errEl) errEl.textContent = error;
  return !error;
}
```

```html
<!-- Field Template -->
<div class="form-field">
  <label for="f-phone">טלפון</label>
  <input id="f-phone" type="tel" data-validate="phone" required
         placeholder="050-1234567"
         oninput="validateField(this)">
  <span class="field-error" id="err-f-phone"></span>
</div>
```

```css
.form-field { display: flex; flex-direction: column; gap: 6px; margin-bottom: 16px; }
.form-field label { font-size: 0.85rem; color: var(--espresso); font-weight: 600; }
.form-field input {
  border: 1.5px solid var(--blush);
  border-radius: var(--radius-sm);
  padding: 12px 14px;
  font-family: var(--font-body); font-size: 1rem;
  background: white; color: var(--ink); direction: rtl;
  transition: border-color 0.2s;
}
.form-field input:focus { outline: none; border-color: var(--terracotta); }
.form-field input.input-error { border-color: var(--error); }
.field-error { font-size: 0.78rem; color: var(--error); min-height: 18px; }
```

---

## Status Badge

```javascript
const STATUS_CONFIG = {
  pending:   { label: 'ממתין',   color: '#C8A028', bg: 'rgba(200,160,40,0.1)' },
  confirmed: { label: 'מאושר',   color: '#7A9E7E', bg: '#EBF2EC' },
  completed: { label: 'הושלם',   color: '#3A2318', bg: '#F7EFE5' },
  cancelled: { label: 'בוטל',    color: '#B84C4C', bg: 'rgba(184,76,76,0.1)' },
  no_show:   { label: 'לא הגיע', color: '#9A7E6F', bg: '#F7EFE5' },
};

function renderStatusBadge(status) {
  const cfg = STATUS_CONFIG[status] ?? STATUS_CONFIG.pending;
  return `<span class="status-badge" style="color:${cfg.color};background:${cfg.bg}">${cfg.label}</span>`;
}
```

```css
.status-badge {
  display: inline-block;
  padding: 3px 10px; border-radius: 999px;
  font-size: 0.75rem; font-weight: 600;
  font-family: var(--font-body);
}
```
