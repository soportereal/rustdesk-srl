#!/bin/bash
# =============================================================================
# Receta de la marca «Soporte Remoto Factupos» sobre un RustDesk OFICIAL limpio
# (#2942, 18-oct-2026). Es EL procedimiento: cuando sale una versión nueva de RustDesk,
# no se pasan cambios a mano — se baja el código oficial de esa versión y se corre esto.
#
# Uso:  srl-marca/aplicar.sh <carpeta del código oficial, CON submódulos>
#
# 🔑 Cada cambio exige encontrar su punto EXACTAMENTE una vez. Si RustDesk movió o cambió
#    algo, la receta SE FRENA con «❌ RECETA: …» (no compila algo a medias). Se arregla
#    acá y se vuelve a correr.
# 🔑 APP_NAME NO SE CAMBIA NUNCA: de él dependen la carpeta de configuración y, con eso,
#    el ID y la clave de cada PC ya instalada.
# =============================================================================
set -euo pipefail

SRC="${1:?falta la carpeta del código oficial}"
AQUI="$(cd "$(dirname "$0")" && pwd)"

APP_NAME="Soporte Remoto Factupos"
SERVIDOR="remote.factupos.com"
LLAVE="Ka3nu6yPqf05OpwXeaMx6DqA7JKAXKl5oC58TKyf1WI="
WEB="https://soportereal.com"
POWERED="Powered by FactuPOS"

fallo() { echo "❌ RECETA: $*" >&2; exit 1; }
ok()    { echo "  ✓ $*"; }

# reemplazar <archivo> <regex python> <reemplazo> <descripción>  (exactamente 1 coincidencia)
reemplazar() {
    python3 - "$1" "$2" "$3" "$4" <<'PY' || exit 1
import re, sys
ruta, patron, nuevo, que = sys.argv[1:5]
s = open(ruta, encoding="utf-8").read()
n = len(re.findall(patron, s, flags=re.M))
if n != 1:
    sys.stderr.write("❌ RECETA: %s — se esperaba 1 coincidencia en %s y hay %d\n" % (que, ruta, n))
    sys.exit(1)
s = re.sub(patron, lambda m: nuevo, s, count=1, flags=re.M)
open(ruta, "w", encoding="utf-8").write(s)
print("  ✓ " + que)
PY
}

[ -f "$SRC/libs/hbb_common/src/config.rs" ] || fallo "no está libs/hbb_common (¿se bajó sin submódulos?)"

echo "== 1. Servidor, llave y nombre (libs/hbb_common/src/config.rs)"
C="$SRC/libs/hbb_common/src/config.rs"
reemplazar "$C" 'PROD_RENDEZVOUS_SERVER: RwLock<String> = RwLock::new\("[^"]*"\.to_owned\(\)\);' \
    "PROD_RENDEZVOUS_SERVER: RwLock<String> = RwLock::new(\"$SERVIDOR\".to_owned());" "servidor por defecto"
reemplazar "$C" 'pub static ref APP_NAME: RwLock<String> = RwLock::new\("[^"]*"\.to_owned\(\)\);' \
    "pub static ref APP_NAME: RwLock<String> = RwLock::new(\"$APP_NAME\".to_owned());" "nombre de la app"
reemplazar "$C" 'pub const RENDEZVOUS_SERVERS: &\[&str\] = &\[[^\]]*\];' \
    "pub const RENDEZVOUS_SERVERS: &[&str] = &[\"$SERVIDOR\"];" "servidores de encuentro"
reemplazar "$C" 'pub const RS_PUB_KEY: &str = "[^"]*";' \
    "pub const RS_PUB_KEY: &str = \"$LLAVE\";" "llave pública del servidor"

echo "== 2. Lanzador de Linux (res/rustdesk.desktop)"
D="$SRC/res/rustdesk.desktop"
reemplazar "$D" '^Name=RustDesk$' "Name=$APP_NAME" "nombre en el menú"
reemplazar "$D" '^Comment=Remote Desktop$' "Comment=$APP_NAME" "descripción en el menú"

echo "== 3. «Powered by» (flutter/lib/common.dart)"
F="$SRC/flutter/lib/common.dart"
reemplazar "$F" "launchUrl\(Uri\.parse\('https://rustdesk\.com'\)\);" "launchUrl(Uri.parse('$WEB'));" "enlace del pie"
reemplazar "$F" 'translate\("powered_by_me"\),' "\"$POWERED\"," "texto del pie"
grep -q "assets/logo.png" "$F" || fallo "common.dart ya no carga assets/logo.png: revisar cómo se pone el logo"

echo "== 4. Logo e íconos"
( cd "$AQUI/archivos" && find . -type f ) | while read -r f; do
    dst="$SRC/${f#./}"
    [ -d "$(dirname "$dst")" ] || fallo "no existe la carpeta de $f en el código oficial"
    cp -f "$AQUI/archivos/${f#./}" "$dst"
    ok "${f#./}"
done
grep -qE '^\s+- assets/$' "$SRC/flutter/pubspec.yaml" || fallo "pubspec.yaml ya no incluye la carpeta assets/ (el logo no entraría)"

echo "== 5. Comprobación final"
grep -q "\"$SERVIDOR\"" "$C" && grep -q "$LLAVE" "$C" && grep -q "\"$APP_NAME\"" "$C" || fallo "config.rs no quedó con la marca"
grep -q "^Name=$APP_NAME$" "$D" || fallo "el lanzador no quedó con el nombre"
grep -q "$POWERED" "$F" || fallo "el pie no quedó con «$POWERED»"
ok "marca aplicada: $APP_NAME · $SERVIDOR"
