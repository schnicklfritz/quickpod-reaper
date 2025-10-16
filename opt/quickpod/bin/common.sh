    #!/usr/bin/env bash
    set -Eeuo pipefail

"${LOG_DIR:=/var/log/quickpod}"
mkdir -p "$LOG_DIR"
chmod 755 "$LOG_DIR"

ts() { date -Is; }
qlog() { echo "[$(ts)] $*" | tee -a "$LOG_DIR/boot.log"; }

ext_port() { local internal="$1"; local var="QUICKPOD_PORT_${internal}"; local val="${!var:-$internal}"; echo "$val"; }

public_url() { local internal="$1"; local scheme="${2:-http}"; local host="${PUBLIC_IPADDR:-localhost}"; local port; port="$(ext_port "$internal")"; echo "${scheme}://${host}:${port}"; }

wait_for_port() { local port="$1" timeout="${2:-20}"; for _ in $(seq 1 "$timeout"); do ss -lnt | awk '{print $4}' | grep -q ":${port}$" && return 0; sleep 1; done; return 1; }

env_summary() {
qlog "ENV SUMMARY: PUBLIC_IPADDR=${PUBLIC_IPADDR:-unknown} GPU_COUNT=${GPU_COUNT:-unknown} LABEL=${CONTAINER_LABEL:-n/a}"
qlog "ENV SUMMARY: DISPLAY=${DISPLAY:-:1} VNC_PORT=${VNC_PORT:-6901} HEALTH_PORT=${HEALTH_PORT:-8686} RVC_PORT=${RVC_PORT:-7865} MUSICGEN_PORT=${MUSICGEN_PORT:-7860}"
}
