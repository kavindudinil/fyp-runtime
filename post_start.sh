
#!/usr/bin/env bash

# Start iLLaDA after RunPod initializes SSH/JupyterLab.
# Keep model weights on the Global Volume.

set -u

LOG="/tmp/illada-server.log"

echo "[FYP] Scheduling iLLaDA startup..."

(
    set -e

    export HF_HOME="/workspace/.cache/huggingface"
    export HF_HUB_CACHE="$HF_HOME/hub"
    export HF_MODULES_CACHE="/tmp/fyp-transformers-modules"
    export HF_HUB_OFFLINE=1
    export TRANSFORMERS_OFFLINE=1
    export PYTHONDONTWRITEBYTECODE=1
    export PYTHONUNBUFFERED=1

    # Local cache: supports permissions and executable modules.
    mkdir -p "$HF_MODULES_CACHE"

    echo "[FYP] Waiting for model files on Global Volume..."

    READY=0

    for attempt in $(seq 1 90); do
        if [ -f /workspace/illada-poc/serve_illada.py ] &&
           [ -d "$HF_HUB_CACHE/models--GSAI-ML--iLLaDA-8B-Instruct/snapshots" ]; then
            READY=1
            break
        fi

        sleep 2
    done

    if [ "$READY" -ne 1 ]; then
        echo "[ERROR] Global Volume or model cache unavailable."
        exit 1
    fi

    cd /workspace/illada-poc

    echo "[FYP] Loading iLLaDA on GPU..."

    exec nohup /opt/fyp/illada-venv/bin/python \
        -m uvicorn serve_illada:app \
        --host 127.0.0.1 \
        --port 8000

) > "$LOG" 2>&1 < /dev/null &

echo "[FYP] iLLaDA startup process launched: PID $!"
echo "[FYP] Log: $LOG"
