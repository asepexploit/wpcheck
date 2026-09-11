# downgrade-playwright.ps1 -- turunkan Playwright ke 1.57.0 (versi yang
# terbukti stabil di PC dev, tidak pernah kena EPIPE/Node-driver-crash)
# buat TES apakah versi Playwright/Chromium yang lebih baru (1.62.0 /
# Chromium 151.x) memang penyebab crash di PC ini.
#
# CARA PAKAI: powershell -ExecutionPolicy Bypass -File notes\downgrade-playwright.ps1
# Setelah selesai, jalankan wp-check.py seperti biasa dan lihat apakah
# crash EPIPE masih muncul atau tidak.

Write-Host "=== Uninstall Playwright versi sekarang ==="
python -m pip uninstall -y playwright

Write-Host ""
Write-Host "=== Install Playwright 1.57.0 ==="
python -m pip install "playwright==1.57.0"

Write-Host ""
Write-Host "=== Download Chromium yang sesuai versi 1.57.0 ==="
python -m playwright install chromium

Write-Host ""
Write-Host "=== Verifikasi versi setelah downgrade ==="
python -m pip show playwright | Select-String "Version"
python -c "import json, os, playwright; d = os.path.join(os.path.dirname(playwright.__file__), 'driver', 'package', 'package.json'); data = json.load(open(d)); print('playwright-core:', data.get('version'))"

Write-Host ""
Write-Host "Selesai. Sekarang jalankan wp-check.py seperti biasa dan lihat apakah crash EPIPE masih muncul."
