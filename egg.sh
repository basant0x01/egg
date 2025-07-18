#!/bin/bash

# egg - Email Grabber from GitHub
# Author: Basant Karki (basant0x01) - Modified for Table Output & Deduplication
# Version: 1.3 (Unique Emails Only)

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
NC='\033[0m'

# Default values
LIMIT=100
OUTPUT_FILE="emails_output.txt"
MAX_THREADS=5
MODE=""
REPO=""
REPO_FILE=""

# Optional GitHub token
GITHUB_TOKEN=""
if [ -n "$GITHUB_TOKEN" ]; then
    AUTH_HEADER="Authorization: Bearer $GITHUB_TOKEN"
else
    AUTH_HEADER=""
fi

# Help Section
show_help() {
    echo -e "${BLUE}Usage:${NC} ./egg.sh [options]"
    echo -e "${YELLOW}Options:${NC}"
    echo -e "  -r <repo>       : Single repo mode (e.g., user/repo)"
    echo -e "  -f <repo_file>  : File repo mode (file with list of repos)"
    echo -e "  -cl <limit>     : Commit limit per repo (default: 100)"
    echo -e "  -o <file>       : Output file (default: emails_output.txt)"
    echo -e "  -h              : Show this help message"
    exit 0
}

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -r)
            MODE="single"
            REPO="$2"
            shift 2
            ;;
        -f)
            MODE="file"
            REPO_FILE="$2"
            shift 2
            ;;
        -cl)
            LIMIT="$2"
            shift 2
            ;;
        -o)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        -h)
            show_help
            ;;
        *)
            echo -e "${YELLOW}[!] Unknown option: $1${NC}"
            show_help
            ;;
    esac
done

# Check dependencies
command -v jq >/dev/null 2>&1 || { echo >&2 "Error: jq is not installed."; exit 1; }

# Validate mode
if [ "$MODE" != "single" ] && [ "$MODE" != "file" ]; then
    echo -e "${YELLOW}[!] Please specify either -r <repo> or -f <repo_file>${NC}"
    show_help
fi

# Normalize and validate single repo input
if [ "$MODE" == "single" ]; then
    REPO="${REPO#github.com/}"
    if ! [[ "$REPO" =~ ^[^/]+/[^/]+$ ]]; then
        echo -e "${YELLOW}[-] Invalid repo format: '$REPO'. Use user/repo (e.g., torvalds/linux)${NC}"
        exit 1
    fi
fi

# Clear or create output file
> "$OUTPUT_FILE"
echo -e "${GREEN}[+] Output file:${NC} $OUTPUT_FILE"
echo -e "${GREEN}[+] Commit limit per repo:${NC} $LIMIT"
echo

# Declare associative array to store seen emails (Bash >=4)
declare -A seen_entries

# Print table header
print_table_header() {
    printf "\n┌%-44s┬%-20s┬%-40s┐\n" "--------------------------------------------" "--------------------" "----------------------------------------"
    printf "│ %-42s │ %-18s │ %-38s │\n" "Commit" "Name" "Email"
    printf "├%-44s┼%-20s┼%-40s┤\n" "--------------------------------------------" "--------------------" "----------------------------------------"
}

# Print table footer
print_table_footer() {
    printf "└%-44s┴%-20s┴%-40s┘\n" "--------------------------------------------" "--------------------" "----------------------------------------"
}

# Extract emails from commit, only unique emails
extract_emails_from_commit() {
    local repo="$1"
    local sha="$2"

    curl -s "https://github.com/$repo/commit/$sha.patch" | \
    grep '^From: ' | sed 's/^From: //' | grep -v "users.noreply.github.com" | while read -r line; do
        name=$(echo "$line" | awk -F '<' '{print $1}' | sed 's/"//g' | perl -MHTML::Entities -pe 'decode_entities($_);')
        email=$(echo "$line" | grep -oP '(?<=<)[^>]+')

        if [ -n "$email" ]; then
            # Check if email already seen
            if [[ -n "${seen_entries[$email]}" ]]; then
                continue
            fi

            seen_entries[$email]=1
            printf "│ %-42s │ %-18s │ %-38s │\n" "$sha" "$name" "$email"
            echo "$repo: $name <$email>" >> "$OUTPUT_FILE"
        fi
    done
}

# Process a single repository
process_repo() {
    local repo="$1"
    echo -e "${GREEN}[+] Processing repo:${NC} $repo"
    echo

    local commits
    commits=$(curl -s -H "$AUTH_HEADER" "https://api.github.com/repos/$repo/commits?per_page=$LIMIT" | jq -r '.[].sha')

    if [ -z "$commits" ] || [[ "$commits" == "null" ]]; then
        echo -e "${YELLOW}[-] No commits found or invalid repo:${NC} $repo"
        return
    fi

    print_table_header
    for sha in $commits; do
        extract_emails_from_commit "$repo" "$sha"
        sleep 0.2
    done
    print_table_footer
    echo
}

# Main execution
if [ "$MODE" == "single" ]; then
    process_repo "$REPO"
elif [ "$MODE" == "file" ]; then
    count=0
    while IFS= read -r repo || [ -n "$repo" ]; do
        [[ "$repo" =~ ^#.*$ ]] && continue
        [[ -z "$repo" ]] && continue
        repo="${repo#github.com/}"

        if ! [[ "$repo" =~ ^[^/]+/[^/]+$ ]]; then
            echo -e "${YELLOW}[-] Skipping invalid repo format in file: $repo${NC}"
            continue
        fi

        process_repo "$repo" &
        ((count++))
        if (( count % MAX_THREADS == 0 )); then
            wait
        fi
    done < "$REPO_FILE"
    wait
fi

# Final message
echo -e "${GREEN}[+] Saved Output:${NC} $(realpath "$OUTPUT_FILE")"
