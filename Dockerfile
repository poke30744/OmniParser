# Multi-stage build for OmniParser Server
FROM nvidia/cuda:12.1.0-cudnn8-runtime-ubuntu22.04 AS base

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1

# Install Python 3.12 from deadsnakes PPA
RUN apt-get update && apt-get install -y --no-install-recommends \
    software-properties-common \
    && add-apt-repository ppa:deadsnakes/ppa -y \
    && apt-get update && apt-get install -y --no-install-recommends \
    python3.12 \
    python3.12-venv \
    python3.12-dev \
    python3-pip \
    git \
    libgl1-mesa-glx \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender-dev \
    libgomp1 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Stage 2: Build dependencies
FROM base AS builder

WORKDIR /build

# Copy requirements first for better caching
COPY requirements.txt .

# Create virtual environment and install dependencies
RUN python3.12 -m venv /opt/venv && \
    . /opt/venv/bin/activate && \
    pip install --no-cache-dir --upgrade pip setuptools wheel && \
    pip install --no-cache-dir -r requirements.txt && \
    rm -rf /tmp/* /var/tmp/*

# Stage 3: Final runtime image
FROM base AS runtime

WORKDIR /app

# Copy Python virtual environment from builder
COPY --from=builder /opt/venv /opt/venv

# Activate virtual environment
ENV PATH="/opt/venv/bin:$PATH" \
    VIRTUAL_ENV="/opt/venv"

# Copy application code
COPY . .

# Create weights directory
RUN mkdir -p /app/weights

# Download model weights
RUN python -c "from huggingface_hub import hf_hub_download; \
    import os; \
    files = ['icon_detect/train_args.yaml', 'icon_detect/model.pt', 'icon_detect/model.yaml', \
             'icon_caption/config.json', 'icon_caption/generation_config.json', 'icon_caption/model.safetensors']; \
    [hf_hub_download(repo_id='microsoft/OmniParser-v2.0', filename=f, local_dir='/app/weights') for f in files]" && \
    mv /app/weights/icon_caption /app/weights/icon_caption_florence && \
    # Clean up cache
    rm -rf ~/.cache/huggingface/* /tmp/* /var/tmp/*

# Expose API port
EXPOSE 8000

# Set working directory for the module
WORKDIR /app/omnitool/omniparserserver

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/probe/')"

# Default command to run the server
CMD ["python", "-m", "omniparserserver", \
     "--som_model_path", "../../weights/icon_detect/model.pt", \
     "--caption_model_name", "florence2", \
     "--caption_model_path", "../../weights/icon_caption_florence", \
     "--device", "cuda", \
     "--BOX_TRESHOLD", "0.05", \
     "--host", "0.0.0.0", \
     "--port", "8000"]
