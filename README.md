# QuickPod Reaper Base - GPU-Accelerated Desktop for Audio Production

A lightweight, GPU-accelerated Docker container providing Reaper DAW with web-based remote desktop access. Perfect foundation for audio production, plugin development, or as a base image for AI music tools.

![Docker Pulls](https://img.shields.io/docker/pulls/schnicklbob/quickpod-reaper-base)
![Docker Image Size](https://img.shields.io/docker/image-size/schnicklbob/quickpod-reaper-base)
![License](https://img.shields.io/badge/license-MIT-blue.svg)

## 🎵 What's Included

- **CUDA 13.0** - NVIDIA GPU acceleration (Ubuntu 24.04 base)
- **Reaper 7.25** - Professional Digital Audio Workstation
- **KasmVNC 1.3.2** - Web-based remote desktop (browser access, no client needed)
- **Python 3.11.9** - Managed via pyenv for easy version switching
- **Audio Stack** - PulseAudio, ALSA, JACK for professional audio routing
- **XFCE Desktop** - Lightweight, responsive desktop environment
- **Firefox & Node.js 20** - For web-based tools and development

## 🚀 Quick Start

### Prerequisites

- NVIDIA GPU (any CUDA-capable GPU)
- [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html)
- Docker and Docker Compose

### Deploy Container

docker run -d
--name reaper-desktop
--gpus all
-p 6901:6901
-e VNC_PW=quickpod123
--shm-size=8g
-v $(pwd)/workspace:/home/kasm-user/workspace
-v $(pwd)/audio:/home/kasm-user/audio
-v $(pwd)/reaper-config:/home/kasm-user/.config/REAPER
schnicklbob/quickpod-reaper-base:latest


### Access Desktop

Open browser: [**https://localhost:6901**](https://localhost:6901)  
Password: `quickpod123`

## 📦 Use as Base Image

Perfect foundation for building specialized containers:

FROM schnicklbob/quickpod-reaper-base:latest

USER root
Add your tools (RVC, MusicGen, plugins, etc.)

RUN pip install your-python-packages
Install VST plugins

COPY plugins/ /home/kasm-user/.vst3/

USER kasm-user

## 🎯 Use Cases

### Audio Production
- Professional DAW with GPU-accelerated plugins
- Remote music production from any device
- Collaborative mixing sessions

### Development
- VST plugin development and testing
- Audio ML/AI model training
- Signal processing research

### Base Image
- Foundation for AI music containers
- Custom audio production environments
- Teaching/training environments

## 📂 Directory Structure


Mounted Volumes:
├── workspace/ # General workspace
├── audio/ # Audio projects
├── projects/ # Project files
└── reaper-config/ # Persistent Reaper settings

Container Paths:
├── /opt/reaper # Reaper installation
├── /opt/pyenv # Python version manager
├── /opt/venv # Active Python virtual environment
└── /home/kasm-user # User home directory

## 🔧 Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `VNC_PW` | quickpod123 | Desktop password |
| `DISPLAY` | :1 | X11 display number |
| `CUDA_HOME` | /usr/local/cuda-13.0 | CUDA installation path |
| `PYENV_ROOT` | /opt/pyenv | Python version manager |

### Volume Mounts

**Required:**
- `/home/kasm-user/workspace` - General workspace
- `/home/kasm-user/audio` - Audio projects

**Optional:**
- `/home/kasm-user/.config/REAPER` - Reaper settings (persistence)
- `/home/kasm-user/projects` - Project files

### Custom Password

docker run -d
-e VNC_PW=mysecurepassword
... other options ...
schnicklbob/quickpod-reaper-base:latest

## 📊 System Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| GPU | CUDA-capable | RTX 2060+ |
| VRAM | 2GB | 6GB+ |
| System RAM | 8GB | 16GB+ |
| Storage | 20GB | 50GB+ |
| Network | 5 Mbps | 25 Mbps+ |

## 🛠️ Advanced Usage

### Install VST Plugins

docker exec -it reaper-desktop bash
Copy plugins to ~/.vst or ~/.vst3
Rescan in Reaper: Options → Preferences → Plug-ins → VST

### Python Development

docker exec -it reaper-desktop bash
source /opt/venv/bin/activate
pip install librosa soundfile numpy
python your_script.py

### Change Python Version

docker exec -it reaper-desktop bash
pyenv install 3.12.0
pyenv global 3.12.0

## 🐛 Troubleshooting

**GPU not detected:**

docker exec reaper-desktop nvidia-smi

**Desktop not loading:**
- Use HTTPS (not HTTP): https://localhost:6901
- Check firewall allows port 6901
- Verify GPU drivers installed on host

**Audio issues:**
- Increase `--shm-size` (8g → 16g)
- Check PulseAudio running: `docker exec reaper-desktop pulseaudio --check`

**Permission errors:**
- Files created as `kasm-user` (UID 1001)
- Adjust host permissions if needed

## 📄 Docker Compose Example

version: '3.8'

services:
reaper-desktop:
image: schnicklbob/quickpod-reaper-base:latest
container_name: reaper-desktop
deploy:
  resources:
    reservations:
      devices:
        - driver: nvidia
          count: 1
          capabilities: [gpu]

ports:
  - "6901:6901"

environment:
  - VNC_PW=quickpod123
  - DISPLAY=:1

volumes:
  - ./workspace:/home/kasm-user/workspace
  - ./audio:/home/kasm-user/audio
  - ./reaper-config:/home/kasm-user/.config/REAPER

shm_size: '8gb'
restart: unless-stopped


## 🤝 Contributing

Contributions welcome! Please open an issue or submit a PR.

## 📜 License

MIT License - See LICENSE file for details

## 🙏 Credits

- [Reaper](https://reaper.fm) - Cockos Incorporated
- [KasmVNC](https://github.com/kasmtech/KasmVNC) - Kasm Technologies
- [NVIDIA CUDA](https://developer.nvidia.com/cuda-toolkit) - NVIDIA Corporation

## 📞 Support

- GitHub Issues: [Report bugs](https://github.com/Schnicklfritz/quickpod-reaper-base/issues)
- Docker Hub: [View images](https://hub.docker.com/r/schnicklbob/quickpod-reaper-base)

