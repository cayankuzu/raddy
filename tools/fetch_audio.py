"""Downloads the approved raw audio sources (2026-10-13) into raw_assets/audio/ (git-ignored and
hidden from Godot by .gdignore). tools/cut_audio.py turns them into the small loops and one-shots in
assets/audio/ that ship with the game. Licences: Sonniss #GameAudioGDC bundle licence (royalty-free,
commercial use, no attribution; not to be redistributed as standalone sound effects), Kenney CC0,
BigSoundBank CC0. Already downloaded files are skipped.
"""
import io
import os
import re
import urllib.parse
import urllib.request
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(ROOT, "raw_assets", "audio")
UA = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) RADDY-asset-fetch/1.0"}
TOYOTA = "https://ftpmirror.your.org/pub/misc/sonniss2020/individual/Pole%20Position%20-%20Toyota%20Corolla%201998%20Rally%20car/"
SOURCES = [
	("sonniss", TOYOTA + "Toyota%20Rally%20Car%2C%20t9%2C%20Onbrd%2C%20Fast%2C%20Drive%2C%20Various%2C%20Exhaust%2C%20Center%2C%20DPA4062.wav"),
	("sonniss", TOYOTA + "Toyota%20Rally%20Car%2C%20t11%2C%20Var%20SFX%2C%20Horn%2C%20Various%2C%20Interior%2C%20AMBEO2.wav"),
	("sonniss", "https://ftpmirror.your.org/pub/misc/sonniss2018/individual/Pole%20Position%20-%20Skids%20%26%20Screeches%20Tarmac/Skids_Tarmac_t4_exterior_skidding_in_circles_MKH8060_stand.wav"),
	("sonniss", "https://ftpmirror.your.org/pub/misc/sonniss2020/individual/Pole%20Position%20-%20Car%20Destruction/Car_Destruction_Designed_t44_Impacts_Interor.wav"),
	("kenney", "https://kenney.nl/media/pages/assets/impact-sounds/87b4ddecda-1677589768/kenney_impact-sounds.zip"),
	("kenney", "https://kenney.nl/media/pages/assets/interface-sounds/fa43c1dd4d-1677589452/kenney_interface-sounds.zip"),
	("bigsoundbank", "https://bigsoundbank.com/UPLOAD/ogg/1293.ogg"),  # rain on car roof (inside)
	("bigsoundbank", "https://bigsoundbank.com/UPLOAD/ogg/1294.ogg"),  # big rain on car roof
	("bigsoundbank", "https://bigsoundbank.com/UPLOAD/ogg/2718.ogg"),  # thunder #1
	("bigsoundbank", "https://bigsoundbank.com/UPLOAD/ogg/2799.ogg"),  # road map #4
	("bigsoundbank", "https://bigsoundbank.com/UPLOAD/ogg/2805.ogg"),  # road map #10
	("bigsoundbank", "https://bigsoundbank.com/UPLOAD/ogg/2371.ogg"),  # screeching tires #4
	("bigsoundbank", "https://bigsoundbank.com/UPLOAD/ogg/0500.ogg"),  # tire squeal
]
ALLOWED = ("https://ftpmirror.your.org/pub/misc/sonniss", "https://kenney.nl/media/", "https://bigsoundbank.com/UPLOAD/")
AUDIO = re.compile(r"^[A-Za-z0-9_ ,.()&-]+\.(ogg|wav)$")


def main() -> None:
	for folder, url in SOURCES:
		assert url.startswith(ALLOWED), url
		target_dir = os.path.join(RAW, folder)
		os.makedirs(target_dir, exist_ok=True)
		name = urllib.parse.unquote(url.rsplit("/", 1)[1])
		target = os.path.join(target_dir, name)
		if os.path.exists(target) or os.path.isdir(target.removesuffix(".zip")):
			print("have", name)
			continue
		with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=600) as response:
			data = response.read()
		if name.endswith(".zip"):
			# Keep only the audio files, flattened into a folder named after the zip.
			unpacked = target.removesuffix(".zip")
			os.makedirs(unpacked, exist_ok=True)
			archive = zipfile.ZipFile(io.BytesIO(data))
			kept = 0
			for member in archive.namelist():
				leaf = os.path.basename(member)
				if AUDIO.match(leaf):
					with open(os.path.join(unpacked, leaf), "wb") as f:
						f.write(archive.read(member))
					kept += 1
			print(f"ok {name}: {len(data) / 1e6:.1f} MB, {kept} audio files")
		else:
			with open(target, "wb") as f:
				f.write(data)
			print(f"ok {name}: {len(data) / 1e6:.1f} MB")


if __name__ == "__main__":
	main()
