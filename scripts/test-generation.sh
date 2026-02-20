#!/bin/bash
# Test image generation via ComfyUI API

set -e

COMFYUI_URL="${COMFYUI_URL:-http://comfyui-worker.default.svc.cluster.local:80}"

# Create workflow JSON
WORKFLOW=$(cat <<'EOF'
{
  "prompt": {
    "3": {
      "class_type": "KSampler",
      "inputs": {
        "cfg": 7,
        "denoise": 1,
        "latent_image": ["5", 0],
        "model": ["4", 0],
        "negative": ["7", 0],
        "positive": ["6", 0],
        "sampler_name": "euler",
        "scheduler": "normal",
        "seed": 12345,
        "steps": 8
      }
    },
    "4": {
      "class_type": "CheckpointLoaderSimple",
      "inputs": {
        "ckpt_name": "v1-5-pruned-emaonly.safetensors"
      }
    },
    "5": {
      "class_type": "EmptyLatentImage",
      "inputs": {
        "batch_size": 1,
        "height": 256,
        "width": 256
      }
    },
    "6": {
      "class_type": "CLIPTextEncode",
      "inputs": {
        "clip": ["4", 1],
        "text": "a beautiful sunset over the ocean"
      }
    },
    "7": {
      "class_type": "CLIPTextEncode",
      "inputs": {
        "clip": ["4", 1],
        "text": "blurry, bad quality"
      }
    },
    "8": {
      "class_type": "VAEDecode",
      "inputs": {
        "samples": ["3", 0],
        "vae": ["4", 2]
      }
    },
    "9": {
      "class_type": "SaveImage",
      "inputs": {
        "filename_prefix": "test_output",
        "images": ["8", 0]
      }
    }
  }
}
EOF
)

echo "Submitting prompt to $COMFYUI_URL/prompt ..."
RESULT=$(curl -s -X POST "$COMFYUI_URL/prompt" \
  -H "Content-Type: application/json" \
  -d "$WORKFLOW")

echo "Result: $RESULT"

PROMPT_ID=$(echo "$RESULT" | grep -o '"prompt_id": "[^"]*"' | cut -d'"' -f4)

if [ -z "$PROMPT_ID" ]; then
  echo "Error: Failed to get prompt_id"
  exit 1
fi

echo "Prompt ID: $PROMPT_ID"
echo "Waiting for generation to complete..."

sleep 60

echo "Checking result..."
curl -s "$COMFYUI_URL/history/$PROMPT_ID"
