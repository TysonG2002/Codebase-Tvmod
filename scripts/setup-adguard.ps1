# Installs AdGuard Home on Windows and loads the LG TV blocklist.
# Run in PowerShell as Administrator, from the repo folder:
#   powershell -ExecutionPolicy Bypass -File scripts\setup-adguard.ps1
$ErrorActionPreference = "Stop"

$RepoDir    = Split-Path $PSScriptRoot -Parent
$List       = Join-Path $RepoDir "blocklist\lg-webos-ads.txt"
$InstallDir = "C:\AdGuardHome"
$Api        = "http://127.0.0.1:3000"

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) { Write-Host "Please run PowerShell as Administrator."; exit 1 }

$AdminUser = Read-Host "Choose an AdGuard admin username"
$SecPass   = Read-Host "Choose an AdGuard admin password (8+ characters)" -AsSecureString
$AdminPass = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecPass))

if (-not (Test-Path "$InstallDir\AdGuardHome.exe")) {
  Write-Host "Downloading AdGuard Home..."
  $arch = if ($env:PROCESSOR_ARCHITECTURE -eq "ARM64") { "arm64" } else { "amd64" }
  $zip  = Join-Path $env:TEMP "AdGuardHome.zip"
  Invoke-WebRequest "https://static.adguard.com/adguardhome/release/AdGuardHome_windows_$arch.zip" -OutFile $zip
  Expand-Archive $zip -DestinationPath "C:\" -Force
  Remove-Item $zip
  & "$InstallDir\AdGuardHome.exe" -s install
  Start-Sleep 3
}

# Let the TV reach this computer for DNS and the dashboard.
if (-not (Get-NetFirewallRule -DisplayName "AdGuard Home" -ErrorAction SilentlyContinue)) {
  New-NetFirewallRule -DisplayName "AdGuard Home" -Direction Inbound -Protocol UDP -LocalPort 53 -Action Allow -Profile Private | Out-Null
  New-NetFirewallRule -DisplayName "AdGuard Home TCP" -Direction Inbound -Protocol TCP -LocalPort 53,3000 -Action Allow -Profile Private | Out-Null
}

Write-Host "Configuring..."
$setup = @{ web = @{ ip = "0.0.0.0"; port = 3000 }; dns = @{ ip = "0.0.0.0"; port = 53 }; username = $AdminUser; password = $AdminPass } | ConvertTo-Json
try { Invoke-RestMethod -Method Post -Uri "$Api/control/install/configure" -ContentType "application/json" -Body $setup | Out-Null }
catch { Write-Host "(Already configured; skipping first-run setup.)" }
Start-Sleep 2

$login = @{ name = $AdminUser; password = $AdminPass } | ConvertTo-Json
Invoke-RestMethod -Method Post -Uri "$Api/control/login" -ContentType "application/json" -Body $login -SessionVariable s | Out-Null

$rules = Get-Content $List | Where-Object { $_ -notmatch '^\s*(#|$)' } | ForEach-Object { "||$($_.Trim())^" }
$body  = @{ rules = @($rules) } | ConvertTo-Json
Invoke-RestMethod -Method Post -Uri "$Api/control/filtering/set_rules" -ContentType "application/json" -Body $body -WebSession $s | Out-Null

$ip = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.PrefixOrigin -in "Dhcp","Manual" -and $_.IPAddress -notlike "169.*" } | Select-Object -First 1).IPAddress
Write-Host ""
Write-Host "Done. AdGuard Home is running and blocking LG ads."
Write-Host "  Dashboard:  http://${ip}:3000"
Write-Host "  On the TV:  Settings > General > Network > (Wired or Wi-Fi) > Edit > DNS = $ip"
