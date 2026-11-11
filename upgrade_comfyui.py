"""Replace the ComfyUI code in /comfyui with the given release tag, keeping models, custom nodes, input and output."""
import io, sys, tarfile, urllib.request

ref = sys.argv[1]
data = urllib.request.urlopen(f"https://github.com/Comfy-Org/ComfyUI/archive/refs/tags/{ref}.tar.gz", timeout=120).read()
with tarfile.open(fileobj=io.BytesIO(data)) as t:
    for m in t.getmembers():
        parts = m.name.split("/", 1)
        if len(parts) < 2 or not parts[1] or parts[1].startswith(("models/", "custom_nodes/", "input/", "output/")):
            continue
        m.name = parts[1]
        t.extract(m, "/comfyui")
print("h3: extracted", ref)
