#!/usr/bin/env bash
# Prueba VLM (Gemma 3 4B) sobre imágenes en Raspberry Pi 5.
#   ./script_vision.sh            # usa 17a.jpg y 6_clean.jpg al lado del script
#   ./script_vision.sh img.jpg    # imágenes a medida
set -e

ROOT=$(cd "$(dirname "$0")" && pwd)
MODEL_DIR=$HOME/vlmodels
BIN=$HOME/llama-bin/llama-cli
export PATH="$HOME/.local/bin:$PATH"
LLAMA_VERSION=$(curl -s "https://api.github.com/repos/ggml-org/llama.cpp/releases?per_page=20" |
  python3 -c "import json,sys; rs=json.load(sys.stdin); ns=[r['tag_name'] for r in rs if r['tag_name'].startswith('b') and not r.get('draft')]; print(ns[0] if ns else '')")
REPO="${REPO:-ggml-org/gemma-3-4b-it-GGUF}"
PESO="${PESO:-gemma-3-4b-it-Q4_K_M.gguf}"
PROJ="${PROJ:-mmproj-model-f16.gguf}"
MODEL=$MODEL_DIR/$PESO
MMPROJ=$MODEL_DIR/$PROJ
PROMPT="${PROMPT:-Describe this image in one short sentence.}"

# Pi 5 de menos RAM
#   Gemma 4 E2B (recomendada, ~2.8 GB + mmproj 0.56 GB):
#   export REPO=ggml-org/gemma-4-E2B-it-GGUF PESO=gemma-4-E2B-it-Q4_0.gguf PROJ=mmproj-gemma-4-E2B-it-Q8_0.gguf
#   SmolVLM2-500M (liviana, ~437 MB + mmproj 109 MB):
#   export REPO=ggml-org/SmolVLM2-500M-Video-Instruct-GGUF PESO=SmolVLM2-500M-Video-Instruct-Q8_0.gguf PROJ=mmproj-SmolVLM2-500M-Video-Instruct-Q8_0.gguf

sudo apt update
sudo apt install -y --no-install-recommends build-essential cmake git curl python3-pip
pip install --user --break-system-packages huggingface-hub

if [[ ! -x "$BIN" ]]; then
  [[ -n "$LLAMA_VERSION" ]] || { echo "no se pudo obtener el nightly de llama.cpp"; exit 1; }
  echo "llama.cpp release: $LLAMA_VERSION"
  mkdir -p "$HOME/llama-bin"
  curl -L -o /tmp/llama.tar.gz \
    "https://github.com/ggml-org/llama.cpp/releases/download/$LLAMA_VERSION/llama-$LLAMA_VERSION-bin-ubuntu-arm64.tar.gz"
  tar -xzf /tmp/llama.tar.gz -C "$HOME/llama-bin"
  CLI=$(find "$HOME/llama-bin" -type f -name llama-cli | head -1)
  ln -sf "$CLI" "$HOME/llama-bin/llama-cli"
fi

mkdir -p "$MODEL_DIR"
hf download "$REPO" "$PESO" --local-dir "$MODEL_DIR"
hf download "$REPO" "$PROJ" --local-dir "$MODEL_DIR"

IMAGES=("$@")
[[ ${#IMAGES[@]} -gt 0 ]] || IMAGES=("$ROOT/17a.jpg" "$ROOT/6_clean.jpg")
for img in "${IMAGES[@]}"; do
  [[ -f "$img" ]] || { echo "no existe: $img"; continue; }
  echo "== $img =="
  "$BIN" -m "$MODEL" --mmproj "$MMPROJ" --image "$img" -p "$PROMPT" -n 64 --temp 0.2 -st < /dev/null
done