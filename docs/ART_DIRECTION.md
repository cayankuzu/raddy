> Kaynak: 2026-10-12 araştırma ajanı raporu (Half Grip mağaza sayfası, basın, Godot 4.7.2 sınıf belgeleri). Half Grip'ten hiçbir görsel, metin veya dosya kullanılmadı; bu belge RADDY için özgün bir brif.

# Half Grip sanat yönetimi incelemesi ve RADDY için özgün görsel brif (2026-10-12)

Kanıt durumu: Steam sayfasını, Steam API'sini ve dört basın kaynağını okudum. Kendim gördüklerim 5 mağaza ekran görüntüsü ve fragmandan alınmış yaklaşık 60 saniyelik kare örnekleri; bu sırada ses dinlenmedi. Godot özellikleri `godotengine/godot` deposunun `4.7.2-stable` etiketindeki sınıf belgeleriyle (XML) doğrulandı. Brifteki sayısal değerler ve hex renkler önerilerdir, ölçülmeleri gerekir. Hiçbir görsel, metin ya da dosya varlık olarak kullanılmadı ve indirilmedi.

## 1) Doğrulanmış bilgiler
- **Kimlik:** Steam uygulama no 4163270. Geliştirici ve yayıncı Half Games. Yalnızca Windows. Türler: Action, Indie, Racing, Simulation. Fiyat listelenmemiş, ücretsiz değil. Çıkış tarihi "To be announced" (`coming_soon=true`), Early Access ibaresi yok. Kaynak: https://store.steampowered.com/app/4163270/Half_Grip/ ve https://store.steampowered.com/api/appdetails?appids=4163270
- **Özellikler:** Tek oyunculu; çevrimiçi ve LAN PvP; çevrimiçi ve LAN co-op; altyazı; Aile Paylaşımı. API ayrıca "Partial Controller Support" diyor. Oyuncu sayısı yazmıyor.
- **Kullanıcı etiketleri:** Action Roguelike, Combat Racing, Driving, Physics, PvE, PvP, Automobile Sim, Character Customization, 3D, First-Person, Third Person, Post-apocalyptic, Bullet Time, Vehicular Combat, Pixel Graphics ve diğerleri.
- **Sayfadaki tanıtım:** Tek kolla direksiyon, ateş, şarj ve vites. Sürüş gerçekçi ile arcade arasında; lastik tutuşu yükseltmelere ve yol koşuluna bağlı. Yarış kazandıkça para gelir; ram, pompalı tüfek, mıknatıs ve mayın açılır. Roguelike koşu yapısı (drifter, stormchaser, speedster kurguları) ve araç rengi seçimi var. Görsel stile dair tek ifade: pistler "harsh pixelated detail" ile çizilmiş.
- **Motor:** Mağazada ve bulduğum basında geçmiyor, yani UNVERIFIED. SteamDB 403 döndürdü.
- **Sistem gereksinimi:** En düşükte i7-6700K, 8 GB RAM, Nvidia 960M, 600 MB. Önerilen GPU da 960M.
- **Yaş sınıflandırması:** DEJUS 14, Almanya 16, IGRS 18.
- **Ödül:** Romanian Game Awards'ta "Best Student / Game Jam Project". Hem Steam sayfasında var, hem RevistaBiz'de (11 Haziran 2026): https://www.revistabiz.ro/tearscape-cel-mai-bun-joc-romanesc-al-anului/
- **Medya:** 5 ekran görüntüsü (1920x1080) ve 2 fragman ("Gameplay Trailer", "Racing Teaser"). Resmi web sitesi yok; Discord, Instagram, YouTube @HalfGripGame ve TikTok bağlantıları var.
- **Basın:**
  - ixbt.games (13 Eylül 2026, B. Piletskiy): Stüdyo çıkışı 2026 sonuna kadar hedefliyor; birinci şahıs kamera. https://ixbt.games/en/news/2026/09/13/pokazali-geimplei-half-grip-boevoi-roguelike-gonki-v-retro-stile.html
  - Denfaminicogamer (6 Ağustos 2026): "pixel-art tarzı" roguelike savaş yarışı. https://news.denfaminicogamer.jp/news/2608063a
  - Foro3D (15 Eylül 2026): Rumen stüdyo; yalnızca fareyle kontrol; demo ve multiplayer planlanıyor. Tek kaynak olduğu için UNVERIFIED. https://foro3d.com/2026/septiembre/half-grip-roguelike-de-carreras-que-se-conduce-solo-con-el-raton.html
  - Niche Gamer 403, 3DNews bağlantı hatası verdi; ikisi de yalnızca arama özetinden biliniyor.
