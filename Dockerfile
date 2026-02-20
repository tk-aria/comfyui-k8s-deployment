# ComfyUI Kubernetes Deployment Dockerfile
# CPU-optimized version based on runpod-workers/worker-comfyui

# Build arguments
ARG BASE_IMAGE=ubuntu:24.04
ARG COMFYUI_VERSION=latest
ARG MODEL_TYPE=none

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

# Install ComfyUI (CPU mode - no CUDA)
RUN /usr/bin/yes | comfy --workspace /comfyui install --version "${COMFYUI_VERSION}" --cpu

# Install PyTorch CPU version
RUN uv pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu

WORKDIR /comfyui

# Create model directories
RUN mkdir -p models/checkpoints models/vae models/unet models/clip \
    models/text_encoders models/diffusion_models models/loras \
    models/controlnet models/embeddings output

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
# Start ComfyUI with CPU mode\n\
exec python -u main.py \\\n\
  --listen 0.0.0.0 \\\n\
  --port 8188 \\\n\
  --disable-auto-launch \\\n\
  --disable-metadata \\\n\
  --cpu\n' > /start.sh && chmod +x /start.sh

# Expose port
EXPOSE 8188

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:8188/ || exit 1

# Default command
CMD ["/start.sh"]

# Stage 2: Download models (optional)
FROM base AS downloader

ARG MODEL_TYPE=none
ARG HUGGINGFACE_ACCESS_TOKEN=""

WORKDIR /comfyui

# Download SD 1.5 model if specified
RUN if [ "$MODEL_TYPE" = "sd15" ]; then \
      echo "Downloading Stable Diffusion 1.5..." && \
      wget -q --show-progress -O models/checkpoints/v1-5-pruned-emaonly.safetensors \
        "https://huggingface.co/stable-diffusion-v1-5/stable-diffusion-v1-5/resolve/main/v1-5-pruned-emaonly.safetensors"; \
    fi

# Download SDXL model if specified
RUN if [ "$MODEL_TYPE" = "sdxl" ]; then \
      echo "Downloading SDXL..." && \
      wget -q -O models/checkpoints/sd_xl_base_1.0.safetensors \
        "https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/resolve/main/sd_xl_base_1.0.safetensors" && \
      wget -q -O models/vae/sdxl_vae.safetensors \
        "https://huggingface.co/stabilityai/sdxl-vae/resolve/main/sdxl_vae.safetensors"; \
    fi

# Stage 3: Final image (without models - models should be mounted via PVC)
FROM base AS final

# Copy any downloaded models if they exist
COPY --from=downloader /comfyui/models /comfyui/models

WORKDIR /comfyui

# Labels
LABEL org.opencontainers.image.source="https://github.com/tk-aria/comfyui-k8s-deployment"
LABEL org.opencontainers.image.description="ComfyUI for Kubernetes (CPU mode)"
LABEL org.opencontainers.image.licenses="MIT"
