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
    libasound2 \
    libasound2-plugins \
    alsa-utils \
    pulseaudio \
    pulseaudio-utils \
    libpulse0 \
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

# Install Python 3.12 (default in Ubuntu 24.04)
RUN apt-get update && apt-get install -y \
    python3 \
    python3-venv \
    python3-dev \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Set Python 3 as default python
RUN update-alternatives --install /usr/bin/python python /usr/bin/python3 1

# Install Node.js and development tools
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y \
    nodejs \
    git \
    vim \
    htop \
    wget \
    curl \
    build-essential \
    firefox \
    && rm -rf /var/lib/apt/lists/*

# Install Reaper
RUN cd /tmp && \
    wget https://www.reaper.fm/files/7.x/reaper725_linux_x86_64.tar.xz && \
    tar -xf reaper725_linux_x86_64.tar.xz && \
    cd reaper_linux_x86_64 && \
    ./install-reaper.sh --install /opt/reaper --integrate-desktop --usr-local-bin-symlink && \
    cd / && rm -rf /tmp/reaper*

# Upgrade pip and install PyTorch with CUDA 13.0
RUN python3 -m pip install --upgrade pip setuptools wheel && \
    pip3 install --no-cache-dir \
    torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu130

# Install vLLM
RUN pip3 install --no-cache-dir vllm

# Clone SillyTavern
RUN cd /opt && \
    git clone https://github.com/SillyTavern/SillyTavern.git && \
    cd SillyTavern && npm install --omit=dev

# Create kasm-user (matching Kasm's default user)
RUN groupadd -g 1000 kasm-user && \
    useradd -u 1000 -g 1000 -s /bin/bash -m kasm-user && \
    usermod -aG ssl-cert kasm-user 2>/dev/null || true && \
    usermod -aG audio kasm-user && \
    usermod -aG video kasm-user

# Create user directories
RUN mkdir -p /home/kasm-user/.vnc \
    /home/kasm-user/Desktop \
    /home/kasm-user/workspace \
    /home/kasm-user/audio \
    /home/kasm-user/.config/REAPER

# Set up KasmVNC for user
USER kasm-user
RUN mkdir -p ~/.vnc && \
    echo "quickpod123" | vncpasswd -f > ~/.vnc/passwd && \
    chmod 600 ~/.vnc/passwd

USER root

# Create startup and utility scripts
RUN mkdir -p /usr/local/bin

# vLLM launch script
RUN echo '#!/bin/bash\n\
export VLLM_USE_V1=0\n\
cd /opt\n\
echo "Starting vLLM server..."\n\
echo "This may take a few minutes on first run to download the model."\n\
python3 -m vllm.entrypoints.openai.api_server \\\n\
  --model ${VLLM_MODEL:-TheBloke/dolphin-2.8-mixtral-8x7b-AWQ} \\\n\
  --quantization awq \\\n\
  --host 0.0.0.0 \\\n\
  --port 8000 \\\n\
  --max-model-len ${MAX_CONTEXT:-32768}' > /usr/local/bin/start-vllm && \
    chmod +x /usr/local/bin/start-vllm

# SillyTavern launch script
RUN echo '#!/bin/bash\n\
cd /opt/SillyTavern\n\
echo "Starting SillyTavern..."\n\
echo "Access at: http://localhost:8001"\n\
node server.js' > /usr/local/bin/start-sillytavern && \
    chmod +x /usr/local/bin/start-sillytavern

# Main startup script with KasmVNC
RUN echo '#!/bin/bash\n\
# Start PulseAudio\n\
pulseaudio -D --exit-idle-time=-1 2>/dev/null || true\n\
\n\
# Start KasmVNC as kasm-user\n\
su - kasm-user -c "vncserver :1 -depth 24 -geometry 1920x1080 -websocket 6901 -interface 0.0.0.0"\n\
\n\
echo ""\n\
echo "╔════════════════════════════════════════════════════════════╗"\n\
echo "║   CUDA 13.0 + Kasm + Reaper Desktop (Ubuntu 24.04)        ║"\n\
echo "║   Access at: https://YOUR_IP:6901                         ║"\n\
echo "╚════════════════════════════════════════════════════════════╝"\n\
echo ""\n\
echo "Default password: quickpod123"\n\
echo ""\n\
echo "Desktop shortcuts available for:"\n\
echo "  - Reaper (audio workstation)"\n\
echo "  - Start vLLM (LLM server)"\n\
echo "  - Start SillyTavern (chat interface)"\n\
echo ""\n\
echo "GPU: $(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null || echo Detection pending...)"\n\
echo "CUDA: $(nvcc --version 2>/dev/null | grep release | awk '"'"'{print $5}'"'"' | sed '"'"'s/,//'"'"' || echo 13.0)"\n\
echo ""\n\
\n\
# Keep container running\n\
tail -f /home/kasm-user/.vnc/*.log' > /usr/local/bin/start-services.sh && \
    chmod +x /usr/local/bin/start-services.sh

# Create desktop shortcuts
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

RUN echo '[Desktop Entry]\n\
Version=1.0\n\
Type=Application\n\
Name=Start vLLM\n\
Comment=Launch vLLM LLM Server\n\
Exec=xfce4-terminal -e /usr/local/bin/start-vllm\n\
Icon=utilities-terminal\n\
Terminal=false\n\
Categories=Development;' > /home/kasm-user/Desktop/start-vllm.desktop && \
    chmod +x /home/kasm-user/Desktop/start-vllm.desktop

RUN echo '[Desktop Entry]\n\
Version=1.0\n\
Type=Application\n\
Name=Start SillyTavern\n\
Comment=Launch SillyTavern Web UI\n\
Exec=xfce4-terminal -e /usr/local/bin/start-sillytavern\n\
Icon=utilities-terminal\n\
Terminal=false\n\
Categories=Development;' > /home/kasm-user/Desktop/start-sillytavern.desktop && \
    chmod +x /home/kasm-user/Desktop/start-sillytavern.desktop

# Fix all permissions
RUN chown -R kasm-user:kasm-user /home/kasm-user

# Set working directory
WORKDIR /home/kasm-user

# Expose ports
EXPOSE 6901 8000 8001

# Start services
CMD ["/usr/local/bin/start-services.sh"]