- **Geliştiricinin sanat yönetimi üzerine yazısı veya devlog'u bulunamadı.**

## 2) Sunum ilkeleri: ne gördüm, ne çıkardım

### Görüntü yapısı
- **[ÇIKARIM]** Düşük iç çözünürlük, en yakın komşu (nearest) büyütmeyle iri pikseller. Düşük poligonlu modeller, düşük çözünürlüklü dokular. Gölge ve dolaylı ışık çok az; ışık düz ve ortam ışığı ağırlıklı.
- **[SAYFA]** Bu durum "harsh pixelated detail" ifadesi ve Pixel Graphics etiketiyle tutarlı.

### Palet ve atmosfer [ÇIKARIM]
Her pist tek baskın renk ve ruh hali üzerine kurulu:
- Gece, karlı çam ormanı (mavi-siyah ve beyaz).
- Yağmurlu alacakaranlık ormanı, uzun başak tarlası (yeşil-gri).
- Sonbahar ormanı, neredeyse tek renk kırmızı-turuncu.
- Gri sisli eğimli oval stadyum.
- Yağmurlu gece şehri, teal ve magenta neon.
- Fragmanda: sisli gri apartman şehri ve mor tonlu karlı dağ.

Yoğun mesafe sisi ve karanlık hem atmosferi kuruyor hem görüş mesafesini, dolayısıyla performans bütçesini sınırlıyor.

### Araç stilizasyonu [ÇIKARIM]
Köşeli, 80'ler tarzı coupé ve sedan siluetleri. Garajda döner tabla üzerinde 3 renkli boya seçici, para ve yükseltme slotları var (fragmandan).

### Çevre yoğunluğu ve siluet [ÇIKARIM]
Konik çamlar ve ağaç gövdeleri gökyüzüne karşı net siluet veriyor. Yol kenarında çit ve tahta var. Yoğun, düşük detaylı tekrar kullanılıyor; uzak plan sisle kesiliyor.

### Kamera [GÖRÜLDÜ]
- Ekran görüntülerinin hepsi kokpit içi birinci şahıs. Torpido ve A direkleri kadrajın yaklaşık alt %40'ını kaplıyor (tahmin).
- Dikiz aynası çalışıyor, tek eldiven ya da el görünüyor. Fragmanda baş çevirme ve takla anı var.
- Third Person yalnızca etiket olarak geçiyor, görmedim: UNVERIFIED.

### HUD ve geri bildirim [GÖRÜLDÜ]
- Diegetik öğeler: torpidoda vites kutusu, dolum çubuklu nitro tüpü, A direğinde LED şerit, kırmızı buton grubu.
- 2D katman: sağ üstte sıralama paneli (oyuncu kırmızı, "0 / 3" tur sayacı) ve sağ üstte süzülen silah görseli.
- Dünyada piksel fontlu kombo yazıları ("Drift x10.0", "OverTake", "Kill").
- Efektler: piksel sprite alev, siyah duman, beyaz çizgi yağmur, kar taneleri, namlu parlaması. Karlı dağ pistinde turuncu viraj şevronları var (okunurluk için).
- Ses: dinlenmedi, UNVERIFIED.

### Okunurluk [ÇIKARIM]
Doygunluğu düşük çevre üzerinde yüksek doygunluklu vurgular (alev, neon, şevron, kırmızı oyuncu adı) önemli bilgiyi taşıyor. Tutarlı ve "tek araya düşük kalite" görünüm, farklı kaynaklardan gelen varlıklar arasındaki kalite farklarını gizliyor.

