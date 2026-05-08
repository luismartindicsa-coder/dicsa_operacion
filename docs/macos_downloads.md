# macOS download link

Para macOS vamos a manejar un flujo simple:

1. Haces cambios en tu Mac.
2. Subes version en `pubspec.yaml`.
3. Haces `git push`.
4. GitHub Actions compila macOS y publica un zip descargable.

## Archivo publicado

El workflow de macOS sube este archivo a GitHub Releases:

- `DICSA-macOS.zip`

## Link directo estable

Si el repo es publico, puedes compartir este link y siempre bajara la ultima version:

- `https://github.com/<owner>/<repo>/releases/latest/download/DICSA-macOS.zip`

Con tu repo actual quedaria asi:

- `https://github.com/luismartindicsa-coder/dicsa_operacion/releases/latest/download/DICSA-macOS.zip`

## Como usarlo

La persona descarga el zip, lo descomprime y abre `DICSA.app`.

## Importante en macOS

Como este flujo no incluye firma de Apple ni notarizacion:

- macOS puede mostrar advertencia de seguridad
- si pasa, hay que hacer clic derecho sobre `DICSA.app` y luego `Open`

Si despues quieres, podemos hacer el siguiente paso y dejarlo firmado/notarizado, pero para compartir un link simple este flujo ya es suficiente.
