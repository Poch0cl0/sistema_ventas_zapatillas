param(
    [string]$Serial,
    [string]$AdbPath
)

$ErrorActionPreference = 'Stop'
if (-not $AdbPath) {
    $adbCommand = Get-Command adb -ErrorAction SilentlyContinue
    if ($adbCommand) { $AdbPath = $adbCommand.Source }
    else {
        $candidates = @(
            'D:\Android\sdk\platform-tools\adb.exe',
            (Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe')
        )
        $AdbPath = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    }
}
if (-not $AdbPath -or -not (Test-Path -LiteralPath $AdbPath)) {
    throw 'No se encontro adb. Usa -AdbPath con la ruta a adb.exe.'
}
$adbArguments = @()
if ($Serial) { $adbArguments += @('-s', $Serial) }
& $AdbPath @adbArguments get-state
if ($LASTEXITCODE -ne 0) {
    throw 'Conecta y autoriza el celular. Con varios dispositivos indica -Serial.'
}
& $AdbPath @adbArguments reverse tcp:3000 tcp:3000
if ($LASTEXITCODE -ne 0) { throw 'No se pudo crear el tunel USB al puerto 3000.' }
& $AdbPath @adbArguments reverse --list
if ($LASTEXITCODE -ne 0) { throw 'No se pudo consultar el tunel USB.' }
Write-Host 'Tunel USB configurado. Abre la app y pulsa Reintentar.'
Write-Host 'El backend debe seguir ejecutandose en el puerto 3000. Este script no lo inicia.'
