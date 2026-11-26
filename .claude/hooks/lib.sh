# Shared setup for the Claude Code hooks in .claude/settings.json.
# Sourced, not run. Reads the hook's JSON input from stdin into $input.
# Exits quietly (0) when it can't work, so a missing tool never blocks the agent:
# CI still runs every check.

root=$(git -C "${CLAUDE_PROJECT_DIR:-.}" rev-parse --show-toplevel 2>/dev/null) || exit 0
cd "$root" || exit 0
command -v jq >/dev/null 2>&1 || exit 0

input=$(cat)
session=$(printf '%s' "$input" | jq -r '.session_id // "default"' | tr -cd 'A-Za-z0-9_-')
[ -n "$session" ] || session=default

# Per-session state lives inside .git, so it is never committed.
state="$(git rev-parse --absolute-git-dir)/claude-hooks"
mkdir -p "$state"
snap="$state/$session.snap"
blocks="$state/$session.blocks"

# One hash for the whole working tree: HEAD, tracked changes and untracked
# (non-ignored) files. It changes whenever anything is edited, by any tool.
tree_hash() {
  {
    git rev-parse HEAD 2>/dev/null
    git diff HEAD --binary 2>/dev/null
    untracked=$(git ls-files --others --exclude-standard)
    if [ -n "$untracked" ]; then
      printf '%s\n' "$untracked"
      printf '%s\n' "$untracked" | git hash-object --stdin-paths
    fi
  } | git hash-object --stdin
}
