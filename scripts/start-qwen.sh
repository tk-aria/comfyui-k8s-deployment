#!/bin/bash
set -e

echo "Starting model download check..."
/download-models.sh

echo "Starting ComfyUI..."
cd /comfyui
exec python -u main.py \
  --listen 0.0.0.0 \
  --port 8188 \
  --disable-auto-launch \
  --disable-metadata
