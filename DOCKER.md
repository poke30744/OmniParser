# OmniParser Docker 部署

## ⚠️ 注意
此 Docker 需要 **NVIDIA GPU + Linux**，macOS 无法构建。

## 快速开始（Linux 机器上）

### 1. 前置要求
```bash
# 验证 GPU 驱动
nvidia-smi

# 安装 NVIDIA Container Toolkit（如未安装）
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -
curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | sudo tee /etc/apt/sources.list.d/nvidia-docker.list
sudo apt-get update && sudo apt-get install -y nvidia-container-toolkit
sudo systemctl restart docker
```

### 2. 构建并运行
```bash
# 一条命令完成（会自动构建镜像）
docker compose up -d

# 查看日志
docker compose logs -f

# 验证
curl http://localhost:8000/probe/
```

### 3. 管理命令
```bash
# 停止
docker compose down

# 重启
docker compose restart

# 强制重新构建
docker compose up -d --build
```

## Dockerfile 优化

- ✅ 使用 deadsnakes PPA 安装 Python 3.12
- ✅ 多阶段构建减小镜像体积
- ✅ 自动清理 apt/pip/huggingface cache
- ✅ 层缓存优化（requirements.txt 先复制）
- ✅ 自动下载模型权重
- ✅ 健康检查和自动重启

## 从 macOS 传输到 Linux

```bash
# 方法 1: rsync
rsync -avz --exclude='.venv' --exclude='__pycache__' \
    . user@linux-server:/path/to/OmniParser/

# 方法 2: git
git add Dockerfile .dockerignore docker-compose.yml DOCKER.md
git commit -m "Add Docker support"
git push
# 然后在 Linux 上 git pull
```

## API 使用示例

```python
import requests
import base64

with open("screenshot.png", "rb") as f:
    image_data = base64.b64encode(f.read()).decode()

response = requests.post(
    "http://localhost:8000/parse/",
    json={"base64_image": image_data}
)

print(response.json())
```

## 故障排查

```bash
# GPU 不可用
docker run --rm --gpus all nvidia/cuda:12.1.0-base-ubuntu22.04 nvidia-smi

# 查看容器日志
docker compose logs omniparser-server

# 进入容器调试
docker compose exec omniparser-server bash
```
