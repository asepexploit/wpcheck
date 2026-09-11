# check-versions.ps1 -- cek versi Python/Playwright/Node driver yang lagi
# kepasang di PC ini. Jalankan dari folder wpcheck:
#   powershell -ExecutionPolicy Bypass -File notes\check-versions.ps1

Write-Host "=== Python ==="
python --version

Write-Host ""
Write-Host "=== Playwright (pip) ==="
python -m pip show playwright

Write-Host ""
Write-Host "=== Playwright driver (Node bundled version) ==="
python -c "import json, os, playwright; d = os.path.join(os.path.dirname(playwright.__file__), 'driver', 'package', 'package.json'); data = json.load(open(d)); print('playwright-core:', data.get('version'))"

Write-Host ""
Write-Host "=== Node.js versi yang dipakai driver Playwright ==="
$driverDir = python -c "import os, playwright; print(os.path.join(os.path.dirname(playwright.__file__), 'driver'))"
$nodeExe = Join-Path $driverDir 'node.exe'
if (Test-Path $nodeExe) {
    & $nodeExe --version
} else {
    Write-Host "node.exe tidak ditemukan di $driverDir"
}

Write-Host ""
Write-Host "=== Chromium yang ke-install (playwright install) ==="
python -m playwright install --dry-run chromium 2>&1
