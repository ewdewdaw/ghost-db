#Requires -RunAsAdministrator
<#
  Reverse of block-10.68.88.31.ps1 — CLIENT ONLY.
  Removes exactly what the block script added, nothing else:
    1. Both firewall rules (CustomBlock-10.68.88.31-IN/OUT)
    2. Persistent + active blackhole /32 route for 10.68.88.31
  Safe to re-run (warns instead of failing when already clean).
  Run elevated: powershell -ExecutionPolicy Bypass -File .\unblock-10.68.88.31.ps1
#>
$ErrorActionPreference = 'Stop'
$Target      = '10.68.88.31'
$DestPrefix  = "$Target/32"
$RuleIn      = "CustomBlock-$Target-IN"
$RuleOut     = "CustomBlock-$Target-OUT"

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
  ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) { Write-Error 'Must run as Administrator (right-click > Run as administrator).'; exit 1 }

Write-Host "Unblocking $Target (removing client-only block)..."

# --- 1. Firewall rules ---
$removedFw = 0
if ($null -ne (Get-Command Remove-NetFirewallRule -ErrorAction SilentlyContinue)) {
  foreach ($n in @($RuleIn, $RuleOut)) {
    $r = Get-NetFirewallRule -DisplayName $n -ErrorAction SilentlyContinue
    if ($r) { $r | Remove-NetFirewallRule -ErrorAction SilentlyContinue; $removedFw++; Write-Host "Firewall: removed $n" }
    else { Write-Host "Firewall: $n not present (already clean)." }
  }
} else {
  & netsh advfirewall firewall delete rule name="$RuleIn"  | Out-Null
  & netsh advfirewall firewall delete rule name="$RuleOut" | Out-Null
  Write-Host 'Firewall: delete attempted via netsh fallback.'
}

# --- 2. Blackhole route (persistent + active) ---
$removedRoute = 0
if ($null -ne (Get-Command Remove-NetRoute -ErrorAction SilentlyContinue)) {
  foreach ($store in @('PersistentStore', 'ActiveStore')) {
    $rt = Get-NetRoute -DestinationPrefix $DestPrefix -PolicyStore $store -ErrorAction SilentlyContinue
    if ($rt) {
      $rt | Remove-NetRoute -Confirm:$false -ErrorAction SilentlyContinue
      $removedRoute++
      Write-Host "Route: removed $DestPrefix from $store."
    }
  }
  if ($removedRoute -eq 0) { Write-Host "Route: $DestPrefix not present (already clean)." }
} else {
  & route delete $Target 2>$null | Out-Null
  Write-Host 'Route: delete attempted via route.exe fallback.'
}

# --- 3. Verify clean ---
Write-Host '--- verify ---'
$leftFw = Get-NetFirewallRule -DisplayName "$RuleIn", "$RuleOut" -ErrorAction SilentlyContinue
$leftRt = Get-NetRoute -DestinationPrefix $DestPrefix -ErrorAction SilentlyContinue
if ($leftFw) { Write-Warning 'Firewall rule(s) still present:'; $leftFw | Select-Object DisplayName, Direction | Format-Table -AutoSize | Out-String | Write-Host }
else { Write-Host 'Firewall: clean (no block rules).' }
if ($leftRt) { Write-Warning 'Route still present:'; $leftRt | Select-Object DestinationPrefix, NextHop | Format-Table -AutoSize | Out-String | Write-Host }
else { Write-Host 'Route: clean (no blackhole).' }

Write-Host "Done. Block reversed — host is back to pre-block state."
Write-Host 'NOTE: ping to 10.68.88.31 may still fail; that net was already unreachable before blocking (Mullvad-side).'
