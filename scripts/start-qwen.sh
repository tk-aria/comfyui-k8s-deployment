#!/bin/bash
set -e

if [ "${SKIP_MODEL_DOWNLOAD}" != "true" ]; then
    echo "Starting model download check..."
    /download-models.sh
else
    echo "SKIP_MODEL_DOWNLOAD=true, skipping model download"
fi

echo "Starting ComfyUI..."
cd /comfyui
exec python -u main.py \
  --listen 0.0.0.0 \
  --port 8188 \
  --disable-auto-launch \
  --disable-metadata
