# egg

**egg** is a Bash-based utility that collects contributor names and publicly exposed email addresses from GitHub commit patches.

It supports scanning:
- a single repository
- a file containing multiple repositories

The project also includes a companion installer script, **`requirement.sh`**, to verify and install the command-line dependencies needed by **`egg.sh`**.

> **Important:** Use this tool responsibly and only for legitimate research, auditing, or maintenance purposes. Respect privacy, platform terms, and applicable laws.

---

## Features

- Extracts contributor names and email addresses from GitHub commit patches
- Supports **single repository** and **repository list file** modes
- Skips GitHub `noreply` email addresses
- De-duplicates discovered email addresses during execution
- Writes results to a configurable output file
- Displays results in a formatted terminal table
- Includes a dependency installer for common Linux distributions

---

## Project Structure

```bash
.
├── egg.sh            # Main script
├── requirement.sh    # Dependency checker and installer
└── README.md         # Project documentation
```

---

## Requirements

The following tools are required:

- `jq`
- `curl`
- `perl`
- `sed`
- `awk`
- `grep`

### Supported package managers

`requirement.sh` currently supports:

- Debian / Ubuntu (`apt-get`)
- Red Hat / CentOS / Fedora (`yum`)
- Arch Linux (`pacman`)

---

## Installation

Clone or download the project files, then make the scripts executable:

```bash
chmod +x egg.sh requirement.sh
```

Install required dependencies:

```bash
./requirement.sh
```

---

## Usage

```bash
./egg.sh [options]
```

### Options

| Option | Description |
|---|---|
| `-r <repo>` | Scan a single repository in `owner/repo` format |
| `-f <repo_file>` | Scan multiple repositories from a file |
| `-cl <limit>` | Number of commits to inspect per repository. Default: `100` |
| `-o <file>` | Output file path. Default: `emails_output.txt` |
| `-h` | Show help message |

---

## Examples

### Scan a single repository

```bash
./egg.sh -r torvalds/linux
```

### Scan a single repository with a custom commit limit

```bash
./egg.sh -r torvalds/linux -cl 50
```

### Scan multiple repositories from a file

```bash
./egg.sh -f repos.txt
```

### Save results to a custom output file

```bash
./egg.sh -r torvalds/linux -o results.txt
```

### Combined example

```bash
./egg.sh -f repos.txt -cl 75 -o extracted_emails.txt
```

---

## Repository File Format

When using `-f <repo_file>`, provide one repository per line:

```text
owner/repo-one
owner/repo-two
owner/repo-three
```

You can also include comments and blank lines:

```text
# Target repositories
owner/repo-one

owner/repo-two
```

---

## Sample Output

### Terminal

```text
[+] Output file: emails_output.txt
[+] Commit limit per repo: 100
[+] Processing repo: owner/repository

┌--------------------------------------------┬--------------------┬----------------------------------------┐
│ Commit                                     │ Name               │ Email                                  │
├--------------------------------------------┼--------------------┼----------------------------------------┤
│ abc123...                                  │ Example User       │ example@example.com                    │
└--------------------------------------------┴--------------------┴----------------------------------------┘
```

### Output file

```text
owner/repository: Example User <example@example.com>
```

---

## How It Works

1. Parses command-line arguments to determine scan mode.
2. Validates required tools and repository input.
3. Fetches recent commit SHAs using the GitHub API.
4. Downloads each commit patch from GitHub.
5. Extracts `From:` header values from patch content.
6. Filters out GitHub `noreply` addresses.
7. Removes duplicates and saves unique results.

---

## Notes and Limitations

- The script depends on **publicly accessible commit patch data**.
- Results are limited by the commit count specified with `-cl`.
- Some repositories may not expose useful email addresses.
- `users.noreply.github.com` addresses are intentionally excluded.
- Multi-repository mode runs jobs in the background with a fixed internal thread limit.
- `GITHUB_TOKEN` is defined in the script but must be set before use if you want authenticated GitHub API requests.

Example:

```bash
GITHUB_TOKEN="your_token_here" ./egg.sh -r owner/repo
```

---

## Troubleshooting

### `jq is not installed`
Run:

```bash
./requirement.sh
```

### Invalid repository format
Use the format below:

```text
owner/repo
```

### No commits found or invalid repository
Possible reasons:
- repository name is incorrect
- repository is private or unavailable
- GitHub API rate limits were reached

Using an authenticated token may help reduce rate-limit issues.

---

## Security and Responsible Use

This project reads contributor information exposed through public GitHub commit metadata. Before using it:

- verify that your use complies with GitHub's Terms of Service
- respect contributor privacy
- avoid unsolicited outreach or bulk contact collection
- use the output only for legitimate and lawful purposes

---

## Future Improvements

- Better package manager detection for more Linux distributions
- Command-line flag for configurable concurrency
- Native support for environment-based GitHub token loading
- CSV / JSON export formats
- Improved error handling and retry logic

---

## Author

**Basant Karki** (`basant0x01`)

---

## License

Add your preferred license here, for example:

- MIT
- Apache-2.0
- GPL-3.0

If you have not chosen one yet, create a `LICENSE` file before publishing.
