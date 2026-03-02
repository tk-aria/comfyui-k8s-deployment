#!/bin/bash
set -e

MODEL_DIR="/comfyui/models"

download_if_missing() {
    local dest="$1"
    local url="$2"
    local name=$(basename "$dest")

    if [ -f "$dest" ]; then
        local size=$(stat -c%s "$dest" 2>/dev/null || echo 0)
        if [ "$size" -gt 1000000 ]; then
            echo "[SKIP] $name already exists ($(numfmt --to=iec $size))"
            return 0
        fi
        echo "[WARN] $name exists but too small (${size}B), re-downloading..."
        rm -f "$dest"
    fi

    echo "[DL] Downloading $name ..."
    mkdir -p "$(dirname "$dest")"
    curl -fSL --retry 3 --retry-delay 5 -o "$dest" "$url"
    local size=$(stat -c%s "$dest" 2>/dev/null || echo 0)
    echo "[OK] $name downloaded ($(numfmt --to=iec $size))"
}

echo "=========================================="
echo " ComfyUI Model Downloader"
echo " Z-Image-Turbo / Qwen-Image-Edit / Qwen-Image-Layered"
echo "=========================================="

# --- Z-Image-Turbo (nvfp4 quantized, ~4.5GB) ---
download_if_missing "$MODEL_DIR/diffusion_models/z_image_turbo_nvfp4.safetensors" \
    "https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/diffusion_models/z_image_turbo_nvfp4.safetensors"

download_if_missing "$MODEL_DIR/text_encoders/qwen_3_4b_fp4_mixed.safetensors" \
    "https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/text_encoders/qwen_3_4b_fp4_mixed.safetensors"

download_if_missing "$MODEL_DIR/vae/ae.safetensors" \
    "https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/vae/ae.safetensors"

# --- Qwen-Image-Edit 2511 (fp8 mixed, ~20.5GB) ---
download_if_missing "$MODEL_DIR/diffusion_models/qwen_image_edit_2511_fp8mixed.safetensors" \
    "https://huggingface.co/Comfy-Org/Qwen-Image-Edit_ComfyUI/resolve/main/split_files/diffusion_models/qwen_image_edit_2511_fp8mixed.safetensors"

# Shared text encoder for Qwen-Image-Edit & Layered (fp8, ~9.4GB)
download_if_missing "$MODEL_DIR/text_encoders/qwen_2.5_vl_7b_fp8_scaled.safetensors" \
    "https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/text_encoders/qwen_2.5_vl_7b_fp8_scaled.safetensors"

download_if_missing "$MODEL_DIR/vae/qwen_image_vae.safetensors" \
    "https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/vae/qwen_image_vae.safetensors"

# --- Qwen-Image-Layered (fp8 mixed, ~20.5GB) ---
download_if_missing "$MODEL_DIR/diffusion_models/qwen_image_layered_fp8mixed.safetensors" \
    "https://huggingface.co/Comfy-Org/Qwen-Image-Layered_ComfyUI/resolve/main/split_files/diffusion_models/qwen_image_layered_fp8mixed.safetensors"

download_if_missing "$MODEL_DIR/vae/qwen_image_layered_vae.safetensors" \
    "https://huggingface.co/Comfy-Org/Qwen-Image-Layered_ComfyUI/resolve/main/split_files/vae/qwen_image_layered_vae.safetensors"

echo "=========================================="
echo " All models ready!"
echo "=========================================="
