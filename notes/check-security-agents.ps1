# check-security-agents.ps1 -- scan proses/service/software yang berjalan
# di PC ini buat cari jejak antivirus/EDR korporat (yang sering TIDAK
# menulis ke Windows Event Log biasa), plus cek resource/process limit
# dari Group Policy atau Remote Desktop Services (RDS) session settings.
# TIDAK mengubah/mematikan apa pun -- cuma membaca & melaporkan.
#
# CARA PAKAI: powershell -ExecutionPolicy Bypass -File notes\check-security-agents.ps1

Write-Host "=== 1. Proses yang sedang berjalan (nama mencurigakan AV/EDR) ===" -ForegroundColor Cyan
$avKeywords = @(
    'crowdstrike', 'csagent', 'csfalcon', 'sentinelone', 'sentinel',
    'cylance', 'carbonblack', 'cb\.exe', 'cbdefense', 'sophos',
    'eset', 'symantec', 'norton', 'mcafee', 'trellix', 'bitdefender',
    'gravityzone', 'trend', 'cortex', 'xdr', 'defender.*atp', 'mde',
    'qualys', 'tanium', 'rapid7', 'insight', 'forcepoint', 'netskope',
    'zscaler', 'druva', 'cyberark', 'harmony', 'checkpoint', 'fortinet',
    'forticlient', 'watchguard', 'cisco.*secure', 'amp\.exe',
    # consumer/SMB AV yang juga sering kepasang di PC kerja/RDP
    'avast', 'avg', 'kaspersky', 'malwarebytes', 'webroot', 'panda',
    'comodo', 'avira', 'f-secure', 'gdata', 'drweb', '360totalsecurity',
    'vipre', 'emsisoft', 'hitmanpro'
)
$avPattern = ($avKeywords -join '|')
$allProcs = Get-Process | Select-Object Name, Id, Path
$suspects = $allProcs | Where-Object { $_.Name -match $avPattern -or ($_.Path -and $_.Path -match $avPattern) }
if ($suspects) {
    Write-Host "DITEMUKAN proses yang cocok pola AV/EDR:" -ForegroundColor Yellow
    $suspects | Format-Table -AutoSize
} else {
    Write-Host "Tidak ada proses yang namanya cocok pola AV/EDR umum." -ForegroundColor Green
}

Write-Host ""
Write-Host "=== 2. Semua proses aktif (daftar lengkap, buat cek manual) ===" -ForegroundColor Cyan
Get-Process | Sort-Object Name | Select-Object Name, Id, @{N='RAM(MB)';E={[math]::Round($_.WorkingSet64/1MB,1)}} | Format-Table -AutoSize

Write-Host ""
Write-Host "=== 3. Windows Services (nama mencurigakan AV/EDR/resource-mgmt) ===" -ForegroundColor Cyan
$svcSuspects = Get-Service | Where-Object {
    $_.Name -match $avPattern -or $_.DisplayName -match $avPattern -or
    $_.DisplayName -match 'endpoint|security agent|protection|guard'
}
if ($svcSuspects) {
    $svcSuspects | Select-Object Name, DisplayName, Status | Format-Table -AutoSize
} else {
    Write-Host "Tidak ada service yang cocok pola AV/EDR umum." -ForegroundColor Green
}

Write-Host ""
Write-Host "=== 4. Installed software (Programs list, cari AV/EDR) ===" -ForegroundColor Cyan
$installed = Get-ItemProperty 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*', `
    'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue |
    Where-Object { $_.DisplayName } | Select-Object DisplayName, DisplayVersion, Publisher
$softwareSuspects = $installed | Where-Object {
    $_.DisplayName -match $avPattern -or $_.Publisher -match $avPattern -or
    $_.DisplayName -match 'endpoint protection|antivirus|security agent'
}
if ($softwareSuspects) {
    $softwareSuspects | Format-Table -AutoSize
} else {
    Write-Host "Tidak ada software terinstall yang cocok pola AV/EDR umum." -ForegroundColor Green
}

Write-Host ""
Write-Host "=== 5. Remote Desktop Services -- batas resource per sesi (kalau ada) ===" -ForegroundColor Cyan
$rdsPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server'
if (Test-Path $rdsPath) {
    Get-ItemProperty $rdsPath -ErrorAction SilentlyContinue |
        Select-Object * -ExcludeProperty PS*, Cim* |
        Format-List
} else {
    Write-Host "Key Terminal Server tidak ditemukan / tidak bisa diakses."
}

Write-Host ""
Write-Host "=== 6. Group Policy -- cek apakah ada GPO aktif (ringkasan) ===" -ForegroundColor Cyan
try {
    gpresult /R 2>&1 | Select-String "Applied Group Policy Objects" -Context 0,15
} catch {
    Write-Host "gpresult gagal dijalankan: $_"
}

Write-Host ""
Write-Host "=== 7. Job Object / CPU rate limit aktif untuk proses saat ini (jarang, tapi kalau ada ini penyebabnya) ===" -ForegroundColor Cyan
Get-CimInstance Win32_Process | Where-Object { $_.Name -match 'python|node|chrome' } |
    Select-Object Name, ProcessId, CreationDate | Format-Table -AutoSize

Write-Host ""
Write-Host "=== SELESAI -- copy semua output di atas dan kirim untuk dianalisis ===" -ForegroundColor Cyan
