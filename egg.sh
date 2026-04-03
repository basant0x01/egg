#!/usr/bin/env bash
set -euo pipefail

# egg_audit.sh - Safe GitHub commit email exposure audit
# Audits public commit metadata for exposed email addresses and writes a redacted report.
# It does NOT dump raw email addresses by default.

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[1;34m'
NC='\033[0m'

LIMIT=100
OUTPUT_FILE="email_audit_report.txt"
MODE=""
REPO=""
REPO_FILE=""
SHOW_DOMAINS_ONLY=false
INCLUDE_REDACTED_SAMPLES=false
PAUSE_SECONDS="0.2"
API_BASE="https://api.github.com"

GITHUB_TOKEN="${GITHUB_TOKEN:-}"
AUTH_ARGS=()
if [[ -n "$GITHUB_TOKEN" ]]; then
  AUTH_ARGS=(-H "Authorization: Bearer $GITHUB_TOKEN")
fi

usage() {
  cat <<USAGE
Usage: ./egg_audit.sh [options]

Options:
  -r <owner/repo>   Audit a single repository
  -f <repo_file>    Audit repositories listed in a file (one per line)
  -cl <limit>       Commit limit per repo (default: 100, max: 100)
  -o <file>         Output report file (default: email_audit_report.txt)
  --domains         Show only domain-level summary in console
  --samples         Include redacted samples in report (e.g. j***@example.com)
  -h                Show this help message

Environment:
  GITHUB_TOKEN      Optional GitHub token for higher rate limits
USAGE
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

require_tools() {
  local missing=()
  for tool in curl jq sed awk grep sort uniq cut tr mktemp; do
    command_exists "$tool" || missing+=("$tool")
  done
  if (( ${#missing[@]} > 0 )); then
    echo -e "${RED}Missing required tools:${NC} ${missing[*]}" >&2
    exit 1
  fi
}

normalize_repo() {
  local input="$1"
  input="${input#https://github.com/}"
  input="${input#http://github.com/}"
  input="${input#github.com/}"
  input="${input%/}"
  printf '%s' "$input"
}

validate_repo() {
  local repo="$1"
  [[ "$repo" =~ ^[^/[:space:]]+/[^/[:space:]]+$ ]]
}

redact_email() {
  local email="$1"
  local localpart domain first
  localpart="${email%@*}"
  domain="${email#*@}"
  first="${localpart:0:1}"
  printf '%s***@%s' "$first" "$domain"
}

print_header() {
  echo -e "${BLUE}== GitHub Commit Email Exposure Audit ==${NC}"
}

fetch_commits() {
  local repo="$1"
  local url="$API_BASE/repos/$repo/commits?per_page=$LIMIT"
  curl -fsSL "${AUTH_ARGS[@]}" "$url"
}

fetch_patch_header() {
  local repo="$1" sha="$2"
  curl -fsSL "https://github.com/$repo/commit/$sha.patch" | grep '^From: ' || true
}

analyze_repo() {
  local repo="$1"
  local tmp_emails tmp_redacted tmp_domains commits_json shas count=0
  tmp_emails="$(mktemp)"
  tmp_redacted="$(mktemp)"
  tmp_domains="$(mktemp)"

  echo -e "${GREEN}[+] Auditing:${NC} $repo"

  if ! commits_json="$(fetch_commits "$repo" 2>/dev/null)"; then
    echo -e "${YELLOW}[-] Failed to fetch commits for ${repo}${NC}" | tee -a "$OUTPUT_FILE"
    rm -f "$tmp_emails" "$tmp_redacted" "$tmp_domains"
    return
  fi

  if jq -e 'type == "object" and .message?' >/dev/null 2>&1 <<<"$commits_json"; then
    local msg
    msg="$(jq -r '.message // "GitHub API error"' <<<"$commits_json")"
    echo -e "${YELLOW}[-] GitHub API error for ${repo}:${NC} $msg" | tee -a "$OUTPUT_FILE"
    rm -f "$tmp_emails" "$tmp_redacted" "$tmp_domains"
    return
  fi

  shas="$(jq -r '.[].sha // empty' <<<"$commits_json")"
  if [[ -z "$shas" ]]; then
    echo -e "${YELLOW}[-] No commits found for:${NC} $repo" | tee -a "$OUTPUT_FILE"
    rm -f "$tmp_emails" "$tmp_redacted" "$tmp_domains"
    return
  fi

  while IFS= read -r sha; do
    [[ -z "$sha" ]] && continue
    local line email
    while IFS= read -r line; do
      email="$(sed -n 's/^From: .*<\([^>]*\)>.*/\1/p' <<<"$line")"
      [[ -z "$email" ]] && continue
      [[ "$email" == *"users.noreply.github.com"* ]] && continue
      printf '%s\n' "$email" >> "$tmp_emails"
      if [[ "$INCLUDE_REDACTED_SAMPLES" == true ]]; then
        redact_email "$email" >> "$tmp_redacted"
      fi
      printf '%s\n' "${email#*@}" >> "$tmp_domains"
    done < <(fetch_patch_header "$repo" "$sha")
    count=$((count + 1))
    sleep "$PAUSE_SECONDS"
  done <<< "$shas"

  {
    echo "Repository: $repo"
    echo "Commits scanned: $count"
  } >> "$OUTPUT_FILE"

  if [[ ! -s "$tmp_emails" ]]; then
    echo "Exposed personal emails found: 0" >> "$OUTPUT_FILE"
    echo >> "$OUTPUT_FILE"
    echo -e "${GREEN}[+] No exposed personal emails found.${NC}"
    rm -f "$tmp_emails" "$tmp_redacted" "$tmp_domains"
    return
  fi

  sort -u "$tmp_emails" -o "$tmp_emails"
  sort "$tmp_domains" | uniq -c | sort -rn > "$tmp_domains.counts"

  local total_unique
  total_unique="$(wc -l < "$tmp_emails" | tr -d ' ')"

  echo "Exposed personal emails found: $total_unique" >> "$OUTPUT_FILE"
  echo "Top domains:" >> "$OUTPUT_FILE"
  awk '{printf "  - %s (%s)\n", $2, $1}' "$tmp_domains.counts" >> "$OUTPUT_FILE"

  if [[ "$INCLUDE_REDACTED_SAMPLES" == true && -s "$tmp_redacted" ]]; then
    echo "Redacted samples:" >> "$OUTPUT_FILE"
    sort -u "$tmp_redacted" | head -n 20 | sed 's/^/  - /' >> "$OUTPUT_FILE"
  fi
  echo >> "$OUTPUT_FILE"

  echo -e "${GREEN}[+] Exposed personal emails found:${NC} $total_unique"
  if [[ "$SHOW_DOMAINS_ONLY" == true ]]; then
    awk '{printf "    %s (%s)\n", $2, $1}' "$tmp_domains.counts"
  else
    echo "    Domains:"
    awk '{printf "      - %s (%s)\n", $2, $1}' "$tmp_domains.counts"
    if [[ "$INCLUDE_REDACTED_SAMPLES" == true && -s "$tmp_redacted" ]]; then
      echo "    Redacted samples:"
      sort -u "$tmp_redacted" | head -n 10 | sed 's/^/      - /'
    fi
  fi

  rm -f "$tmp_emails" "$tmp_redacted" "$tmp_domains" "$tmp_domains.counts"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -r)
      MODE="single"
      REPO="${2:-}"
      shift 2
      ;;
    -f)
      MODE="file"
      REPO_FILE="${2:-}"
      shift 2
      ;;
    -cl)
      LIMIT="${2:-}"
      shift 2
      ;;
    -o)
      OUTPUT_FILE="${2:-}"
      shift 2
      ;;
    --domains)
      SHOW_DOMAINS_ONLY=true
      shift
      ;;
    --samples)
      INCLUDE_REDACTED_SAMPLES=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo -e "${YELLOW}[!] Unknown option:${NC} $1" >&2
      usage
      exit 1
      ;;
  esac
