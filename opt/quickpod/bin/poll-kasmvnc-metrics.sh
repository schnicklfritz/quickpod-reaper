    set -Eeuo pipefail
    source /opt/quickpod/bin/common.sh

"${KASMVNC_OWNER_USER:?set KASMVNC_OWNER_USER}"
"${KASMVNC_OWNER_PASS:?set KASMVNC_OWNER_PASS}"

VNC_PORT_INTERNAL="${VNC_PORT:-6901}"
VNC_EXT_PORT="$(ext_port "$VNC_PORT_INTERNAL")"
HOST="${PUBLIC_IPADDR:-localhost}"
URL="https://${HOST}:${VNC_EXT_PORT}/api/get_bottleneck_stats"

OUT="$LOG_DIR/kasmvnc-metrics.log"
touch "$OUT"; chmod 644 "$OUT" || true

qlog "Starting KasmVNC metrics poller at ${URL}"
while true; do
TS="$(date -Is)"
RESP="$(curl -sk -u "${KASMVNC_OWNER_USER}:${KASMVNC_OWNER_PASS}" --max-time 4 "$URL" || echo '{}')"
echo "[$TS] $RESP" | tee -a "$OUT"
sleep "${KASMVNC_POLL_INTERVAL:-15}"
done
