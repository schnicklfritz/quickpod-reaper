# Start with NVIDIA's official CUDA 13.0 image (Ubuntu 24.04)
FROM nvidia/cuda:13.0.1-devel-ubuntu24.04

USER root

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV PATH=/usr/local/cuda-13.0/bin:${PATH}
ENV LD_LIBRARY_PATH=/usr/local/cuda-13.0/lib64:${LD_LIBRARY_PATH}
ENV CUDA_HOME=/usr/local/cuda-13.0

# Install basic dependencies
RUN apt-get update && apt-get install -y \
    software-properties-common \
    wget \
    curl \
    gnupg2 \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install desktop environment and audio dependencies
RUN apt-get update && apt-get install -y \
    xfce4 \
    xfce4-goodies \
    dbus-x11 \
    xorg \
    libasound2t64 \
    alsa-utils \
    pulseaudio \
    pulseaudio-utils \
    libjack-jackd2-0 \
    xdotool \
    libfontconfig1 \
    libfreetype6 \
    libx11-6 \
    libxcb1 \
    libxext6 \
    libxrender1 \
    libxi6 \
    libxrandr2 \
    && rm -rf /var/lib/apt/lists/*

# Install KasmVNC for Ubuntu 24.04 (Noble)
RUN cd /tmp && \
    wget https://github.com/kasmtech/KasmVNC/releases/download/v1.3.2/kasmvncserver_noble_1.3.2_amd64.deb && \
    apt-get update && \
    apt-get install -y ./kasmvncserver_noble_1.3.2_amd64.deb && \
    rm kasmvncserver_noble_1.3.2_amd64.deb && \
    rm -rf /var/lib/apt/lists/*

# Install pyenv dependencies
RUN apt-get update && apt-get install -y \
    make \
    build-essential \
    libssl-dev \
    zlib1g-dev \
    libbz2-dev \
    libreadline-dev \
    libsqlite3-dev \
    wget \
    curl \
    llvm \
    libncurses5-dev \
    libncursesw5-dev \
    xz-utils \
    tk-dev \
    libffi-dev \
    liblzma-dev \
    git \
    vim \
    htop \
    && rm -rf /var/lib/apt/lists/*

# Install pyenv
ENV PYENV_ROOT="/opt/pyenv"
ENV PATH="$PYENV_ROOT/bin:$PATH"

RUN git clone https://github.com/pyenv/pyenv.git $PYENV_ROOT && \
    cd $PYENV_ROOT && src/configure && make -C src

# Initialize pyenv
RUN echo 'eval "$(pyenv init --path)"' >> /root/.bashrc && \
    echo 'eval "$(pyenv init -)"' >> /root/.bashrc

# Install Python 3.11.9 via pyenv
RUN eval "$(pyenv init --path)" && \
    eval "$(pyenv init -)" && \
    pyenv install 3.11.9 && \
    pyenv global 3.11.9

# Set Python paths
ENV PATH="$PYENV_ROOT/versions/3.11.9/bin:$PATH"

# Create virtual environment
RUN eval "$(pyenv init --path)" && \
    eval "$(pyenv init -)" && \
    python -m venv /opt/venv

# Activate venv by default
ENV PATH="/opt/venv/bin:$PATH"

# Upgrade pip in venv
RUN pip install --upgrade pip setuptools wheel

# ============================================
# AI AUDIO PROCESSING DEPENDENCIES
# ============================================

# Install FFmpeg and audio tools
RUN apt-get update && apt-get install -y \
    ffmpeg \
    sox \
    libsox-fmt-all \
    rubberband-cli \
    lame \
    flac \
    vorbis-tools \
    opus-tools \
    && rm -rf /var/lib/apt/lists/*

# Install Cython first (required for madmom and other packages)
RUN /opt/venv/bin/pip install --no-cache-dir \
    cython \
    numpy

# Install Python audio and AI libraries in venv
RUN /opt/venv/bin/pip install --no-cache-dir \
    librosa==0.10.2 \
    soundfile \
    pydub \
    audioread \
    resampy \
    torchaudio \
    torchvision \
    demucs \
    essentia \
    pyworld \
    praat-parselmouth \
    faiss-cpu \
    noisereduce \
    pedalboard \
    scipy \
    numba \
    matplotlib \
    transformers \
    accelerate \
    aubio \
    madmom \
    mir_eval

# Install fairseq and pyannote separately (can have dependency conflicts)
RUN /opt/venv/bin/pip install --no-cache-dir \
    fairseq || echo "fairseq install failed, continuing..."

RUN /opt/venv/bin/pip install --no-cache-dir \
    pyannote.audio || echo "pyannote.audio install failed, continuing..."

# ============================================
# VST PLUGIN SUPPORT
# ============================================

# Create VST plugin directories
RUN mkdir -p \
    /usr/lib/vst \
    /usr/lib/vst3 \
    /home/kasm-user/.vst \
    /home/kasm-user/.vst3 \
    /home/kasm-user/.lv2

# Install WINE for Windows VST support (optional but useful)
RUN dpkg --add-architecture i386 && \
    apt-get update && \
    apt-get install -y \
    wine64 \
    wine32 \
    winetricks \
    && rm -rf /var/lib/apt/lists/*

# Install Yabridge for Windows VST bridge
RUN cd /tmp && \
    wget https://github.com/robbert-vdh/yabridge/releases/download/5.1.0/yabridge-5.1.0.tar.gz && \
    tar -C /usr -xavf yabridge-5.1.0.tar.gz && \
    rm yabridge-5.1.0.tar.gz

# ============================================
# FREE LINUX-NATIVE VST PLUGINS
# ============================================

# Install LSP Plugins (comprehensive suite)
RUN apt-get update && apt-get install -y \
    lsp-plugins-lv2 \
    lsp-plugins-vst \
    && rm -rf /var/lib/apt/lists/*

# Install Vital synth (modern wavetable synth)
RUN cd /tmp && \
    wget https://github.com/mtytel/vital/releases/download/v1.5.5/vital-1.5.5-linux-x86_64.tar.gz && \
    tar -xzf vital-1.5.5-linux-x86_64.tar.gz && \
    cp -r Vital/VST3/Vital.vst3 /usr/lib/vst3/ && \
    cp -r Vital/LV2/Vital.lv2 /home/kasm-user/.lv2/ && \
    rm -rf Vital vital-1.5.5-linux-x86_64.tar.gz

# Install Surge XT synth
RUN cd /tmp && \
    wget https://github.com/surge-synthesizer/releases-xt/releases/download/1.3.4/surge-xt-linux-x64-1.3.4.deb && \
    apt-get update && apt-get install -y ./surge-xt-linux-x64-1.3.4.deb && \
    rm surge-xt-linux-x64-1.3.4.deb && \
    rm -rf /var/lib/apt/lists/*

# ============================================
# AI MODEL CACHING SETUP
# ============================================

# Set Hugging Face cache location
ENV HF_HOME=/home/kasm-user/.cache/huggingface
ENV TORCH_HOME=/home/kasm-user/.cache/torch

# Install Node.js and Firefox
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y \
    nodejs \
    firefox \
    && rm -rf /var/lib/apt/lists/*

# Install Reaper
RUN cd /tmp && \
    wget https://www.reaper.fm/files/7.x/reaper725_linux_x86_64.tar.xz && \
    tar -xf reaper725_linux_x86_64.tar.xz && \
    cd reaper_linux_x86_64 && \
    ./install-reaper.sh --install /opt/reaper --integrate-desktop --usr-local-bin-symlink && \
    cd / && rm -rf /tmp/reaper*

# Create kasm-user with UID/GID 1001 (1000 already taken by base image)
RUN groupadd -g 1001 kasm-user && \
    useradd -u 1001 -g 1001 -s /bin/bash -m kasm-user && \
    usermod -aG audio kasm-user && \
    usermod -aG video kasm-user

# Set up pyenv for kasm-user
RUN echo 'export PYENV_ROOT="/opt/pyenv"' >> /home/kasm-user/.bashrc && \
    echo 'export PATH="$PYENV_ROOT/bin:$PATH"' >> /home/kasm-user/.bashrc && \
    echo 'eval "$(pyenv init --path)"' >> /home/kasm-user/.bashrc && \
    echo 'eval "$(pyenv init -)"' >> /home/kasm-user/.bashrc && \
    echo 'source /opt/venv/bin/activate' >> /home/kasm-user/.bashrc

# Create user directories
RUN mkdir -p /home/kasm-user/.vnc \
    /home/kasm-user/Desktop \
    /home/kasm-user/workspace \
    /home/kasm-user/audio \
    /home/kasm-user/projects \
    /home/kasm-user/.config/REAPER \
    /home/kasm-user/.cache/huggingface \
    /home/kasm-user/.cache/torch \
    /home/kasm-user/.cache/demucs \
    /home/kasm-user/models \
    /home/kasm-user/scripts

# Configure Reaper VST paths
RUN echo 'vstpath=/usr/lib/vst' > /home/kasm-user/.config/REAPER/reaper-vstpaths64.ini && \
    echo 'vstpath=/usr/lib/vst3' >> /home/kasm-user/.config/REAPER/reaper-vstpaths64.ini && \
    echo 'vstpath=/home/kasm-user/.vst' >> /home/kasm-user/.config/REAPER/reaper-vstpaths64.ini && \
    echo 'vstpath=/home/kasm-user/.vst3' >> /home/kasm-user/.config/REAPER/reaper-vstpaths64.ini

# Create Demucs helper script
RUN echo '#!/bin/bash\n\
# Demucs stem separation helper\n\
# Usage: ./demucs-split.sh <audio-file>\n\
source /opt/venv/bin/activate\n\
INPUT_FILE="$1"\n\
OUTPUT_DIR="${2:-./separated}"\n\
\n\
if [ -z "$INPUT_FILE" ]; then\n\
    echo "Usage: $0 <audio-file> [output-dir]"\n\
    exit 1\n\
fi\n\
\n\
echo "Separating stems from: $INPUT_FILE"\n\
demucs --two-stems=vocals "$INPUT_FILE" -o "$OUTPUT_DIR"\n\
echo "Done! Check $OUTPUT_DIR for separated stems"' > /home/kasm-user/scripts/demucs-split.sh && \
    chmod +x /home/kasm-user/scripts/demucs-split.sh

# Create audio format converter helper
RUN echo '#!/bin/bash\n\
# Audio format converter using FFmpeg\n\
# Usage: ./convert-audio.sh <input> <output>\n\
INPUT="$1"\n\
OUTPUT="$2"\n\
\n\
if [ -z "$INPUT" ] || [ -z "$OUTPUT" ]; then\n\
    echo "Usage: $0 <input-file> <output-file>"\n\
    exit 1\n\
fi\n\
\n\
ffmpeg -i "$INPUT" -ar 44100 -ac 2 -b:a 320k "$OUTPUT"' > /home/kasm-user/scripts/convert-audio.sh && \
    chmod +x /home/kasm-user/scripts/convert-audio.sh

# Fix permissions before switching to kasm-user
RUN chown -R kasm-user:kasm-user /home/kasm-user

# Set up KasmVNC password as kasm-user
USER kasm-user
RUN mkdir -p ~/.vnc && \
    printf "quickpod123\nquickpod123\n" | vncpasswd -u kasm-user -w ~/.vnc/passwd && \
    chmod 600 ~/.vnc/passwd

# Switch back to root for remaining setup
USER root

# Main startup script
RUN echo '#!/bin/bash\n\
# Activate venv\n\
source /opt/venv/bin/activate\n\
\n\
# Start PulseAudio\n\
pulseaudio -D --exit-idle-time=-1 2>/dev/null || true\n\
\n\
# Start KasmVNC as kasm-user\n\
su - kasm-user -c "vncserver :1 -depth 24 -geometry 1920x1080 -websocket 6901 -interface 0.0.0.0"\n\
\n\
echo ""\n\
echo "╔════════════════════════════════════════════════════════════╗"\n\
echo "║   CUDA 13.0 + Kasm + Reaper Desktop (Ubuntu 24.04)        ║"\n\
echo "║   AI Audio Workstation Base Image                         ║"\n\
echo "║   Access at: https://YOUR_IP:6901                         ║"\n\
echo "╚════════════════════════════════════════════════════════════╝"\n\
echo ""\n\
echo "Default password: quickpod123"\n\
echo ""\n\
echo "Python: $(python --version)"\n\
echo "GPU: $(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null || echo Detection pending...)"\n\
echo "CUDA: $(nvcc --version 2>/dev/null | grep release | awk '"'"'{print $5}'"'"' | sed '"'"'s/,//'"'"' || echo 13.0)"\n\
echo ""\n\
echo "Reaper installed at: /opt/reaper"\n\
echo "Audio projects: ~/audio"\n\
echo "General workspace: ~/workspace"\n\
echo "Helper scripts: ~/scripts"\n\
echo ""\n\
echo "Available AI Tools:"\n\
echo "  - Demucs stem separation"\n\
echo "  - Voice cloning libraries (RVC)"\n\
echo "  - Audio processing (librosa, torchaudio)"\n\
echo "  - VST plugins (LSP, Vital, Surge XT)"\n\
echo ""\n\
\n\
# Keep container running\n\
tail -f /home/kasm-user/.vnc/*.log' > /usr/local/bin/start-services.sh && \
    chmod +x /usr/local/bin/start-services.sh

# Create Reaper desktop shortcut
RUN echo '[Desktop Entry]\n\
Version=1.0\n\
Type=Application\n\
Name=Reaper\n\
Comment=Digital Audio Workstation\n\
Exec=/opt/reaper/reaper\n\
Icon=/opt/reaper/Resources/main.png\n\
Terminal=false\n\
Categories=AudioVideo;Audio;Recorder;' > /home/kasm-user/Desktop/reaper.desktop && \
    chmod +x /home/kasm-user/Desktop/reaper.desktop

# Final permission fix
RUN chown -R kasm-user:kasm-user /home/kasm-user

# Set working directory
WORKDIR /home/kasm-user

# Expose Kasm port
EXPOSE 6901

# Start services
CMD ["/usr/local/bin/start-services.sh"]
