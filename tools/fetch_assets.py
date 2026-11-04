"""Downloads the assets the owner approved on 2026-10-19 (batches A-D of the asset research) that
need no login, into raw_assets/downloads/<group>/ (git-ignored). Fonts, icons and their licence
texts go straight into assets/ (they ship as they are). Only the listed hosts are contacted;
already downloaded files are skipped. Sketchfab and Freesound items are downloaded by the owner's
own logged-in browser session, not by this script.
  python tools/fetch_assets.py
Licences: Quaternius UAL CC0, Kenney CC0, Google Fonts OFL 1.1, Tabler Icons MIT, Sonniss GDC
bundle licence (royalty-free in games, not to be redistributed as standalone files), BigSoundBank
CC0, Spring Spring fanfares CC BY 4.0 (credit "Spring / Spring Enterprises").
"""
import os
import urllib.parse
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(ROOT, "raw_assets", "downloads")
UA = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) RADDY-asset-fetch/1.0"}
ALLOWED = (
	"https://opengameart.org/sites/default/files/",
	"https://kenney.nl/media/",
	"https://raw.githubusercontent.com/google/fonts/main/ofl/",
	"https://raw.githubusercontent.com/tabler/tabler-icons/main/",
	"https://ftpmirror.your.org/pub/misc/sonniss",
	"https://bigsoundbank.com/UPLOAD/",
)
GF = "https://raw.githubusercontent.com/google/fonts/main/ofl/"
TABLER = "https://raw.githubusercontent.com/tabler/tabler-icons/main/"
M = "https://ftpmirror.your.org/pub/misc/"
BSB = "https://bigsoundbank.com/UPLOAD/ogg/"

