# ============================================
# STAGE 1: Base System + Desktop
# ============================================
FROM nvidia/cuda:13.0.1-runtime-ubuntu24.04 AS base-system

USER root
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies with aggressive cleanup
RUN apt-get update && apt-get install -y \
    software-properties-common wget curl gnupg2 ca-certificates \
    xfce4 xfce4-goodies dbus-x11 xorg \
    libasound2t64 alsa-utils pulseaudio pulseaudio-utils libjack-jackd2-0 \
    xdotool libfontconfig1 libfreetype6 libx11-6 libxcb1 libxext6 libxrender1 libxi6 libxrandr2 \
    && cd /tmp \
    && wget https://github.com/kasmtech/KasmVNC/releases/download/v1.3.2/kasmvncserver_noble_1.3.2_amd64.deb \
    && apt-get install -y ./kasmvncserver_noble_1.3.2_amd64.deb \
    && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /root/.cache/*

# Generate SSL certificate for KasmVNC
RUN mkdir -p /etc/ssl/private \
    && openssl req -x509 -nodes -newkey rsa:2048 \
    -keyout /etc/ssl/private/ssl-cert-snakeoil.key \
    -out /etc/ssl/certs/ssl-cert-snakeoil.pem \
    -days 3650 -subj "/CN=kasmvnc" \
    && chmod 640 /etc/ssl/private/ssl-cert-snakeoil.key

# ============================================
# STAGE 2: Python Environment
# ============================================
FROM base-system AS python-env

# Install pyenv dependencies
RUN apt-get update && apt-get install -y \
    make build-essential libssl-dev zlib1g-dev libbz2-dev libreadline-dev \
    libsqlite3-dev llvm libncurses5-dev libncursesw5-dev xz-utils tk-dev \
    libffi-dev liblzma-dev git vim htop \
    && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Install pyenv
ENV PYENV_ROOT="/opt/pyenv"
ENV PATH="$PYENV_ROOT/bin:$PATH"

RUN git clone --depth 1 https://github.com/pyenv/pyenv.git $PYENV_ROOT \
    && cd $PYENV_ROOT && src/configure && make -C src \
    && rm -rf $PYENV_ROOT/.git

# Install Python and create venv
RUN eval "$(pyenv init --path)" && eval "$(pyenv init -)" \
    && pyenv install 3.11.9 && pyenv global 3.11.9

ENV PATH="$PYENV_ROOT/versions/3.11.9/bin:$PATH"

RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

RUN pip install --no-cache-dir --upgrade pip setuptools wheel \
    && rm -rf /root/.cache/pip

# ============================================
# STAGE 3: Audio Tools + Python Libs
# ============================================
FROM python-env AS audio-tools

# Install audio tools and Node.js
RUN apt-get update && apt-get install -y \
    ffmpeg sox libsox-fmt-all rubberband-cli lame flac firefox \
    && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Install Python libraries with aggressive cleanup
RUN pip install --no-cache-dir numpy scipy \
    && rm -rf /root/.cache/pip /tmp/* /var/tmp/*

RUN pip install --no-cache-dir librosa==0.10.2 soundfile pydub \
    && rm -rf /root/.cache/pip /tmp/* /var/tmp/*

# Install PyTorch with CUDA support and aggressive cleanup
RUN pip install --no-cache-dir torch torchvision torchaudio \
    && rm -rf /root/.cache/pip /tmp/* /var/tmp/* \
    && find /opt/venv -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true \
    && find /opt/venv -type f -name "*.pyc" -delete \
    && find /opt/venv -type f -name "*.pyo" -delete

RUN pip install --no-cache-dir demucs transformers accelerate \
    && rm -rf /root/.cache/pip /tmp/* /var/tmp/* \
    && find /opt/venv -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true \
    && find /opt/venv -type f -name "*.pyc" -delete

# ============================================
# STAGE 4: Final Assembly
# ============================================
FROM audio-tools AS final

# Install Reaper
RUN cd /tmp \
    && wget https://www.reaper.fm/files/7.x/reaper725_linux_x86_64.tar.xz \
    && tar -xf reaper725_linux_x86_64.tar.xz \
    && cd reaper_linux_x86_64 \
    && ./install-reaper.sh --install /opt/reaper --integrate-desktop --usr-local-bin-symlink \
    && cd / && rm -rf /tmp/*

# Create kasm-user
RUN groupadd -g 1001 kasm-user \
    && useradd -u 1001 -g 1001 -s /bin/bash -m kasm-user \
    && usermod -aG audio,video kasm-user

# Set up user environment
RUN echo 'export PYENV_ROOT="/opt/pyenv"' >> /home/kasm-user/.bashrc \
    && echo 'export PATH="$PYENV_ROOT/bin:$PATH"' >> /home/kasm-user/.bashrc \
    && echo 'eval "$(pyenv init --path)"' >> /home/kasm-user/.bashrc \
    && echo 'eval "$(pyenv init -)"' >> /home/kasm-user/.bashrc \
    && echo 'source /opt/venv/bin/activate' >> /home/kasm-user/.bashrc

# Create directories
RUN mkdir -p /home/kasm-user/{.vnc,Desktop,workspace,audio,projects,scripts,models} \
    /home/kasm-user/.config/REAPER \
    /home/kasm-user/.cache/{huggingface,torch
# Create directories
RUN mkdir -p /home/kasm-user/{.vnc,Desktop,workspace,audio,projects,scripts,models} \
    /home/kasm-user/.config/REAPER \
    /home/kasm-user/.cache/{huggingface,torch} \
    && chown -R kasm-user:kasm-user /home/kasm-user

# Fix KasmVNC interactive prompt issue
RUN mkdir -p /home/kasm-user/.vnc && \
    echo -e "kasm\nkasm\n" | vncpasswd -u kasm-user -w && \
    echo "write_users=kasm-user" >> /home/kasm-user/.vnc/kasmvnc.yaml && \
    chown -R kasm-user:kasm-user /home/kasm-user/.vnc

# Install net-tools for debugging
RUN apt-get update && apt-get install -y net-tools && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Copy QuickPod scripts
COPY opt/quickpod/bin /opt/quickpod/bin
RUN chmod -R +x /opt/quickpod/bin && mkdir -p /var/log/quickpod
COPY usr/local/bin/quickpod-entrypoint.sh /usr/local/bin/quickpod-entrypoint.sh
RUN chmod +x /usr/local/bin/quickpod-entrypoint.sh
ENTRYPOINT ["/usr/local/bin/quickpod-entrypoint.sh"]



COPY opt/quickpod/bin /opt/quickpod/bin
RUN chmod -R +x /opt/quickpod/bin && mkdir -p /var/log/quickpod
COPY usr/local/bin/quickpod-entrypoint.sh /usr/local/bin/quickpod-entrypoint.sh
RUN chmod +x /usr/local/bin/quickpod-entrypoint.sh
ENTRYPOINT ["/usr/local/bin/quickpod-entrypoint.sh"]
