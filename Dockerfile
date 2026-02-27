# ComfyUI Kubernetes Deployment Dockerfile
# GPU-enabled version with pre-downloaded workflow models

# Build arguments
ARG BASE_IMAGE=nvidia/cuda:12.8.0-runtime-ubuntu24.04
ARG COMFYUI_VERSION=latest
ARG MODEL_TYPE=workflow

# Stage 1: Base image with ComfyUI
FROM ${BASE_IMAGE} AS base

ARG COMFYUI_VERSION

# Prevents prompts from packages asking for user input during installation
ENV DEBIAN_FRONTEND=noninteractive
ENV PIP_PREFER_BINARY=1
ENV PYTHONUNBUFFERED=1
ENV CMAKE_BUILD_PARALLEL_LEVEL=8

# Install Python, git and other necessary tools
RUN apt-get update && apt-get install -y \
    python3.12 \
    python3.12-venv \
    python3-pip \
    git \
    wget \
    curl \
    libgl1 \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender1 \
    ffmpeg \
    && ln -sf /usr/bin/python3.12 /usr/bin/python \
    && apt-get autoremove -y \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*

# Install uv and create virtual environment
RUN wget -qO- https://astral.sh/uv/install.sh | sh \
    && ln -s /root/.local/bin/uv /usr/local/bin/uv \
    && ln -s /root/.local/bin/uvx /usr/local/bin/uvx \
    && uv venv /opt/venv

# Use the virtual environment
ENV PATH="/opt/venv/bin:${PATH}"

# Install comfy-cli and dependencies
RUN uv pip install comfy-cli pip setuptools wheel

# Install ComfyUI (GPU mode)
RUN /usr/bin/yes | comfy --workspace /comfyui install --version "${COMFYUI_VERSION}"

# Install PyTorch with CUDA support
RUN uv pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu128

WORKDIR /comfyui

# Create model directories
RUN mkdir -p models/checkpoints models/vae models/unet models/clip \
    models/text_encoders models/diffusion_models models/loras \
    models/controlnet models/embeddings models/upscale_models output

# Create extra model paths config
RUN echo "comfyui:\n\
  base_path: /comfyui\n\
\n\
# External model paths (for persistent volumes)\n\
external_models:\n\
  base_path: /runpod-volume/models\n\
  checkpoints: checkpoints\n\
  clip: clip\n\
  clip_vision: clip_vision\n\
  configs: configs\n\
  controlnet: controlnet\n\
  embeddings: embeddings\n\
  loras: loras\n\
  upscale_models: upscale_models\n\
  vae: vae\n\
  unet: unet\n" > /comfyui/extra_model_paths.yaml

WORKDIR /

# Install runtime dependencies
RUN uv pip install requests websocket-client

# Create startup script
RUN echo '#!/bin/bash\n\
set -e\n\
\n\
echo "Starting ComfyUI..."\n\
cd /comfyui\n\
\n\
# Start ComfyUI (auto-detect GPU/CPU)\n\
exec python -u main.py \\\n\
  --listen 0.0.0.0 \\\n\
  --port 8188 \\\n\
  --disable-auto-launch \\\n\
  --disable-metadata\n' > /start.sh && chmod +x /start.sh

# Expose port
EXPOSE 8188

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:8188/ || exit 1

# Default command
CMD ["/start.sh"]

# Stage 2: Download workflow models
FROM base AS downloader

ARG MODEL_TYPE=workflow

WORKDIR /comfyui

# Download Checkpoint: PrimeMix V2.1
RUN echo "Downloading primemix_v21.safetensors..." && \
    curl -fSL --retry 3 --retry-delay 5 -o models/checkpoints/primemix_v21.safetensors \
      "https://huggingface.co/Kevalon/orangecocoamix/resolve/main/primemix_v21.safetensors"

# Download ControlNet: QR Code Monster v2
RUN echo "Downloading control_v1p_sd15_qrcode_monster_v2.safetensors..." && \
    curl -fSL --retry 3 --retry-delay 5 -o models/controlnet/control_v1p_sd15_qrcode_monster_v2.safetensors \
      "https://huggingface.co/monster-labs/control_v1p_sd15_qrcode_monster/resolve/main/v2/control_v1p_sd15_qrcode_monster_v2.safetensors"

# Download ControlNet: Brightness
RUN echo "Downloading control_v1p_sd15_brightness.safetensors..." && \
    curl -fSL --retry 3 --retry-delay 5 -o models/controlnet/control_v1p_sd15_brightness.safetensors \
      "https://huggingface.co/ioclab/ioc-controlnet/resolve/main/models/control_v1p_sd15_brightness.safetensors"

# Download LoRA: add_detail
RUN echo "Downloading add_detail.safetensors..." && \
    curl -fSL --retry 3 --retry-delay 5 -o models/loras/add_detail.safetensors \
      "https://civitai.com/api/download/models/62833"

# Download VAE: blessed2
RUN echo "Downloading blessed2.vae.pt..." && \
    curl -fSL --retry 3 --retry-delay 5 -o models/vae/blessed2.vae.pt \
      "https://huggingface.co/NoCrypt/blessed_vae/resolve/main/blessed2.vae.pt"

# Download Upscale Model: 4x-UltraSharp
RUN echo "Downloading 4x-UltraSharp.pth..." && \
    curl -fSL --retry 3 --retry-delay 5 -o models/upscale_models/4x-UltraSharp.pth \
      "https://huggingface.co/Kim2091/UltraSharp/resolve/main/4x-UltraSharp.pth"

# Stage 3: Final image with models
FROM base AS final

# Copy downloaded models
COPY --from=downloader /comfyui/models /comfyui/models

WORKDIR /comfyui

# Labels
LABEL org.opencontainers.image.source="https://github.com/tk-aria/comfyui-k8s-deployment"
LABEL org.opencontainers.image.description="ComfyUI for Kubernetes with workflow models"
LABEL org.opencontainers.image.licenses="MIT"
