#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# Usage: ./add_netskope_users.sh <TENANT_FQDN> <API_TOKEN> <CSV_FILE>
# Example: ./add_netskope_users.sh example.goskope.com abc123def456ghi789jk users.csv
# CSV format: email,first_name,last_name
# ---------------------------------------------------------------------------

if [[ $# -ne 3 ]]; then
  echo "Usage: $0 <TENANT_FQDN> <API_TOKEN> <CSV_FILE>"
  exit 1
fi

TENANT_FQDN="$1"
API_TOKEN="$2"
CSV_FILE="$3"
API_URL="https://${TENANT_FQDN}/api/v2/scim/Users"

if [[ ! -f "$CSV_FILE" ]]; then
  echo "Error: CSV file '$CSV_FILE' not found."
  exit 1
fi

# Check for non-empty CSV content
valid_lines=$(grep -Ev '^[[:space:]]*$' "$CSV_FILE" | wc -l | tr -d ' ' || true)
if [[ -z "$valid_lines" || "$valid_lines" -eq 0 ]]; then
  echo "No users found in CSV file. Nothing to process."
  exit 0
fi

echo "------------------------------------------------------------"
echo "Processing $CSV_FILE"
echo "Netskope tenant: $TENANT_FQDN"
echo "------------------------------------------------------------"

user_count=0
added_count=0
exists_count=0
error_count=0
skipped_count=0
line_number=0

# Read each line
while IFS=',' read -r email first last || [[ -n "$email" ]]; do
  line_number=$((line_number + 1))
  email=$(echo "$email" | xargs)
  first=$(echo "$first" | xargs)
  last=$(echo "$last" | xargs)

  # Skip blank or invalid lines, but report them
  if [[ -z "$email" || -z "$first" || -z "$last" ]]; then
    echo "Skipping line $line_number: invalid or missing fields -> '$email,$first,$last'"
    skipped_count=$((skipped_count + 1))
    echo "------------------------------------------------------------"
    continue
  fi

  user_count=$((user_count + 1))
  echo "Adding user: $email ($first $last)"

  payload=$(cat <<EOF
{
  "active": true,
  "emails": [
    {
      "primary": true,
      "value": "$email"
    }
  ],
  "meta": {
    "resourceType": "User"
  },
  "name": {
    "familyName": "$last",
    "givenName": "$first"
  },
  "schemas": [
    "urn:ietf:params:scim:schemas:core:2.0:User",
    "urn:ietf:params:scim:schemas:extension:enterprise:2.0:User",
    "urn:ietf:params:scim:schemas:extension:tenant:2.0:User"
  ],
  "userName": "$email"
}
EOF
)

  response=$(mktemp)
  http_code=$(curl -sk -w "%{http_code}" -o "$response" -X POST "$API_URL" \
    -H "accept: application/scim+json;charset=utf-8" \
    -H "Authorization: Bearer $API_TOKEN" \
    -H "Content-Type: application/scim+json;charset=utf-8" \
    -d "$payload")

  case "$http_code" in
    201)
      echo "User added successfully."
      added_count=$((added_count + 1))
      ;;
    409)
      echo "User already exists."
      exists_count=$((exists_count + 1))
      ;;
    400)
      echo "Invalid request. Check CSV format."
      jq -r '.detail? // "No details"' < "$response" 2>/dev/null || cat "$response"
      error_count=$((error_count + 1))
      ;;
    401|403)
      echo "Authentication failed. Invalid or expired API token."
      error_count=$((error_count + 1))
      ;;
    *)
      echo "Unexpected error ($http_code):"
      cat "$response"
      error_count=$((error_count + 1))
      ;;
  esac

  rm -f "$response"
  echo "------------------------------------------------------------"
done < "$CSV_FILE"

if [[ "$user_count" -eq 0 && "$skipped_count" -gt 0 ]]; then
  echo "No valid user entries found in the CSV file."
  exit 0
fi

echo "Summary:"
printf "  %-20s %s\n" "Tenant:" "$TENANT_FQDN"
printf "  %-20s %s\n" "Total Users:" "$user_count"
printf "  %-20s %s\n" "Added:" "$added_count"
printf "  %-20s %s\n" "Pre-existing Users:" "$exists_count"
printf "  %-20s %s\n" "Errors:" "$error_count"
printf "  %-20s %s\n" "Invalid Entries:" "$skipped_count"
