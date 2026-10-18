# Marca «Soporte Remoto Factupos» (#2942)

Cómo se arma nuestro RustDesk a partir de **cualquier versión oficial**, sin pasar cambios a mano.

| Qué | Dónde |
|---|---|
| La receta (servidor, llave, nombre, lanzador, «Powered by FactuPOS», logo e íconos) | `srl-marca/aplicar.sh` |
| Logo e íconos que se copian encima del código oficial | `srl-marca/archivos/` (mismas rutas que en RustDesk) |
| La compilación (Linux .deb + Windows .msi) | `.github/workflows/actualizar-srl.yml` — *Run workflow* con la versión, ej. `1.5.0` |
| Quién la dispara solo | el vigía del servidor .11 (ver memoria `panel-bluetooth-y-actualiza-apps-2942`) |

## Reglas

- **`APP_NAME` no se cambia nunca**: de él depende la carpeta de configuración → el ID y la clave de cada PC.
- Si RustDesk cambia algo que la receta toca, `aplicar.sh` **se frena** con `❌ RECETA: …`. Se ajusta el
  patrón en `aplicar.sh` y se vuelve a correr. Nunca se compila a medias.
- Las versiones de Flutter / Rust / vcpkg / generador del puente salen del propio RustDesk oficial.
- Android sigue por `flutter-build.yml` / `flutter-nightly.yml` (todavía no pasa por la receta).
- `build-srl.yml` (el proceso viejo, código 1.4.6 dentro de este repo) quedó solo a mano.

Probar la receta en local: bajar `rustdesk/rustdesk` con `--recurse-submodules` en el tag y
`bash srl-marca/aplicar.sh <carpeta>`. Sobre la 1.4.6 reproduce byte a byte lo que había en este repo.
