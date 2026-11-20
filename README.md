# Plataforma de mensajería instantánea con Matrix + Element

Proyecto de Computación en la Nube.

**Integrantes:** Andrea Torres · Andrés Valdivieso

## Componentes
- **Synapse**: servidor Matrix (usuarios, salas, mensajes)
- **PostgreSQL**: base de datos
- **Element Web**: cliente web para chatear (configuración inyectada dinámicamente desde `.env`)
- **Caddy**: proxy inverso con HTTPS automático y distribución de certificado local (`/cert`)

## Inicialización por primera vez (Entorno Local en 1 PC)

Antes de levantar los contenedores por primera vez, cada integrante debe generar en su máquina los archivos locales ignorados en Git por seguridad:

1. **Variables de entorno (`.env`)**
   Crea una copia de `.env.example` llamada `.env`. Puedes colocar los dominios locales (terminados en `.localhost`) y la contraseña de base de datos que prefieras. Por ejemplo:
   ```env
   MATRIX_DOMAIN=matrix.localhost
   ELEMENT_DOMAIN=chat.localhost
   POSTGRES_PASSWORD=tu_contrasena_segura
   ```
   *(Nota: No hace falta crear `element/config.json` manualmente; el contenedor de Element lo genera automáticamente al iniciar usando `element/config.template.json` y el `MATRIX_DOMAIN` del `.env`).*

2. **Generar configuración de Synapse (`data/synapse/homeserver.yaml`)**
   Ejecuta el generador de Synapse indicando en `SYNAPSE_SERVER_NAME` el dominio de Matrix que elegiste:
   ```bash
   docker compose run --rm --no-deps -e SYNAPSE_SERVER_NAME=matrix.localhost -e SYNAPSE_REPORT_STATS=no synapse generate
   ```

3. **Conectar PostgreSQL y habilitar registro (`data/synapse/homeserver.yaml`)**
   Abre `data/synapse/homeserver.yaml` y reemplaza la sección `database:` (SQLite por defecto) por PostgreSQL, colocando en `password` la misma contraseña de tu `.env`:
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

4. **Levantar la plataforma**
   ```bash
   docker compose up -d
   ```

## Acceso desde otros dispositivos en la misma red (LAN / Wi-Fi)

Los dominios `.localhost` solo resuelven dentro de la misma PC. Para conectar celulares u otras laptops en el mismo Wi-Fi usando `nip.io`:

1. **Obtener la IP local de la PC anfitriona (Windows PowerShell)**
   ```powershell
   (Get-NetIPConfiguration | Where-Object { $_.IPv4DefaultGateway -ne $null }).IPv4Address.IPAddress
   ```
   *(Ejemplo: `192.168.0.107`)*

2. **Actualizar los dominios en `.env`**
   Solo necesitas cambiar la IP en el `.env` (Element tomará el nuevo dominio automáticamente):
   ```env
   MATRIX_DOMAIN=matrix.192.168.0.107.nip.io
   ELEMENT_DOMAIN=chat.192.168.0.107.nip.io
   POSTGRES_PASSWORD=tu_contrasena_segura
   ```

3. **Abrir los puertos 80 y 443 en el Firewall de Windows (solo la primera vez)**
   ```powershell
   Start-Process powershell -Verb RunAs -ArgumentList '-Command "New-NetFirewallRule -DisplayName \"Matrix Caddy\" -Direction Inbound -LocalPort 80,443 -Protocol TCP -Action Allow"'
   ```

4. **Recrear contenedores**
   ```bash
   docker compose up -d --force-recreate
   ```

## Instalación del certificado local (para cargar imágenes y avatares)

Al usar HTTPS local (`tls internal`), los navegadores bloquean el *Service Worker* (necesario para ver imágenes y archivos adjuntos) hasta que confían en el certificado de Caddy.

Para instalarlo en cualquier PC o celular conectado a la red:
1. Descarga el certificado directamente desde: **`https://<ELEMENT_DOMAIN>/cert`** (ej. `https://chat.192.168.0.107.nip.io/cert`).
2. Instálalo como **Certificado de CA / Entidad de certificación raíz de confianza** en el dispositivo:
   - **Windows:** Doble clic a `root.crt` -> *Instalar certificado* -> *Usuario actual* -> *Colocar todos los certificados en el siguiente almacén* -> *Entidades de certificación raíz de confianza*.
   - **Android:** *Ajustes -> Seguridad -> Cifrado y credenciales -> Instalar certificado -> Certificado de CA*.
   - **iOS:** Abrir el archivo para instalar el perfil y luego activarlo en *Configuración -> General -> Información -> Configuración de certificados de confianza*.
3. Reinicia el navegador y entra a `https://<ELEMENT_DOMAIN>`.

## Plan de trabajo
- [x] Repositorio y estructura base
- [x] Configuración e inicialización local y en red LAN
- [x] Desplegar los servicios con Docker
- [x] Pruebas en red local
- [ ] Mejoras (Panel de administración / Monitoreo)
- [ ] Informe