# h3-swap-worker

RunPod serverless worker image for MiniMax H3 character-swap jobs: the official
[`runpod/worker-comfyui`](https://github.com/runpod-workers/worker-comfyui) base image with ComfyUI upgraded to the
release the H3 nodes need. The upgrade happens at build time, so a cold start does not download or install it.

No model weights are in the image. They come from the endpoint's RunPod Cached Model (a Hugging Face repo that keeps
ComfyUI's folder layout); `h3-boot.sh` points ComfyUI at that cache and then starts the stock worker.

## Image

`ghcr.io/nigelimmanuel/h3-swap-worker:comfy-v0.44.0` (also `:latest`), built by GitHub Actions on every change to the
Dockerfile or the scripts. To build another ComfyUI release, change `ARG COMFYUI_REF` in the `Dockerfile` and push.

## Endpoint settings

| Setting | Value |
|---|---|
| Container image | the image above |
| Container start command | leave empty (the image's own command runs `h3-boot.sh`) |
| Env `H3_MODEL_REPO` | the Hugging Face repo set as the endpoint's cached model (required) |
| Env `COMFYUI_REF` | optional; only set it to run a different ComfyUI release than the baked one |

## Stale cache

RunPod pins the cached model to the repo commit that was current when it was configured. Files added to the repo
later are not on the host until the cache is re-pinned. `h3-boot.sh` covers that for SAM3.1 and the Fun ControlNet
Union 2.0 by fetching them from their public upstream repos when the snapshot lacks them; with an up-to-date cache
nothing is downloaded at start.