# (target path relative to the repo, url)
FILES = [
	# --- A: animation libraries (Quaternius, CC0) ---
	("raw_assets/downloads/ual/universal_animation_library_standard.zip", "https://opengameart.org/sites/default/files/universal_animation_librarystandard.zip"),
	("raw_assets/downloads/ual/universal_animation_library_2_standard.zip", "https://opengameart.org/sites/default/files/universal_animation_library_2standard.zip"),
	# --- C: fonts (OFL), button prompts (CC0), icons (MIT) ---
	("assets/fonts/saira/Saira-Variable.ttf", GF + "saira/Saira%5Bwdth,wght%5D.ttf"),
	("assets/fonts/saira/OFL.txt", GF + "saira/OFL.txt"),
	("assets/fonts/inter/Inter-Variable.ttf", GF + "inter/Inter%5Bopsz,wght%5D.ttf"),
	("assets/fonts/inter/OFL.txt", GF + "inter/OFL.txt"),
	("assets/fonts/jetbrains_mono/JetBrainsMono-Variable.ttf", GF + "jetbrainsmono/JetBrainsMono%5Bwght%5D.ttf"),
	("assets/fonts/jetbrains_mono/OFL.txt", GF + "jetbrainsmono/OFL.txt"),
	("raw_assets/downloads/kenney/kenney_input-prompts_1.5.zip", "https://kenney.nl/media/pages/assets/input-prompts/8de120163f-1783763952/kenney_input-prompts_1.5.zip"),
	("assets/icons/tabler/LICENSE", TABLER + "LICENSE"),
	# --- D: sounds (Sonniss GDC, BigSoundBank CC0, Spring CC BY) ---
	("raw_assets/audio/sonniss/volvo_door_interior.wav", M + "sonniss2020/individual/Pole%20Position%20-%20Volvo%20142%20Rally%20car/Volvo%2C%20142%2C%20Rally%2C%20t11%2C%20Var%20SFX%2C%20Door%2C%20Various%2C%20Interior%2C%20AMBEO3.wav"),
	("raw_assets/audio/sonniss/fiesta_door_various.wav", M + "sonniss2020/individual/Pole%20Position%20-%20Ford%20Fiesta%20WRC%202016/Ford%2C%20Fiesta%2C%20WRC%2C%20t9%2C%20Var%20SFX%2C%20Door%20Various%2C%20Decoded%2C%20RSM191.wav"),
	("raw_assets/audio/sonniss/seatbelt_buckle_in.wav", M + "sonniss2020/individual/Sounds%20Great%20-%20Car%20Interiors/seatbelt_buckle_in.WAV"),
	("raw_assets/audio/sonniss/wood_crushing_branches.wav", M + "sonniss2019/individual/BlueZone%20-%20Wood%20Sound%20Effects/Bluezone_BC0254_wood_crushing_branches_001_001.wav"),
	("raw_assets/audio/sonniss/tree_limb_impact.wav", M + "sonniss2018/individual/Soundrangers%20-%20Foley%20Elements%20Foliage/tree_dead_tree_limb_impact_05.wav"),
	("raw_assets/audio/sonniss/leaves_pile.wav", M + "sonniss2018/individual/Soundrangers%20-%20Foley%20Elements%20Foliage/leaves_pile_pick_up_04.wav"),
	("raw_assets/audio/sonniss/tree_falling.wav", M + "sonniss2018/individual/Soundrangers%20-%20Foley%20Elements%20Foliage/tree_falling_04.wav"),
	("raw_assets/audio/sonniss/rock_roll.wav", M + "sonniss2020/individual/Tatak%20Audio%20-%20Rocks%20and%20Debris/Tatak_ROCKS_Rock%20Roll%20Movement.wav"),
	("raw_assets/audio/sonniss/rock_impact.wav", M + "sonniss2020/individual/Tatak%20Audio%20-%20Rocks%20and%20Debris/Tatak_ROCKS_Single%20Rock%20Impact%20on%20Stones.wav"),
	("raw_assets/audio/sonniss/rockslide.wav", M + "sonniss2018/individual/Soundrangers%20-%20Foley%20Elements%20Rocks%2C%20Dirt%20And%20Stone/rockslide_02.wav"),
	("raw_assets/audio/sonniss/crowd_cheer.wav", M + "sonniss2016/individual/Game%20Audio%20Factory%20-%20GAFSFX03%20-%20Small%20Crowds%20Outdoors/GAF%20SFX03%20-%20Audience%20Reactions%20-%20Small%20Crowd%20Men%2C%20Cheer%20Applause%2C%20Long%2C%20Decrescendo%2C%20Crescendo%2C%20EN%20-%20ORTF.wav"),
	("raw_assets/audio/sonniss/volvo_start_stop.wav", M + "sonniss2020/individual/Pole%20Position%20-%20Volvo%20142%20Rally%20car/Volvo%2C%20142%2C%20Rally%2C%20t1%2C%20Onbrd%2C%20Start%2C%20Slow%2C%20Drive%2C%20Stop%2C%20Reverse%2C%20Stop%2C%20Drive%2C%20Stop%2C%20Off%2C%20Interior%2C%20Left%2C%20DPA4061.wav"),
	("raw_assets/audio/sonniss/radio_beep.wav", M + "sonniss2020/individual/Bluezone%20-%20Interception%20-%20Radio%20Transmission/Bluezone_BC0266_radio_beep_walkie_talkie_002.wav"),
	("raw_assets/audio/sonniss/radio_interference.wav", M + "sonniss2020/individual/Bluezone%20-%20Interception%20-%20Radio%20Transmission/Bluezone_BC0266_radio_transmission_interference_noise_transmitter_008.wav"),
	("raw_assets/audio/sonniss/ui_confirm.wav", M + "sonniss2019/individual/InspectorJ%20-%20UI%20-%20Mechanical/UI_Mechanical_Confirm_04_FX.wav"),
	("raw_assets/audio/sonniss/ui_error.wav", M + "sonniss2019/individual/InspectorJ%20-%20UI%20-%20Mechanical/UI_Mechanical_Error_11_FX_01.wav"),
	("raw_assets/audio/sonniss/ui_move.wav", M + "sonniss2019/individual/InspectorJ%20-%20UI%20-%20Mechanical/UI_Mechanical_Move_40.wav"),
	("raw_assets/audio/sonniss/ui_open.wav", M + "sonniss2019/individual/InspectorJ%20-%20UI%20-%20Mechanical/UI_Mechanical_Turning-On_03_Raw.wav"),
	("raw_assets/audio/sonniss/whoosh_soft.wav", M + "sonniss2019/individual/Airborne%20Sound%20-%20Airy%20Whooshes/Whoosh%2CSound%20Design%2CAiry%2CFull%2CSoft%2CBuffet%2CMedium.wav"),
	("raw_assets/audio/sonniss/whoosh_forceful.wav", M + "sonniss2019/individual/Airborne%20Sound%20-%20Airy%20Whooshes/Whoosh%2CSound%20Design%2CAiry%2CFull%2CForceful%2CSoft.wav"),
	("raw_assets/audio/sonniss/electric_shock.wav", M + "sonniss2018/individual/Hear%20and%20Now%20Sound%20-%20High%20Voltage%20Electricity%20-%20The%20Essential%20Collection/Damp%20Electric%20Shock%208.wav"),
	("raw_assets/audio/bigsoundbank/gas_horn_1.ogg", BSB + "1048.ogg"),
	("raw_assets/audio/bigsoundbank/gas_horn_2.ogg", BSB + "1049.ogg"),
	("raw_assets/audio/bigsoundbank/cow_moos.ogg", BSB + "0546.ogg"),
	("raw_assets/audio/bigsoundbank/sheep_1.ogg", BSB + "2343.ogg"),
	("raw_assets/audio/bigsoundbank/sheep_2.ogg", BSB + "2344.ogg"),
	("raw_assets/audio/bigsoundbank/sheep_3.ogg", BSB + "2345.ogg"),
	("raw_assets/audio/bigsoundbank/air_leak.ogg", BSB + "1486.ogg"),
	("raw_assets/audio/bigsoundbank/balloon_burst.ogg", BSB + "0551.ogg"),
	("raw_assets/audio/bigsoundbank/car_difficult_start.ogg", BSB + "0872.ogg"),
	("raw_assets/audio/bigsoundbank/seat_belt_in.ogg", BSB + "1506.ogg"),
	("raw_assets/audio/bigsoundbank/seat_belt_out.ogg", BSB + "1507.ogg"),
	("raw_assets/audio/bigsoundbank/walkie_talkie_start.ogg", BSB + "0589.ogg"),
	("raw_assets/audio/bigsoundbank/road_map_2.ogg", BSB + "2797.ogg"),
	("raw_assets/audio/bigsoundbank/road_map_7.ogg", BSB + "2802.ogg"),
	("raw_assets/audio/bigsoundbank/road_map_12.ogg", BSB + "2807.ogg"),
	("raw_assets/audio/spring/VICTORY.ogg", "https://opengameart.org/sites/default/files/VICTORY_0.ogg"),
	("raw_assets/audio/spring/LOSE.ogg", "https://opengameart.org/sites/default/files/LOSE_0.ogg"),
	("raw_assets/audio/spring/TITLE_BOUT.ogg", "https://opengameart.org/sites/default/files/TITLE%20BOUT_0.ogg"),
]

