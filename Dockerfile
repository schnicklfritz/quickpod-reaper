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

# Upgrade pip in venv
RUN pip install --upgrade pip setuptools wheel

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
    /home/kasm-user/.config/REAPER

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
echo "║   Professional Audio Workstation                           ║"\n\
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
