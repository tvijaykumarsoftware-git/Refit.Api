# Must be run as Administrator
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
    Write-Error "This script must be run as Administrator. Open PowerShell as Administrator and re-run."
    exit 1
}

# Get current account identity (use exact form whoami returns)
$acct = (whoami).Trim()
if ([string]::IsNullOrWhiteSpace($acct)) {
    Write-Error "Unable to determine current account (whoami returned empty)."
    exit 1
}

Write-Host "Account detected: $acct"

# Ensure docker-users group exists
if (-not (Get-LocalGroup -Name 'docker-users' -ErrorAction SilentlyContinue)) {
    try {
        New-LocalGroup -Name 'docker-users' -ErrorAction Stop
        Write-Host "Created local group 'docker-users'."
    } catch {
        Write-Warning "New-LocalGroup failed or not available; attempting legacy net command..."
        net localgroup docker-users /add
    }
} else {
    Write-Host "Local group 'docker-users' already exists."
}

# Add user to docker-users (try modern cmdlet first, fallback to net)
$added = $false
try {
    Add-LocalGroupMember -Group 'docker-users' -Member $acct -ErrorAction Stop
    Write-Host "Added $acct to docker-users (Add-LocalGroupMember)."
    $added = $true
} catch {
    Write-Warning "Add-LocalGroupMember failed: $_. Trying 'net localgroup' fallback..."
    $quoted = $acct
    net localgroup docker-users "$quoted" /add
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Added $acct to docker-users (net localgroup)."
        $added = $true
    } else {
        Write-Error "Failed to add $acct to docker-users via net localgroup (exit code $LASTEXITCODE)."
    }
}

# Show resulting group membership
Write-Host "`nCurrent docker-users group members:"
try {
    Get-LocalGroupMember -Name 'docker-users' -ErrorAction Stop | ForEach-Object { $_.Name }
} catch {
    net localgroup docker-users
}

if ($added) {
    Write-Host "`nSuccess: You must sign out and sign back in (or restart) for the new group membership to take effect."
    exit 0
} else {
    Write-Error "`nThe script could not add the account to docker-users. If you use a Microsoft/AD account, use the exact whoami output and try the net localgroup command manually."
    exit 2
}