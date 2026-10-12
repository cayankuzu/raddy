"""Downloads CC0 ambientCG assets (1K JPG zips) through the official API and extracts only their
image maps into assets/foliage/<id>/ (or assets/textures/<id>/ with --textures). Nothing in the
archive is executed; names are checked so no file lands outside its folder.
  python tools/fetch_ambientcg.py PineNeedles001 Foliage008 [--textures]
"""
import io
import json
import os
import re
import sys
import urllib.request
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
UA = {"User-Agent": "RADDY-asset-fetch/1.0 (indie game; CC0 assets via the public API)"}
IMAGE = re.compile(r"^[A-Za-z0-9_.-]+\.(jpg|jpeg|png)$")


def get(url: str) -> bytes:
    assert url.startswith("https://ambientcg.com/"), url
    with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=180) as response:
        return response.read()


def main() -> None:
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    base = "textures" if "--textures" in sys.argv else "foliage"
    manifest = os.path.join(ROOT, "assets", "_ambientcg_manifest.tsv")
    for asset in args:
        info = json.loads(get(f"https://ambientcg.com/api/v2/full_json?id={asset}&include=downloadData"))
        found = info["foundAssets"][0]
        url = None
        for category in found["downloadFolders"]["default"]["downloadFiletypeCategories"].values():
            for download in category["downloads"]:
                if download["attribute"] == "1K-JPG":
                    url = download["fullDownloadPath"]
        assert url, f"no 1K-JPG download for {asset}"
        archive = zipfile.ZipFile(io.BytesIO(get(url)))
        folder = os.path.join(ROOT, "assets", base, asset)
        os.makedirs(folder, exist_ok=True)
        kept = []
        for name in archive.namelist():
            leaf = os.path.basename(name)
            if not IMAGE.match(leaf):
                continue
            with open(os.path.join(folder, leaf), "wb") as f:
                f.write(archive.read(name))
            kept.append(leaf)
        print(f"ok {asset}: {', '.join(sorted(kept))}")
        with open(manifest, "a", encoding="utf-8", newline="\n") as f:
            f.write(f"{asset}\t{found.get('displayName')}\tambientCG (CC0)\thttps://ambientcg.com/view?id={asset}\n")


if __name__ == "__main__":
    main()
