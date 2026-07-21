#!/usr/bin/env bash
# Launch a GLM model locally via Ollama and expose an OpenAI-compatible
# endpoint that AgentScope's OpenAIChatModel can talk to.
#
# Usage:
#   ./scripts/launch_glm_local.sh [model_tag] [port]
#
# Examples:
#   ./scripts/launch_glm_local.sh
#   ./scripts/launch_glm_local.sh glm-5.2:q4_k_m 11434

set -euo pipefail

MODEL_TAG="${1:-${GLM_MODEL_TAG:-glm-5.2}}"
PORT="${2:-${OLLAMA_PORT:-11434}}"
HOST="127.0.0.1"

if ! command -v ollama >/dev/null 2>&1; then
    echo "ollama not found. Install it first: https://ollama.com/download" >&2
    exit 1
fi

export OLLAMA_HOST="${HOST}:${PORT}"

if ! curl -sf "http://${HOST}:${PORT}/api/version" >/dev/null 2>&1; then
    echo "Starting ollama serve on ${HOST}:${PORT} ..."
    ollama serve >/tmp/ollama-serve.log 2>&1 &
    OLLAMA_PID=$!

    for _ in $(seq 1 30); do
        if curl -sf "http://${HOST}:${PORT}/api/version" >/dev/null 2>&1; then
            break
        fi
        sleep 1
    done

    if ! curl -sf "http://${HOST}:${PORT}/api/version" >/dev/null 2>&1; then
        echo "ollama serve did not come up in time; check /tmp/ollama-serve.log" >&2
        exit 1
    fi
    echo "ollama serve started (pid ${OLLAMA_PID})."
else
    echo "ollama is already serving on ${HOST}:${PORT}."
fi

if ! ollama list | awk '{print $1}' | grep -qx "${MODEL_TAG}"; then
    echo "Pulling model '${MODEL_TAG}' (this may take a while) ..."
    ollama pull "${MODEL_TAG}"
else
    echo "Model '${MODEL_TAG}' already present."
fi

echo
echo "Model '${MODEL_TAG}' is ready at http://${HOST}:${PORT}/v1"
echo
echo "Point AgentScope at it with:"
cat <<PYEOF
    from agentscope.model import OpenAIChatModel

    model = OpenAIChatModel(
        model_name="${MODEL_TAG}",
        api_key="not-needed",
        client_kwargs={"base_url": "http://${HOST}:${PORT}/v1"},
    )
PYEOF
echo
echo "Run '${MODEL_TAG}' interactively with: ollama run ${MODEL_TAG}"
