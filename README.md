# RADDY

Online co-op rally for up to six players: three crews of a driver and a navigator race the same
named stage. The driver sees only the road through the windscreen; the navigator holds the paper
map with the pace notes and talks the driver through on proximity voice chat. Mud on the glass,
a map that blows out of the window, a bonnet flapping over the windscreen and boulders on the
road do the rest.

Windows x64 · Godot 4.7.2 (GDScript) · test build 0.2.0

---

## Türkçe: hızlı başlangıç (arkadaş testi)

1. `RADDY.exe` ve `RADDY.pck` aynı klasörde olmalı. Çalıştırın. Windows "Bilgisayarınız korundu"
   derse **Ek bilgi → Yine de çalıştır** (imzasız oyun; ücretli kod imzası kullanmıyoruz).
2. Ana menüde adınızı yazın.
3. **Oda kuran kişi (host):** "Oda Kur". Odada kodlar görünür:
   - **LAN kodu:** aynı evdeki / aynı ağdaki arkadaşlar için.
   - **İnternet kodu:** modeminiz UPnP'ye izin veriyorsa otomatik çıkar. Windows Güvenlik Duvarı
     sorarsa **İzin ver** deyin.
   - İnternet kodu çıkmıyorsa (operatör CGNAT kullanıyor olabilir): herkes ücretsiz
     **Radmin VPN**'i kurup aynı ağa girsin, sonra **LAN kodu** ile bağlanın.
4. **Katılanlar:** "Odaya Katıl" kutusuna kodu yazıp "Katıl".
5. Odada bir takımın **Sürücü** ya da **Navigatör** koltuğuna tıklayın, "Hazırım" deyin. Host
   etabı, zorluğu ve havayı seçer (ya da "Sürpriz Ralli"), sonra "Yarışı Başlat".
6. Mikrofon: **Ayarlar → Ses**. Varsayılan bas-konuş **V**. "Mikrofon testi" ile seviyeyi görün;
   doğru mikrofonu listeden seçin. Ses yalnızca yakındakilere gider (takım/genel kanal yok).

### Tuşlar (Ayarlar → Kontroller'den değiştirilebilir)

| Herkes | |
|---|---|
| Fare | Kafayı çevir (serbest bakış) |
| V | Bas-konuş |
| R (basılı tut / ikiniz de bas) | Takılan aracı kurtar |
| Esc | Menü |

| Sürücü | | Navigatör | |
|---|---|---|---|
| W / ↑ | Gaz | M | Haritayı aç/kapat |
| S / ↓ | Fren, durunca geri | Fare sürükle / teker | Haritayı kaydır / yakınlaştır |
| A D / ← → | Direksiyon | Home | Haritayı sıfırla |
| Boşluk | El freni | Q / E | Sol / sağ cam |
| H | Korna | Sol tık | Pencereden kutu at |
| Q | Sol cam | F | Ön camı tekmele |
| T | Silecekler | L | Tavan lambası |

Gamepad: tetikler gaz/fren, sol çubuk direksiyon.

### Bilinen kısıtlar (test sürümü)
- İnternetten bağlanmak için host'un modemi UPnP'ye izin vermeli ya da herkes Radmin VPN
  kullanmalı. Ücretsiz bir "relay" sunucusu henüz yok.
- Bağlantı koparsa yeniden bağlanma yok; host çıkarsa oda kapanır.
- Sürücü ve navigatörün gövdesi/elleri henüz yok.
- Geri bildirim: oyunun günlükleri `%APPDATA%\Godot\app_userdata\RADDY\logs\` altında.
  Oyun ses kaydetmez, kişisel veri toplamaz.

---

## English

### Playing a test build
1. Keep `RADDY.exe` next to `RADDY.pck` and run it. On "Windows protected your PC" choose
   **More info → Run anyway** (the game is unsigned: no paid code signing).
2. **Host:** "Create Room" shows a LAN code (same network) and, when the router allows UPnP, an
   internet code; allow the Windows Firewall prompt. Behind carrier-grade NAT there is no internet
   code: everyone joins the same free **Radmin VPN** network and uses the LAN code.
3. **Guests:** type the code under "Join Room".
4. Take a driver or navigator seat, press Ready; the host picks the stage, difficulty and weather
   (or Surprise Rally) and starts.
5. Microphone: Settings → audio. Push-to-talk on **V** by default; pick the device and use the
   level test. Voice reaches nearby players only.

Controls: see the Turkish table above (Settings → Controls rebinds every action).

### Stages
Six fixed, named point-to-point stages (1.9-2.3 km), two per biome: Kara Çam Geçidi / Black Pine
Pass and Sisli Dere / Misty Creek (forest), Kızıl Kanyon / Red Canyon and Akrep Tepeleri / Scorpion
Hills (desert), Kartal Yuvası / Eagle's Nest and Buzul Sırtı / Glacier Ridge (mountain). Crests,
jumps, water splashes, cliffs with rails, switchbacks; leave the road and you meet trees and,
36 m out, the stage's wall.

### Known limitations
- Internet play needs UPnP on the host's router or a shared VPN (Radmin); no relay server yet.
  Always test from really different networks before calling it "online for everyone".
- No reconnect after a drop, no host migration.
- Crew bodies and hands are missing.
- Logs: `%APPDATA%\Godot\app_userdata\RADDY\logs\`. Voice is never recorded; no accounts, no personal data.

---

## Development

Requirements: Godot 4.7.2 at `C:\Tools\Godot\4.7.2\` (or `GODOT_DIR`), export templates 4.7.2,
PowerShell 7, Python 3 with numpy (asset tools only). Everything is free; see `ASSET_LICENSES.md`.

| Command (repo root) | What it does |
|---|---|
| `pwsh -NoProfile -File tools\import.ps1` | Headless import (after new assets or class_name scripts) |
| `pwsh -NoProfile -File tools\test.ps1` | GUT unit and physics tests (`reports\junit.xml`) |
| `pwsh -NoProfile -File tools\nettest.ps1` | Host + 3 clients, scripted multiplayer checks |
| `pwsh -NoProfile -File tools\flowtest.ps1` | Menu → room → whole stage with bots → results → room |
| `pwsh -NoProfile -File tools\export_windows.ps1` | `builds\windows\RADDY.exe` |
| `tools\launch.ps1 -Clients N [-Server]` | Several game windows on one PC |
| `tools\screenshot.ps1 -Scene res://... -Out reports\screenshots\x.png` | Movie Maker screenshot |
| `python -I tools\fetch_audio.py` then `python -I tools\cut_audio.py` | Rebuild the sound assets |

Dev scenes: `scenes/dev/route_test.tscn -- --stage=eagle_nest --autodrive --chase`,
`scenes/dev/net_test.tscn`, `scenes/dev/vehicle_test_track.tscn`.

Architecture and conventions: `CLAUDE.md`. Plan and status: `docs/DEVELOPMENT_PLAN.md`.
Networking: player-hosted ENet (host = peer 1, authoritative for the race, cans, cabin state);
driver-authoritative car physics with 30 Hz snapshots; proximity voice relayed by the host.
No servers, accounts or secrets: there is nothing to configure (see `.env.example`).
