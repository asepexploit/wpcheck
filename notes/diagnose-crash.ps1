# diagnose-crash.ps1
#
# Logger diagnostik buat cari akar penyebab wp-check.py crash dengan
# "EPIPE: broken pipe" / "Unhandled 'error' event" di Node.js driver
# Playwright. TIDAK mengubah/mematikan apa pun -- cuma merekam.
#
# CARA PAKAI (di PC kerja / RDP yang sering crash):
#   1. Buka PowerShell BARU (window terpisah dari yang menjalankan wp-check.py).
#   2. Masuk ke folder wpcheck, lalu jalankan:
#         powershell -ExecutionPolicy Bypass -File notes\diagnose-crash.ps1
#      (kalau file ini ditaruh di tempat lain, sesuaikan path-nya)
#   3. Di window LAIN, jalankan wp-check.py seperti biasa dan tunggu sampai
#      crash EPIPE muncul lagi.
#   4. Begitu crash muncul, kembali ke window logger ini, tekan Ctrl+C untuk
#      berhenti merekam.
#   5. Kirim file crash-log-<timestamp>.txt yang dihasilkan (ada di folder
#      yang sama dengan script ini) -- itu yang dianalisis buat cari
#      penyebabnya (Defender kill proses? OOM? proses hang lalu di-kill
#      Windows? dll).
#
# Isi log: setiap detik -- jumlah proses chrome-headless-shell.exe yang
# hidup + RAM totalnya, RAM/CPU sistem, dan setiap kali ada Windows Event
# baru (Application/System log) yang match chrome/node/playwright/wpcheck.

$ErrorActionPreference = 'SilentlyContinue'
$logDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$logFile = Join-Path $logDir "crash-log-$stamp.txt"

Write-Host "Merekam ke: $logFile"
Write-Host "Biarkan window ini terbuka, jalankan wp-check.py di window lain."
Write-Host "Tekan Ctrl+C di sini begitu crash EPIPE muncul lagi."
Write-Host ""

"=== diagnose-crash.ps1 dimulai $(Get-Date -Format o) ===" | Out-File -FilePath $logFile -Encoding utf8

# Titik awal buat Event Viewer -- cuma event SETELAH waktu ini yang direkam,
# biar log tidak penuh histori lama yang tidak relevan.
$startTime = Get-Date
$seenEventRecordIds = New-Object System.Collections.Generic.HashSet[Int64]

function Log($text) {
    $line = "[$( (Get-Date).ToString('HH:mm:ss.fff') )] $text"
    $line | Out-File -FilePath $logFile -Append -Encoding utf8
}

try {
    while ($true) {
        # --- Proses chrome-headless-shell.exe / node.exe / chrome.exe ---
        $procs = Get-Process -Name 'chrome-headless-shell', 'chrome', 'node' -ErrorAction SilentlyContinue
        if ($procs) {
            $count = ($procs | Measure-Object).Count
            $totalMB = [math]::Round((($procs | Measure-Object WorkingSet64 -Sum).Sum) / 1MB, 1)
            Log "procs: $count hidup, total RAM ~${totalMB}MB"
        } else {
            Log "procs: TIDAK ADA proses chrome-headless-shell/chrome/node hidup"
        }

        # --- RAM & CPU sistem ---
        $os = Get-CimInstance Win32_OperatingSystem
        $freeMB = [math]::Round($os.FreePhysicalMemory / 1KB, 0)
        $totalMB = [math]::Round($os.TotalVisibleMemorySize / 1KB, 0)
        $cpuLoad = (Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average
        Log "sistem: RAM free ${freeMB}MB / ${totalMB}MB, CPU load ~${cpuLoad}%"

        # --- Windows Event Log (Application + System), filter chrome/node/playwright/wpcheck ---
        $events = Get-WinEvent -FilterHashtable @{
            LogName   = 'Application', 'System'
            StartTime = $startTime
        } -ErrorAction SilentlyContinue |
            Where-Object {
                $_.Message -match 'chrome|node\.exe|playwright|wpcheck|wp-check'
            }

        foreach ($ev in $events) {
            if ($seenEventRecordIds.Add($ev.RecordId)) {
                Log "EVENT [$($ev.LogName)] Id=$($ev.Id) Level=$($ev.LevelDisplayName) Provider=$($ev.ProviderName)"
                Log "  Time=$($ev.TimeCreated)"
                $msg = ($ev.Message -split "`n" | Select-Object -First 5) -join ' | '
                Log "  Msg: $msg"
            }
        }

        Start-Sleep -Seconds 1
    }
} finally {
    Log "=== diagnose-crash.ps1 dihentikan $(Get-Date -Format o) ==="
    Write-Host ""
    Write-Host "Selesai. Log tersimpan di: $logFile"
    Write-Host "Kirim file itu untuk dianalisis."
}