done

require_tools
print_header

if [[ ! "$LIMIT" =~ ^[0-9]+$ ]] || (( LIMIT < 1 || LIMIT > 100 )); then
  echo -e "${RED}Commit limit must be an integer between 1 and 100.${NC}" >&2
  exit 1
fi

: > "$OUTPUT_FILE"

echo "GitHub Commit Email Exposure Audit Report" >> "$OUTPUT_FILE"
echo "Generated: $(date -u '+%Y-%m-%d %H:%M:%S UTC')" >> "$OUTPUT_FILE"
echo >> "$OUTPUT_FILE"

case "$MODE" in
  single)
    REPO="$(normalize_repo "$REPO")"
    if ! validate_repo "$REPO"; then
      echo -e "${RED}Invalid repository format. Use owner/repo.${NC}" >&2
      exit 1
    fi
    analyze_repo "$REPO"
    ;;
  file)
    if [[ ! -f "$REPO_FILE" ]]; then
      echo -e "${RED}Repo file not found:${NC} $REPO_FILE" >&2
      exit 1
    fi
    while IFS= read -r repo || [[ -n "$repo" ]]; do
      repo="${repo%%#*}"
      repo="$(echo "$repo" | xargs)"
      [[ -z "$repo" ]] && continue
      repo="$(normalize_repo "$repo")"
      if ! validate_repo "$repo"; then
        echo -e "${YELLOW}[-] Skipping invalid repo:${NC} $repo"
        continue
      fi
      analyze_repo "$repo"
    done < "$REPO_FILE"
    ;;
  *)
    echo -e "${RED}Please specify -r <owner/repo> or -f <repo_file>.${NC}" >&2
    usage
    exit 1
    ;;
esac

echo -e "${GREEN}[+] Saved report:${NC} $(realpath "$OUTPUT_FILE")"
