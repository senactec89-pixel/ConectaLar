param(
  [string]$Email = "conectalar.suporte@gmail.com",
  [string]$FromName = "ConectaLar",
  [switch]$Help
)

$ErrorActionPreference = "Stop"

if ($Help) {
  Write-Host "Uso:"
  Write-Host "  .\scripts\configurar-email-local.ps1"
  Write-Host "  scripts\configurar-email-local.cmd"
  Write-Host ""
  Write-Host "Opcoes:"
  Write-Host "  -Email conectalar.suporte@gmail.com"
  Write-Host "  -FromName ConectaLar"
  exit 0
}

$apiDir = Resolve-Path (Join-Path $PSScriptRoot "..")
$envPath = Join-Path $apiDir ".env.local"

Write-Host "Configuracao local de e-mail do ConectaLar"
Write-Host "O arquivo criado fica em apps/api/.env.local e nao deve ser commitado."
Write-Host ""

$securePassword = Read-Host "Cole a senha de aplicativo do Gmail" -AsSecureString
$bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
try {
  $password = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
} finally {
  [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
}

$password = ($password -replace "\s", "").Trim()
if ($password -notmatch "^[A-Za-z]{16}$") {
  throw "Senha de aplicativo invalida. Depois de remover espacos, ela deve ter exatamente 16 letras."
}

$content = @(
  "# Configuracao local. Nao commitar.",
  "SMTP_HOST=smtp.gmail.com",
  "SMTP_PORT=587",
  "SMTP_SECURE=false",
  "SMTP_STARTTLS=true",
  "SMTP_USER=$Email",
  "SMTP_PASSWORD=$password",
  "SMTP_FROM=$FromName <$Email>",
  "APP_PASSWORD_RESET_URL=conectalar://recuperar-senha"
)

Set-Content -Path $envPath -Value $content -Encoding UTF8
Write-Host ""
Write-Host "Configuracao salva em $envPath"
Write-Host "Agora rode: npm.cmd run email:test -- seu-email-de-teste@gmail.com"
