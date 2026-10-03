# Lock-Registries.ps1
# Locks wallpaper / personalization / settings policies.
# Run as Administrator (needed for HKLM).

$ErrorActionPreference = 'Continue'

# ---------- Values to SET (lock) ----------
# Format: Hive, Path, Name, Value, Type
$lockRegs = @(
    # --- HKCU System policies ---
    @{H='HKCU';P='Software\Microsoft\Windows\CurrentVersion\Policies\System';N='Wallpaper';           V=''; D='String'}
    @{H='HKCU';P='Software\Microsoft\Windows\CurrentVersion\Policies\System';N='WallpaperStyle';      V='0'; D='String'}
    @{H='HKCU';P='Software\Microsoft\Windows\CurrentVersion\Policies\System';N='NoDispBackgroundPage';V=1;  D='DWord'}

    # --- HKCU ActiveDesktop ---
    @{H='HKCU';P='Software\Microsoft\Windows\CurrentVersion\Policies\ActiveDesktop';N='NoChangingWallPaper';   V=1; D='DWord'}
    @{H='HKCU';P='Software\Microsoft\Windows\CurrentVersion\Policies\ActiveDesktop';N='NoActiveDesktopChanges';V=1; D='DWord'}

    # --- HKCU Explorer ---
    @{H='HKCU';P='Software\Microsoft\Windows\CurrentVersion\Policies\Explorer';N='NoThemesTab';           V=1; D='DWord'}
    @{H='HKCU';P='Software\Microsoft\Windows\CurrentVersion\Policies\Explorer';N='SettingsPageVisibility';V='hide:personalization'; D='String'}

    # --- HKLM System policies ---
    @{H='HKLM';P='SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System';N='Wallpaper';      V=''; D='String'}
    @{H='HKLM';P='SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System';N='WallpaperStyle'; V='0'; D='String'}

    # --- HKLM ActiveDesktop ---
    @{H='HKLM';P='SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\ActiveDesktop';N='NoChangingWallPaper';   V=1; D='DWord'}
    @{H='HKLM';P='SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\ActiveDesktop';N='NoActiveDesktopChanges';V=1; D='DWord'}

    # --- HKLM Explorer ---
    @{H='HKLM';P='SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer';N='SettingsPageVisibility';V='hide:personalization'; D='String'}

    # --- HKCU Personalization ---
    @{H='HKCU';P='Software\Policies\Microsoft\Windows\Personalization';N='DesktopImage';     V=''; D='String'}
    @{H='HKCU';P='Software\Policies\Microsoft\Windows\Personalization';N='DesktopImagePath'; V=''; D='String'}
    @{H='HKCU';P='Software\Policies\Microsoft\Windows\Personalization';N='LockScreenImage';  V=''; D='String'}
    @{H='HKCU';P='Software\Policies\Microsoft\Windows\Personalization';N='Slideshow';        V=0; D='DWord'}
    @{H='HKCU';P='Software\Policies\Microsoft\Windows\Personalization';N='NoLockScreen';     V=1; D='DWord'}

    # --- HKLM Personalization ---
    @{H='HKLM';P='SOFTWARE\Policies\Microsoft\Windows\Personalization';N='DesktopImage';     V=''; D='String'}
    @{H='HKLM';P='SOFTWARE\Policies\Microsoft\Windows\Personalization';N='DesktopImagePath'; V=''; D='String'}
    @{H='HKLM';P='SOFTWARE\Policies\Microsoft\Windows\Personalization';N='LockScreenImage';  V=''; D='String'}
    @{H='HKLM';P='SOFTWARE\Policies\Microsoft\Windows\Personalization';N='Slideshow';        V=0; D='DWord'}
    @{H='HKLM';P='SOFTWARE\Policies\Microsoft\Windows\Personalization';N='NoLockScreen';     V=1; D='DWord'}

    # --- HKLM System (personalization lockdown) ---
    @{H='HKLM';P='SOFTWARE\Policies\Microsoft\Windows\System';N='UserPolicyMode';V=1; D='DWord'}
)

# ---------- Apply the locks ----------
foreach ($r in $lockRegs) {
    $regPath = "$($r.H):\$($r.P)"

    # Create the key path if it doesn't exist
    if (-not (Test-Path $regPath)) {
        try {
            New-Item -Path $regPath -Force -ErrorAction Stop | Out-Null
        } catch {
            Write-Host "Cannot create key: $regPath  ($($_.Exception.Message))" -ForegroundColor Red
            continue
        }
    }

    try {
        New-ItemProperty -Path $regPath -Name $r.N -Value $r.V -PropertyType $r.D -Force -ErrorAction Stop | Out-Null
        Write-Host "Locked: $regPath -> $($r.N) = $($r.V) [$($r.D)]" -ForegroundColor Green
    }
    catch {
        Write-Host "Failed: $regPath -> $($r.N)  ($($_.Exception.Message))" -ForegroundColor Yellow
    }
}

Write-Host "`nAll policies applied. Sign out or restart for changes to take effect." -ForegroundColor Cyan
