#!/bin/bash
set -euo pipefail

# Only run in remote Claude Code on the web
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
STATUS_FILE="$PROJECT_DIR/.claude/skills/crm-status.md"

# ── CRM Session Banner ──────────────────────────────────────
cat << 'BANNER'
╔══════════════════════════════════════════════════════╗
║          🌿  מלי • יופי ועור CRM  🌿                ║
╚══════════════════════════════════════════════════════╝
BANNER

# Git state
BRANCH=$(git -C "$PROJECT_DIR" branch --show-current 2>/dev/null || echo "unknown")
LAST_COMMIT=$(git -C "$PROJECT_DIR" log --oneline -1 2>/dev/null || echo "no commits")
echo "📁 Branch: $BRANCH"
echo "📝 Last: $LAST_COMMIT"
echo ""

# ── Inline CRM project status (loaded into every session) ──
if [ -f "$STATUS_FILE" ]; then
  cat "$STATUS_FILE"
else
  cat << 'FALLBACK'
## מצב פרויקט — מלי יופי ועור CRM

### ✅ בנוי: Booking flow מלא, Admin panel, Design system, 8 שירותים, לוח שנה RTL
### ❌ חסר: Supabase connection (נתונים hardcoded), WhatsApp automations, Google Calendar sync

**קובץ ראשי:** index.html (1,296 שורות — HTML + CSS + JS הכל ביחד)
**עדיפות הבאה:** חיבור Supabase — החלפת `const S` בשאיבה אמיתית מה-DB
FALLBACK
fi

echo ""
echo "══════════════════════════════════════════════════════"
echo "📖 לפרטים נוספים: /crm-status | /booking-flow | /make-whatsapp | /google-cal"
echo "══════════════════════════════════════════════════════"
