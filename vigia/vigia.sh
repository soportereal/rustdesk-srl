#!/bin/bash
# =============================================================================
# Vigía de Soporte Remoto FactuPOS (#2942, 18-oct-2026) — en el .11, usuario factupos.
# Lo corre el cron /etc/cron.d/fp-vigia-soporte-remoto cada hora.
#
#   RustDesk oficial saca versión ─(7 días)─► GitHub compila con la marca (actualizar-srl.yml)
#        ─► acá se baja, se COMPRUEBA y se publica en STAGING ─► Telegram «SRL TRABAJO»
#        ─► el dueño prueba y da Deploy ─► la barra de cada PC la instala sola.
#
# Uso:  vigia.sh                    (lo normal: revisa y avanza un paso)
#       vigia.sh publicar <ver> <run>   (publicar a mano una compilación ya terminada)
# Estado: /var/www/_logs/soporte-remoto-vigia.estado  →  «<versión> <run> <compilando|fallo|staging>»
# =============================================================================
set -uo pipefail

REPO=soportereal/rustdesk-srl
ESPERA_DIAS=7                      # no tomar una versión recién salida (puede traer errores)
A=/var/www/soportereal.com
MAN_LINUX=$A/software/factupos-app/linux/Factupos-SoporteRemoto_version.json
MSI=$A/software/factupos-app/windows/Factupos-SoporteRemoto.msi
MAN_WIN=$A/software/factupos-app/windows/Factupos-SoporteRemoto_version.json
POOL=$A/apt/pool/Factupos-Soporte.deb
RESPALDOS=/var/www/_respaldos/soporte-remoto
EST=/var/www/_logs/soporte-remoto-vigia.estado
LOG=/var/www/_logs/soporte-remoto-vigia.log

[ -t 1 ] || exec >>"$LOG" 2>&1
log()   { echo "$(date '+%F %T') $*"; }
aviso() { php -r 'require "/var/www/seguridad/telegram_soporte.php"; tg_soporte_enviar($argv[1]);' "$1" >/dev/null 2>&1 || log "no se pudo encolar el aviso"; }
fallo() { log "❌ $1"; echo "${VER:-?} ${RUN:-?} fallo" > "$EST"; aviso "🔴 <b>Soporte Remoto ${VER:-}</b>: $1"; exit 1; }
version_de() { python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['version'])" "$1"; }

publicar() {
    VER="$1"; RUN="$2"
    log "publicando $VER (corrida $RUN)"
    T=$(mktemp -d); trap 'rm -rf "$T"' RETURN
    gh run download "$RUN" -R "$REPO" -D "$T" >/dev/null 2>&1 || fallo "no se pudieron bajar los archivos de la corrida $RUN"
    DEB=$(find "$T" -name "SoporteRemoto-Factupos-$VER-x86_64.deb" | head -1)
    NUEVO_MSI=$(find "$T" -name "SoporteRemoto-Factupos-$VER-x86_64.msi" | head -1)
    [ -n "$DEB" ] || fallo "la corrida $RUN no trae el .deb de Linux"

    # --- comprobaciones: nunca se publica algo sin la marca ---
    [ "$(dpkg-deb -f "$DEB" Package)" = rustdesk ] || fallo "el .deb no es el paquete rustdesk"
    [ "$(dpkg-deb -f "$DEB" Version)" = "$VER" ] || fallo "el .deb no es la versión $VER"
    mkdir "$T/x" && dpkg-deb -x "$DEB" "$T/x"
    # 🪤 NO «strings … | grep -q» con pipefail: grep -q corta al encontrar, strings muere con SIGPIPE
    #    y el tubo da 141 → decía «no trae el servidor» justo cuando SÍ lo traía (18-oct, 1.5.0).
    strings "$T/x/usr/share/rustdesk/lib/librustdesk.so" > "$T/textos.txt" || fallo "no se pudo leer librustdesk.so"
    grep -qF "remote.factupos.com" "$T/textos.txt" || fallo "el .deb no trae nuestro servidor"
    grep -qF "Ka3nu6yPqf05OpwXeaMx6DqA7JKAXKl5oC58TKyf1WI=" "$T/textos.txt" || fallo "el .deb no trae la llave del servidor"
    grep -qF "Soporte Remoto Factupos" "$T/textos.txt" || fallo "el .deb no trae el nombre (cambiaría el ID de las PCs)"
    ! grep -qF "rs-ny.rustdesk.com" "$T/textos.txt" || fallo "el .deb todavía apunta al servidor de RustDesk"

    # --- respaldo de lo publicado ahora (para volver atrás) ---
    ANT=$(version_de "$MAN_LINUX")
    mkdir -p "$RESPALDOS/$ANT"
    [ -f "$RESPALDOS/$ANT/Factupos-Soporte.deb" ] || cp -f "$POOL" "$RESPALDOS/$ANT/"
    [ -f "$MSI" ] && { [ -f "$RESPALDOS/$ANT/Factupos-SoporteRemoto.msi" ] || cp -f "$MSI" "$RESPALDOS/$ANT/"; }

    # --- Linux: repo APT (la barra de las PCs lo toma de acá) ---
    cp -f "$DEB" "$POOL" || fallo "no se pudo copiar al pool"
    bash "$A/apt/actualizar-repo.sh" >/dev/null || fallo "actualizar-repo.sh falló"
    ( cd "$A/apt" && SIM=$(python3 publicar.py) && ! echo "$SIM" | grep -qi "se quita" \
        && python3 publicar.py --aplicar >/dev/null; R=$?; rm -rf __pycache__; exit $R ) \
        || fallo "publicar.py frenó (revisar a mano: python3 publicar.py)"
    [ "$(version_de "$MAN_LINUX")" = "$VER" ] || fallo "el manifiesto de Linux no quedó en $VER"

    # --- Windows: instalador en descargas (no se actualiza solo en las PCs Windows) ---
    if [ -n "$NUEVO_MSI" ]; then
        cp -f "$NUEVO_MSI" "$MSI"
        python3 - "$MAN_WIN" "$VER" <<'PY'
import json, sys
p, v = sys.argv[1], sys.argv[2]
m = json.load(open(p)); m["version"] = v
open(p, "w").write(json.dumps(m, indent=2, ensure_ascii=False) + "\n")
PY
    else
        log "la corrida no trae .msi: Windows queda en la versión anterior"
    fi

    echo "$VER $RUN staging" > "$EST"
    log "✅ $VER publicada en staging (antes $ANT)"
    aviso "🟢 <b>Soporte Remoto FactuPOS $VER</b> listo en STAGING (antes $ANT). Probar en una PC y dar <b>Deploy</b>: después la barra de tareas lo instala sola en todas las PCs."
}

