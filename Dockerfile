
# RunPod PyTorch 2.8 / CUDA 12.8 base
# Confirm this tag matches the currently working template.
FROM runpod/pytorch:1.0.2-cu1281-torch280-ubuntu2404

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV MAMBA_ROOT_PREFIX=/opt/fyp/mamba \
    PIP_NO_CACHE_DIR=1 \
    HF_HOME=/workspace/.cache/huggingface \
    HF_HUB_CACHE=/workspace/.cache/huggingface/hub

# Fail rather than silently build against the wrong PyTorch.
RUN python -c "import torch; assert torch.__version__.startswith('2.8.0'), torch.__version__"

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      curl ca-certificates bzip2 && \
    rm -rf /var/lib/apt/lists/*

# iLLaDA Python environment
# Reuse PyTorch from the base image.
RUN python -m venv \
      --system-site-packages /opt/fyp/illada-venv && \
    /opt/fyp/illada-venv/bin/python -m pip install \
      --no-cache-dir \
      transformers==4.53.2 \
      accelerate==1.15.0 \
      huggingface-hub==0.36.2 \
      safetensors==0.8.0 \
      fastapi==0.165.0 \
      uvicorn==0.54.0 \
      einops==0.8.2 \
      sentencepiece==0.2.3 \
      protobuf==7.36.2 \
      requests

# Install Micromamba for AgentBoard Python 3.8
RUN curl -fLsS \
      https://micro.mamba.pm/api/micromamba/linux-64/latest \
      | tar -xj -C /usr/local/bin \
          --strip-components=1 bin/micromamba && \
    micromamba create -y \
      -p /opt/fyp/agentboard-env \
      -c conda-forge \
      python=3.8.20 pip=24.3.1

# AgentBoard and BabyAI dependencies
RUN /opt/fyp/agentboard-env/bin/python -m pip install \
      --no-cache-dir \
      numpy==1.24.4 \
      gym==0.24.0 \
      gymnasium==0.29.1 \
      minigrid==2.3.0 \
      matplotlib==3.7.5 \
      pygame==2.5.2 \
      Pillow==10.4.0 \
      requests==2.32.4 \
      PyYAML==6.0.3 \
      python-dotenv==1.0.1 \
      tqdm==4.70.1 \
      jsonlines==4.0.0

# Verify installed environments during image build
RUN /opt/fyp/illada-venv/bin/python -c \
      "import torch, transformers, accelerate" && \
    /opt/fyp/agentboard-env/bin/python -c \
      "import gym, gymnasium, minigrid"

RUN micromamba clean -a -y


# Automatically start iLLaDA after RunPod startup.
COPY post_start.sh /post_start.sh
RUN chmod 755 /post_start.sh


# Preserve the RunPod base image's startup configuration.
# Research source files and models remain on /workspace.
