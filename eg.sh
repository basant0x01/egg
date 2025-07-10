#!/bin/bash

# egg - Email Grabber from GitHub
# Usage: ./egg.sh <user/repo> [commit_limit]
# Author: Basant Karki (basant0x01)
# Version: 0.1

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Input validation
if [ -z "$1" ]; then
  echo -e "${YELLOW}Usage: $0 <user/repo> [commit_limit]${NC}"
  exit 1
fi

REPO="$1"
LIMIT="${2:-100}"

echo -e "${GREEN}[+] Target repository:${NC} $REPO"
echo -e "${GREEN}[+] Commit limit:${NC} $LIMIT"
echo -e "${GREEN}[+] Extracting emails from commits...${NC}"
echo

# Header for table
printf "${BLUE}%-30s %-40s${NC}\n" "Name" "Email"
printf "${CYAN}%-30s %-40s${NC}\n" "------------------------------" "----------------------------------------"

# Get commit SHAs
commits=$(curl -s "https://api.github.com/repos/$REPO/commits?per_page=$LIMIT" | jq -r '.[].sha')

# Extract emails
for sha in $commits; do
    curl -s "https://github.com/$REPO/commit/$sha.patch" | \
    grep '^From: ' | sed 's/^From: //' | grep -v "users.noreply.github.com" | while read line; do
        # Clean up encoded names and quotes
        name=$(echo "$line" | sed -E 's/^"?=?UTF-8\?q\?//;s/\?="$//;s/"//g' | sed -E 's/ =20/ /g' | sed -E 's/=\?UTF-8\?q\?//g' | cut -d '<' -f1 | xargs)
        email=$(echo "$line" | grep -oP '(?<=<)[^>]+')
        [ -n "$email" ] && printf "%-30s %-40s\n" "$name" "$email"
    done
done | sort -u
