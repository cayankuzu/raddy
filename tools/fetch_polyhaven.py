"""Downloads CC0 assets from Poly Haven's official API into the project (only api.polyhaven.com
and dl.polyhaven.org are contacted) and appends them to assets/_polyhaven_manifest.tsv.
  python tools/fetch_polyhaven.py models <id> [<id> ...]    -> assets/models/<id>/<id>_1k.gltf (+bin, textures)
  python tools/fetch_polyhaven.py textures <id> [<id> ...]  -> assets/textures/<id>/<id>_{diff,nor_gl,arm}_1k.jpg
Already downloaded files are skipped. Run tools/texture_imports.py and tools/import.ps1 afterwards.
"""
import json
import os
import sys
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
UA = {"User-Agent": "RADDY-asset-fetch/1.0 (indie game; CC0 assets via the public API)"}
ALLOWED = ("https://api.polyhaven.com/", "https://dl.polyhaven.org/")


def get(url: str) -> bytes:
    assert url.startswith(ALLOWED), url
    with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=120) as response:
        return response.read()


def save(path: str, url: str) -> int:
    if os.path.exists(path) and os.path.getsize(path) > 0:
        return 0
    data = get(url)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(data)
    return len(data)


def fetch_model(asset: str) -> tuple:
    files = json.loads(get(f"https://api.polyhaven.com/files/{asset}"))
    entry = files["gltf"]["1k"]["gltf"]
    folder = os.path.join(ROOT, "assets", "models", asset)
    # Keep the glTF's own relative layout (the .gltf names its .bin and textures/ paths).
    total = save(os.path.join(folder, f"{asset}_1k.gltf"), entry["url"])
    for relative, include in entry.get("include", {}).items():
        safe = os.path.normpath(relative)
        assert not safe.startswith("..") and not os.path.isabs(safe), relative
        total += save(os.path.join(folder, safe), include["url"])
    return total, f"assets/models/{asset}"


def fetch_texture(asset: str) -> tuple:
    files = json.loads(get(f"https://api.polyhaven.com/files/{asset}"))
    folder = os.path.join(ROOT, "assets", "textures", asset)
    total = 0
    for key, short in (("Diffuse", "diff"), ("nor_gl", "nor_gl"), ("arm", "arm")):
        total += save(os.path.join(folder, f"{asset}_{short}_1k.jpg"), files[key]["1k"]["jpg"]["url"])
    return total, f"assets/textures/{asset}"


def main() -> None:
    kind, ids = sys.argv[1], sys.argv[2:]
    manifest = os.path.join(ROOT, "assets", "_polyhaven_manifest.tsv")
    known = set()
    if os.path.exists(manifest):
        known = {line.split("\t")[0] for line in open(manifest, encoding="utf-8")}
    for asset in ids:
        info = json.loads(get(f"https://api.polyhaven.com/info/{asset}"))
        total, folder = fetch_model(asset) if kind == "models" else fetch_texture(asset)
        authors = ", ".join(info.get("authors", {}).keys())
        tris = info.get("polycount", "")
        print(f"ok {asset}: {total / 1e6:.1f} MB new, by {authors}, polycount {tris}")
        if asset not in known:
            with open(manifest, "a", encoding="utf-8", newline="\n") as f:
                f.write(f"{asset}\t{kind}\t{info.get('name')}\t{authors}\thttps://polyhaven.com/a/{asset}\t{tris}\n")
            known.add(asset)


if __name__ == "__main__":
    main()
