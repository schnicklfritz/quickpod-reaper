    set -Eeuo pipefail
    source /opt/quickpod/bin/common.sh

VNC_USER="${VNC_USER:-kasm-user}"
DISPLAY_VAL="${DISPLAY:-:1}"
VNC_PORT="${VNC_PORT:-6901}"
VNC_GEOM="${VNC_GEOM:-1920x1080}"
VNC_DEPTH="${VNC_DEPTH:-24}"
HEALTH_PORT="${HEALTH_PORT:-8686}"

touch "$LOG_DIR/bootstrap.log" "$LOG_DIR/desktop.log"
chmod 644 "$LOG_DIR"/*.log || true

ln -sf /proc/1/fd/1 "$LOG_DIR/boot.stdout" || true
ln -sf /proc/1/fd/2 "$LOG_DIR/boot.stderr" || true

qlog "Bootstrap start"
env_summary
qlog "CUDA: $(nvcc --version 2>/dev/null | grep release || echo 'nvcc not found')"
qlog "GPU: $(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null || echo 'nvidia-smi unavailable')"

qlog "Starting PulseAudio..."
pulseaudio -D --exit-idle-time=-1 >/dev/null 2>&1 || qlog "PulseAudio not started (non-fatal)"

rm -f /tmp/.X"${DISPLAY_VAL#:}".lock || true
rm -rf /tmp/.X11-unix/X"${DISPLAY_VAL#:}" || true

qlog "Launching KasmVNC on ${DISPLAY_VAL} (internal port ${VNC_PORT})"
su - "$VNC_USER" -c "vncserver ${DISPLAY_VAL} -depth ${VNC_DEPTH} -geometry ${VNC_GEOM} -websocket ${VNC_PORT} -interface 0.0.0.0"
2>&1 | tee -a "$LOG_DIR/desktop.log" &

python - <<'PY' &
import http.server, socketserver, os, subprocess
PORT=int(os.environ.get("HEALTH_PORT","8686"))
VNC_PORT=int(os.environ.get("VNC_PORT","6901"))
class H(http.server.SimpleHTTPRequestHandler):
def do_GET(self):
try:
out=subprocess.check_output(["ss","-lnt"]).decode()
ok = f":{VNC_PORT}" in out
except Exception:
ok=False
self.send_response(200 if ok else 503); self.end_headers()
self.wfile.write(b"ready" if ok else b"starting")
with socketserver.TCPServer(("0.0.0.0", PORT), H) as httpd:
httpd.serve_forever()
PY

if ! wait_for_port "$VNC_PORT" 30; then
qlog "ERROR: VNC port ${VNC_PORT} did not bind within timeout"; exit 1
fi

VNC_EXT="$(public_url "$VNC_PORT" https)"
HEALTH_EXT="$(public_url "$HEALTH_PORT" http)"
qlog "Desktop (KasmVNC): ${VNC_EXT}"
qlog "Health endpoint: ${HEALTH_EXT}"
qlog "Bootstrap ready"
