# How the owner releases a game (the recipe RADDY's launch follows)

Researched read-only on 2026-11-17 from the owner's itch.io account (MeMoDe: Haluk'un 7 Günü, Merbut), their portfolio site fikkis
(`C:\Users\Cayan\Desktop\fikkis`, live at https://fikkis.vercel.app) and their other games' repositories. The owner asked that RADDY be
published the same way, through their own signed-in Chrome, when the game is ready: the itch.io page, the demo, the portfolio card.
The source is public at https://github.com/cayankuzu/raddy since 2026-11-17 (pushed by the lead at milestones, after a scan of the
whole history for secrets: `git log` must never carry a token, a password or a private address).

Sources: memode.itch.io/haluk (edit id 5341408), memode.itch.io/merbut (edit id 5144074), memode.itch.io profile, C:\Users\Cayan\Desktop\fikkis (src/app/projects.ts, _lib/projects-en.ts, public/project-previews/SOURCES.md, README.md), C:\Users\Cayan\Desktop\merbut (vercel.json, docs/ITCH_PAGE.md, README). Haluk is the closest model for RADDY (Godot 4.7.2, newest, most polished); Merbut is the older reference.

## 1. itch.io page (account MeMoDe, https://memode.itch.io)

### Edit form (as filled for Haluk; Merbut the same unless noted)
| Field | Haluk | Merbut |
|---|---|---|
| Title | Haluk'un 7 Günü | Merbut |
| Project URL slug | haluk | merbut |
| Tagline (short_text) | `English line · Türkçe line` e.g. "His stress bar is his name. · Stres barı kendi adı." (bilingual, one dot-separated line) | English only: "Hazrat Ali and Samurai Jack cross ten realms to stop Aku. A story-driven 2.5D local co-op brawler." |
| Classification | Games | Games |
| Kind of project | HTML (browser build + extra downloads) | HTML |
| Release status | In development | Released |
| Pricing | No payments (free; the form warns "You don't have payment configured") | No payments |
| Genre | Simulation | Action |
| Tags (max 10, lowercase) | 3d, comedy, destruction, first-person, funny, office, physics, satire, short, singleplayer | beat-em-up, boss-battle, co-op, fangame, hack-and-slash, local-co-op, local-multiplayer, samurai, story-rich, stylized |
| Made with (metadata) | Godot | Three.js |
| Community | Comments (community_type=topic) | Comments |
| Visibility | Public (published) | Public |
| AI disclosure | Yes: Text + Code, with a bilingual statement ("The code and the draft text ... / Kod ve taslak metinler ...") | Yes: Graphics, Sounds, Text, Code |
| Metadata table (public "More information") | Status, Platforms HTML5+Windows, Author, Genre, Made with, Tags, AI Disclosure | also Average session, Languages (English, Turkish), Inputs, Accessibility (Subtitles, Configurable controls), Multiplayer, Player count, Links (Homepage, Source code, Instagram) |
| Gameplay video/trailer | empty (no YouTube) | not checked, assume empty |
| App store links, custom noun, download instructions | empty (Merbut has bilingual "Install instructions" about SmartScreen under the download) | |

### Uploads (two files, the pattern to copy)
1. `haluk-html5.zip` ("html5" channel), ~30 MB, index.html at the zip root, flag **"This file will be played in the browser"** ON.
2. `Haluk7Gun_Demo.exe` ("windows-demo" channel), ~126 MB, kind Executable, platform **Windows** only. NOT flagged "demo" (itch has no demo flag; the word is in the name). Merbut: `merbut-html5.zip` (html5) + `Merbut v3.2.0 · Windows 64-bit` (windows channel, portable zip, display name set, 170 MB).
- Version string pushed with butler `--userversion` (Haluk 0.1.0, Merbut 3.2.0). Merbut's docs: `butler push release/merbut-itch-v<ver>.zip memode/merbut:html5 --userversion <ver>` and `butler push ...windows-x64.zip memode/merbut:windows ...`. butler is NOT installed on this PC (`which butler` empty); needs the owner's email verified ("Please verify your account's email address") and `butler login`.
- Haluk shows "Added haluk-html5.zip, Haluk7Gun_Demo.exe..." so it was pushed/uploaded 4-5 days ago (Nov 12).

