#!/usr/bin/env bash
# One-click: init git (if needed), create GitHub repo, push main.
# Never uploads auth files (see .gitignore).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

REPO_NAME="Ai-credits-menubar"
VISIBILITY="public"   # public | private
DESCRIPTION="Ai工具余额展示 — macOS 菜单栏显示 Grok Build / OpenAI Codex 用量余量与重置时间"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name) REPO_NAME="$2"; shift 2 ;;
    --public) VISIBILITY="public"; shift ;;
    --private) VISIBILITY="private"; shift ;;
    -h|--help)
      echo "Usage: $0 [--name REPO] [--public|--private]"
      exit 0
      ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
done

# --- safety: refuse if secrets would be committed ---
echo "→ Scanning for accidental secrets…"
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  :
else
  git init -b main
fi

# Ensure ignore rules exist
test -f .gitignore || { echo "missing .gitignore"; exit 1; }

# Block common secret filenames if present and tracked
SECRET_HITS=$(git ls-files 2>/dev/null | grep -E '(^|/)(auth\.json|\.env|credentials|id_rsa|\.pem$)' || true)
if [[ -n "${SECRET_HITS}" ]]; then
  echo "✗ Refusing to publish: tracked secret-like files:"
  echo "$SECRET_HITS"
  exit 1
fi

# Content scan of staged/unstaged source (heuristic)
if command -v rg >/dev/null 2>&1; then
  if rg -n --glob '!**/.git/**' \
      -e 'eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}' \
      -e 'sk-[A-Za-z0-9]{20,}' \
      -e 'xai-[A-Za-z0-9]{20,}' \
      -e 'rt\.[A-Za-z0-9._-]{20,}' \
      -e 'BEGIN (RSA |OPENSSH )?PRIVATE KEY' \
      . 2>/dev/null | grep -v 'publish-to-github' | head -5 | grep -q .; then
    echo "✗ Possible secret material found in working tree. Aborting."
    rg -n --glob '!**/.git/**' \
      -e 'eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}' \
      -e 'sk-[A-Za-z0-9]{20,}' \
      -e 'xai-[A-Za-z0-9]{20,}' \
      . 2>/dev/null | head -10
    exit 1
  fi
fi
echo "  OK (no obvious secrets)"

# --- gh auth ---
if ! command -v gh >/dev/null 2>&1; then
  echo "✗ Install GitHub CLI: brew install gh && gh auth login"
  exit 1
fi
if ! gh auth status >/dev/null 2>&1; then
  echo "✗ Run: gh auth login"
  exit 1
fi

USER="$(gh api user --jq .login)"
REMOTE_URL="https://github.com/${USER}/${REPO_NAME}.git"
echo "→ GitHub user: ${USER}"
echo "→ Repo: ${USER}/${REPO_NAME} (${VISIBILITY})"

# --- commit ---
git add -A
# Double-check nothing secret is staged
if git diff --cached --name-only | grep -E '(^|/)(auth\.json|\.env|credentials)' >/dev/null; then
  echo "✗ Secret-like path staged. Aborting."
  exit 1
fi

if git diff --cached --quiet && git rev-parse HEAD >/dev/null 2>&1; then
  echo "  (no new changes to commit)"
else
  git commit -m "$(cat <<'EOF'
Initial release: Grok & Codex macOS menu bar usage monitors

G and C monograms with remaining quota, reset time, and task-running blink.
Credentials stay on the local machine; none are included in the repository.
EOF
)" || true
fi

# --- create remote if needed ---
if gh repo view "${USER}/${REPO_NAME}" >/dev/null 2>&1; then
  echo "→ Repo already exists on GitHub"
else
  echo "→ Creating GitHub repository…"
  gh repo create "${USER}/${REPO_NAME}" \
    --"${VISIBILITY}" \
    --description "${DESCRIPTION}" \
    --source=. \
    --remote=origin \
    --push
  echo "✓ Published: https://github.com/${USER}/${REPO_NAME}"
  exit 0
fi

# Existing remote: ensure origin and push
if git remote get-url origin >/dev/null 2>&1; then
  git remote set-url origin "$REMOTE_URL"
else
  git remote add origin "$REMOTE_URL"
fi

git push -u origin HEAD:main
echo "✓ Pushed: https://github.com/${USER}/${REPO_NAME}"
