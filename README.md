# ComfyUI Kubernetes Deployment

ComfyUI を Kubernetes にデプロイするためのマニフェストとスクリプト集です。

## 概要

- **イメージ**: `runpod/worker-comfyui:5.7.1-base`
- **モード**: GPU推論 (CPU fallback対応)
- **モデル**: Stable Diffusion v1.5

## ディレクトリ構成

```
.
├── k8s/
│   ├── deployment.yaml     # Deployment マニフェスト (自動GPU/CPU検出)
│   ├── deployment-gpu.yaml # GPU専用Deployment (nvidia.com/gpu要求)
│   ├── service.yaml        # Service マニフェスト
│   ├── pvc.yaml            # PersistentVolumeClaim (オプション)
│   └── kustomization.yaml  # Kustomize設定
├── scripts/
│   ├── download-model.sh  # モデルダウンロードスクリプト
│   └── test-generation.sh # 画像生成テストスクリプト
└── README.md
```

## デプロイ方法

### 1. Kubernetes マニフェストの適用

```bash
kubectl apply -k k8s/
```

または個別に:

```bash
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
```

### 2. モデルのダウンロード

Pod起動後、SD1.5モデルをダウンロード:

```bash
chmod +x scripts/download-model.sh
./scripts/download-model.sh
```

### 3. 動作確認

```bash
# Pod状態確認
kubectl get pods -l app=comfyui-worker

# ログ確認
kubectl logs -l app=comfyui-worker -f

# 画像生成テスト
chmod +x scripts/test-generation.sh
./scripts/test-generation.sh
```

## API エンドポイント

| エンドポイント | 説明 |
|---------------|------|
| `GET /` | Web UI |
| `GET /system_stats` | システム情報 |
| `GET /object_info/{node_type}` | ノード情報 |
| `POST /prompt` | 画像生成リクエスト |
| `GET /history/{prompt_id}` | 生成履歴 |
| `GET /queue` | キュー状態 |

### 画像生成例

```bash
curl -X POST http://comfyui-worker.default.svc.cluster.local:80/prompt \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": {
      "4": {
        "class_type": "CheckpointLoaderSimple",
        "inputs": {"ckpt_name": "v1-5-pruned-emaonly.safetensors"}
      },
      "5": {
        "class_type": "EmptyLatentImage",
        "inputs": {"batch_size": 1, "height": 512, "width": 512}
      },
      "6": {
        "class_type": "CLIPTextEncode",
        "inputs": {"clip": ["4", 1], "text": "a beautiful landscape"}
      },
      "7": {
        "class_type": "CLIPTextEncode",
        "inputs": {"clip": ["4", 1], "text": "ugly, blurry"}
      },
      "3": {
        "class_type": "KSampler",
        "inputs": {
          "model": ["4", 0], "positive": ["6", 0], "negative": ["7", 0],
          "latent_image": ["5", 0], "seed": 42, "steps": 20,
          "cfg": 7, "sampler_name": "euler", "scheduler": "normal", "denoise": 1
        }
      },
      "8": {
        "class_type": "VAEDecode",
        "inputs": {"samples": ["3", 0], "vae": ["4", 2]}
      },
      "9": {
        "class_type": "SaveImage",
        "inputs": {"images": ["8", 0], "filename_prefix": "output"}
      }
    }
  }'
```

## リソース要件

### 通常モード (deployment.yaml)

| リソース | Request | Limit |
|---------|---------|-------|
| CPU | 10m | 500m |
| Memory | 2Gi | 8Gi |

### GPUモード (deployment-gpu.yaml)

| リソース | Request | Limit |
|---------|---------|-------|
| CPU | 10m | 4 |
| Memory | 2Gi | 16Gi |
| nvidia.com/gpu | 1 | 1 |

**注意**: SD1.5モデルの読み込みと推論には最低4GBのメモリが必要です。

## GPU対応デプロイ

GPUノードが利用可能な場合、GPU専用のDeploymentを使用:

```bash
kubectl apply -f k8s/deployment-gpu.yaml
kubectl apply -f k8s/service.yaml
```

GPUを使用する場合の前提条件:
- NVIDIA GPU Driver インストール済み
- NVIDIA Device Plugin for Kubernetes デプロイ済み
- `nvidia.com/gpu` リソースが利用可能

## トラブルシューティング

### OOMエラー (CrashLoopBackOff)

メモリ不足の場合、Deploymentのリソース制限を増やしてください:

```bash
kubectl patch deployment comfyui-worker --type='json' -p='[
  {"op": "replace", "path": "/spec/template/spec/containers/0/resources/limits/memory", "value": "12Gi"}
]'
```

### モデル読み込みエラー

モデルファイルが破損している可能性があります。再ダウンロードしてください:

```bash
kubectl exec -n default deployment/comfyui-worker -- \
  rm -f /comfyui/models/checkpoints/v1-5-pruned-emaonly.safetensors

./scripts/download-model.sh
```

## ライセンス

MIT License