### RADDY için dersler (ilke düzeyinde, kopya değil)
1. Her biyom ve hava kombinasyonu tek bir ruh hali tarifi olsun: Environment, güneş, sis ve LUT aynı veri kaynağından seed ile seçilsin.
2. Sis hem estetik hem bütçe aracı olsun: bitki örtüsünün görünürlük mesafesi sis bitişine bağlansın. Kavşak tabelası ve tehlike ipuçları sisi delmeli (MASTER §14.2).
3. Kokpit kadrajı hız ve ölçek hissi veriyor. RADDY'de göstergeler, kâğıt harita, camlar ve kutular diegetik olsun.
4. Doygun renkleri yalnızca oynanış için kritik şeylere ayır.
5. RADDY "stilize gerçekçilik" hedefliyor, yani düşük kalitenin birleştirici etkisi yok. Birliği malzeme kuralları ve LUT sağlamalı.
6. Ödül ve geri bildirim yazıyla değil, fizik, ses ve navigatör sesiyle verilsin.

## 3) RADDY özgün sanat brifi: "Stilize Gerçekçilik / Saha Rallisi" (Godot 4.7.2, Forward+)

**Fikir:** Gerçek oranlı araç ve arazi. Sınırlı ve biyoma özgü palet. Alçak güneş. Katmanlı sis. Oyunun ikonu, kabin içindeki sıcak kâğıt harita.

Doğrulanan proje durumu: `project.godot` içinde "Forward Plus" ve D3D12 tanımlı. Brif şu belgelerle uyumlu: `C:\Users\Cayan\Desktop\raddy\docs\RADDY_SUPPLEMENT_ART_ENGINEERING.md` §3 ve `RADDY_MEGA_MASTER_PROMPT_FINAL.md` §7.3 ve §14.

### WorldEnvironment
- **Gökyüzü ve ortam ışığı:** Arka plan Sky. Ortam ve yansıma ışığı Sky kaynaklı.
- **Ton eşleme:** `tonemap_mode=AGX(4)` [DOĞRULANDI: AgX renk tonunu en iyi koruyan seçenek, ayarlanabilir, ama "en yavaş" ton eşleyici].
  - `tonemap_agx_white` en az 6 (belge fotogerçekçi görüntü için ≥6.0 öneriyor; varsayılan 16.29). Öneri 8–12.
  - `tonemap_agx_contrast` varsayılan 1.25. Öneri: orman 1.25, çöl 1.2, dağ 1.4.
  - ACES yalnızca karşılaştırma için düşünülsün. Belgeye göre daha sert kontrastlı, ayarı yok ve yalnızca SDR.
- **Mesafe sisi:** `fog_mode=FOG_MODE_DEPTH(1)` ile `fog_depth_begin/end/curve` deterministik çalışır.
  - Öneri: bitki örtüsünün `visibility_range_end` değeri yaklaşık `fog_depth_end` olsun.
  - Çöl ve dağ için `fog_aerial_perspective` 0.3–0.6 [DOĞRULANDI: küçük maliyet, BG_SKY gerekir].
  - Vadi ve sabah sisi için `fog_height` ve `fog_height_density`.
- **Hacimsel sis:** Yalnızca Forward+ [DOĞRULANDI].
  - Sis, yağmur ve toz fırtınası hava durumlarında ve Orta kalite ve üstünde açılsın.
  - `volumetric_fog_length` 48–64 m. Belge "olabildiğince düşük tut" diyor; varsayılan 64.
  - Proje ayarlarında `volume_size` ve `volume_depth` varsayılan 64; Düşük kalitede kapalı olsun.
  - **Kabin hilesi:** Kabine bağlı, negatif yoğunluklu FogMaterial kullanan bir FogVolume, araç içini sisten temizler [DOĞRULANDI: negatif yoğunluk sisi kaldırır].
  - Hızlı kamerada zamansal yeniden izdüşümün iz bırakıp bırakmadığı test edilmeli: UNVERIFIED.