# Tabler outline icons the menus and the HUD use.
ICONS = ["steering-wheel", "helmet", "car", "microphone", "microphone-off", "settings", "map", "map-2", "users",
	"user", "door-exit", "player-play", "refresh", "trophy", "flag", "flag-3", "clock", "volume", "volume-off",
	"keyboard", "device-gamepad-2", "world", "lock", "home", "arrow-left", "chevron-right", "check", "x", "bolt",
	"alert-triangle", "eye", "eye-off", "wifi", "plug-connected", "copy", "info-circle", "medal", "road", "tool",
	"wind", "droplet", "mountain", "tree", "sun", "cloud-rain", "cloud-fog", "snowflake", "rotate", "hand-stop",
	"hand-finger", "gauge", "car-crash", "first-aid-kit", "photo", "brand-discord", "help-circle", "language"]


def fetch(path: str, url: str) -> str:
	assert url.startswith(ALLOWED), url
	target = os.path.join(ROOT, path)
	if os.path.exists(target) and os.path.getsize(target) > 0:
		return "skip"
	os.makedirs(os.path.dirname(target), exist_ok=True)
	try:
		with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=300) as response:
			data = response.read()
	except Exception as error:  # a missing file is reported, the rest goes on
		return "FAILED %s" % error
	with open(target, "wb") as out:
		out.write(data)
	return "%.1f MB" % (len(data) / 1e6)


def main() -> None:
	items = list(FILES) + [("assets/icons/tabler/%s.svg" % name, TABLER + "icons/outline/%s.svg" % name) for name in ICONS]
	for path, url in items:
		print("%-60s %s" % (path, fetch(path, url)), flush=True)


if __name__ == "__main__":
	main()
