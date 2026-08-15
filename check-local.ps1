$ErrorActionPreference = "Continue"

$commands = @("terraform", "aws", "git", "ssh", "code")

Write-Host "=== Local tool check ==="
foreach ($cmd in $commands) {
    $found = Get-Command $cmd -ErrorAction SilentlyContinue
    if ($found) {
        Write-Host "[OK] $cmd -> $($found.Source)"
    } else {
        Write-Host "[MISSING] $cmd"
    }
}

Write-Host ""
Write-Host "=== AWS identity check ==="
try {
    aws sts get-caller-identity
} catch {
    Write-Host "AWS authentication is not configured yet."
}

Write-Host ""
Write-Host "=== Public IP ==="
try {
    $publicIp = (Invoke-RestMethod https://checkip.amazonaws.com).Trim()
    Write-Host "$publicIp/32"
} catch {
    Write-Host "Could not query public IP."
}
