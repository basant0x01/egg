# egg v0.1
<img width="1920" height="345" alt="image" src="https://github.com/user-attachments/assets/a2636257-cf1b-4fc7-b3ae-5928ab45d1ef" />


[Example: `./egg.sh basant0x01/GasGuard -cl 100 -o <output>`]

egg (Email Grabber from GitHub) is a lightweight OSINT and recon tool designed to extract publicly available email addresses from GitHub repositories, commits, and patch files. Ideal for bug bounty hunters, security researchers, and OSINT professionals, egg helps streamline GitHub-based reconnaissance by identifying exposed email metadata in commit history.

GitHub repositories often reveal author information through commits, and although GitHub obfuscates many emails using noreply addresses, contributors who haven't enabled privacy settings or who commit using external Git clients may still expose their real email addresses. egg automates the process of identifying these email addresses in a streamlined and ethical way.




# Usage
`./egg.sh <user/repo> [commit_limit] -o [output]` 

🔍 What egg Does:

- Clones or parses a target repository
- Extracts author emails from commit history
- Optionally scrapes .patch views for raw email metadata
- Filters or highlights non-obfuscated emails
- Supports batch mode for multiple repos or targets

This tool is ideal for bug bounty hunters, red teamers, OSINT analysts, and developers conducting security audits on public repositories. It can be integrated into larger recon pipelines or used as a standalone CLI utility.


⚡ Use Cases:

- Gathering contact details for responsible disclosure
- Mapping contributors to organizations
- Identifying exposed emails in open-source projects
- Pre-engagement recon for pentests or bounty programs


egg was created with privacy and responsible disclosure in mind. It only targets public data that users have chosen to expose via commits, and it should never be used to target private information or violate GitHub’s terms of service.

Whether you're hunting for bugs, tracking contributions, or conducting passive intelligence gathering, egg provides a fast and focused way to reveal publicly visible email traces within the GitHub ecosystem.

# Contact Author
Email: basant0x01@wearehackerone.com / [x.com/basant0x01](https://x.com/basant0x01) / www.linkedin.com/in/basantkarki/
