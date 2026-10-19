# itch.io release checklist

Target: a downloadable Windows x64 game at about 5.99 USD. Nothing here costs money except
itch.io's revenue share (set by the seller, may be 0 %). Steam is not a target (it needs a
100 USD fee per game).

## Before uploading
- [ ] `config/version` in `project.godot` and the CHANGELOG entry match the build.
- [ ] `pwsh -NoProfile -File tools\test.ps1`, `tools\nettest.ps1`, `tools\flowtest.ps1` pass.
- [ ] `pwsh -NoProfile -File tools\export_windows.ps1` (release); the folder holds only
      `RADDY.exe`, `RADDY.pck`, `README.txt` (copy of the Turkish/English quick start) and
      `ASSET_LICENSES.md`.
- [ ] Start the exe on a clean PC (or a fresh Windows user): SmartScreen → More info → Run
      anyway; main menu appears; no dev buttons; credits list every CC BY author.
- [ ] Two PCs on different networks: create room, internet code, join, race, voice both ways.
- [ ] A crew of friends played every stage at least once; known issues updated in README.
- [ ] Zip the folder as `RADDY-<version>-windows.zip`.

## itch.io (manual, the developer's own account: payments, tax forms and login are theirs)
- [ ] Create the project: Kind "Downloadable", Classification "Game", Release status
      "In development" for tests ("Released" at launch), Pricing "Paid" 5.99 USD (or free test keys).
- [ ] Upload the zip, tick "Windows". Optionally set up `butler` for later uploads.
- [ ] Short description (TR/EN):
      "3 ekip, 6 oyuncu, tek kâğıt harita. Navigatör yolu okur, sürücü çamurlu camdan bakar."
      / "Three crews, six players, one paper map. The navigator reads the road; the driver sees it
      through a muddy windscreen."
- [ ] Long description: what the game is (online co-op rally, driver + navigator per crew, up to 3
      crews), six named stages in three biomes, weather, proximity voice chat, the chaos (map
      flying out, mud, bonnet flapping, falling trees, rockfalls, faints), how to host and join
      (room code, UPnP, Radmin VPN when there is no internet code). Promise only what is in the
      build.
- [ ] System requirements: Windows 10/11 64-bit; a DirectX 12 GPU (feature level 12_0); 8 GB RAM;
      ~300 MB disk; a microphone for voice; for internet play the host's router needs UPnP or
      everyone uses the same VPN network.
- [ ] Controls section (copy the table from README).
- [ ] Screenshots (1920×1080, from `tools\screenshot.ps1`): cockpit at speed on Kara Çam Geçidi;
      the paper map in the navigator's hands; a water splash; Kartal Yuvası cliff rail; Kızıl
      Kanyon; the HUD with three crews on the stage bar; muddy windscreen with wipers; results.
- [ ] Cover image 630×500 and a short gameplay GIF/video (record with a free tool such as OBS).
- [ ] Credits / attribution text: paste the CC BY lines from `ASSET_LICENSES.md` (car: Daniel
      Zhabotinsky; trees: Dari, Igor_K., evolveduk) and mention Poly Haven, ambientCG, Kenney,
      BigSoundBank (CC0) and the Sonniss GDC bundle.
- [ ] Tell players about SmartScreen ("More info → Run anyway") on the page: the game is unsigned.
- [ ] Community: enable comments or a devlog for feedback; say that crash/network logs live in
      `%APPDATA%\Godot\app_userdata\RADDY\logs\` and that voice is never recorded.

## Risks to weigh before a paid release
- Internet play depends on UPnP or a VPN; a free relay (e.g. a self-hosted noray) would need a
  server somebody pays for or hosts: decide before selling.
- Voice is relayed by the host: a weak host upload limits six-player rooms.
- No reconnect or host migration yet.
