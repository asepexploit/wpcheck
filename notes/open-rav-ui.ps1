# open-rav-ui.ps1 -- cari & buka UI RAV Endpoint Protection (ReasonLabs)
# supaya kamu bisa tambah exclusion/exception buat python.exe & folder
# Chromium Playwright, TANPA mematikan RAV sama sekali (kamu tetap
# terlindungi, cuma proses wp-check.py yang dikecualikan dari scanning).
#
# CARA PAKAI: powershell -ExecutionPolicy Bypass -File notes\open-rav-ui.ps1

Write-Host "=== Mencari lokasi RAV/rsAppUI.exe ===" -ForegroundColor Cyan
$proc = Get-Process -Name 'rsAppUI' -ErrorAction SilentlyContinue | Select-Object -First 1
if ($proc -and $proc.Path) {
    Write-Host "Ketemu (sedang jalan): $($proc.Path)" -ForegroundColor Green
    Write-Host "Membuka UI RAV..."
    Start-Process $proc.Path
} else {
    Write-Host "Proses rsAppUI tidak sedang jalan -- cari file exe-nya di disk..." -ForegroundColor Yellow
    $candidates = @(
        "$env:ProgramFiles\ReasonLabs",
        "${env:ProgramFiles(x86)}\ReasonLabs",
        "$env:ProgramFiles\RAV Endpoint Protection",
        "${env:ProgramFiles(x86)}\RAV Endpoint Protection",
        "$env:ProgramData\ReasonLabs"
    )
    $found = $null
    foreach ($dir in $candidates) {
        if (Test-Path $dir) {
            $exe = Get-ChildItem -Path $dir -Filter 'rsAppUI.exe' -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($exe) { $found = $exe.FullName; break }
        }
    }
    if ($found) {
        Write-Host "Ketemu: $found" -ForegroundColor Green
        Start-Process $found
    } else {
        Write-Host "Tidak ketemu otomatis. Coba manual:" -ForegroundColor Red
        Write-Host "  1. Tekan tombol Windows, ketik 'RAV' atau 'Reason', buka aplikasinya."
        Write-Host "  2. Atau cek system tray (pojok kanan bawah, klik panah '^' show hidden icons)."
        Write-Host "  3. Atau buka folder ini manual di Explorer: $env:ProgramFiles dan ${env:ProgramFiles(x86)}, cari folder ReasonLabs / RAV."
    }
}

Write-Host ""
Write-Host "=== Setelah UI RAV terbuka ===" -ForegroundColor Cyan
Write-Host "Cari menu: Settings / Pengaturan -> Exclusions / Exceptions / Whitelist."
Write-Host "Tambahkan 2 pengecualian:"
Write-Host "  1. File/Program: $env:USERPROFILE\AppData\Local\Python\pythoncore-3.14-64\python.exe"
Write-Host "     (sesuaikan path python.exe yang kamu pakai -- cek dengan: where python)"
Write-Host "  2. Folder: $env:USERPROFILE\AppData\Local\ms-playwright\"
Write-Host "     (ini folder tempat Chromium/chrome-headless-shell.exe Playwright ter-install)"
