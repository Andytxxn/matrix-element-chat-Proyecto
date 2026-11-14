# Plataforma de mensajería instantánea con Matrix + Element

Proyecto de Computación en la Nube.

**Integrantes:** Andrea Torres · Andrés Valdivieso

## Componentes
- **Synapse**: servidor Matrix (usuarios, salas, mensajes)
- **PostgreSQL**: base de datos
- **Element Web**: cliente web para chatear
- **Caddy**: proxy inverso con HTTPS automático

## Inicialización por primera vez (Entorno Local en 1 PC)

Antes de levantar los contenedores por primera vez, cada integrante debe generar en su máquina los archivos locales que están ignorados en Git por seguridad:

1. **Variables de entorno (`.env`)**
   Crea una copia de `.env.example` llamada `.env`. Puedes colocar los dominios locales (terminados en `.localhost`) y la contraseña de base de datos que prefieras. Por ejemplo:
   ```env
   MATRIX_DOMAIN=matrix.localhost
   ELEMENT_DOMAIN=chat.localhost
   POSTGRES_PASSWORD=tu_contrasena_segura
   ```

2. **Configuración de Element (`element/config.json`)**
   Crea una copia de `element/config.template.json` llamada `element/config.json` y reemplaza `__MATRIX_DOMAIN__` por el mismo dominio de Matrix que definiste en tu `.env` (ej. `matrix.localhost`).

3. **Generar configuración de Synapse (`data/synapse/homeserver.yaml`)**
   Ejecuta el generador de Synapse indicando en `SYNAPSE_SERVER_NAME` el dominio de Matrix que elegiste:
   ```bash
   docker compose run --rm --no-deps -e SYNAPSE_SERVER_NAME=matrix.localhost -e SYNAPSE_REPORT_STATS=no synapse generate
   ```

4. **Conectar PostgreSQL y habilitar registro (`data/synapse/homeserver.yaml`)**
   Abre el archivo generado `data/synapse/homeserver.yaml` y reemplaza la sección `database:` (que viene en SQLite por defecto) por PostgreSQL, asegurándote de colocar en `password` la misma contraseña que pusiste en tu `.env`:
   ```yaml
   database:
     name: psycopg2
     args:
       user: synapse
       password: tu_contrasena_segura
       database: synapse
       host: postgres
       cp_min: 5
       cp_max: 10
   ```
   Además, agrega estas dos líneas al final del archivo (sin espacios al inicio) para permitir registrar usuarios directamente desde Element:
   ```yaml
   enable_registration: true
   enable_registration_without_verification: true
   ```

5. **Levantar la plataforma**
   ```bash
   docker compose up -d
   ```

## Acceso desde otros dispositivos en la misma red (LAN / Wi-Fi)

Los dominios `.localhost` solo resuelven dentro de la misma computadora. Si se desea acceder al chat desde celulares u otras laptops conectadas a la misma red Wi-Fi/LAN, sigue estos pasos usando `nip.io`:

1. **Obtener la IP local de la PC anfitriona (Windows PowerShell)**
   ```powershell
   (Get-NetIPConfiguration | Where-Object { $_.IPv4DefaultGateway -ne $null }).IPv4Address.IPAddress
   ```
   *(Ejemplo de IP obtenida: `192.168.1.50`)*

2. **Actualizar dominios con `nip.io` en `.env` y `element/config.json`**
   - En `.env`:
     ```env
     MATRIX_DOMAIN=matrix.192.168.1.50.nip.io
     ELEMENT_DOMAIN=chat.192.168.1.50.nip.io
     POSTGRES_PASSWORD=tu_contrasena_segura
     ```
   - En `element/config.json` (manteniendo `server_name` igual al usado al generar `homeserver.yaml`, y actualizando `base_url`):
     ```json
     "m.homeserver": {
       "base_url": "[https://matrix.192.168.1.50.nip.io](https://matrix.192.168.1.50.nip.io)",
       "server_name": "matrix.localhost"
     }
     ```

3. **Abrir los puertos 80 y 443 en el Firewall de Windows**
   Ejecuta en PowerShell para permitir que otros dispositivos de la red entren a Caddy:
   ```powershell
   Start-Process powershell -Verb RunAs -ArgumentList '-Command "New-NetFirewallRule -DisplayName \"Matrix Caddy\" -Direction Inbound -LocalPort 80,443 -Protocol TCP -Action Allow"'
   ```

4. **Recrear contenedores y acceder**
   ```bash
   docker compose up -d --force-recreate
   ```
   En el navegador del otro dispositivo (o celular), ingresa primero a `https://matrix.<TU_IP>.nip.io/_matrix/client/versions` para aceptar el certificado local, y luego entra a `https://chat.<TU_IP>.nip.io`.

## Plan de trabajo
- [x] Repositorio y estructura base
- [x] Configuración e inicialización local y en red LAN
- [x] Desplegar los servicios con Docker
- [ ] Pruebas
- [ ] Informe