    set -Eeuo pipefail
    source /opt/quickpod/bin/common.sh

touch "$LOG_DIR/uvr.log"; chmod 644 "$LOG_DIR/uvr.log" || true
qlog "UVR service not enabled (placeholder). Set ENABLE_UVR=1 and add your CLI commands here."
