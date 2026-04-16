# Windows auto-updates

Este proyecto ya queda preparado para este flujo:

1. Instalas la app en cada PC una sola vez con `DicsaOperacionSetup.exe`.
2. Cada vez que publicas una version nueva, GitHub Actions genera el instalador.
3. La app en Windows revisa `version.json` al arrancar.
4. Si detecta una version mas nueva, muestra un dialogo para descargar la actualizacion.

## Lo que ya hace el proyecto

- Compila Windows en GitHub Actions.
- Genera `DicsaOperacionSetup.exe` con Inno Setup.
- Publica el instalador y `version.json` en GitHub Releases.
- La app consulta la URL configurada con `DICSA_UPDATE_MANIFEST_URL`.

## Lo que necesitas configurar

### 1. Subir estos cambios al repo correcto

El workflow vive en:

- `.github/workflows/windows-release.yml`

GitHub Actions solo correra cuando este archivo exista en el repo remoto.

### 2. Confirmar la rama principal

El workflow escucha `main` y `master`.
Si tu rama principal usa otro nombre, cambialo en:

- `.github/workflows/windows-release.yml`

### 3. Hacer publico el canal de descarga o cambiar el hosting

La configuracion actual asume que el instalador y el manifiesto se descargan desde GitHub Releases con una URL publica:

- `https://github.com/<owner>/<repo>/releases/latest/download/version.json`

Si el repo es privado, las PCs no podran descargar el release sin autenticacion.
En ese caso, la salida correcta es mover `version.json` y el instalador a un hosting publico controlado por ti, por ejemplo Supabase Storage, y cambiar:

- `UPDATE_MANIFEST_URL`
- `DOWNLOAD_URL`

en `.github/workflows/windows-release.yml`.

## Como publicar una nueva version

### 1. Subir la version en `pubspec.yaml`

Ejemplo:

- de `1.0.1+2`
- a `1.0.2+3`

Si no cambias la version, GitHub puede reconstruir el release, pero la app instalada no vera una actualizacion nueva porque el numero seguira igual.

### 2. Hacer push

Cuando haces push a `main` o `master`, GitHub Actions:

- corre `flutter pub get`
- hace `flutter build windows --release`
- genera `DicsaOperacionSetup.exe`
- publica el release `v<version>`
- sube `version.json`

### 3. Instalar la primera vez

En cada PC nueva:

- descarga `DicsaOperacionSetup.exe`
- instala la app

### 4. Actualizar despues

En las PCs ya instaladas:

- la app detecta la nueva version al abrir
- muestra el aviso
- abre la descarga del instalador nuevo

## Alcance actual

La implementacion actual detecta y ofrece la descarga automaticamente.
Todavia no hace instalacion silenciosa en segundo plano.

Eso ya es suficiente para quitarte:

- copiar carpetas de `build`
- reinstalar manualmente archivo por archivo
- tocar cada PC para reemplazar binarios

Si despues quieres el paso siguiente, podemos montar un updater mas agresivo para descargar e instalar con menos intervencion del usuario.