if [ "${1:-}" = publicar ]; then
    publicar "${2:?versión}" "${3:?corrida}"
    exit 0
fi

E_VER=""; E_RUN=""; E_ETAPA=""
[ -f "$EST" ] && read -r E_VER E_RUN E_ETAPA < "$EST"

# 1) ¿hay una compilación en curso?
if [ "$E_ETAPA" = compilando ]; then
    VER=$E_VER; RUN=$E_RUN
    ST=$(gh run view "$RUN" -R "$REPO" --json status,conclusion --jq '.status+" "+.conclusion' 2>/dev/null)
    case "$ST" in
        "completed success") publicar "$VER" "$RUN" ;;
        completed*)          fallo "la compilación falló (https://github.com/$REPO/actions/runs/$RUN). Revisar la receta srl-marca/aplicar.sh" ;;
        *)                   log "sigue compilando $VER ($ST)" ;;
    esac
    exit 0
fi

# 2) ¿salió una versión oficial nueva?
read -r ULTIMA FECHA < <(gh api repos/rustdesk/rustdesk/releases/latest --jq '.tag_name+" "+.published_at' 2>/dev/null)
[ -n "${ULTIMA:-}" ] || { log "no se pudo consultar GitHub"; exit 0; }
PUBLICADA=$(version_de "$MAN_LINUX")
if ! dpkg --compare-versions "$ULTIMA" gt "$PUBLICADA"; then
    log "al día ($PUBLICADA; oficial $ULTIMA)"; exit 0
fi
if [ "$E_VER" = "$ULTIMA" ]; then
    log "$ULTIMA ya está en etapa «$E_ETAPA»: no se repite (borrar $EST para reintentar)"; exit 0
fi
EDAD=$(( ( $(date +%s) - $(date -d "$FECHA" +%s) ) / 86400 ))
if [ "$EDAD" -lt "$ESPERA_DIAS" ]; then
    log "$ULTIMA salió hace $EDAD días: espero a $ESPERA_DIAS"; exit 0
fi

VER=$ULTIMA
gh workflow run actualizar-srl.yml -R "$REPO" -f version="$VER" -f windows=true >/dev/null 2>&1 || fallo "no se pudo disparar la compilación"
sleep 15
RUN=$(gh run list -R "$REPO" --workflow actualizar-srl.yml --limit 1 --json databaseId --jq '.[0].databaseId')
echo "$VER $RUN compilando" > "$EST"
log "compilando $VER (corrida $RUN)"
aviso "🛠️ <b>Soporte Remoto FactuPOS</b>: RustDesk sacó la $VER (tenemos $PUBLICADA). Compilando con nuestra marca (~45 min)."