- **SSAO:** Forward+ ve Compatibility'de var [DOĞRULANDI]. Varsayılan yarım çözünürlük. Orta kalitede açık; öneri `ssao_intensity` 1.5–2, `ssao_radius` 0.6–1.0.
- **SSIL:** Yalnızca Forward+. Belgeye göre SDFGI veya VoxelGI ile birlikte kullanılmak üzere tasarlanmış, bu yüzden yalnızca Yüksek kalitede açılsın.
- **Küresel aydınlatma (GI):**
  - LightmapGI dünya için kullanılamaz: dışa aktarılmış projede pişirilemez ve prosedürel seviyeye uygun değil [DOĞRULANDI].
  - VoxelGI çalışma anında pişirilebilir ama her pişirme 5–20 saniye sürer ve kapsamı sınırlıdır [DOĞRULANDI]. Uzun etaplar için uygun değil.
  - SDFGI prosedürel seviyeye uygun ama GPU'ya "görece ağır". Dinamik engelleyicileri desteklemiyor, yani araçlar GI'yı kapatmaz [DOĞRULANDI]. Yalnızca "Ultra" isteğe bağlı seçenek olsun, `gi/use_half_resolution` açık.
- **Glow:** Hafif tutulsun (yoğunluk 0.3–0.5, `hdr_threshold` en az 1). Farlar, stop lambaları ve sis içindeki emissive tabelalar için.
- **Renk düzeltme:** Biyom ve hava başına `adjustment_color_correction` ile LUT (GradientTexture1D veya Texture3D). Belgeye göre LUT yalnızca SDR aralığında çalışır.
- **Pozlama:** Biyom başına sabit pozlama önerilir. CameraAttributesPractical'daki otomatik pozlama kullanılacaksa dar aralıkta tutulsun, yoksa kabinden dışarı geçişte pompalama yapar (öneri).

### Güneş (DirectionalLight3D)
- Gölge açık, mod `SHADOW_PARALLEL_4_SPLITS(2)` (varsayılan).
- `directional_shadow_max_distance` varsayılan 100. Öneri 120–150.
- `split_1` için öneri yaklaşık 0.04–0.05: kabin içi gölgeleri keskin olsun.
- `blend_splits` yalnızca Yüksek kalitede (orta düzey maliyet [DOĞRULANDI]).
- `shadow_caster_mask` ile çim ve küçük objeler gölge düşürmesin [DOĞRULANDI özellik].
- `light_angular_distance` (PCSS) Düşük ve Orta'da 0, Yüksek'te yaklaşık 0.5 (belirgin maliyet, yalnızca Forward+).
- Proje ayarı: gölge haritası 4096, 16 bit (varsayılan).
- Güneş alçakta dursun, 15–35°: tümsek ve tekerlek izleri uzun gölgeyle okunur. Bu bir çıkarım ve öneri.
- **Farlar:** Gölgeli SpotLight sayısı sınırlı olsun: yalnızca yerel araç ya da en yakın N araç. Diğerleri gölgesiz (öneri, ölçülmeli).
- **Kabin dolgu ışığı:** Gölgesiz, kabin katmanına `light_cull_mask` ile sınırlı OmniLight.

