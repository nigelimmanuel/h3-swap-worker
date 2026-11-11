# Worker for the MiniMax H3 character swap: the official worker-comfyui image with ComfyUI upgraded at build time,
# so a cold start no longer downloads and installs it. Models are not in the image: they come from RunPod Cached
# Models (see h3-boot.sh).
FROM runpod/worker-comfyui:5.10.0-base
ARG COMFYUI_REF=v0.44.0
ENV COMFYUI_REF=${COMFYUI_REF}
COPY upgrade_comfyui.py /usr/local/bin/h3-upgrade-comfyui.py
RUN set -eux; \
    /opt/venv/bin/python /usr/local/bin/h3-upgrade-comfyui.py "${COMFYUI_REF}"; \
    cd /comfyui; /opt/venv/bin/pip install -q --no-cache-dir -r requirements.txt; \
    test "v$(/opt/venv/bin/python -c 'import comfyui_version as v; print(v.__version__)')" = "${COMFYUI_REF}"
COPY h3-boot.sh /h3-boot.sh
CMD ["bash", "/h3-boot.sh"]
