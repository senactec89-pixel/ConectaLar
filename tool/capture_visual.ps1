param(
  [string[]]$Scenes = @('home', 'categoria', 'historico', 'admin-documentos', 'admin-denuncias', 'admin-avaliacoes', 'admin-categorias'),
  [int[]]$Widths = @(360, 390, 412),
  [string]$OutputDir = 'docs/evidencias/estilizacao-2026-10-13',
  [string]$BaseUrl = 'http://127.0.0.1:8765/',
  [int]$DebugPort = 9222,
  [int]$WaitSeconds = 5
)

$ErrorActionPreference = 'Stop'
$pages = Invoke-RestMethod -Uri "http://127.0.0.1:$DebugPort/json"
$page = $pages | Where-Object { $_.type -eq 'page' } | Select-Object -First 1
if (-not $page) { throw 'Nenhuma pagina do Chrome com depuracao remota foi encontrada.' }
$socket = [System.Net.WebSockets.ClientWebSocket]::new()
$null = $socket.ConnectAsync([Uri]$page.webSocketDebuggerUrl, [Threading.CancellationToken]::None).GetAwaiter().GetResult()
$script:nextId = 0

function Invoke-Cdp([string]$method, [hashtable]$parameters) {
  $script:nextId++
  $request = @{ id = $script:nextId; method = $method; params = $parameters } | ConvertTo-Json -Depth 10 -Compress
  $payload = [Text.Encoding]::UTF8.GetBytes($request)
  $null = $socket.SendAsync([ArraySegment[byte]]::new($payload), [System.Net.WebSockets.WebSocketMessageType]::Text, $true, [Threading.CancellationToken]::None).GetAwaiter().GetResult()
  do {
    $buffer = New-Object byte[] 65536
    $message = [Text.StringBuilder]::new()
    do {
      $received = $socket.ReceiveAsync([ArraySegment[byte]]::new($buffer), [Threading.CancellationToken]::None).GetAwaiter().GetResult()
      if ($received.MessageType -eq [System.Net.WebSockets.WebSocketMessageType]::Close) { throw 'Chrome fechou a conexao de depuracao.' }
      [void]$message.Append([Text.Encoding]::UTF8.GetString($buffer, 0, $received.Count))
    } until ($received.EndOfMessage)
    $response = $message.ToString() | ConvertFrom-Json
  } until ($response.id -eq $script:nextId)
  if ($response.error) { throw "$method falhou: $($response.error.message)" }
  return $response.result
}

try {
  New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
  Invoke-Cdp 'Page.enable' @{} | Out-Null
  foreach ($width in $Widths) {
    Invoke-Cdp 'Emulation.setDeviceMetricsOverride' @{
      width = $width
      height = 844
      deviceScaleFactor = 1
      mobile = $true
      screenWidth = $width
      screenHeight = 844
    } | Out-Null
    foreach ($scene in $Scenes) {
      $routeScene = $scene -replace '-modal$', '' -replace '-200$', ''
      $scaleQuery = if ($scene.EndsWith('-200')) { '&escala=2' } else { '' }
      $url = "$BaseUrl`?tela=$routeScene$scaleQuery"
      Invoke-Cdp 'Page.navigate' @{ url = $url } | Out-Null
      Start-Sleep -Seconds $WaitSeconds
      if ($scene.EndsWith('-modal')) {
        $y = switch ($routeScene) {
          'admin-documentos' { 235 }
          'admin-denuncias' { 145 }
          'admin-avaliacoes' { 200 }
          default { throw "Cena sem modal configurado: $scene" }
        }
        foreach ($kind in @('mousePressed', 'mouseReleased')) {
          Invoke-Cdp 'Input.dispatchMouseEvent' @{
            type = $kind
            x = [int]($width / 2)
            y = $y
            button = 'left'
            clickCount = 1
          } | Out-Null
        }
        Start-Sleep -Seconds 1
      }
      for ($attempt = 0; $attempt -lt 3; $attempt++) {
        $capture = Invoke-Cdp 'Page.captureScreenshot' @{
          format = 'png'
          fromSurface = $true
          captureBeyondViewport = $false
        }
        $imageBytes = [Convert]::FromBase64String($capture.data)
        if ($imageBytes.Length -ge 10000) { break }
        Start-Sleep -Seconds 2
      }
      if ($imageBytes.Length -lt 10000) { throw "Captura vazia: $scene em $width px" }
      $path = Join-Path $OutputDir "$scene-$width.png"
      [IO.File]::WriteAllBytes([IO.Path]::GetFullPath($path), $imageBytes)
      Write-Output $path
    }
  }
} finally {
  $socket.Dispose()
}
