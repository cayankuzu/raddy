"""Sets 3D-ready import options on downloaded textures (run after adding textures, then
tools\\import.ps1 re-imports them):
  - VRAM compression (BPTC/S3TC on desktop) with mipmaps, no "detect 3D" guess
  - *_nor_gl_* files are tagged as normal maps (RGTC, OpenGL green-up as Poly Haven ships them)
  - *_arm_* files (AO/Roughness/Metal packed, the ORMMaterial3D layout) stay linear
Usage: python tools/texture_imports.py [folder ...]   (default: assets/textures and assets/models)
Prints how many .import files changed; unchanged files are left alone so Godot does not re-import.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FOLDERS = sys.argv[1:] or ["assets/textures", "assets/models"]


def wanted(name: str) -> dict:
    params = {
        "compress/mode": "2",
        "mipmaps/generate": "true",
        "detect_3d/compress_to": "0",
        "compress/high_quality": "false",
    }
    lower = name.lower()
    params["compress/normal_map"] = "1" if "_nor_gl" in lower or "_normal" in lower else "0"
    return params


changed = 0
seen = 0
for folder in FOLDERS:
    base = os.path.join(ROOT, folder)
    if not os.path.isdir(base):
        continue
    for dirpath, _dirs, files in os.walk(base):
        for file in files:
            if not file.endswith(".import") or not re.search(r"\.(jpg|jpeg|png|webp)\.import$", file, re.I):
                continue
            path = os.path.join(dirpath, file)
            text = open(path, encoding="utf-8").read()
            if 'importer="texture"' not in text:
                continue
            seen += 1
            new = text
            for key, value in wanted(file).items():
                pattern = re.compile(r"^" + re.escape(key) + r"=.*$", re.M)
                if pattern.search(new):
                    new = pattern.sub(f"{key}={value}", new)
                else:
                    new = new.rstrip("\n") + f"\n{key}={value}\n"
            if new != text:
                with open(path, "w", encoding="utf-8", newline="\n") as f:
                    f.write(new)
                changed += 1
print(f"{changed} of {seen} texture imports updated")
