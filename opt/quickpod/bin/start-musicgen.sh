#!/usr/bin/env bash
    set -Eeuo pipefail
    source /opt/quickpod/bin/common.sh

MUSICGEN_PORT="${MUSICGEN_PORT:-7860}"
touch "$LOG_DIR/musicgen.log"; chmod 644 "$LOG_DIR/musicgen.log" || true

if python - <<'PY' 2>/dev/null; then exit 0; else exit 1; fi
import importlib, sys
sys.exit(0 if importlib.util.find_spec("audiocraft") else 1)
PY
then
qlog "Starting MusicGen (Gradio) on ${MUSICGEN_PORT}"
bash -lc "source /opt/venv/bin/activate && python - <<'PY'
from audiocraft.models import MusicGen
import gradio as gr
model = MusicGen.get_pretrained('facebook/musicgen-medium')
def generate(prompt, duration):
model.set_generation_params(duration=int(duration))
wav = model.generate([prompt])
return (model.sample_rate, wav.cpu().numpy().T)
demo = gr.Interface(fn=generate,
inputs=[gr.Textbox(label='Prompt'),
gr.Slider(1,30,value=10,step=1,label='Duration (s)')],
outputs='audio',
title='MusicGen (QuickPod)')
demo.launch(server_name='0.0.0.0', server_port=int('${MUSICGEN_PORT}'))
PY" 2>&1 | tee -a "$LOG_DIR/musicgen.log" &
MUSICGEN_EXT="$(public_url "$MUSICGEN_PORT" http)"
qlog "MusicGen UI: ${MUSICGEN_EXT}"
else
qlog "MusicGen not started (audiocraft not installed)"
fi