### Embed options
- Embed in page, **Manually set size**: Haluk 1000 x 563, Merbut 1280 x 720. Fullscreen button ON. Mobile friendly OFF, Autostart OFF, Scrollbars OFF, **SharedArrayBuffer OFF** (the Godot web build is single-threaded, under a 40 MB download budget). For RADDY a thread-less web export is a must if a web demo is wanted, and its size/perf is a hard problem (see "Missing").

### Theme (Edit theme)
| | Haluk (red) | Merbut (amber) |
|---|---|---|
| BG | #0c0909 | #0f0a0c |
| BG 2 | #171213 | #1b1315 |
| Text | #e9e3dd | #ece3d8 |
| Link | #e2363c | #e6a94a |
| Font | Lato, size **Large**, header font default | same |
| Screenshots | **Sidebar** | **Sidebar** |
| Banner | image, centered (Haluk: the red "H A LUK" logo on a dark red scene, line "MEMODE SUNAR" above, title + subtitle "Haluk'un 7 Günü · Haluk Has Had Enough" and tagline under it) | image, centered (key art 1920x1080) |
| Background | image, centered, repeat Both, fixed (a blurred dark-red scene) | image, repeat None, centered, fixed |
| Embed BG | none | image 1280x720 + alpha 50 (replaces the grey box before "Run game"; 80 px shifted so the button sits on the sun) |
| Page width | 1000 px column (itch default) | |
Recipe: dark near-black BG with one game-specific accent (the link colour), warm off-white text, Lato Large, screenshots in the sidebar, a banner that is the game's logo/key art, a faint fixed background image. Colours derive from the game's palette (Haluk red, Merbut amber): for RADDY pick the accent from its look.

### Images (sizes from Merbut's docs/ITCH_PAGE.md)
- Cover 630x500 PNG (minimum 315x250). Key art/banner 1920x1080 JPG. Embed BG 1280x720 JPG. Screenshots 1280x720 PNG (Haluk 5, Merbut 6; itch asks 3-5 best). Haluk's own are 1920x1080 PNG (resized to 1600x900 JPG for the portfolio).

