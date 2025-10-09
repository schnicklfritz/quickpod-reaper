FROM kasmweb/core-ubuntu-focal:1.15.0

USER root

# Install NVIDIA CUDA 13.0
RUN wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64/cuda-keyring_1.1-1_all.deb && \
    dpkg -i cuda-keyring_1.1-1_all.deb && \
    apt-get update && \
    apt-get install -y cuda-toolkit-13-0 && \
    rm cuda-keyring_1.1-1_all.deb

# Set CUDA environment variables
ENV PATH=/usr/local/cuda-13.0/bin:${PATH}
ENV LD_LIBRARY_PATH=/usr/local/cuda-13.0/lib64:${LD_LIBRARY_PATH}
ENV CUDA_HOME=/usr/local/cuda-13.0

# Install audio dependencies for Reaper
RUN apt-get install -y \
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
    libxrandr2

# Install Python 3.11, Node.js, and development tools
RUN apt-get install -y \
    software-properties-common && \
    add-apt-repository ppa:deadsnakes/ppa && \
    apt-get update && \
    apt-get install -y \
    python3.11 \
    python3.11-venv \
    python3.11-dev \
    python3-pip \
    git \
    nodejs \
    npm \
    firefox \
    vim \
    htop \
    wget \
    curl \
    build-essential

# Update alternatives to use Python 3.11
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1 && \
    update-alternatives --install /usr/bin/python python /usr/bin/python3.11 1

# Install Reaper
RUN cd /tmp && \
    wget https://www.reaper.fm/files/7.x/reaper725_linux_x86_64.tar.xz && \
    tar -xf reaper725_linux_x86_64.tar.xz && \
    cd reaper_linux_x86_64 && \
    ./install-reaper.sh --install /opt/reaper --integrate-desktop --usr-local-bin-symlink && \
    cd / && rm -rf /tmp/reaper*

# Upgrade pip and install PyTorch with CUDA 13.0 support
RUN python3 -m pip install --upgrade pip setuptools wheel && \
    pip3 install --no-cache-dir \
    torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu130

# Install vLLM
RUN pip3 install --no-cache-dir vllm

# Clone SillyTavern
RUN cd /opt && \
    git clone https://github.com/SillyTavern/SillyTavern.git && \
    cd SillyTavern && npm install --omit=dev

# Create utility scripts
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

# Service startup script
RUN echo '#!/bin/bash\n\
# Start PulseAudio for Reaper audio support\n\
pulseaudio -D --exit-idle-time=-1 2>/dev/null || true\n\
\n\
# Auto-start services (optional - comment out to start manually)\n\
# nohup /usr/local/bin/start-vllm > /var/log/vllm.log 2>&1 &\n\
# sleep 5\n\
# nohup /usr/local/bin/start-sillytavern > /var/log/sillytavern.log 2>&1 &\n\
\n\
echo "CUDA + Kasm + Reaper Desktop Ready"\n\
echo "===================================="\n\
echo "Reaper: Double-click desktop icon"\n\
echo "vLLM: Run '\''start-vllm'\'' in terminal"\n\
echo "SillyTavern: Run '\''start-sillytavern'\'' in terminal"\n\
echo "===================================="\n\
\n\
tail -f /dev/null' > /usr/local/bin/start-services.sh && \
    chmod +x /usr/local/bin/start-services.sh

# Create desktop shortcuts for kasm-user
RUN mkdir -p /home/kasm-user/Desktop

# Reaper desktop shortcut
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

# Start vLLM desktop shortcut
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

# Start SillyTavern desktop shortcut
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

# Create welcome message script
RUN echo '#!/bin/bash\n\
cat << EOF\n\
\n\
╔════════════════════════════════════════════════════════════╗\n\
║   CUDA 13.0 + Kasm + Reaper Desktop Environment           ║\n\
║   Ready for LLM inference and voice cloning workflows     ║\n\
╚════════════════════════════════════════════════════════════╝\n\
\n\
Quick Start:\n\
  1. Double-click "Reaper" icon for audio workstation\n\
  2. Double-click "Start vLLM" to launch LLM server\n\
  3. Double-click "Start SillyTavern" to launch web UI\n\
  4. Open Firefox and go to http://localhost:8001\n\
\n\
GPU: $(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null || echo "Detection pending...")\n\
CUDA: $(nvcc --version 2>/dev/null | grep release | awk "{print \\$5}" | sed "s/,//" || echo "13.0")\n\
\n\
Useful Commands:\n\
  start-vllm              Start LLM inference server\n\
  start-sillytavern       Start SillyTavern web interface\n\
  nvidia-smi              Check GPU status\n\
  htop                    Monitor system resources\n\
\n\
EOF' > /usr/local/bin/welcome && \
    chmod +x /usr/local/bin/welcome

# Fix permissions
RUN chown -R kasm-user:kasm-user /home/kasm-user/Desktop && \
    mkdir -p /home/kasm-user/workspace /home/kasm-user/audio && \
    chown -R kasm-user:kasm-user /home/kasm-user/workspace /home/kasm-user/audio

USER kasm-user

# Set working directory
WORKDIR /home/kasm-user

# Expose ports
EXPOSE 6901 8000 8001

# Default command
CMD ["/usr/local/bin/start-services.sh"]
