# diagnose-crash.ps1
#
# Logger diagnostik buat cari akar penyebab wp-check.py crash dengan
# "EPIPE: broken pipe" / "Unhandled 'error' event" di Node.js driver
# Playwright. TIDAK mengubah/mematikan apa pun -- cuma merekam.
#
# CARA PAKAI (di PC kerja / RDP yang sering crash):
#   1. Buka PowerShell BARU **sebagai Administrator** (klik kanan > Run as
#      administrator) -- WAJIB supaya log Security & Defender/Operational
#      bisa dibaca; tanpa admin, keduanya diam-diam gagal (tidak error,
#      cuma kosong) dan kamu kehilangan bukti paling berharga.
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
# Isi log: tiap 0.5 detik -- jumlah proses chrome-headless-shell.exe yang
# hidup + RAM totalnya, RAM/CPU sistem, dan setiap kali ada Windows Event
# baru yang match chrome/node/playwright/wpcheck DI SALAH SATU log berikut:
# Application, System, Security (audit process-termination -- kalau di-enable
# lewat Group Policy, ini nunjukin SIAPA yang kill proses & Process ID-nya),
# dan Microsoft-Windows-Windows Defender/Operational (log Defender SENDIRI --
# tidak masuk ke Application/System biasa, jadi harus dicek terpisah).

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

# Deteksi PID individual yang hilang antar-tick (bukan cuma total count) --
# kalau banyak PID beda hilang BERSAMAAN dalam 1 tick, itu tanda proses induk
# di-kill (semua child ikut mati serentak), bukan mati wajar satu-satu.
$prevPids = @{}

try {
    while ($true) {
        # --- Proses chrome-headless-shell.exe / node.exe / chrome.exe ---
        $procs = Get-Process -Name 'chrome-headless-shell', 'chrome', 'node' -ErrorAction SilentlyContinue
        $curPids = @{}
        if ($procs) {
            $count = ($procs | Measure-Object).Count
            $totalMB = [math]::Round((($procs | Measure-Object WorkingSet64 -Sum).Sum) / 1MB, 1)
            Log "procs: $count hidup, total RAM ~${totalMB}MB"
            foreach ($p in $procs) { $curPids[$p.Id] = $p.ProcessName }
        } else {
            Log "procs: TIDAK ADA proses chrome-headless-shell/chrome/node hidup"
        }

        if ($prevPids.Count -gt 0) {
            $gone = $prevPids.Keys | Where-Object { -not $curPids.ContainsKey($_) }
            $goneCount = ($gone | Measure-Object).Count
            if ($goneCount -ge 5) {
                Log "!!! MASSAL: $goneCount proses hilang SEKALIGUS di tick ini (PID: $($gone -join ', ')) -- indikasi proses induk di-kill, bukan mati wajar satu-satu"
            }
        }
        $prevPids = $curPids

        # --- RAM & CPU sistem ---
        $os = Get-CimInstance Win32_OperatingSystem
        $freeMB = [math]::Round($os.FreePhysicalMemory / 1KB, 0)
        $totalMB = [math]::Round($os.TotalVisibleMemorySize / 1KB, 0)
        $cpuLoad = (Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average
        Log "sistem: RAM free ${freeMB}MB / ${totalMB}MB, CPU load ~${cpuLoad}%"

        # --- Windows Event Log, filter chrome/node/playwright/wpcheck ---
        # Application + System (crash umum), Security (audit kill proses --
        # kalau audit policy-nya aktif), dan Windows Defender/Operational
        # (log Defender sendiri, terpisah dari Application/System biasa).
        foreach ($logName in @('Application', 'System', 'Security', 'Microsoft-Windows-Windows Defender/Operational')) {
            $events = Get-WinEvent -FilterHashtable @{
                LogName   = $logName
                StartTime = $startTime
            } -ErrorAction SilentlyContinue |
                Where-Object {
                    $_.Message -match 'chrome|node\.exe|playwright|wpcheck|wp-check'
                }

            foreach ($ev in $events) {
                $key = "$logName-$($ev.RecordId)"
                if ($seenEventRecordIds.Add($key)) {
                    Log "EVENT [$logName] Id=$($ev.Id) Level=$($ev.LevelDisplayName) Provider=$($ev.ProviderName)"
                    Log "  Time=$($ev.TimeCreated)"
                    $msg = ($ev.Message -split "`n" | Select-Object -First 5) -join ' | '
                    Log "  Msg: $msg"
                }
            }
        }

        # Event 4689 (proses berhenti) di Security log -- SIAPA yang minta
        # proses berhenti (jarang di-enable default, tapi kalau ada, ini
        # bukti paling langsung). Dicek terpisah karena tidak match filter
        # Message di atas (Message-nya berisi nama exe langsung, bukan kata
        # "chrome" literal kalau path-nya beda casing/format).
        $termEvents = Get-WinEvent -FilterHashtable @{
            LogName = 'Security'; Id = 4689; StartTime = $startTime
        } -ErrorAction SilentlyContinue |
            Where-Object { $_.Message -match 'chrome|node\.exe' }
        foreach ($ev in $termEvents) {
            $key = "Security-4689-$($ev.RecordId)"
            if ($seenEventRecordIds.Add($key)) {
                Log "EVENT [Security] Process Termination (4689):"
                $msg = ($ev.Message -split "`n" | Select-Object -First 8) -join ' | '
                Log "  Msg: $msg"
            }
        }

        Start-Sleep -Milliseconds 500
    }
} finally {
    Log "=== diagnose-crash.ps1 dihentikan $(Get-Date -Format o) ==="
    Write-Host ""
    Write-Host "Selesai. Log tersimpan di: $logFile"
    Write-Host "Kirim file itu untuk dianalisis."
}
