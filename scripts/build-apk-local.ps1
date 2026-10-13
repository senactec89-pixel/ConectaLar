param(
  [string]$Ip,
  [int]$Port = 3012,
  [switch]$Install
)

$ErrorActionPreference = 'Stop'

function Write-Step($Message) {
  Write-Host ""
  Write-Host "==> $Message" -ForegroundColor Cyan
}

function Get-PreferredIPv4 {
  $addresses = Get-NetIPConfiguration |
    Where-Object { $_.IPv4Address -and $_.NetAdapter.Status -eq 'Up' } |
    ForEach-Object {
      [PSCustomObject]@{
        InterfaceAlias = $_.InterfaceAlias
        IPv4 = $_.IPv4Address.IPAddress
        Gateway = $_.IPv4DefaultGateway.NextHop
      }
    } |
    Where-Object {
      $_.IPv4 -and
      $_.IPv4 -notlike '169.254.*' -and
      $_.IPv4 -notlike '127.*' -and
      $_.InterfaceAlias -notmatch 'VirtualBox|VMware|Hyper-V|Radmin|Loopback|Teredo'
    }

  $withGateway = $addresses | Where-Object { $_.Gateway } | Select-Object -First 1
  if ($withGateway) { return $withGateway.IPv4 }

  $first = $addresses | Select-Object -First 1
  if ($first) { return $first.IPv4 }

  return $null
}

if (-not $Ip) {
  $Ip = Get-PreferredIPv4
  if (-not $Ip) {
    throw 'Nao consegui detectar o IPv4 automaticamente. Informe manualmente: .\scripts\build-apk-local.ps1 -Ip 192.168.x.x'
  }
}

if ($Ip -notmatch '^(\d{1,3}\.){3}\d{1,3}$') {
  throw "IP invalido: $Ip"
}

$apiBaseUrl = "http://${Ip}:${Port}"
$repoRoot = Split-Path -Parent $PSScriptRoot
$apkSource = Join-Path $repoRoot 'build\app\outputs\flutter-apk\app-debug.apk'
$safeIp = $Ip.Replace('.', '-')
$apkDestination = Join-Path $env:USERPROFILE "Downloads\ConectaLar-debug-${safeIp}-${Port}.apk"

Write-Step "Gerando APK para $apiBaseUrl"
Push-Location $repoRoot
try {
  flutter build apk --debug --dart-define="CONECTALAR_API_BASE_URL=$apiBaseUrl"
} finally {
  Pop-Location
}

if (-not (Test-Path -LiteralPath $apkSource)) {
  throw "APK nao encontrado em $apkSource"
}

Copy-Item -LiteralPath $apkSource -Destination $apkDestination -Force
Write-Step "APK pronto"
Write-Host $apkDestination -ForegroundColor Green

Write-Step "Teste rapido antes de abrir o app no celular"
Write-Host "1. No navegador do celular, abra: $apiBaseUrl/health"
Write-Host "2. O esperado e: {`"status`":`"ok`"}"
Write-Host "3. Se abrir no navegador, instale o APK acima."

if ($Install) {
  Write-Step "Instalando via adb"
  adb install -r $apkDestination
}
