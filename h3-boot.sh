#!/usr/bin/env bash
# Start script of the h3-swap worker image.
# 1) make sure ComfyUI is at $COMFYUI_REF (already true for the version baked into the image; an override in the
#    endpoint's env still works, at the cost of an upgrade on every cold start), 2) point ComfyUI at the Hugging Face
#    repo RunPod cached on this host ($H3_MODEL_REPO), 3) fetch the few files a stale cache may lack, 4) start.
set -u
: "${H3_MODEL_REPO:?set H3_MODEL_REPO to the Hugging Face repo configured as the cached model of the endpoint}"
REF="${COMFYUI_REF:-v0.44.0}"
cd /comfyui
CUR="$(/opt/venv/bin/python -c 'import comfyui_version as v; print(v.__version__)' 2>/dev/null || echo '?')"
if [ "v$CUR" != "$REF" ]; then
  echo "h3: ComfyUI $CUR -> $REF"
  /opt/venv/bin/python /usr/local/bin/h3-upgrade-comfyui.py "$REF"
  /opt/venv/bin/pip install -q --no-cache-dir -r requirements.txt 2>&1 | tail -n 3
  echo "h3: ComfyUI now $(/opt/venv/bin/python -c 'import comfyui_version as v; print(v.__version__)')"
fi
REPO_DIR="/runpod-volume/huggingface-cache/hub/models--${H3_MODEL_REPO//\//--}"
YAML=/comfyui/extra_model_paths.yaml
if [ -d "$REPO_DIR/snapshots" ]; then
  REV="$(cat "$REPO_DIR/refs/main" 2>/dev/null)"
  SNAP="$REPO_DIR/snapshots/$REV"
  { [ -n "$REV" ] && [ -d "$SNAP" ]; } || SNAP="$(ls -d "$REPO_DIR"/snapshots/* | head -n 1)"
  grep -q "^h3_cached:" "$YAML" 2>/dev/null || cat >> "$YAML" <<YML

h3_cached:
  base_path: $SNAP
  diffusion_models: diffusion_models/
  text_encoders: text_encoders/
  vae: vae/
  loras: loras/
  model_patches: model_patches/
  checkpoints: checkpoints/
YML
  echo "h3: models from $SNAP"; ls "$SNAP"/*/ | head -n 20
else
  echo "h3: cached model not found at $REPO_DIR"; ls /runpod-volume/huggingface-cache/hub 2>&1 | head
fi
# Files added to the model repo after the endpoint's cache was pinned are missing from the snapshot on this host.
# They are public, so they are fetched here until the cache is re-pinned; with an up-to-date cache nothing is downloaded.
fetch_if_missing() {  # <path inside the models folder> <public url>
  local rel="$1" url="$2" dst="/comfyui/models/$1"
  if [ ! -s "$dst" ] && [ ! -s "${SNAP:-/nonexistent}/$rel" ]; then
    mkdir -p "$(dirname "$dst")"
    /opt/venv/bin/python - "$dst" "$url" <<'PY'
import os, sys, time, urllib.request
dst, url = sys.argv[1], sys.argv[2]; t = time.time()
urllib.request.urlretrieve(url, dst + ".part")
os.replace(dst + ".part", dst)
print("h3: fetched %s in %.0fs (%.2f GB)" % (os.path.basename(dst), time.time() - t, os.path.getsize(dst) / 1e9))
PY
  fi
}
# SAM3.1: person masks for the character swap
fetch_if_missing checkpoints/sam3.1_multiplex_fp16.safetensors \
  https://huggingface.co/Comfy-Org/sam3.1/resolve/main/checkpoints/sam3.1_multiplex_fp16.safetensors
# Fun ControlNet Union 2.0: inpainting with mid-gray holes
fetch_if_missing model_patches/minimax_h3_fun_controlnet_union_2.0_pruned_int8_convrot.safetensors \
  https://huggingface.co/Comfy-Org/MiniMax-H3/resolve/main/model_patches/minimax_h3_fun_controlnet_union_2.0_pruned_int8_convrot.safetensors
exec /start.sh