### Description template (Haluk, bilingual in ONE description, English first)
Order, all in one description field:
1. **Bold tagline** (EN) + 1-2 sentence premise.
2. "Türkçe aşağıda ↓" (link-style note that Turkish follows).
3. H2-ish headline (e.g. "One week. Seven things taken.") + 1 paragraph + 3 bullets (Do / Hold it in / Or don't).
4. Named sub-feature section (sTressT) 1 paragraph.
5. **Features** (4 bullets: length + demo scope, systems, languages EN+TR, "Play in the browser, or download the demo for Windows").
6. **Controls** (key -> action list; Merbut a 2-column table per player + gamepad line).
7. Install note: "Windows: unzip and run X.exe. Windows may warn about an unknown publisher: More info, then Run anyway." (Merbut adds: Smart App Control blocks -> play in the browser.)
8. "You may stream this game and monetize your videos." + "Made with Godot by MeMoDe. Third-party models, sounds and fonts are listed with their licences in the game's credits."
9. Heading **Türkçe**, the same sections in Turkish (Kontroller, Özellikler, Windows: zip'i aç ... Ek bilgi, sonra Yine de çalıştır, "Bu oyunu yayınlayabilir ve videolarından para kazanabilirsin.", "MeMoDe tarafından Godot ile yapıldı...").
10. "© 2026 MeMoDe".
(Merbut variant: legal fan-work note in both languages at the end; not needed for RADDY. Merbut's full TR page in docs/ITCH_PAGE.md has title "MERBUT · On Diyar, Tek Kader" etc.)

### Profile page (memode.itch.io)
Dark (#0e0c0b), Lato; name MeMoDe, link fikkis.vercel.app, bilingual bio paragraph (EN then TR: "independent game studio making story-driven action games. The name comes from memento mori debes ..."; mentions Merbut only, so it is stale for Haluk and will need a RADDY line), Instagram @memode333, then a grid of game cards (title, tagline, genre, "Play in browser"): Haluk, Merbut.

## 2. Portfolio (fikkis, live: https://fikkis.vercel.app/)
- Repo C:\Users\Cayan\Desktop\fikkis, remote github.com/cayankuzu/fikkis, Next.js, deploys on Vercel (metadataBase fikkis.vercel.app). Live Games filter: "Oyun 17", total 42 cards; the three newest game cards are Haluk'un 7 Günü (first, amber, "Geliştiriliyor", Masaüstü badge), Merbut, Bibish.
- Add a game = append/insert an object in `src/app/projects.ts` (array order = order shown; Haluk sits before Merbut), copy the image(s) to `public/project-previews/`, add a row to `public/project-previews/SOURCES.md`, add English in `src/app/_lib/projects-en.ts` (key = the id), commit "feat(...)"/"chore(...)", push; Vercel builds.
- Fields in game entries: `id, featured: true, category: "game", desktopOnly: true` (shows "Masaüstü deneyimi" badge, gates narrow/touch screens), `title, hook` (one sentence on the card), `description` (detail panel), `platform` ("Web · Windows · Klavye ve fare"), `status` (green for "Canlı"/"yayında"/"Satışta"; orange for "Geliştiriliyor"), `role`, `tools[]`, `highlights[]` (2-3), `href` (the browser demo), `ctaLabel` ("Demoyu web'de oyna"), `purchase {href, label, store: "itch.io"}` (second button), `sourceUrl` (GitHub), `images[{src, caption}]` (first = card cover), optional `video` (silent hover preview mp4), `tone`. `tags` used only on some (beatter). `upcomingStores` only for App Store/Google Play, not for itch.io.
- Haluk's card has NO video and 4 jpg screenshots; Merbut/Bibish have an mp4.

### Filled example for RADDY (Turkish, in their voice)
```ts
{
  id: "raddy",
  featured: true,
  category: "game",
  desktopOnly: true,
  title: "RADDY",
  hook: "Üç takım, iki koltuk: biri sürer, biri haritayı okur, ikiniz de kırılan camdan ve uçan konserveden kurtulmaya çalışırsınız.",
  description:
    "Üç takımın aynı ralli etabında yarıştığı, her takımda sürücü ile yardımcı pilotun bir arabayı paylaştığı çevrimiçi iş birliği ralli oyunu. Sürücü yolu sürer; yardımcı pilot kâğıt haritayı ve yol notlarını okur, camı açar, şok tabancasını doldurur. Altı etap, her biri farklı biyomda ve her saat dilimiyle; hava, çamur ve taş izleri arabayı gerçekten kirletir ve camı çatlatır. Oyun Windows için itch.io'dan indirilir; arkadaşınız odanın kodunu yazarak katılır. Ücretsiz.",
  platform: "Windows · Çevrimiçi 3 takım · Klavye ve gamepad",
  status: "Geliştiriliyor · Ücretsiz demo itch.io'da",   // or "Canlı" once released
  role: "Bağımsız oyun tasarımı · Araç fiziği, ağ ve prosedürel etap sistemleri · Godot ile programlama ve yapım",
  tools: ["Godot 4.7.2", "GDScript", "Jolt Physics", "ENet"],
  highlights: [
    "Üç takım, iki koltuk: sürücü sürer, yardımcı pilot haritayı okur ve kabine müdahale eder",
    "Altı etap, her saat diliminde ve havada; arabanın camı çatlar, çamur ve toz gerçekten birikir",
  ],
  href: "https://memode.itch.io/raddy",
  ctaLabel: "Demoyu itch.io'da oyna",           // web demo only if one exists
  purchase: { href: "https://memode.itch.io/raddy", label: "Windows sürümünü indir", store: "itch.io" },
  sourceUrl: "https://github.com/cayankuzu/raddy",   // only if the repo is made public
  images: [
    { src: "/project-previews/raddy-stage.jpg", caption: "..." },
    { src: "/project-previews/raddy-cabin.jpg", caption: "..." },
    { src: "/project-previews/raddy-map.jpg", caption: "..." },
    { src: "/project-previews/raddy-night.jpg", caption: "..." },
  ],
  video: "/project-previews/videos/raddy-gameplay.mp4",   // optional, hover preview
  tone: "orange",
},
```
(Copy to be re-checked against what RADDY really is at release; `tone` options: amber blue red green violet ink lime navy cream coral orange; used so far for games: amber, red, lime.)

### English override (`projectsEn.raddy`, same file shape as `merbut`/`stresst`)
```ts
raddy: {
  title: "RADDY",
  hook: "...",
  description: "...",
  platform: "Windows · Online 3 teams · Keyboard and gamepad",
  status: "In development · Free demo on itch.io",
  role: "Independent game design · Vehicle physics, networking and procedural stages · Programming and production in Godot",
  highlights: ["...", "..."],
  ctaLabel: "Play the demo on itch.io",
  purchase: { href: "https://memode.itch.io/raddy", label: "Download for Windows", store: "itch.io" },
  tags: ["Racing", "Co-op", "Multiplayer"],
  images: [{ caption: "..." }, ...],   // captions only, same count/order as Turkish
},
```
The English override only re-states translated text; ids, hrefs, src and tone come from the Turkish entry. Merbut's override even re-lists `purchase` with an English label.

### Media sizes and paths
- Stills: `public/project-previews/<id>-<what>.jpg|png`. Haluk's: 1600x900 JPG (resized from 1920x1080 PNG, 65-190 KB each); Merbut's: 1600x960 PNG (1-1.4 MB); Bibish 1440x900 PNG. 3-4 per game; first = card cover; each has a caption.
- Video: `public/project-previews/videos/<id>-gameplay.mp4` (silent loop, Merbut 0.96 MB, Bibish 0.2 MB: keep under ~1 MB).
- Provenance row per file group in `public/project-previews/SOURCES.md` (date, size, what each shot shows).

## 3. Browser demo hosting and deploy
- Merbut: Vite app; `vercel.json` in repo root: `buildCommand: "npm run build:demo"`, `outputDirectory: "dist"`, immutable cache for /assets, nosniff/Referrer-Policy/Permissions-Policy headers. Its README: `build:demo` builds the public demo (first two realms, then a "Demo tamamlandı" screen linking to itch.io), `package:itch` zips the FULL build for itch.io. Deploy = push to GitHub (github.com/cayankuzu/merbut), Vercel's Git integration builds it. No GitHub workflow deploys it (`.github/workflows/ci.yml` is CI only). No deploy script found. Bibish: vite + `vercel.json` (framework vite, `npm run build`, sw.js no-cache), Cloudflare Worker backend (`npm run cloudflare:deploy`), repo cayankuzu/bibish... (README Vercel section) - same Git-push deploy.
- Haluk's web demo is NOT on Vercel: it is the itch.io html5 zip (embedded, 1000x563). The portfolio's Haluk card points `href` at the itch page itself (ctaLabel "Demoyu web'de oyna"). So for RADDY the equivalent of "demo" is itch's own HTML5 channel, or none.
- Tooling on this PC: `vercel` CLI NOT installed (`vercel --version`, `vercel whoami` -> command not found); `gh` is logged in as `cayankuzu` (token via keyring); node 26.11.1 / npm 11.20 present; `butler` NOT installed. `C:\Users\Cayan\Desktop\raddy` has NO git remote (`git remote -v` empty); merbut and fikkis remotes are github.com/cayankuzu/<name>.git.

## 4. Owner-only steps / not yet in place
- Nothing for RADDY exists yet: no itch page (memode.itch.io/raddy), no GitHub repo/remote, no card, no art (cover 630x500, banner 1920x1080, embed BG, 5 screenshots 1920x1080/1280x720, optional mp4), no export-ready HTML5 build.
- Owner's login needed: itch.io (create the project via "Upload new project": creating needs the owner), `butler login` + email verification, butler install (free, from itch.io/docs/butler), optional Vercel login/CLI.
- Payments: the account has no payment configured ("You don't have payment configured"), all games are free ("No payments"). Zero-cost rule: RADDY should also be "No payments" or "$0 or donate" (donating also needs payment setup; stay No payments).
- Web demo caveat: RADDY is a heavy 3D Jolt/D3D12 game with 120 Hz physics, multiplayer over ENet (UDP, player-hosted). A browser build would need a Godot web export (single-threaded, no SharedArrayBuffer like Haluk), cannot use ENet/UDP at all (WebRTC/WebSocket only), and would have to fit a ~40 MB download budget. Realistic free choice: a Windows download as the main file, plus (optional) a small single-player/practice web demo. Not verified.
- Windows download: itch's SmartScreen / Smart App Control wording exists in both bilingual texts; keep it (no code signing, zero-cost).
- Profile bio on memode.itch.io still names only Merbut: add RADDY (owner edits).
- The portfolio's hero stats (project and game counts) update themselves from projects.ts.
