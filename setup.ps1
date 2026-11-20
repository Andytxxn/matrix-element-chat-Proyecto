# setup.ps1 - Despliegue automático de Matrix + Element + Admin + Dozzle
$ErrorActionPreference = "Stop"

Write-Host "=== Asistente de despliegue: Matrix + Element ===" -ForegroundColor Cyan

# 1. Verificar que Docker Desktop esté corriendo
docker info *> $null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Error: Docker Desktop no está corriendo. Ábrelo e intenta de nuevo." -ForegroundColor Red
    exit 1
}

# 2. Detectar IP local y elegir modo de despliegue
$ip = (Get-NetIPConfiguration | Where-Object { $_.IPv4DefaultGateway -ne $null } | Select-Object -First 1).IPv4Address.IPAddress
$modo = Read-Host "¿Desplegar en red local (LAN/Wi-Fi) usando tu IP ($ip)? [S/n]"

if ($modo -eq "n" -or $modo -eq "N") {
    $matrixDomain = "matrix.localhost"
    $elementDomain = "chat.localhost"
}
else {
    $matrixDomain = "matrix.$ip.nip.io"
    $elementDomain = "chat.$ip.nip.io"
}

# 3. Crear o actualizar .env conservando la contraseña de PostgreSQL
if (Test-Path ".env") {
    $envContent = Get-Content ".env"
    $pgPass = ($envContent | Where-Object { $_ -match "^POSTGRES_PASSWORD=" }) -replace "^POSTGRES_PASSWORD=", ""
    Write-Host "Archivo .env detectado. Actualizando dominios y conservando contraseña..." -ForegroundColor Cyan
}
else {
    $pgPass = Read-Host "Ingresa una contraseña para PostgreSQL (Enter para usar 'supersecreto123')"
    if ([string]::IsNullOrWhiteSpace($pgPass)) { $pgPass = "supersecreto123" }
}

@"
MATRIX_DOMAIN=$matrixDomain
ELEMENT_DOMAIN=$elementDomain
POSTGRES_PASSWORD=$pgPass
"@ | Set-Content ".env" -Encoding UTF8

# 4. Generar y configurar homeserver.yaml solo si es la primera vez
$primeraVez = -not (Test-Path "data/synapse/homeserver.yaml")
if ($primeraVez) {
    Write-Host "Primera ejecución detectada. Generando configuración de Synapse..." -ForegroundColor Yellow
    docker compose run --rm --no-deps -e SYNAPSE_SERVER_NAME=matrix.localhost -e SYNAPSE_REPORT_STATS=no synapse generate

    $yamlPath = "data/synapse/homeserver.yaml"
    $yaml = Get-Content $yamlPath -Raw

    # Reemplazar SQLite por PostgreSQL
    $pgBlock = @"
database:
  name: psycopg2
  args:
    user: synapse
    password: $pgPass
    database: synapse
    host: postgres
    cp_min: 5
    cp_max: 10
"@
    $yaml = [regex]::Replace($yaml, "(?ms)^database:\r?\n\s+name:\s+sqlite3.*?database:\s+[^\r\n]+", $pgBlock)

    # Habilitar registro de usuarios
    $yaml += "`nenable_registration: true`nenable_registration_without_verification: true`n"
    Set-Content $yamlPath $yaml -Encoding UTF8
    Write-Host "homeserver.yaml configurado con PostgreSQL y registro habilitado." -ForegroundColor Green
}

# 5. Abrir Firewall en Windows si es modo LAN y no existe la regla
if ($matrixDomain -ne "matrix.localhost") {
    $rule = Get-NetFirewallRule -DisplayName "Matrix Caddy" -ErrorAction SilentlyContinue
    if (-not $rule) {
        Write-Host "Creando regla de Firewall para puertos 80 y 443..." -ForegroundColor Yellow
        Start-Process powershell -Verb RunAs -Wait -ArgumentList '-Command "New-NetFirewallRule -DisplayName \"Matrix Caddy\" -Direction Inbound -LocalPort 80,443 -Protocol TCP -Action Allow"'
    }
}

# 6. Levantar / recrear todos los contenedores
Write-Host "Levantando servicios con Docker Compose..." -ForegroundColor Cyan
docker compose up -d --force-recreate

# 7. Resumen de accesos
Write-Host "`n¡Plataforma desplegada con éxito!" -ForegroundColor Green
Write-Host "--------------------------------------------------"
Write-Host "  Chat (Element):     https://$elementDomain"
Write-Host "  Certificado (/cert): https://$elementDomain/cert"
Write-Host "  Panel Admin:        https://admin.$elementDomain"
Write-Host "    (Homeserver URL): https://$matrixDomain"
Write-Host "  Logs (Dozzle):      https://logs.$elementDomain"
Write-Host "--------------------------------------------------"

if ($primeraVez) {
    Write-Host "`nTip: Para crear tu usuario administrador de Synapse Admin, ejecuta:" -ForegroundColor Yellow
    Write-Host "  docker compose exec synapse register_new_matrix_user http://localhost:8008 -c /data/homeserver.yaml"
}