### Malzemeler
- **Genel:** ORMMaterial3D, tek ORM dokusu [DOĞRULANDI]. Kanal sırası R=AO, G=roughness, B=metallic (glTF düzeni; Godot belgesi sırayı yazmıyor: UNVERIFIED).
- **Albedo aralığı:** Doğal yüzeylerde sRGB 30–240; saf siyah ve saf beyaz yok (öneri).
- **Doku yoğunluğu (öneri):** Dünya 256–512 px/m, araç dışı 512 px/m, kabin içi 1024 px/m.
- **Kaya ve yamaç:** `uv1_triplanar` ve `uv1_world_triplanar`. Belgeye göre 3 kat doku okuması yapar, daha yavaştır ve keskin değildir; yalnızca dik kayalarda kullanılsın.
- **Arazi:** Özel shader. Yol grafından gelen maske ile yol / şev / arazi ayrımı; triplanar yalnızca eğim eşiğinin üstünde; döşeme tekrarını kırmak için ortak makro gürültü dokusu.
- **Görsel ve fizik eşleşmesi:** Aynı yüzey kimliği hem malzemeyi hem tutuş değerini sürsün (çakıl, çamur, kum, asfalt, kar). Gördüğün zemin, hissettiğin zemin olmalı.
- **Decal'ler:**
  - Çamur sıçraması, yağ lekesi, kavşak fren izleri, taş düşmesi izleri.
  - Kümelenmiş atlas yapısında; Forward+ ve Mobile'da var, Compatibility'de yok.
  - `distance_fade_enabled` açık (varsayılan başlangıç 40 m).
  - Decal'ler alttaki malzemenin şeffaflığını değiştiremez [DOĞRULANDI].
  - Sürekli lastik izi için decal yerine şerit mesh (öneri).
- **Araç kiri:** Araç shader'ında `dirt_amount` parametresi. Maske: yukarı bakan yüzeyler, alt gövde gradyanı ve AO.
- **Islaklık:** Küresel shader değişkeni `wetness`. Gözenekli albedo yaklaşık ×0.65, yol pürüzlülüğü 0.15–0.3.
- **Cam:** Sağlam / çatlak / tekmelenip çıkmış durumları maske dokusuyla; tek şeffaf katman.
- **Etkileşim vurgusu:** `stencil_mode` dış çizgisi düşünülebilir ama belgede deneysel (experimental) işaretli.

### Bitki örtüsü
- **Parçalı MultiMesh:** Yol boyunca 32–64 m'lik parçalara bölünmüş MultiMeshInstance3D. Gerekçe [DOĞRULANDI]:
  - Bir MultiMesh bütün olarak görünür ya da görünmez sayılır.
  - Nesne başına ışık sınırı tüm MultiMesh için geçerlidir; sınır dolunca kalan örnekler ışık almaz. Sis ve gece farlarında bu önemli.
- **LOD kademeleri:**
  - L0: tam mesh, 0–40 m.
  - L1: kartlar, 40–120 m.
  - L2: impostor, 120 m'den sis sonuna.
  - Geçiş `visibility_range_*`, margin değerleri ve `FADE_SELF` ile (fade yalnızca Forward+ [DOĞRULANDI]).
  - İçe aktarılan mesh'lerde otomatik LOD: `mesh_lod/lod_change/threshold_pixels`.
- **Çim:** Yalnızca 0–25 m. Gölge düşürmesin, rüzgâr shader'ı kullansın.
- **Rüzgâr:** Küresel shader rüzgâr vektörü, haritanın uçması ve açık pencere rüzgârıyla aynı kaynaktan gelsin.
- **Occlusion culling:** Varsayılan kapalı. Belgeye göre açık sahnelerde az fayda verir ve CPU maliyeti vardır. Dağ tepeleri için ölçülerek açılabilir.
- **Biyoma göre siluet:**
  - Orman: yoğun karışık tepe örtüsü ve orta katman çalılık.
  - Çöl: seyrek, alçak ağaç ve çalı, kaya kemerleri.
  - Dağ: seyrek iğne yapraklılar, iri kaya blokları, moloz yamaçlar.

