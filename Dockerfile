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
# ESSENTIAL AUDIO TOOLS ONLY
# ============================================

# Install FFmpeg and essential audio CLI tools (combined to reduce layers)
RUN apt-get update && apt-get install -y \
    ffmpeg \
    sox \
    libsox-fmt-all \
    rubberband-cli \
    lame \
    flac \
    && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Install CORE Python libraries only (smaller subset)
RUN /opt/venv/bin/pip install --no-cache-dir \
    numpy \
    scipy \
    librosa==0.10.2 \
    soundfile \
    pydub \
    torchaudio \
    demucs \
    transformers \
    accelerate \
    && rm -rf /root/.cache/pip

# ============================================
# VST PLUGIN DIRECTORIES (no plugins yet)
# ============================================

# Create VST plugin directories (install plugins in child images)
RUN mkdir -p \
    /usr/lib/vst \
    /usr/lib/vst3 \
    /home/kasm-user/.vst \
    /home/kasm-user/.vst3 \
    /home/kasm-user/.lv2

# ============================================
# AI MODEL CACHING SETUP
# ============================================

# Set Hugging Face cache location
ENV HF_HOME=/home/kasm-user/.cache/huggingface
ENV TORCH_HOME=/home/kasm-user/.cache/torch

# Install Node.js and Firefox
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs firefox && \
    apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Install Reaper
RUN cd /tmp && \
    wget https://www.reaper.fm/files/7.x/reaper725_linux_x86_64.tar.xz && \
    tar -xf reaper725_linux_x86_64.tar.xz && \
    cd reaper_linux_x86_64 && \
    ./install-reaper.sh --install /opt/reaper --integrate-desktop --usr-local-bin-symlink && \
    cd / && rm -rf /tmp/reaper*

# Create kasm-user with UID/GID 1001 (1000 already taken by base
