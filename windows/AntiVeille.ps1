\xef\xbb\xbf# AntiVeille - empeche la mise en veille de Windows 11 pendant une duree donnee
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class Native {
    [DllImport("user32.dll")] public static extern void mouse_event(uint dwFlags, int dx, int dy, uint dwData, UIntPtr dwExtraInfo);
    [DllImport("kernel32.dll")] public static extern uint SetThreadExecutionState(uint esFlags);
}
"@

$ES_CONTINUOUS       = [uint32]2147483648
$ES_SYSTEM_REQUIRED  = [uint32]1
$ES_DISPLAY_REQUIRED = [uint32]2
$MOUSEEVENTF_MOVE    = 1

function Parse-Duree([string]$txt) {
    $t = $txt.Trim().ToLower().Replace(' ', '')
    if ($t -match '^(\d+):(\d{1,2})$') { return [int]$Matches[1]*60 + [int]$Matches[2] }
    if ($t -match '^(?:(\d+)h)?(?:(\d+)(?:min|m)?)?$' -and $t -ne '') {
        $h = if ($Matches[1]) { [int]$Matches[1] } else { 0 }
        $m = if ($Matches[2]) { [int]$Matches[2] } else { 0 }
        if ($t -notmatch 'h' ) { return $h*60 + $m }   # "84" = 84 minutes
        return $h*60 + $m
    }
    return $null
}

Clear-Host
Write-Host "=== AntiVeille - garde le PC eveille ===" -ForegroundColor Cyan
Write-Host "Exemples de duree : 1h24min | 1h24 | 2h | 45min | 84 (minutes) | 1:24"
Write-Host ""

$minutes = $null
while (-not $minutes -or $minutes -le 0) {
    $saisie = Read-Host "Combien de temps ?"
    $minutes = Parse-Duree $saisie
    if (-not $minutes -or $minutes -le 0) { Write-Host "Format non reconnu, reessaie." -ForegroundColor Yellow; $minutes = $null }
}

$fin = (Get-Date).AddMinutes($minutes)
Write-Host ""
Write-Host ("Actif pendant {0}h{1:00}min - fin prevue a {2:HH:mm:ss}" -f [math]::Floor($minutes/60), ($minutes % 60), $fin) -ForegroundColor Green
Write-Host "Ctrl+C ou fermer la fenetre pour arreter." -ForegroundColor DarkGray
Write-Host ""

# Bloque la veille (systeme + ecran) en plus du mouvement de souris
[Native]::SetThreadExecutionState($ES_CONTINUOUS -bor $ES_SYSTEM_REQUIRED -bor $ES_DISPLAY_REQUIRED) | Out-Null

try {
    while ((Get-Date) -lt $fin) {
        # petit mouvement de 1 pixel puis retour
        [Native]::mouse_event($MOUSEEVENTF_MOVE, 1, 0, 0, [UIntPtr]::Zero)
        Start-Sleep -Milliseconds 100
        [Native]::mouse_event($MOUSEEVENTF_MOVE, -1, 0, 0, [UIntPtr]::Zero)

        $reste = $fin - (Get-Date)
        Write-Host ("`rTemps restant : {0:00}:{1:00}:{2:00}   " -f [int][math]::Floor($reste.TotalHours), $reste.Minutes, $reste.Seconds) -NoNewline

        # attend 30 s (par pas d'1 s pour mettre a jour le compte a rebours)
        for ($i = 0; $i -lt 30 -and (Get-Date) -lt $fin; $i++) {
            Start-Sleep -Seconds 1
            $reste = $fin - (Get-Date)
            if ($reste.TotalSeconds -lt 0) { break }
            Write-Host ("`rTemps restant : {0:00}:{1:00}:{2:00}   " -f [int][math]::Floor($reste.TotalHours), $reste.Minutes, $reste.Seconds) -NoNewline
        }
    }
    Write-Host "`n`nTermine ! Le PC peut de nouveau se mettre en veille." -ForegroundColor Cyan
}
finally {
    [Native]::SetThreadExecutionState($ES_CONTINUOUS) | Out-Null
}
Start-Sleep -Seconds 3
