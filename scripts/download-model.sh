#!/bin/bash
# Download Stable Diffusion v1.5 model to the ComfyUI pod

set -e

POD_NAME=$(kubectl get pods -n default -l app=comfyui-worker -o jsonpath='{.items[0].metadata.name}')

if [ -z "$POD_NAME" ]; then
  echo "Error: No comfyui-worker pod found"
  exit 1
fi

echo "Downloading model to pod: $POD_NAME"

# Download SD 1.5 model
kubectl exec -n default "$POD_NAME" -- \
  wget -q --show-progress -O /comfyui/models/checkpoints/v1-5-pruned-emaonly.safetensors \
  "https://huggingface.co/stable-diffusion-v1-5/stable-diffusion-v1-5/resolve/main/v1-5-pruned-emaonly.safetensors"

echo "Model download complete!"
kubectl exec -n default "$POD_NAME" -- ls -lh /comfyui/models/checkpoints/
