# Netskope-SCIM-Bulk-User-Importer
Automate the bulk creation of users in a Netskope tenant using the SCIM API.

## Features
- Supports both **macOS (Bash)** and **Windows (PowerShell)**.
- Accepts a CSV user list.
- Validates CSV input and skips invalid or blank lines.
- Handles authentication, API error codes, and summary reporting.

## Requirements
- A Netskope SCIM API token with permission to manage users.

### Bash Version
- Bash 4+
- `curl`
- `jq`

### PowerShell Version
- PowerShell 5.1 or newer (Windows)
- TLS 1.2 support enabled (automatic in script)

## CSV Format
Each user should be listed on a new line, with values separated by commas in the following order:

`email,first_name,last_name`

Refer to the included `example_users.csv` file for a sample.

## Usage

### Bash Version
**Syntax:** `./add_netskope_users.sh <TENANT_FQDN> <API_TOKEN> <CSV_FILE>`

**Example:** `./add_netskope_users.sh example.goskope.com abc123def456ghi789jk users.csv`

### PowerShell Version
**Syntax:** `./add_netskope_users.ps1 <TENANT_FQDN> <API_TOKEN> <CSV_FILE>`

**Example:** `./add_netskope_users.ps1 example.goskope.com abc123def456ghi789jk users.csv`

## License
Licensed under MIT — free to use, modify, and share, with no warranty.

## Disclaimer
This project is **not affiliated with or supported by Netskope**. It may be incomplete, outdated, or inaccurate. Use at your own risk.
