#!/usr/bin/env bash

# Pre-commit hook to prevent committing secrets and build artifacts.
# Blocks:
# - Non-example .xcconfig files
# - Build artifacts (build/, */build/, .xcarchive, .ipa, .app)
# - Added lines with common secret patterns (OpenAI, GitHub, AWS, private keys, JWTs)
#
# Install: copy/symlink to .git/hooks/pre-commit and ensure executable.

set -euo pipefail

RED="\033[0;31m"; YEL="\033[0;33m"; GRN="\033[0;32m"; NC="\033[0m"

echo -e "${YEL}[pre-commit] Running secret/build checks...${NC}" >&2

staged_files=$(git diff --cached --name-only --diff-filter=ACMR)
if [[ -z "${staged_files}" ]]; then
  exit 0
fi

fail() {
  echo -e "${RED}ERROR:${NC} $1" >&2
  echo -e "${YEL}Hint:${NC} $2" >&2
  exit 1
}

# 1) File path checks
while IFS= read -r f; do
  # Block non-example xcconfig files
  if [[ "$f" == *.xcconfig && "$f" != *".example"* ]]; then
    fail "Attempt to commit xcconfig file: $f" "Keep secrets in local Config.xcconfig; only commit Config.xcconfig.example."
  fi

  # Block build artifacts
  case "$f" in
    build/*|*/build/*|*.xcarchive|*.ipa|*.app)
      fail "Build artifact staged: $f" "Add build outputs to .gitignore and remove from index: git rm --cached -r build" ;;
  esac
done <<<"${staged_files}"

# 2) Content checks on added lines per-file
check_file() {
  local file="$1"
  # Skip obvious templates/examples
  if [[ "$file" == *.example || "$file" == *.md ]]; then
    return 0
  fi

  local added
  added=$(git diff --cached -U0 -- "$file" | sed -n 's/^+//p')
  [[ -z "$added" ]] && return 0

  # Patterns to block
  local -a patterns=()
  patterns+=('sk-[A-Za-z0-9]{20,}')                                 # OpenAI key
  patterns+=('ghp_[A-Za-z0-9]{36,}')                                # GitHub token
  patterns+=('AKIA[0-9A-Z]{16}')                                    # AWS key id
  patterns+=('AWS_SECRET_ACCESS_KEY|aws_secret_access_key')          # AWS secret
  patterns+=('-----BEGIN [A-Z ]*PRIVATE KEY-----')                   # PEM private key
  patterns+=('BEGIN OPENSSH PRIVATE KEY')                            # SSH private key
  patterns+=('Authorization:\s*Bearer\s+[A-Za-z0-9._-]{20,}')       # Bearer tokens
  patterns+=('OPENAI_API_KEY\s*[:=]\s*sk-[A-Za-z0-9_-]{20,}')       # OpenAI via var
  patterns+=('(SUPABASE_ANON_KEY|NOTIFICATIONS_SUPABASE_ANON_KEY)\s*[:=]\s*eyJhbGci') # JWT-like
  # Guard against accidental hardcoded passwords in code (quoted, 8+ chars)
  patterns+=('password\s*[:=]\s*"[^"\s]{8,}"')

  for rx in "${patterns[@]}"; do
    if echo "$added" | LC_ALL=C grep -E -q "$rx"; then
      echo -e "${RED}ERROR:${NC} Potential secret detected in $file" >&2
      echo -e "${YEL}Pattern:${NC} $rx" >&2
      echo -e "${YEL}Tip:${NC} Move credentials to Config.xcconfig (ignored) or env vars; use placeholders in committed files." >&2
      exit 1
    fi
  done
}

while IFS= read -r f; do
  # Skip scanning the hook itself to avoid false positives on pattern literals
  if [[ "$f" == "Scripts/pre-commit.sh" ]]; then
    continue
  fi
  check_file "$f"
done <<<"${staged_files}"

echo -e "${GRN}[pre-commit] OK: no secrets/build artifacts detected.${NC}" >&2
exit 0
