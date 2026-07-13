#!/usr/bin/env sh
set -eu

usage() {
  cat <<'USAGE'
Usage: audit.sh [path ...]

Scans files for common Cloudflare x DeepSeek cost-control gaps.
Environment:
  AUDIT_STRICT=1   fail on any major issue
USAGE
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi

if [ "$#" -eq 0 ]; then
  set -- .
fi

fail=0
scan_file() {
  f=$1
  case "$f" in
    *.js|*.ts|*.tsx|*.jsx|*.py|*.sh|*.ps1|*.json|*.yaml|*.yml|*.toml|*.md|*.env|*.env.*)
      :
      ;;
    *)
      return 0
      ;;
  esac

  if grep -Ei 'deepseek|openai|anthropic|google|llm|ai gateway|ai-gateway|gateway' "$f" >/dev/null 2>&1; then
    grep -nEi 'deepseek|openai|anthropic|google|llm|ai gateway|ai-gateway|gateway' "$f" || true
  fi

  if grep -Eiq 'fetch\(|axios\.|requests\.|urllib|curl .*deepseek|direct.*deepseek' "$f"; then
    echo "[major] possible direct model access: $f"
    fail=1
  fi

  if grep -Eiq 'retry|retries|backoff' "$f"; then
    :
  fi

  if grep -Eiq 'max_tokens|max completion|max_output|max_output_tokens|temperature|top_p' "$f"; then
    :
  else
    echo "[minor] no obvious output bound found: $f"
  fi
}

for p in "$@"; do
  if [ -d "$p" ]; then
    find "$p" -type f | while IFS= read -r f; do scan_file "$f"; done
  elif [ -f "$p" ]; then
    scan_file "$p"
  fi
done

if [ "${AUDIT_STRICT:-0}" = "1" ] && [ "$fail" -ne 0 ]; then
  exit 1
fi
