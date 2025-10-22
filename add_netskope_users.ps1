<#
.SYNOPSIS
  Bulk-adds users to Netskope via SCIM API (PowerShell version).
.EXAMPLE
  PS> .\add_netskope_users.ps1 example.goskope.com 'abc123def456ghi789jk' '.\users.csv'
#>

param (
    [Parameter(Mandatory = $true)] [string] $TenantFQDN,
    [Parameter(Mandatory = $true)] [string] $ApiToken,
    [Parameter(Mandatory = $true)] [string] $CsvFile
)

# Allow self-signed certs (PowerShell 5.x safe)
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$ApiUrl = "https://$TenantFQDN/api/v2/scim/Users"

if (-not (Test-Path $CsvFile)) {
    Write-Host "Error: CSV file '$CsvFile' not found."
    exit 1
}

# Check for non-empty CSV
$nonEmpty = Get-Content $CsvFile | Where-Object { $_.Trim() -ne "" }
if (-not $nonEmpty) {
    Write-Host "No users found in CSV file. Nothing to process."
    exit 0
}

Write-Host "------------------------------------------------------------"
Write-Host "Processing $CsvFile"
Write-Host "Netskope tenant: $TenantFQDN"
Write-Host "------------------------------------------------------------"

$userCount = 0
$addedCount = 0
$existsCount = 0
$errorCount = 0
$skippedCount = 0
$lineNumber = 0

Get-Content $CsvFile | ForEach-Object {
    $lineNumber++
    $line = $_.Trim()
    if ([string]::IsNullOrWhiteSpace($line)) {
        Write-Host ("Skipping line ${lineNumber}: blank or whitespace only.")
        $skippedCount++
        Write-Host "------------------------------------------------------------"
        return
    }

    $fields = $line.Split(',').ForEach({ $_.Trim() })
    if ($fields.Count -lt 3) {
        Write-Host ("Skipping line ${lineNumber}: malformed CSV -> '$line'")
        $skippedCount++
        Write-Host "------------------------------------------------------------"
        return
    }

    $email, $first, $last = $fields[0], $fields[1], $fields[2]
    if ([string]::IsNullOrWhiteSpace($email) -or
        [string]::IsNullOrWhiteSpace($first) -or
        [string]::IsNullOrWhiteSpace($last)) {

        Write-Host ("Skipping line ${lineNumber}: invalid or missing fields -> '$email,$first,$last'")
        $skippedCount++
        Write-Host "------------------------------------------------------------"
        return
    }

    $userCount++
    Write-Host "Adding user: $email ($first $last)"

    $payload = @{
        active  = $true
        emails  = @(@{ primary = $true; value = $email })
        meta    = @{ resourceType = "User" }
        name    = @{ familyName = $last; givenName = $first }
        schemas = @(
            "urn:ietf:params:scim:schemas:core:2.0:User",
            "urn:ietf:params:scim:schemas:extension:enterprise:2.0:User",
            "urn:ietf:params:scim:schemas:extension:tenant:2.0:User"
        )
        userName = $email
    } | ConvertTo-Json -Depth 5

    try {
        $response = Invoke-RestMethod -Uri $ApiUrl `
            -Method Post `
            -Headers @{
                "Authorization" = "Bearer $ApiToken"
                "accept"        = "application/scim+json;charset=utf-8"
                "Content-Type"  = "application/scim+json;charset=utf-8"
            } `
            -Body $payload `
            -ErrorAction Stop

        Write-Host "User added successfully."
        $addedCount++
    }
    catch [System.Net.WebException] {
        $resp = $_.Exception.Response
        if ($resp) {
            $status = [int]$resp.StatusCode
            switch ($status) {
                201 { Write-Host "User added successfully."; $addedCount++ }
                409 { Write-Host "User already exists."; $existsCount++ }
                400 { Write-Host "Invalid request. Check CSV format."; $errorCount++ }
                401 { Write-Host "Authentication failed. Invalid or expired API token."; $errorCount++ }
                403 { Write-Host "Authentication failed. Invalid or expired API token."; $errorCount++ }
                default {
                    Write-Host "Unexpected error ($status):"
                    try {
                        $reader = New-Object IO.StreamReader($resp.GetResponseStream())
                        $body = $reader.ReadToEnd()
                        Write-Host $body
                    } catch {}
                    $errorCount++
                }
            }
        } else {
            Write-Host "Unexpected error: $($_.Exception.Message)"
            $errorCount++
        }
    }

    Write-Host "------------------------------------------------------------"
}

if ($userCount -eq 0 -and $skippedCount -gt 0) {
    Write-Host "No valid user entries found in the CSV file."
    exit 0
}

Write-Host "Summary:"
Write-Host "  Tenant:               $TenantFQDN"
Write-Host "  Total Users:          $userCount"
Write-Host "  Added:                $addedCount"
Write-Host "  Pre-existing Users:   $existsCount"
Write-Host "  Errors:               $errorCount"
Write-Host "  Invalid Entries:      $skippedCount"
