#!/bin/bash

# egg - Email Grabber from GitHub (File Input Version)
# Usage: ./egg.sh <repo_file> [commit_limit] [output_file]
# Author: Basant Karki (basant0x01)
# Version: 0.5 (with dynamic output)

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
NC='\033[0m'

# Check dependencies
command -v jq >/dev/null 2>&1 || { echo >&2 "Error: jq is not installed."; exit 1; }

# Input validation
if [ -z "$1" ]; then
  echo -e "${YELLOW}Usage: $0 <repo_file> [commit_limit] [output_file]${NC}"
  exit 1
fi

REPO_FILE="$1"
LIMIT="${2:-100}"
OUTPUT_FILE="${3:-emails_output.txt}"

MAX_THREADS=5

# Optional GitHub token for rate limiting
GITHUB_TOKEN=""
if [ -n "$GITHUB_TOKEN" ]; then
    AUTH_HEADER="Authorization: Bearer $GITHUB_TOKEN"
else
    AUTH_HEADER=""
fi

echo -e "${GREEN}[+] Loading repositories from:${NC} $REPO_FILE"
echo -e "${GREEN}[+] Commit limit per repo:${NC} $LIMIT"
echo -e "${GREEN}[+] Output file:${NC} $OUTPUT_FILE"
echo -e "${GREEN}[+] Extracting emails from commits...${NC}"
echo

# Clear or create the output file
> "$OUTPUT_FILE"

# Function to extract emails from a single commit
extract_emails_from_commit() {
    local repo="$1"
    local sha="$2"
    curl -s "https://github.com/$repo/commit/$sha.patch" | \
    grep '^From: ' | sed 's/^From: //' | grep -v "users.noreply.github.com" | while read line; do
        name=$(echo "$line" | awk -F '<' '{print $1}' | sed 's/"//g' | perl -MHTML::Entities -pe 'decode_entities($_);')
        email=$(echo "$line" | grep -oP '(?<=<)[^>]+')
        if [ -n "$email" ]; then
            formatted="$repo: $name <$email>"
            echo "$formatted"
            echo "$formatted" >> "$OUTPUT_FILE"
        fi
    done
}

# Function to process a single repo
process_repo() {
    local repo="$1"
    echo -e "${GREEN}[+] Processing repo:${NC} $repo"

    local commits=$(curl -s -H "$AUTH_HEADER" "https://api.github.com/repos/$repo/commits?per_page=$LIMIT" | jq -r '.[].sha')

    if [ -z "$commits" ]; then
        echo -e "${YELLOW}[-] No commits found or invalid repo:${NC} $repo"
        return
    fi

    for sha in $commits; do
        extract_emails_from_commit "$repo" "$sha" &
        sleep 0.2 # Avoid hitting rate limits
    done

    wait # Wait for all commits to finish before moving to next repo
}

# Main loop over repo file
count=0
while IFS= read -r repo || [ -n "$repo" ]; do
    # Skip empty lines and comments
    [[ "$repo" =~ ^#.*$ ]] && continue
    [[ -z "$repo" ]] && continue

    process_repo "$repo" &

    ((count++))
    if (( count % MAX_THREADS == 0 )); then
        wait
    fi
done < "$REPO_FILE"

# Final wait for remaining jobs
wait

echo -e "${GREEN}[+] Extraction complete. Results saved to:${NC} $OUTPUT_FILE"
