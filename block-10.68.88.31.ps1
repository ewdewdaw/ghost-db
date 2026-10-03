#Requires -RunAsAdministrator
<#
  Block 10.68.88.31 — CLIENT ONLY.
  No ARP spoofing, no gateway/LAN changes, no promiscuous mode.
  Does: Windows Defender Firewall block (In+Out, all protocols, all profiles)
       + persistent blackhole /32 route so packets die locally even with FW off.
  Run elevated: powershell -ExecutionPolicy Bypass -File .\block-10.68.88.31.ps1
#>
$ErrorActionPreference = 'Stop'
$Target      = '10.68.88.31'
$DestPrefix  = "$Target/32"
$RuleIn      = "CustomBlock-$Target-IN"
$RuleOut     = "CustomBlock-$Target-OUT"

# --- admin check (belt + suspenders behind #Requires) ---
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
  ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) { Write-Error 'Must run as Administrator (right-click > Run as administrator).'; exit 1 }

Write-Host "Blocking $Target (client-only: firewall + null route)..."

# --- 1. Firewall rules (idempotent: remove ours first) ---
function Remove-OurRule([string]$Name) {
  Get-NetFirewallRule -DisplayName $Name -ErrorAction SilentlyContinue | Remove-NetFirewallRule -ErrorAction SilentlyContinue
}

$haveCmdlets = $null -ne (Get-Command New-NetFirewallRule -ErrorAction SilentlyContinue)

if ($haveCmdlets) {
  Remove-OurRule $RuleIn
  Remove-OurRule $RuleOut
  New-NetFirewallRule -DisplayName $RuleIn  -Direction Inbound  -RemoteAddress $Target `
    -Protocol Any -Action Block -Profile Any -Enabled True -EdgeTraversalPolicy Block | Out-Null
  New-NetFirewallRule -DisplayName $RuleOut -Direction Outbound -RemoteAddress $Target `
    -Protocol Any -Action Block -Profile Any -Enabled True -EdgeTraversalPolicy Block | Out-Null
  Write-Host 'Firewall: inbound + outbound block rules added (Protocol Any, all profiles).'
} else {
  # Fallback for Win7-era hosts without NetSecurity module
  & netsh advfirewall firewall delete rule name="$RuleIn"  | Out-Null
  & netsh advfirewall firewall delete rule name="$RuleOut" | Out-Null
  & netsh advfirewall firewall add rule name="$RuleIn"  dir=in  action=block remoteip=$Target protocol=any profile=any enable=yes | Out-Null
  & netsh advfirewall firewall add rule name="$RuleOut" dir=out action=block remoteip=$Target protocol=any profile=any enable=yes | Out-Null
  Write-Host 'Firewall: rules added via netsh fallback.'
}

# --- 2. Persistent blackhole /32 route (idempotent) ---
# Sends $Target to loopback so it dies on this host. Client-only, no LAN effect.
$routeCmdlets = $null -ne (Get-Command New-NetRoute -ErrorAction SilentlyContinue)
if ($routeCmdlets) {
  Get-NetRoute -DestinationPrefix $DestPrefix -PolicyStore PersistentStore -ErrorAction SilentlyContinue |
    Remove-NetRoute -Confirm:$false -ErrorAction SilentlyContinue
  Get-NetRoute -DestinationPrefix $DestPrefix -PolicyStore ActiveStore -ErrorAction SilentlyContinue |
    Remove-NetRoute -Confirm:$false -ErrorAction SilentlyContinue
  $loopIf = (Get-NetRoute -DestinationPrefix '127.0.0.0/8' -ErrorAction SilentlyContinue |
    Select-Object -First 1 -ExpandProperty InterfaceIndex)
  if (-not $loopIf) { $loopIf = 1 }
  New-NetRoute -DestinationPrefix $DestPrefix -InterfaceIndex $loopIf `
    -NextHop 127.0.0.1 -RouteMetric 1 -PolicyStore PersistentStore -ErrorAction Stop | Out-Null
  Write-Host "Route: persistent blackhole $DestPrefix -> 127.0.0.1 (ifIndex $loopIf)."
} else {
  & route delete $Target 2>$null | Out-Null
  & route add -p $Target mask 255.255.255.255 127.0.0.1 metric 1 | Out-Null
  Write-Host "Route: persistent blackhole $Target/32 -> 127.0.0.1 (route.exe fallback)."
}

# --- 3. Verify ---
Write-Host '--- verify ---'
Get-NetFirewallRule -DisplayName "$RuleIn", "$RuleOut" -ErrorAction SilentlyContinue |
  Select-Object DisplayName, Direction, Action, Enabled, Profile | Format-Table -AutoSize | Out-String | Write-Host
Get-NetRoute -DestinationPrefix $DestPrefix -ErrorAction SilentlyContinue |
  Select-Object DestinationPrefix, NextHop, InterfaceIndex, RouteMetric | Format-Table -AutoSize | Out-String | Write-Host

$pingOk = Test-Connection -ComputerName $Target -Count 2 -Quiet -ErrorAction SilentlyContinue
if ($pingOk) { Write-Warning "Ping to $Target still replies — firewall/route may not have applied yet." }
else { Write-Host "Ping to $Target fails (expected = blocked)." }

Write-Host "Done. $Target is blocked client-side. Reverse with .\\unblock-$Target.ps1"
