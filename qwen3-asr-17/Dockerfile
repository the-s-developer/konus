FROM nvidia/cuda:12.4.1-cudnn-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 python3-pip python3-dev \
    git ffmpeg libsndfile1 \
    && rm -rf /var/lib/apt/lists/*

RUN pip3 install --no-cache-dir --upgrade pip

# PyTorch with CUDA 12.4
RUN pip3 install --no-cache-dir \
    torch torchaudio \
    --index-url https://download.pytorch.org/whl/cu124

# Qwen3-ASR
RUN pip3 install --no-cache-dir qwen-asr

# Server dependencies
RUN pip3 install --no-cache-dir \
    fastapi "uvicorn[standard]" python-multipart

WORKDIR /app
COPY server.py .

EXPOSE 8000
CMD ["python3", "server.py"]
