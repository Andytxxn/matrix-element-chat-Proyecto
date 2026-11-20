# Plataforma de mensajería instantánea con Matrix + Element

Proyecto de Computación en la Nube.

**Integrantes:** Andrea Torres · Andrés Valdivieso

## Componentes
- **Synapse**: servidor Matrix (usuarios, salas, mensajes)
- **PostgreSQL**: base de datos
- **Element Web**: cliente web para chatear (configuración inyectada dinámicamente desde `.env`)
- **Caddy**: proxy inverso con HTTPS automático y distribución de certificado local (`/cert`)
- **Synapse Admin**: panel web de administración de usuarios, salas y multimedia
- **Dozzle**: visor en tiempo real de logs y métricas (CPU/RAM) de los contenedores

## Despliegue en Windows (Automatizado con `setup.ps1`)

El script `setup.ps1` es **exclusivo para Windows (PowerShell)**, ya que detecta la IP y configura la regla del Firewall de Windows automáticamente.

1. Abre **Docker Desktop**.
2. En la raíz del proyecto, ejecuta en PowerShell:
   ```powershell
   .\setup.ps1
   ```
   *(Si Windows restringe la ejecución de scripts, usa: `powershell -ExecutionPolicy Bypass -File .\setup.ps1`)*
3. El asistente detectará tu IP local y te preguntará si deseas desplegar en **red local (LAN/Wi-Fi con `nip.io`)** o solo en **esta PC (`.localhost`)**.
4. Si tu equipo cambia de red/IP más adelante, solo vuelve a ejecutar `.\setup.ps1` para actualizar los dominios sin perder datos ni contraseñas.

## Despliegue manual (Linux / macOS)

Si usas Linux o macOS, realiza la configuración inicial en 4 pasos (con Docker corriendo):

1. **Crear `.env`** a partir de `.env.example`:
   ```env
   # Para uso local en 1 PC usa .localhost; para red LAN reemplaza por matrix.<TU_IP>.nip.io y chat.<TU_IP>.nip.io
   MATRIX_DOMAIN=matrix.localhost
   ELEMENT_DOMAIN=chat.localhost
   POSTGRES_PASSWORD=tu_contrasena_segura
   ```
   *(Element genera su `config.json` automáticamente al iniciar usando el `MATRIX_DOMAIN` del `.env`).*

2. **Generar la configuración inicial de Synapse:**
   ```bash
   docker compose run --rm --no-deps -e SYNAPSE_SERVER_NAME=matrix.localhost -e SYNAPSE_REPORT_STATS=no synapse generate
   ```

3. **Configurar PostgreSQL y registro en `data/synapse/homeserver.yaml`:**
   Reemplaza la sección `database:` (SQLite) por PostgreSQL usando la misma contraseña del `.env`:
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
   Y agrega al final del archivo (sin espacios al inicio):
   ```yaml
   enable_registration: true
   enable_registration_without_verification: true
   ```

4. **Levantar los servicios:**
   ```bash
   docker compose up -d
   ```
   *(En modo LAN con firewall activo en Linux, habilita los puertos 80 y 443, ej. `sudo ufw allow 80,443/tcp`. Si cambia tu IP más adelante, actualiza `.env` y ejecuta `docker compose up -d --force-recreate`).*

## Accesos generados
Reemplaza `<ELEMENT_DOMAIN>` y `<MATRIX_DOMAIN>` por los dominios definidos en tu `.env`:
- **Chat (Element):** `https://<ELEMENT_DOMAIN>`
- **Descarga de certificado local:** `https://<ELEMENT_DOMAIN>/cert`
- **Panel de administración (Synapse Admin):** `https://admin.<ELEMENT_DOMAIN>` *(Homeserver URL: `https://<MATRIX_DOMAIN>`)*
- **Monitoreo y logs (Dozzle):** `https://logs.<ELEMENT_DOMAIN>`

### Crear usuario administrador (para Synapse Admin)
Con los contenedores encendidos, ejecuta y responde `yes` cuando pregunte `Make admin`:
```bash
docker compose exec synapse register_new_matrix_user http://localhost:8008 -c /data/homeserver.yaml
```

## Instalación del certificado local (para cargar imágenes y avatares)

Al usar HTTPS local (`tls internal`), los navegadores bloquean el *Service Worker* (necesario para ver imágenes y archivos adjuntos) hasta que confían en el certificado de Caddy.

Para instalarlo en cualquier PC o celular conectado a la red:
1. Descarga el certificado directamente desde **`https://<ELEMENT_DOMAIN>/cert`**.
2. Instálalo como **Certificado de CA / Entidad de certificación raíz de confianza**:
   - **Windows:** Doble clic a `root.crt` -> *Instalar certificado* -> *Usuario actual* -> *Colocar todos los certificados en el siguiente almacén* -> *Entidades de certificación raíz de confianza*.
   - **macOS:** Doble clic a `root.crt` para agregarlo a *Acceso a Llaveros* (*Keychain Access*) -> doble clic al certificado -> *Confiar* -> *Confiar siempre*.
   - **Linux (Ubuntu/Debian):** Copia `root.crt` a `/usr/local/share/ca-certificates/caddy-root.crt` y ejecuta `sudo update-ca-certificates`.
   - **Android:** *Ajustes -> Seguridad -> Cifrado y credenciales -> Instalar certificado -> Certificado de CA*.
   - **iOS:** Abrir el archivo para instalar el perfil y luego activarlo en *Configuración -> General -> Información -> Configuración de certificados de confianza*.
3. Reinicia el navegador y entra a `https://<ELEMENT_DOMAIN>`.

## Plan de trabajo
- [x] Repositorio y estructura base
- [x] Configuración e inicialización local y en red LAN
- [x] Desplegar los servicios con Docker
- [x] Pruebas en red local
- [x] Mejoras (Synapse Admin, Dozzle y script de despliegue `setup.ps1`)
- [ ] Informe