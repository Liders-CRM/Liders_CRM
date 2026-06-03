#!/usr/bin/env bash
# ============================================================
# Liders CRM — Skills Installer
# מושך את כל הסקילים העדכניים מה-repo הראשי
# ============================================================
# שימוש:
#   bash install-skills.sh              # מתקין בתיקייה הנוכחית
#   bash install-skills.sh /path/to/project
# ============================================================

set -e

SKILLS_REPO="https://github.com/elgrablidudu-prog/-"
TARGET_DIR="${1:-.}"
SKILLS_DIR="$TARGET_DIR/.claude/skills"
CLAUDE_DIR="$TARGET_DIR/.claude"

echo ""
echo "🔧 Liders CRM Skills Installer"
echo "================================"
echo "📁 Target: $TARGET_DIR"
echo ""

# בדוק git
if ! command -v git &>/dev/null; then
  echo "❌ git לא מותקן"
  exit 1
fi

# צור תיקייה זמנית
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

echo "📥 מושך skills מ-GitHub..."

# Clone רק את תיקיית .claude/ (sparse)
git clone --quiet --filter=blob:none --sparse "$SKILLS_REPO" "$TMPDIR" 2>/dev/null
cd "$TMPDIR"
git sparse-checkout set ".claude/skills" ".claude/SKILLSEXPORT.md" ".claude/settings.json" 2>/dev/null
cd - >/dev/null

# צור תיקיות
mkdir -p "$SKILLS_DIR"

# העתק skills
cp -r "$TMPDIR/.claude/skills/." "$SKILLS_DIR/"
echo "✅ Skills הועתקו"

# העתק SKILLSEXPORT.md
if [ -f "$TMPDIR/.claude/SKILLSEXPORT.md" ]; then
  cp "$TMPDIR/.claude/SKILLSEXPORT.md" "$CLAUDE_DIR/SKILLSEXPORT.md"
  echo "✅ SKILLSEXPORT.md הועתק"
fi

# settings.json — העתק רק אם לא קיים
if [ ! -f "$CLAUDE_DIR/settings.json" ] && [ -f "$TMPDIR/.claude/settings.json" ]; then
  cp "$TMPDIR/.claude/settings.json" "$CLAUDE_DIR/settings.json"
  echo "✅ settings.json נוצר"
else
  echo "ℹ️  settings.json קיים — לא הוחלף"
fi

# ספירה
SKILL_COUNT=$(ls "$SKILLS_DIR"/*.md 2>/dev/null | wc -l | tr -d ' ')

echo ""
echo "================================"
echo "✅ הותקנו $SKILL_COUNT סקילים:"
for f in "$SKILLS_DIR"/*.md; do
  name=$(basename "$f" .md)
  echo "   • /$name"
done
echo ""
echo "📖 לרשימה המלאה: .claude/SKILLSEXPORT.md"
echo ""
