    set -Eeuo pipefail
    source /opt/quickpod/bin/common.sh

RVC_PORT="${RVC_PORT:-7865}"
touch "$LOG_DIR/rvc.log"; chmod 644 "$LOG_DIR/rvc.log" || true

if [ -d /opt/rvc-webui ] && [ -x /opt/venv/bin/python ]; then
qlog "Starting RVC WebUI on ${RVC_PORT}"
bash -lc "cd /opt/rvc-webui && source /opt/venv/bin/activate && python infer-web.py --listen 0.0.0.0 --port ${RVC_PORT}"
2>&1 | tee -a "$LOG_DIR/rvc.log" &
RVC_EXT="$(public_url "$RVC_PORT" http)"
qlog "RVC WebUI: ${RVC_EXT}"
else
qlog "RVC not started (missing /opt/rvc-webui or Python venv)"
fi
