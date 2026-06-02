#!/usr/bin/env bash
# Hook: runs after Write tool — reminds Claude to update SKILLSEXPORT.md when a skill is added

FILE=$(jq -r '.tool_input.file_path // empty' 2>/dev/null)

if echo "$FILE" | grep -qE '\.claude/skills/[^/]+\.md$'; then
  SKILL=$(basename "$FILE" .md)
  DATE=$(date +%Y-%m-%d)
  printf '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"[SKILLS EXPORT UPDATE REQUIRED] New skill written: %s (%s)\nYou MUST update .claude/SKILLSEXPORT.md now — add a row to the custom skills table with: skill name, /command (from the ## command line in the file), short description, and today date %s."}}\n' "$SKILL" "$FILE" "$DATE"
fi