### Post FX sınırları
- **Açık olanlar:** AgX, hafif glow, LUT, SSAO, hava durumuna bağlı hacimsel sis.
- **Kenar yumuşatma:**
  - Varsayılan SMAA.
  - Seçenek olarak TAA, ya da FSR2 1.0 ölçekte (belgeye göre FSR2 1.0'da TAA çözümü olarak çalışır).
  - Düşük donanımda FSR1 (yalnızca Forward+) ya da FSR2 0.67–0.77 ölçek.
- **Kapalı olanlar:** Kromatik sapma, film grain, piksel efekti ya da `SCALING_3D_MODE_NEAREST` ölçekleme (4.7'de var ama referansın imza görünümü), posterize, PS1 tarzı vertex titremesi.
- **Hareket bulanıklığı:** Okunan 4.7.2 belgelerinde (Environment, CameraAttributesPractical, ProjectSettings) yerleşik bir ayar bulunamadı. Yazılmayacak.
- **Kısıtlı olanlar:**
  - DOF yalnızca harita yakın planı ve menülerde.
  - Vignette yalnızca hasar ve bayılma durumunda.
  - Kamera sarsıntısı üst sınırlı ve ayardan azaltılabilir (MASTER §7.3).
- **Kalite ön ayarları (öneri, ölçülmeli):**
  - Düşük: derinlik sisi, SSAO kapalı, 2 gölge bölmesi, 2048 gölge haritası, 80 m gölge mesafesi.
  - Orta: SSAO, 4 bölme, 4096, 120 m, hava durumunda hacimsel sis.
  - Yüksek: Orta'ya ek olarak SSIL, blend splits, PCSS, TAA.
  - Ultra: SDFGI yarım çözünürlük.
  - Performans hedefi (ör. GTX 1060 sınıfı, 1080p60) önerilmiş, doğrulanmamış bir hedef.

### Biyom paletleri (sRGB hex, özgün öneri)

| Öğe | ORMAN (nemli, serin gölge, sıcak ışık hüzmesi) | ÇÖL (yüksek tonlu, ağartılmış, sert gölge) | KAYALIK DAĞ (serin, berrak, irtifa) |
|---|---|---|---|
| Gök zenit / ufuk | #5F82A6 / #B4C3C8 | #4A82C2 / #E0CFB2 | #3C6A99 / #BFCEDA |
| Güneş | #FFE2B8, enerji 2.0–2.5 | #FFF0D6, enerji 3.0–3.5, yükseklik 35–55° | #FFF3E6, enerji 2.5–3 |
| Ortam ışığı | #6F8A86 | #A8B4C0 (gölgeler serin kalır) | #9DB0C2 |
| Sis | Derinlik #8A9C91, hacimsel albedo #D5E0D6 | Pus #D6BC94, toz fırtınası #B48858, hacimsel #E2C49A | Vadi (height fog) #A9B7C3, hacimsel #E4EAF0 |
| Ana bitki | Kanopi #22331D / #3D5629 / güneş alan #77893F; çalı-eğrelti #4B6532 | Soluk zeytin çalı #7A7748, kuru ot #BCA36A | Alpin çimen #6C7C3B, kuru alpin #A0985A, iğne yapraklı #2A392A |
| Kaya / kum | Yosunlu kaya #686C5A | Kum #DEC198 / #C49C68 / #9E7149; kil #B47F57; kızıl kaya #A0533B; koyu kaya #5B3B2D | Granit #A19C95 / #77736D / #4A4846; moloz #8B847A |
| Yol yüzeyi | Kuru çamur #5C4834, ıslak çamur #392A1D (roughness 0.3), stabilize #866F55 | Çakıl #A58F73, eskimiş asfalt #6C6863 | Sert çakıl / moloz #8B847A |
| Diğer | Kabuk #4A3A2C; seyrek yaprak vurgusu #A85F2C | — | Kar #E4EAF0 (asla #FFFFFF değil); liken vurgusu #B08A2C |

**Hava durumu değiştiricileri (öneri):**
- Yağmur: güneş ×0.35, gök #8C959C.
- Sis: `fog_depth_end` 70–110 m, ama tam hızdaki fren mesafesinden kısa olmasın.
- Toz fırtınası: güneş ×0.4, ton #FFD9A8.

**Biyomdan bağımsız vurgular (çevrede kullanılmaz):**
- Takım renkleri: #F08A24 (turuncu), #2C7BD6 (mavi), #C2368C (fuşya). Renk körlüğü için kaplama deseni ve numara ikinci kodlama olsun.
- Kavşak ve navigasyon tabelası: zemin #F1ECE2, mürekkep #1C1C1C, numara #FFD23F, emissive 0.3–0.6.
- Tehlike: #C62828 ve #F1ECE2 şerit.
- Kâğıt harita: kâğıt #EDE3CF, kat gölgesi #CDBFA3, mürekkep #2B2A33.
- Okunurluk kuralları (öneri):
  - Yol ile şev arasında en az yaklaşık %15 parlaklık farkı.
  - Bitki doygunluğu (HSV S) en fazla %55.
  - Rota bilgisi asla yalnızca renkle verilmesin.

## 4) KOPYALANMAYACAKLAR LİSTESİ
- **Arayüz:**
  - Sağ üst sıralama paneli ve "0 / 3" tur sayacı, oyuncunun kırmızı adı.
  - Piksel font.
  - Sağ üstte süzülen silah görseli.
  - Kombo yazıları ("Kill / OverTake / Drift xN").
  - A direği LED şeridi, torpido vites kutusu, nitro tüpü göstergesi, kırmızı buton grubu.
  - Sağdaki "Paint the Car" paneli ve Color 1/2/3 garaj düzeni.
- **Görünüm:**
  - Düşük çözünürlük ve nearest pikselleme, "harsh pixel" estetiği.
  - Tek renkli kırmızı sonbahar ormanı.
  - Teal ve magenta neon gece şehri, magenta üst afiş.
  - Sprite piksel alev.
- **Araçlar ve kabin:** Köşeli 80'ler coupé tasarımları, torpido ve direksiyon düzeni (dümen şakası dahil), eldivenli tek el.
- **Varlıklar:** Ekran görüntüleri, fragman kareleri, anahtar görsel (far ve patlama kompozisyonu), el yazısı logo, sesler ve müzik, "Half" ve "Grip" adları, rakip adları (Nirdox, UnclePecos, Ema, Waka, El Pollo, Apollyon), mağaza metni.
- **Yapı:**
  - Roguelike koşu döngüsü, yarış arası para ile silah ve yükseltme.
  - Pompalı, tabanca, mayın, mıknatıs, ram.
  - Öldürme ve sollama puanlaması.
  - Tek kol ve yalnızca fareyle kontrol düzeni.
  - Bullet time, silahlı yapay zekâ rakipler.
  - Oval stadyum ve şehir pisti formatı.
- **RADDY'de kalacak kimlik:** Navigatör, fiziksel kâğıt harita, ortak R-kurtarma, yakınlık sesli sohbeti, cam ve pencere durumları, fırlatılan kutular, fiziksel komedi.

## Kaynaklar
- Steam sayfası: https://store.steampowered.com/app/4163270/Half_Grip/
- Steam API: https://store.steampowered.com/api/appdetails?appids=4163270
- Ekran görüntüsü klasörü: `https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/4163270/` (ss_88a02b6d…, ss_8940da82…, ss_6597dfe0…, ss_467a15cb…, ss_070c5e12…). Yalnızca tarayıcıda görüntülendi, indirilmedi.
- ixbt.games, Denfaminicogamer, Foro3D, RevistaBiz bağlantıları yukarıda.
- startupcafe.ro: yalnızca arama özeti. https://startupcafe.ro/jocurile-si-studiourile-romanesti-premiate-la-romanian-game-awards-2026-cine-sunt-castigatorii-101304
- Godot sınıf belgeleri (4.7.2-stable etiketi): https://github.com/godotengine/godot/tree/4.7.2-stable/doc/classes — Environment, DirectionalLight3D, Light3D, GeometryInstance3D, BaseMaterial3D, ORMMaterial3D, Decal, MultiMesh, FogVolume, VoxelGI, LightmapGI, Viewport, ProjectSettings, CameraAttributesPractical.
- Proje: `C:\Users\Cayan\Desktop\raddy\project.godot`, `docs\RADDY_SUPPLEMENT_ART_ENGINEERING.md`, `docs\RADDY_MEGA_MASTER_PROMPT_FINAL.md` (§7.3, §14).

