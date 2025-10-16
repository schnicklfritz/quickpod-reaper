#!/usr/bin/env bash
set -Eeuo pipefail

: "${LOG_DIR:=/var/log/quickpod}"
mkdir -p "$LOG_DIR"
touch "$LOG_DIR/boot.log" "$LOG_DIR/desktop.log"
chmod 644 "$LOG_DIR"/*.log || true

ln -sf /proc/1/fd/1 "$LOG_DIR/boot.stdout" || true
ln -sf /proc/1/fd/2 "$LOG_DIR/boot.stderr" || true

export PATH="/opt/venv/bin:/usr/local/cuda-13.0/bin:${PATH}"

bash /opt/quickpod/bin/bootstrap.sh

if [ "${ENABLE_RVC:-1}" = "1" ]; then
  bash /opt/quickpod/bin/start-rvc.sh
fi
if [ "${ENABLE_MUSICGEN:-1}" = "1" ]; then
  bash /opt/quickpod/bin/start-musicgen.sh
fi
if [ "${ENABLE_UVR:-0}" = "1" ]; then
  bash /opt/quickpod/bin/start-uvr.sh
fi

if [ "${ENABLE_KASMVNC_METRICS:-0}" = "1" ]; then
  bash /opt/quickpod/bin/poll-kasmvnc-metrics.sh 2>&1 | tee -a "$LOG_DIR/metrics-runner.log" &
fi
if [ -n "${QUICKPOD_STATUS_URL:-}" ] && [ "${ENABLE_QUICKPOD_STATUS:-0}" = "1" ]; then
  bash /opt/quickpod/bin/poll-quickpod-status.sh 2>&1 | tee -a "$LOG_DIR/quickpod-status-runner.log" &
fi

source /opt/quickpod/bin/common.sh
VNC_EXT="$(public_url "${VNC_PORT:-6901}" https)"
RVC_EXT="$(public_url "${RVC_PORT:-7865}" http)"
MUSICGEN_EXT="$(public_url "${MUSICGEN_PORT:-7860}" http)"
HEALTH_EXT="$(public_url "${HEALTH_PORT:-8686}" http)"

qlog "════════ QuickPod Endpoints ═════════"
qlog "Desktop (KasmVNC):  ${VNC_EXT}"
qlog "RVC WebUI:          ${RVC_EXT}"
qlog "MusicGen UI:        ${MUSICGEN_EXT}"
qlog "Health:             ${HEALTH_EXT}"
qlog "Public IP:          ${PUBLIC_IPADDR:-unknown}"
qlog "GPUs (requested):   ${GPU_COUNT:-unknown}"
qlog "Pod Label/API Key:  ${CONTAINER_LABEL:-n/a}"
qlog "SSH PubKey present: $([ -n "${SSH_PUBLIC_KEY:-}" ] && echo yes || echo no)"
qlog "═════════════════════════════════════"

tail -n 200 -F "$LOG_DIR"/boot.log "$LOG_DIR"/desktop.log "$LOG_DIR"/rvc.log "$LOG_DIR"/musicgen.log /home/kasm-user/.vnc/*.log 2>/dev/null
