# RADDY — ULTIMATE MEGA MASTER PROMPT
## Godot 4 tabanlı, çevrim içi, üç takımlı fiziksel co-op ralli oyunu
> **Bu doküman, Claude Code'a verilecek ana geliştirme talimatıdır.** Sadece fikir, tasarım önerisi, maket veya teknik plan üretme. Mevcut proje klasörünü incele, sistemi doğrula, çalışan oyunu adım adım geliştir, test et, hataları düzelt ve yayınlanabilir bir MVP teslim et. Projede zaten içerik varsa onu koru ve iyileştir; körlemesine yeniden yazma.
---
# 0. GÖREVİN, ÇALIŞMA TARZIN VE BAŞARI TANIMIN
Sen; kıdemli Godot oyun programcısı, multiplayer/network mimarı, araç fiziği geliştiricisi, procedural level designer, oyun tasarımcısı, teknik sanatçı, ses tasarımcısı ve QA lideri gibi çalışacaksın. Hedef, tek bir bağımsız geliştiricinin Claude Code yardımıyla geliştirebileceği, kapsamı kontrollü ama karakteri güçlü bir oyun çıkarmaktır.
## 0.1. Temel çalışma ilkeleri
1. Önce çalışma dizinini, `project.godot` dosyasını, sahneleri, scriptleri, varlıkları, Git durumunu, export ayarlarını ve mevcut testleri denetle.
2. Dizin boşsa veya proje başlamamışsa düzenli ve minimal bir Godot projesi oluştur. Doluysa mevcut yapıya saygı göster.
3. Kod yazmadan önce en fazla bir sayfalık uygulama planı ve risk listesi çıkar; sonra gerçek uygulamaya devam et. Sadece plan verip işi bırakma.
4. Kullanıcının vermediği ama uygulama için gereken küçük kararları profesyonel ve makul varsayımlarla al. Gereksiz açıklama sorularıyla geliştirmeyi durdurma.
5. Her önemli aşamada projeyi aç, import et, çalıştır, test et ve hataları düzelt. Test etmediğin bir özelliği bitmiş gibi anlatma.
6. Yalnızca çalışır durumda olan özellikleri “tamamlandı” olarak işaretle. Yapılamayan noktaları, teknik nedenini ve en kısa manuel adımı açıkça belirt.
7. KISS uygula: gereksiz soyutlama, gereksiz eklenti, devasa tek script, kopyalanmış kod, kullanılmayan dosya, placeholder içerik, sahte buton ve çalışmayan ayar bırakma.
8. Bütün önemli sistemler birbirine doğru bağlansın. Harita üretimi navigasyon notlarıyla, hava durumu zemin tutuşuyla, açık/kırık pencereler rüzgârla, fırlatılan nesneler gerçek araçlarla ve kurtarma yarış doğrulamasıyla entegre çalışsın.
9. İnternet erişimin varsa teknik kararları güncel resmi Godot belgeleri ve gerçek eklenti depolarıyla doğrula. Mevcut olmayan API, node, paket, eklenti, export özelliği veya test sonucu uydurma.
10. Gerçek 3D modelleme yapma. Ücretsiz ve lisansı uygun gerçek varlıkları bulup entegre et; gerektiğinde basit yol geometrisi, collision, spline, procedural modül ve temel teknik mesh üret. Oyunun çevresi gri kutulardan ibaret kalmasın.
11. Proje dosyalarını yıkıcı şekilde silme veya tüm yapıyı tek seferde yeniden yazma. Değişiklikleri küçük, anlaşılır ve doğrulanabilir adımlarla yap. Mümkünse önce Git branch/checkpoint oluştur; Git yoksa değişiklik öncesi güvenli yedek al.
12. Geliştirmeyi kullanıcının tek bilgisayarında yapılabilecek şekilde tasarla. İkinci bilgisayar zorunlu olmasın. Bir bilgisayarda bir sunucu ve birden çok istemci örneğiyle test düzeni kur.
## 0.2. Ürün hedefi
RADDY; **ralli ciddiyetini fiziksel komediyle buluşturan, üç takımın aynı değişken güzergâhta yarıştığı, araç içi kaosu ve yakınlık sesli sohbetini kullanan bir çevrim içi co-op ralli oyunudur.**

Sürücü otomobili sürer. Navigatör büyük fiziksel kâğıt haritayı açıp yolları okur, kavşak seçimlerinde yardımcı olur, pencereleri açar, araç içindeki nesneleri yönetir ve gerektiğinde ön camı tekmeleyerek çıkarır. Harita uçabilir, kutular pencereden fırlatılabilir, taşlar camı çatlatabilir, çarpışmalar aracı hasarlayabilir. Her oturumda yol ağı farklı oluşturulur; yollar yalnızca dekoratif şerit değil, etkileşimli bir arazi ağının parçalarıdır.

Oyunun mizahı slapstick ve fiziksel olaylardan gelir. Oyun görsel olarak tamamen karikatür olmak zorunda değildir: araçlar, arazi, ışık ve sesler inandırıcı olmalı; komedi, gerçekçi bir ralli ortamında oyuncuların başına gelen saçma ama fiziksel olarak anlaşılır olaylardan doğmalıdır.
---
# 1. SABİT ÜRÜN KARARLARI
Bu kararları geliştirme sırasında keyfî biçimde değiştirme.

- Oyun adı: **RADDY**.
- Motor: Godot 4, tercihen güncel kararlı 4.x sürümü. Preview/dev/beta sürümünü üretim projesi için kullanma. Makinedeki kurulu sürümü ve proje uyumluluğunu kontrol et; sürüm yükseltmesi gerekirse sebebini belgele.
- Ana dil: GDScript. Web hedefi nedeniyle C# veya native-only bağımlılık seçme; proje hedefi indirilebilir PC olsa bile GDScript KISS ve dağıtımı kolay tutar.
- İlk ücretli hedef: itch.io üzerinden indirilebilir masaüstü oyun; ilk hedef platform Windows x64. Linux desteği ancak ana sürüm kararlı olduktan ve ayrı test edildikten sonra eklenebilir.
- Test aşaması: ücretsiz, özel arkadaş testi build'i. İlk aşamada ödeme, kayıt, hesap, reklam veya mağaza entegrasyonu yok.
- Yayın hedefi: oyun hazır olduğunda yaklaşık **5,99 USD** fiyatla itch.io tam sürüm. Bu fiyat teknik gereklilik değil, ürün hedefidir.
- Tarayıcı demosu: MVP'nin çıkış şartı değildir. Mimariyi gereksiz yere web ile sınırlama; ileride web demosu değerlendirilebilsin ama öncelik kararlı masaüstü sürümüdür.
- Oda sınırı: **en fazla 6 oyuncu, 3 takım, takım başına en fazla 2 oyuncu**. 8 oyuncu/4 takım yok.
- Her takımda bir sürücü zorunlu, navigatör isteğe bağlı.
- Oyuncular arasında ayrı takım ses kanalı yoktur. Sesli sohbet yalnızca mesafeye/konuma bağlıdır. Oyuncular yakındaysa duyulur; uzaktaysa ses duyulmaz.
- Tek bir yarış lobisindeki bütün oyuncular aynı rota grafiğini, aynı yol üretim seed'ini, aynı biyom/hava ayarını ve aynı yarış kurallarını kullanır.
- Her yeni yarışta rota yeni oluşturulabilir; aynı yarışın 2. ve 3. turlarında rota yeniden üretilmez.
- Birincil kamera, araç içindeki sürücü/navigatör rolüne uygun kokpit perspektifidir. Görüş seçenekleri gerekiyorsa ikincil bir araç takip kamerası eklenebilir; ancak kokpit sistemlerinin yerini almayacak.
- Oyuncu etkileşimleri ve hasar ağ üzerinde herkes için tutarlı olmalı. Yalnızca görsel istemci hilesiyle fizik sonuçları değişmemeli.
- Ücretli oyun için mutlaka harici ücretli bir servis satın almak zorunda kalınmamalı. Her dış hizmetin fiyatı, limitleri, ücretsiz katmanı ve olmazsa ne olacağı belgelenmeli.
---
# 2. MVP'NİN SINIRI: ŞİMDİ YAPILACAKLAR VE SONRAYA KALACAKLAR
## 2.1. MVP'de zorunlu
1. Açılış ekranı, ayarlar, çevrim içi oda oluşturma/katılma ve özel oda kodu.
2. Oda başına en fazla 3 takım / 6 oyuncu; takım seçimi ve sürücü/navigatör rolü.
3. Takımda bir sürücü olmadan yarışa başlatmama; navigatör olmadan tek sürücülü oynama desteği.
4. Çalışan sürüş fiziği: direksiyon, gaz, fren, el freni, drift, tümsek, çarpışma, devrilme ve yüzeye göre tutuş.
5. Çevrim içi oyuncu konumları ve araç fizik durumları için tutarlı senkronizasyon.
6. Gerçek mikrofon kullanan, mesafeye bağlı/mekânsal sesli sohbet; bas-konuş, mikrofon kapatma, ses seviyesi ve konuşan oyuncu göstergesi.
7. Ön cam ve sağ/sol yan camların durumları; yan camları açıp kapama, taş darbesi ve hasar, navigatörün ön camı istediğinde tekmeleyip çıkarabilmesi.
8. Açık/kırık camla artan rüzgâr, toz, çakıl ve çamur girişi; cam kirliliği ve çalışan silecekler.
9. Çakıl/yüz maruziyeti için stilize kan, kısa görüş bozulması ve aşırı maruziyette 6 saniyelik bayılma. Gerçekçi gore yok.
10. Navigatörün büyük fiziksel kâğıt haritayı M ile açması; büyütme/küçültme ve kaydırma; fiziksel açılma/kapanma animasyonu; sert sarsıntı/rüzgârla haritanın düşebilmesi/uçması.
11. Harita kaybolduğunda yeni haritanın 6 saniyede hazırlanması; bu sırada navigatörün tam haritaya erişememesi.
12. Torpidodan sınırlı sayıda enerji içeceği kutusu alma; kutuları elde tutma ve açık pencereden fırlatma; kutunun diğer araca/cama fiziksel olarak çarpması ve sınırlı hasar verebilmesi.
13. R tuşu kurtarma sistemi: devrilme/sıkışma/kritik hareketsizlik 3 saniye devam edince aracı kurtarma seçeneği görünmesi; iki oyunculu takımda iki oyuncunun da onayı; tek oyuncuda tek onay; araç mevcut konumda güvenle düzeltilemiyorsa en yakın güvenli konuma koyma.
14. Hafif/orta/kritik basit araç hasarı; çarpışma hızına, açısına ve darbe bölgesine göre görsel ve sınırlı sürüş etkileri.
15. Üç biyom: Orman, Çöl, Kayalık Dağ. Her biri farklı siluet, çevre objeleri, yüzeyler ve yol karakteri taşımalı.
16. Hava seçenekleri: Açık, Yağmur, Sis, Kar, Toz Fırtınası. Biyom-hava kombinasyonları mantıklı kurallarla filtrelenmeli.
17. Yarış zorluğu: Keşif, Ralli, Kırmızı Çizgi, Rastgele.
18. Tur sayısı: 1, 2, 3 ve Rastgele.
19. Her ayar için ayrı Rastgele seçeneği ve tüm ayarları birden seçen Sürpriz Ralli.
20. Yeni oturumda farklı rota üreten ama oynanabilirliği doğrulanan prosedürel yol ağı.
21. Üçlü kavşaklar, yol çatalları, alternatif yollar, kestirmeler, yanlış yollar, çıkmaz veya gecikmeli döngüler, yeniden birleşen yollar ve belirgin arazi işaretleri.
22. Profesyonel level design: dar koridorlar, görüşü kesen virajlar, tepeler, çukurlar, kaya geçitleri, ağaçlar, çalılar, çitler, hendekler, su kanalları, tabelalar, köprüler ve yol kenarı etkileşimleri.
23. Kontrol noktaları, tur doğrulaması, kesme/kestirme kuralları, bitiş ve takım sıralaması.
24. Korna, selektör/ışık flaşı, silecekler, cam kontrolleri ve yeniden yarış.
25. Ücretsiz gerçek 3D varlıklar; lisans ve kaynak manifestosu.
26. Tek bilgisayarda sunucu ve birden çok istemciyle test, ağ simülasyonu ve altı oyuncu yük testi.
27. Windows build'i, kurulum/çalıştırma talimatları, hata raporlama/logging, test checklist'i ve itch.io paketleme notları.
## 2.2. Sonraki güncellemelere bırak
- Tam araç modifikasyon ağacı, garaj ekonomisi, parça satın alma ve kalıcı ilerleme.
- Derinlemesine motor, şanzıman, fren, lastik aşınması ve süspansiyon hasar simülasyonu.
- Araçtan araca tam parça kopma, ayrıntılı deformasyon ve binlerce fiziksel cam parçası.
- Araç tamir mini oyunları, pit-stop ekonomisi ve çok etaplı ralli hafta sonu.
- Sezonlar, ligler, sıralamalı eşleştirme, kozmetik mağaza veya mikro ödeme.
- Çok sayıda araç sınıfı, çok sayıda biyom ve devasa açık dünya.
- Önceki ekiplerin geçişiyle yolun kalıcı fiziksel değişmesi.
- Gelişmiş yapay zekâ rakipleri.
- Zorunlu tarayıcı sürümü.

MVP, sonraki sürümlerin bu sistemlerini eklemeyi imkânsızlaştırmayan temiz bir veri modeli kurmalı; fakat gelecekte eklenebilecek her şeyi şimdiden inşa etmemeli.
---
# 3. ANA OYUN DÖNGÜSÜ
1. Oyuncu oyunu açar ve ana menüye gelir.
2. Oda oluşturur veya oda koduyla katılır.
3. En fazla üç takıma ayrılır. Her takım bir sürücü seçer; ikinci oyuncu varsa navigatör olur.
4. Host yarış ayarlarını seçer: zorluk, tur, biyom, hava. Her ayar Rastgele olabilir; tümü tek seçimle Sürpriz Ralli yapılabilir.
5. Sunucu rota seed'ini üretir, yol ağını oluşturur, bağlantı ve oynanabilirlik doğrulaması yapar. Geçersiz rota yeniden üretilir.
6. Tüm istemcilere rota bilgisi/seed ve kurallar gönderilir; her istemci aynı yol geometrisini ve haritayı üretir veya doğrulanmış rota verisini yükler.
7. Oyuncular kısa başlangıç alanında buluşur; yarış kısa aralıklarla başlatılabilir. Klasik ralli hissini koru, fakat takımların yarış sırasında birbirine yaklaşmasına/yan yana gelmesine fırsat ver.
8. Sürücü aracı kullanır, navigatör haritayı okur, kavşaklar hakkında karar verir ve gerekirse kabin etkileşimlerini yönetir.
9. Yol, hava, nesne fırlatma, cam ve araç hasarı sistemleri aynı yarışın içinde birbirini etkiler.
10. Takımlar kontrol noktalarını geçer; geçerli rota dışındaki sürüşe izin verilir ancak checkpoint atlanamaz ve yarış mantığı sömürülemez.
11. Tur tamamlanır; gerekiyorsa aynı rota bir sonraki turda tekrar kullanılır.
12. Bitiş zamanları, kurtarma cezaları ve kontrol noktaları doğrulanır; sonuç ekranı açılır.
13. Oyuncular aynı rotayı tekrar oynayabilir veya yeni seed ile yeni rota seçebilir.

Yarış süresi ilk MVP testlerinde makul tutulmalı. Uzun bir simülasyon yerine tekrar oynanabilir, kısa ve komik oturumlar hedefle. Tur uzunluğunu procedural route modülleriyle kontrol et; çok kısa ve çok uzun rota varyantlarına sınır koy.
---
# 4. TEKNİK ÖN KONTROL VE MULTIPLAYER MİMARİSİ
Multiplayer ve voice chat, projenin en yüksek riskli kısmıdır. Bunları oyun tamamlandıktan sonra ekleme. İlk aşamada küçük fakat gerçek bir prototip kur.
## 4.1. Önce doğrulanacak prototip
Tam içerik üretmeden önce şu prototipi tamamla:

- İki ayrı istemci aynı odaya katılabiliyor.
- Bir istemci sürücü, diğeri navigatör olabiliyor.
- Aynı aracın temel durumu ve iki oyuncunun konumları tutarlı.
- Gerçek mikrofon girdisi başka istemcide duyuluyor.
- Ses mesafeye göre kısılıyor ve konuma göre sağ/sol yön hissi veriyor.
- Bir cam durumu ve bir fırlatılan nesne ağda senkronize olabiliyor.
- Bağlantı kesildiğinde uygulama donmuyor veya bütün oyun çökmeden hatalı oturumdan çıkabiliyor.
- Windows debug build'i ve release template ile çalışıyor.

Bu testlerden biri çalışmıyorsa başarısız teknolojinin üzerine bütün oyunu inşa etme. Önce nedeni bul, güncel resmi dokümantasyonu ve ilgili eklentinin bakım/uyumluluk durumunu doğrula, küçük alternatifleri karşılaştır ve en az bağımlılık isteyen çalışan çözümü seç.
## 4.2. Ağ mimarisi gereklilikleri
- Yarış state'i için bir authoritative otorite olmalı: dedicated/listen server veya gerekçelendirilmiş host-authoritative çözüm.
- Oyuncu input'ları, pozisyon/fizik state'i, rota seed'i, eşya atma, cam kırılması, hasar, kurtarma onayı ve yarış sonuçları net bir mesaj şemasına sahip olmalı.
- İstemci kendi başına skor, checkpoint, kurtarma konumu veya başkasının hasarını kesinleştirememeli.
- Network mesajları doğrulanmalı; yetkisiz oyuncu başka takımın araç state'ini veya oda ayarlarını değiştirememeli.
- Her oyuncunun bir `player_id`, `team_id` ve `role` değeri olsun. Aynı takımda en fazla iki oyuncu, birden fazla sürücü yok.
- Oyuncu yarışı terk ederse takımın kalan oyuncusu devam edebilsin; sürücü giderse belirlenmiş bir kurala göre takım yarışı bırakabilsin veya navigatör kontrolü devralabilsin. MVP'de devralma desteklenmiyorsa net bir takım sonucu göster.
- Host kopması, timeout, yeniden bağlanma ve oda kapanması için zarif davranış ekle. Host migration gibi büyük özellikleri MVP'de uygulamak zorunda değilsin.
- Oyuncuların internet üzerinden kolayca bağlanması hedefleniyorsa NAT/firewall gerçeğini açıkça ele al. Salt LAN'da çalışan sistemi internette çalışıyor gibi sunma.
- Ücretsiz arkadaş testi için yerel ağ/direct connection/host modu geçici kullanılabilir; ancak herkesin internet üzerinden gireceği yayın hedefinde gerçek bağlantı yolunu doğrula. Port yönlendirme veya sunucu kurulumu gerekiyorsa README'de açıkça belirt; oyuncunun bunları bilmek zorunda kalıp kalmayacağını önceden değerlendir.
- Yönetilen servis/eklenti kullanılacaksa güncel ücret, limit, build uyumluluğu, export bağımlılıkları ve vendor lock-in incelensin. Ücretli servis zorunluysa bunu gizleme; maliyetsiz/öz barındırılan alternatifini de incele.
- Altı oyuncu için gereksiz mikroservis mimarisi, Kubernetes, ayrı veritabanı, kullanıcı hesabı sistemi veya büyük backend kurma.
- Vercel benzeri serverless işlevleri sürekli çalışan gerçek zamanlı oyun sunucusu gibi kullanma. Eğer eşleştirme için HTTP/serverless uygunsa bunu gerçek zamanlı state sunucusundan ayır.
- Ağ sorunu olduğunda kullanıcıya “Bağlantı zayıf”, “Sunucu yanıt vermiyor”, “Mikrofon izni yok” gibi net bilgiler ver.
## 4.3. Senkronizasyon
- Oyun fiziği için tek gerçek kaynak belirle. Her istemcinin aracı bağımsız simüle edip pozisyonları gelişigüzel birbiri üstüne yazmasına izin verme.
- Yerel input'a hızlı tepki verilebilir; uzaktaki arabalar interpolasyonla yumuşatılmalı.
- Araç çarpışmalarında çakışan fizik state'lerini düzeltmek için deterministik/authority tabanlı kararlar kullan.
- Fırlatılan nesnelerin çıkış pozisyonu, ilk hızı, spin'i, çarpışması ve despawn zamanı tutarlı olsun.
- Her saniye gereksiz büyük scene ağ üzerinden gönderilmesin. Yalnızca gerekli değişiklikleri/özet state'leri gönder.
- Her oyuncu her karede bütün ağaçların ve her parçacığın state'ini yollamasın. Dekoratif parçacıklar mümkün olduğunca yerel olarak üretilebilir; gameplay etkisi olan sonuçları otorite belirler.
- Ağ güncelleme sıklıklarını profil ölçümleriyle ayarla. Keyfî şekilde çok yüksek rate kullanma.
---
# 5. SESLİ SOHBET — SADECE PROXIMITY VOICE
Bu özellik temel ürün özelliğidir, sonradan eklenecek bir aksesuar değildir.
## 5.1. Davranış
- Takım ses kanalı, global ses kanalı veya uzak oyuncuların duyulduğu sürekli yayın yok.
- Oyuncular fiziksel olarak yakındaysa birbirlerini duyabilir.
- Aynı araçtaki sürücü ve navigatör yakın oldukları için rahatça konuşabilir.
- Başka araçtaki oyuncular yaklaşıp uzaklaştıkça ses seviyeleri ve netlikleri değişir.
- Ses, oyuncunun bulunduğu 3D pozisyona göre pan/uzamsal konum almalı.
- Duvar, araç gövdesi, kapalı cam, açık cam ve dış ortam sesleri için abartısız occlusion/filter farkları kullanılabilir. Kabin filtresi tasarımını performansla dengele.
- Mesafe sınırının dışında karşı tarafın sesi tamamen duyulmaz hale gelir.
- Kısık ses/mesafe eğrisi ani bir aç/kapa yerine yumuşak olmalı.
- Varsayılan push-to-talk önerilir; isteğe bağlı ses etkinliği modu eklenebilir, ama hot mic davranışını varsayılan yapma.
- Kişi bazında sessize alma, mikrofon test ekranı, giriş aygıtı seçimi, sesli sohbet açık/kapalı, push-to-talk tuşu, input gain ve voice volume seçenekleri bulunmalı.
- HUD'da yalnızca gerçekten konuşan yakındaki oyuncunun adını/ikonunu kısa süre göster. Ekranı dolduran voice widget yapma.
- Yalnızca sesli sohbet çalışmadığı için oyunun tamamı çökmesin. Ses bağlantısı ayrı bir servis/katman gibi yönetilsin.
- Tarayıcı gelecekte hedeflenirse HTTPS, mikrofon izni, autoplay ve WebRTC sinyalleşme kısıtlarını ayrıca ele al; ancak masaüstü MVP'sini web export desteğine bağlı hale getirme.
## 5.2. Teknoloji seçimi
- Güncel Godot 4 sürümüyle Windows build'inde gerçekten mikrofon yakalama, ses kodlama/iletme, uzak ses oynatma ve mesafeye bağlı 3D ses sağlayan çalışan çözümü araştır.
- Bir eklentinin “Godot 4 destekli” yazması tek başına yeterli değil. Depo hareketliliği, sürüm uyumluluğu, lisans, Windows ikili dosyaları, gereken ek servis, paketleme ve gerçek 2 istemci testi kontrol edilmeli.
- Steam'e bağlı eklentiyi seçme; hedef dağıtım itch.io ve oyuncuların Steam'e sahip olması zorunlu değil.
- Deneysel veya kararsız paket ana mimariyi riske atıyorsa daha sade alternatif seç. Kendin özel ses protokolü kurmaya başlamadan önce kanıtlanmış çözümü değerlendir.
- Mikrofon verisini kaydetme veya sunucuda saklama. Ses chat sadece canlı iletim için kullanılsın.
- Voice sisteminin bağlantı kuramaması halinde kullanıcıya açık uyarı göster ve mikrofon izinlerini doğrulama ekranı sun.
---
# 6. ODA, TAKIM, ROL VE LOBİ
## 6.1. Oda
- “Oda Oluştur”, “Odaya Katıl”, “Arkadaşlarla Test”, “Ayarlar”, “Çıkış” akışları gerçek çalışmalı.
- Özel oda kodu veya güvenilir oda bağlantısı bulunmalı. Oda kodu tahmin edilmesi kolay, kısa ve çakışmaya açık olmamalı; basit oda kodlarında rate limit/expiry düşün.
- Test build'inde LAN/özel oda akışı olabiliyorsa hem host hem client talimatları gösterilsin.
- Oda içindeki oyuncu listesi bağlantı durumunu, takımını ve rolünü göstersin.
- Her takımda en fazla iki koltuk: Driver ve Navigator. İki sürücü veya iki navigatör aynı anda aynı takımda olamaz.
- Takım başına Driver olmadan “Hazırım” yarışa geçemez.
- Navigator boşsa tek oyuncu takımına izin ver.
- Yarış başlamadan önce herkes aynı zorluk/tur/biyom/hava özetini görsün.
- Host ayarları değiştirirse tüm istemcilere güncellenmiş hali gitsin.
- Yarış sürerken oda parametreleri değiştirilemesin.
## 6.2. Rol farkları
**Sürücü:** Aracı kullanır, direksiyon/gaz/fren/el freni, korna, selektör, sürücü tarafı cam kontrolü ve temel gösterge panelini yönetir.

**Navigatör:** Büyük haritayı açar ve inceler, yol notlarını okur, sağ/sol pencereleri yönetebilir, torpidoyu açar, enerji içeceği alır ve atar, ön camı istediği zaman tekmeleyip çıkarır. Bu etkileşimler sürücünün direksiyonunu veya kamerasını yanlışlıkla devralmamalı.

**Tek oyunculu takım:** Sürücü tek başına katılabilir. Navigatör eylemlerini gerektiren nesne/harita sistemleri tamamen kilitlenmesin; fakat sürücü harita açıp tüm ekranı kapatırken aracın kontrolünü kaybedebileceği için bu bir risk olsun. Tek oyuncuya yardımcı olmak için küçük bir sürüş notu/uyarı bileşeni sunulabilir; bu yardımcı tam haritanın veya navigatör rolünün yerini almamalı.
---
# 7. SÜRÜŞ FİZİĞİ VE ARAÇ KONTROLÜ
## 7.1. Sürüş hedefi
Fizik, simülasyon meraklıları için anlaşılmaz derecede zor veya arcade olacak kadar ağırlıksız olmamalı. Araç ağırlığını, hızını, momentumunu ve zemine göre tutuşunu hissettirmeli. Direksiyonun etkisi hızla değişmeli; yüksek hızda sert dönüş anında aracı kusursuz döndürmemeli. El freni arkayı kontrollü biçimde bırakabilmeli. Havadayken araç kısa süre kontrol edilebilir ama havada uçak gibi yön değiştirmemeli.
## 7.2. Temel davranışlar
- Gaz ve fren ayrı kuvvet/ivme eğrileriyle çalışsın.
- Direksiyon düşük hızda daha çevik, yüksek hızda kontrollü olsun.
- El freni arka teker tutuşunu geçici azaltarak dönüş/slide başlatabilsin.
- Çakıl, toprak, kum, çamur, ıslak zemin ve kar tutuşu farklılaştırılsın.
- Tümsek ve hendekler süspansiyon/araç gövdesinde okunabilir tepki yaratsın.
- Aracın kütlesi, ağırlık merkezi ve dönüş momenti hissedilsin.
- Hava zamanı, görüşü ve yüzey tutuşunu değiştirir; sadece renk filtresi olmasın.
- Araç çarpışmaları saçma şekilde hız kazandırmamalı. Köşeye sıkışan aracın güvenli şekilde kurtarılması mümkün olmalı.
- Ağda farklı istemcilerde farklı araç yönelimleri veya ani ışınlanmalar minimumda tutulmalı.
- Debug için fizik göstergeleri ekle: hız, RPM benzeri basit motor göstergesi, yüzey türü, hasar state'i, traction bilgisi. Debug HUD üretim sürümünde kapalı olmalı.
## 7.3. Sürüş hissi ve kamera
- Birincil görünüm cockpit/driver-seat hissi vermeli.
- Yol çukurları, tümsekler, hız ve çarpışmalar küçük ve kontrollü kamera tepkileri yaratmalı.
- Kamera sallanması oyuncunun yön bulmasını imkânsız hale getirmemeli; ayarlardan azaltılabilmeli.
- Araç içindeki dash, torpido, yan camlar, ön cam kenarları ve navigatör tarafı için gerektiği kadar görünür 3D geometri oluştur.
- Araba içi etkileşim nesneleri kameranın önünü gereksiz kapatmasın. Büyük harita açıldığında yalnızca navigatör görüntüsü kapanmalı; sürücünün kendi ekranı harita ile kapanmamalı.
- İkinci bir chase camera eklenirse yarış avantajı ve checkpoint okunabilirliği test edilsin. Multiplayer fairness bozulmamalı.
---
# 8. ARAÇ HASARI: GÖRÜNÜR, HİSSEDİLİR, KAPSAMI KONTROLLÜ
MVP'de araç hasarı olmalı ama tam araç simülasyonu yapılmamalı.
## 8.1. Üç seviye
**Hafif:** küçük göçük/çizik, tampon hasarı, darbe sesi. Sürüşe etkisi ihmal edilebilir.

**Orta:** ön/arka/sağ/sol darbe bölgesine göre hasar. Araç hızlanması sınırlı düşebilir, direksiyon hafifçe bir yöne çekebilir, titreşim/ses eklenebilir. Etki anlaşılabilir ama sürücüye açıklanmaz rastgele ceza gibi gelmemeli.

**Kritik:** araç ilerleyemeyecek kadar zarar görür, motor gücü düşer veya sürüş tepkisi ağırlaşır. R kurtarma göstergesi şartları uygunsa açılır.
## 8.2. Hasar hesaplama
- Darbe hızı, darbe açısı, çarpışma normal vektörü ve etkilenen bölge hesaba katılsın.
- Ufak sürtmeler aracın çalışamaz hale gelmesine neden olmasın.
- Ağaca yüksek hızda çarpma, kayaya yandan vurma ve başka araca çarpma farklı sonuçlar üretsin.
- Hasarı yalnızca istemci hesaplayıp authoritative state gibi göndermesin.
- Hasar görseli için birkaç basit gövde varyantı/decal/durum değişimi yeterlidir. Gerçek metal deformasyonu şart değil.
- Motor, şanzıman, süspansiyon ve tekerlek başına ayrı gerçekçi simülasyon MVP dışıdır.
- Araç hasarının kullanıcı arayüzünde okunabilir bir göstergesi olsun; sayısal 0-100 çubuğu yerine sade 3-seviyeli ikon veya durum göstergesi tercih edilebilir.
## 8.3. Çarpışma adaleti
- Araç/prop çarpışmaları yarış sonuçlarını manipüle etmeye izin vermemeli.
- Kasıtlı araç çarpma mümkün olabilir ama sınırlı hasar ve adil fizik kuralları olsun.
- Nesne fırlatma rakipleri tamamen durdurmaya veya sürekli grief yapmaya dönüşmemeli.
- Kritik hasarda aracı otomatik ışınlamak yerine önce kurtarma seçeneği sun. Otomatik kurtarma ancak açık tasarım koşulu gerektiriyorsa ve exploit test edildiyse uygulanabilir.
---
# 9. CAMLAR, PENCERELER, RÜZGÂR, ÇAMUR, TAŞ VE BAYILMA
Bu sistemler tek bir kabin durum sistemi tarafından yönetilsin. Her biri ayrı scriptlerde kopya kurallara sahip olmasın.
## 9.1. Ön cam
- Başlangıçta sağlam.
- Taş/çakıl darbeleri görünür çatlaklar oluşturabilir.
- Çamur, yağmur ve yol suyu camı kirletebilir.
- Silecekler açılıp kapanabilir; görüşü belirli oranda temizler. Her şeyi anında kusursuz temizlememeli ama işe yaradıkları açıkça görülmeli.
- Navigatörün özel “Camı Tekmele” input'u ile camı istediği zaman kırıp yerinden çıkarmasına izin ver.
- Bu işlem bir animasyon, ses, kısa titreşim ve durum değişimiyle tamamlanmalı. Tekme butonu sadece UI efektini çalıştırmamalı; gerçek cam state'ini değiştirmeli.
- Ön cam çıkarılınca ön görüş daha açık görünür ama rüzgâr/toz/çakıl maruziyeti artar.
## 9.2. Yan camlar
- Sürücü tarafı ve navigatör tarafı camları ayrı state taşısın: kapalı, açık, çatlak/kırık.
- İlgili oyuncu penceresini açıp kapatabilsin. Navigatör her iki tarafa erişebilsin.
- Taş veya yeterince hızlı fırlatılmış enerji içeceği kutusu yan cama hasar verebilir. Her küçük kutu darbesi camı anında patlatmamalı; hız/eşik/hasar state'i baz alınsın.
- Kırık pencere fiziksel olarak boşluk yaratmalı; rüzgâr, dış ses, toz ve nesne davranışları bu state'i izlesin.
- Pencereyi açmak/kapamak sadece görsel animasyon değil, fizik/oyun etkisi olan state değişikliğidir.
## 9.3. Toz, çamur, rüzgâr ve çakıl
- Tekerlek hızına ve yüzeye göre araç arkasında toz/çamur/çakıl parçacıkları oluştur.
- Yağmur/ıslak zeminde çamur sıçraması, kuru çakılda toz ve gevşek taş; kumda yoğun toz bulutu; karda ince parçacık/sis etkisi oluşabilir.
- Etkiler mesafe ve hızla tutarlı olsun; her aracın arkasından sürekli aynı miktarda parçacık çıkmasın.
- Açık/kırık cam içeri giren toz ve çakılı artırır. Kapalı sağlam cam koruma sağlar.
- Rüzgâr sesi hızla artar. Açık pencerede iç mekân sesi açık cam hissi verir; ön cam yokken rüzgâr daha güçlüdür.
- Etkiler performans için GPU/CPU dostu olsun, uzaktaki partiküller azaltılsın.
## 9.4. Yüze çarpan çakıl ve bayılma
- Kabin açıksa hızlı çakıl/taş içeri girme ihtimali olabilir.
- Yüz darbesi kısa stilize bir kan sıçrama overlay'i, ses ve kısa görüş bozulması oluşturabilir.
- Grafikler gore seviyesine çıkmamalı; gerçekçi parçalanma/detaylı yaralanma yok.
- Maruziyet/yaralanma birikimi belirlenen eşik üstüne çıkarsa oyuncu 6 saniye baygın kalır. Bayılma durumu multiplayer'da tutarlı senkronize edilir.
- Bayılma sırasında oyuncu geçici olarak ilgili rol girdilerini kullanamaz; kamera abartısız bulanıklaşır/kapanır. Altı saniye sonunda kontrollere geri dönülür.
- Sürücü bayılırsa araç hareketi güvenli biçimde yönetilsin: input kesilmesi, gazın serbest bırakılması ve fiziksel aracın momentumla devam etmesi; sihirli bir anda frenle durdurma yok.
- Navigatör bayılırsa sürücü devam edebilir ancak yönlendirme yardımı kaybedilir.
- Bu sistemde kalıcı oyuncu ölümü yok. MVP'de ceza kontrollü, oyun akışı kesintisiz ve komik kalmalı.
- Maruziyet oyuncuyu sürekli kilitleyecek şekilde abartılmasın; oyuncuların cam/pencere/rüzgâr kararları gerçek bir risk-ödül yaratsın.
---
# 10. FİZİKSEL KABİN NESNELERİ VE ENERJİ İÇECEĞİ KUTULARI
## 10.1. Torpido
- Navigatör torpidoyu açabilsin.
- İçinde sınırlı sayıda enerji içeceği kutusu bulunsun. İlk MVP'de örneğin 3 kutu yeterlidir; sayı oyun testleriyle ayarlanabilir.
- Kutuyu almak için net bir etkileşim input'u olsun. Kutunun elinde görünmesi veya kameraya uygun yakın fiziksel konumda durması gerekir.
- Elde tutulan nesne, kamera önünde yapışık/arayüz ikonu gibi görünmesin; mümkün olduğunca 3D fiziksel nesne gibi algılansın.
- Navigatör sağ veya sol pencereyi açıp kutuyu dışarı fırlatabilsin. Pencereler kapalıysa fırlatma davranışı net olsun: önce pencereyi açmasını iste veya cam varsa çarpışıp geri sekmesini göster. Nesne camın içinden klipsle geçmesin.
## 10.2. Fırlatma fiziği
- Fırlatma yönü nişan açısına/oyuncu bakışına veya seçilen basit bir throw aim'e bağlı olsun.
- İlk hız, otomobil hızı ve fırlatma gücünün sınırlı birleşimi olabilir. Araç yüksek hızda giderken kutu dünya hızına uygun davransın.
- Nesne düşüş, spin, sekme ve çarpışma yaşasın.
- Nesne multiplayer'da otorite altında oluşturulup state'i gerektiği kadar senkronize edilsin.
- Nesnelerin yaşam süresi ve azami eşzamanlı sayısı sınırlansın. Uzakta/etkisiz nesneler güvenli şekilde temizlensin.
- Torpido stokları yeniden yarış başlatıldığında resetlenebilir; MVP'de karmaşık loot sistemi yok.
## 10.3. Hasar
- Enerji kutusu rakip aracın kaportasına vurduğunda ufak ses/çarpma tepkisi verebilir ve çok küçük bir hasar etkisi oluşturabilir.
- Hızlı kutu yan cama vurursa cama hasar/çatlak verebilir; camın kırılması için hız ve mevcut cam dayanımı eşiği olmalı.
- Kutu araca ağır mekanik hasar vermemeli.
- Kutu oyuncuya/karakter modeline çarparsa kısa komik tepki/ekran titreşimi oluşabilir; gerçekçi yaralama veya gore yok.
- Başka oyuncuya sürekli obje atarak oyunu kilitleme veya sınırsız spam engellenmeli.
- Friendly-fire gibi kural seçenekleri MVP'nin parçası olmak zorunda değil; kutular genel olarak küçük komedi etkileşimi olarak dengelensin.
## 10.4. Diğer fiziksel nesneler
MVP'de ek envanter sistemi oluşturma. Harita ve enerji içeceği yeterlidir. Boş kutular kabinde savrulabilir; her birinin full physics object olmasına gerek yok. Daha fazla nesne türü sonraya kalır.
---
# 11. BÜYÜK FİZİKSEL KÂĞIT HARİTA VE NAVİGASYON
Harita RADDY'nin en ayırt edici görsel ve oynanış objelerinden biridir. Küçük bir minimap'e indirgeme.
## 11.1. Fiziksel hissiyat
- Büyük, katlanabilir, eski tip kâğıt arazi/şehir haritası hissi.
- Harita navigatörün elinden açılır ve kapanır; kat izleri, kâğıt kıvrılması ve sarsıntı animasyonları bulunur.
- Navigatör M'ye bastığında ekranın büyük bölümünü kaplayabilir. Bu sadece statik full-screen UI olmamalı; görünür kabin kamerasından harita açılma animasyonuyla geçiş yapılmalı.
- M tekrar basılınca harita katlanıp kapanır.
- Mouse wheel ile yakınlaştırma/uzaklaştırma; drag ile kaydırma. Tüm harita görünümü tek tuşla geri alınabilsin.
- Harita açıkken navigatörün kabin etkileşimleri geçici olarak başka kontrollere yönlendirilmesin; harita modu net bir input context'e sahip olsun.
- Sürücünün kamerası ve input'u etkilenmesin.
## 11.2. Harita içeriği
- Tam prosedürel rota/yol ağı, dallanmalar ve kavşaklar görünür olsun.
- Yol ayrımlarının şekli ve çevredeki ayırt edici işaretler okunabilsin.
- Harita biyoma göre topografik görünüm taşısın: ormanda yoğun konturlar/yeşil alanlar, çölde kum tepeleri/kurak bölge, kayalık dağda yükselti ve kaya siluetleri gibi.
- Harita sadece doğru yolu parlak bir çizgiyle gösteren GPS olmamalı. Navigatör yol ağını, dalları ve dönüm noktalarını görür; doğru seçimi yol notları, arazi işaretleri ve kavşak numaralarıyla yorumlar.
- Kullanıcı tüm harita ağını görmek istediği için rota kopyası saklanmış bir minimap olmasın. O yarışın oluşturulmuş harita ağının tamamını gösterebilmeli.
- Harita ve oyun dünyası aynı route graph/seed datasından türetilmeli; ayrı ayrı üretilip birbirinden kopmamalı.
- Harita üzerinde araç konumu güncellenebilir; bunun görünürlüğünü ayarlanabilir yap. Oyuncu aracı haritada küçük bir işaret olarak takip edebilsin.
- Harita üstünde bütün yanlış yollar da gösterilebilir ama doğru yolun çizgiyle aşırı belirgin gösterilmesi navigasyon görevini ortadan kaldırmamalı.
## 11.3. Haritanın düşmesi/uçması
- Harita açıkken, pencere açık ve araç hız/rüzgârı belirli eşiğin üzerindeyse uçma riski başlar.
- Harita uçmadan önce kâğıt titreşimi, rüzgâr sesi ve kısa görsel uyarı olsun. Uyarısız rastgele kaybolma olmasın.
- Yeterince şiddetli sarsıntı/çarpışma da haritayı düşürebilir.
- Harita uçtuğunda kabinden dışarı doğru fiziksel hareketle çıkmalı; networkte aynı olay yaşanmalı. Harita dışarıda dekoratif bir süre görünüp ardından kaybolabilir.
- Harita uçtuktan sonra 6 saniyelik yeniden hazırlama süresi başlar. Süre bitince navigatör yeni haritayı açabilir.
- Bu 6 saniyede HUD gizli tam haritayı göstererek cezayı boşa çıkarmasın.
- Her açık pencere ve her düşük hızda harita otomatik uçmamalı. Risk hıza, rüzgâra ve yol sarsıntısına dayansın.
- Harita fizik etkileşimini gameplay açısından önemli tut ama oyunu sürekli kilitleyecek şekilde sık tetikleme.
## 11.4. Yol notları
- Procedural route graph'tan navigatöre yol notları üret.
- Notlar gerçek dallanma sırasıyla örtüşmeli. Örneğin “üçüncü çıkıştan sağa”, “kırmızı tabelayı geçince dar sola”, “köprüden sonra orta yol” gibi okunabilir çağrılar olabilir.
- Aynı kavşağa ait not oyunun her istemcisinde aynı olmalı.
- Navigatör bir yol notunu geç kaldığında, yanlış dal seçildiğinde veya harita kapalıyken sürücünün kararı yine oynanışla sonuçlansın.
- Notlar her virajı otomatik doğru söyleyen bir HUD'a dönüşmemeli. Navigatörün katkısı gerçek olmalı.
- Zorluk modu notların erkenliği, ayrıntı seviyesi veya işaretlerin belirginliği üzerinde etkili olabilir; zorluk, sahte/random yanlış bilgi vererek oyuncuyu cezalandırmamalı.
---
# 12. PROCEDURAL ROUTE GRAPH VE BRANŞLI GÜZERGÂHLAR
Bu sistemi “rastgele kıvrılan spline” gibi uygulama. Gerçek bir bağlantı grafiği, yol parçası seti, rota doğrulaması ve harita eşleşmesi kullan.
## 12.1. Yol graph'i
- Düğümler (junction, checkpoint, start/finish, landmark, branch start/end) ve aralarındaki edge/yol segmentleri mantıklı bir graf oluşturmalı.
- Her edge bir gerçek geometri modülüne veya spline tabanlı yol segmentine bağlı olmalı.
- Segmentlerde giriş/çıkış yönü, genişlik, eğim, yüzey türü, biyom uyumu, tehlike seviyesi ve izin verilen komşu modüller gibi metadata bulunabilir.
- Segmentler birbirine bağlandığında yolun genişliği, yükseklik, zemin ve collision kopuklukları olmamalı.
- Araçların manevra yapamayacağı kadar keskin veya kendi içine giren yol bağlantıları otomatik reddedilsin.
- Rota seed'i oda state'inin bir parçası olsun. Sunucu seed'i üretir ve tüm istemcilere yollar.
- Aynı seed + aynı generator version aynı graph'i oluşturmalı; generator deterministik değilse sunucu grafisini serialize ederek yolla. İki yöntemden birini kanıtla ve kullan.
- Networkte bütün ham 3D mesh verilerini sürekli göndermek yerine seed/version/parametreleri veya kompakt graph verisini kullan.
## 12.2. Yol çeşitleri
En az aşağıdaki türleri modüler segment/kavşak ailesi olarak destekle:

- Orman dar yolu.
- Orman içi hafif açık gravel.
- Keskin kör viraj.
- S virajı.
- Yükselen yol/tepe aşımı.
- Alçalan yol.
- Üçlü kavşak.
- İki kollu kavşak.
- Birleşen iki alternatif rota.
- Daha uzun güvenli alternatif.
- Kısa ama riskli kestirme.
- Terk edilmiş toprak servis yolu.
- Dar kaya geçidi.
- Hendek/su kanalı yanı.
- Basit köprü/menfez.
- Geçici su birikintisi veya çamurlu geçit.
- Yanlış yöne götüren döngü/uzayan yol.
- Geçerli çıkmaz ve geri dönüş alanı.
- Start/finish çevrimi ve checkpoint segmenti.

MVP'de her türün onlarca varyantı gerekmiyor. Her tür için az ama kaliteli modül ve rastgele parametre kombinasyonu yeterli.
## 12.3. Alternatif yollar ve kestirmeler
- Oyuncu normal yol dışına çıkabilsin. Oyun sadece görünmez şeride bağlı bir yarış pisti olmamalı.
- Yol ağında kısa/uzun, güvenli/tehlikeli seçenekler olsun.
- Bazı dallar yeniden birleşsin. Bazıları uzun döngüyle aynı bölgeye dönsün. Tasarım gerekiyorsa kontrollü çıkmaz da olabilir.
- Navigatör, örneğin üç yol ayrımında “sağdaki kestirme ama çamurlu; ortadaki teknik; soldaki daha uzun” gibi anlamlı bilgi aktarabilsin.
- Alternatif yol kullanıldığı için oyuncuya otomatik ceza kesme. Oyuncular meşru bir kestirmeyi keşfedebilmeli.
- Adalet; kontrol noktalarının sırası, güzergâh bütünlüğü, zemin riski ve gerçek mesafe ile sağlansın. Harita sınırının dışına çıkarak checkpoint atlamak veya bitişe ışınlanmak engellensin.
- Her dalın bir gameplay gerekçesi olsun. Farklı yolların tümü aynı mesafede ve aynı yüzeyde olursa karar anlamsızlaşır.
- Rastgele üretimde bir dal tek yönlü çıkmaza gidiyorsa oyuncuya geri çıkabilme alanı ve fiziksel dönüş alanı bırak. Aracı sıkıştıran procedural softlock üretme.
## 12.4. Oynanabilirlik doğrulaması
Her üretim sonrası şunları doğrula:

1. Start/finish arasında geçerli ana route bulunur.
2. Her zorunlu checkpoint doğru sırada erişilebilirdir.
3. Ana rota süresi minimum/maksimum sınırlar arasında kalır.
4. Hiçbir junction yolu havada, yeraltında veya başka bir mesh'in içine bağlanmaz.
5. Araçların dönüş yarıçapları fiziksel olarak mümkün kalır.
6. En az bir meşru alternatif rota bulunur.
7. Harita grafı gerçek dünyadaki yol bağlantılarıyla eşleşir.
8. Yol notları graph edge ve junction'lara bağlanır.
9. Biyom/hava kombinasyonu geçerlidir.
10. AI/bot ya da otomatik test aracı ana rotayı geçebilir.
11. Checkpoint'ler alternatif güzergâhları yasaklamadan yarışın ilerlemesini doğrular.
12. Seed çökme veya sonsuz generator döngüsü üretemez; retry sayısını sınırla ve güvenli fallback seed kullan.

Geçersiz rota üretildiğinde otomatik tekrar dene; çok sayıda başarısızlıktan sonra doğrulanmış fallback layout kullan. Oyun oyuncuya boş sahne veya birbirine bağlanmayan yollar göstermemeli.
---
# 13. PROFESYONEL LEVEL DESIGN VE ÇEVRE YOĞUNLUĞU
RADDY bir açık yarış pistinde geçmemeli. Yol kenarları ve uzak çevre, oyuncuya sürüş becerisi ve navigasyon için yeterli görsel/uzamsal ipucu sunan bir arazi oluşturmalı.
## 13.1. Görüşü tasarlamak
- Sürücü çoğu zaman her virajın ve her yol ayrımının tamamını önceden görememeli.
- Görüş; yol kıvrımı, tepe, orman yoğunluğu, kaya çıkıntısı, dar geçit, çukur, sis ve çevre geometriyle kontrollü şekilde sınırlandırılmalı.
- Oyuncu adil ipuçları almalı: yol kenarı izi, tabelalar, belirgin landmark, toprak rengi, ışık/kontrast veya navigatörün notları.
- Tehlike hiçbir uyarı olmadan, son anda oyuncunun önüne fırlayan hileli bir engel olmamalı.
- Oyuncu bütün rotayı aynı görüş çizgisinde takip edebiliyorsa yol modülünü yeniden tasarla.
- Harita ve navigatör faydalı olsun; fakat sürüşün kendisi de keyifli, öğrenilebilir ve adil kalsın.
## 13.2. Yol kenarı varlıkları
Orman:
- Çeşitli gövde boyutlarında ağaçlar, ağaç kökleri, çalılar, eğrelti otları, yosun, kütükler, kayalar, yaprak örtüsü, çamur, dere, su birikintisi, çit, ahşap köprü, tabelalar ve yol işaretleri.
- Ağaçlar yolun yakınında sürücü görüşünü anlamlı biçimde kesebilsin; fakat bütün yolun görünüşünü düz bir yeşil duvara çevirmesin.
- Zemin doğal düzlükte kalmasın; küçük yükseltiler, hendekler, banketler ve çöküntüler olsun.

Çöl:
- Kum tepeleri, taş kümeleri, kurak çalılar, kaya çıkıntıları, toz ve gevşek kum cepleri, kuru dere yatağı, dar kaya koridorları, küçük geçit ve uzakta tanınabilir arazi silueti.
- Sadece sarı zemin ve kopyalanmış kaktüslerden ibaret yapma.

Kayalık dağ:
- Kayalık duvarlar, dağ yamaçları, taş düşmesi bölgeleri, dar geçitler, hendekli kenarlar, uçurum hissi, taş köprü/menfez, sert toprak ve çakıl yığınları.
- Gerçek uçurum tehlikesi kullanılacaksa oyuncunun tehlikeyi önceden okuyabilmesi ve kurtulma şansı bulunması gerekir.
## 13.3. Bütün nesneler etkileşimli mi?
“Bütün harita etkileşimli” hedefini gameplay açısından yorumla: oyuncunun sürülebilir alan içinde karşılaştığı önemli nesneler yalnızca dekoratif resim olmasın; çarpışma, tutuş, görüş, ses veya rota seçimi üzerinde anlamlı sonuçları olsun.

- Ağaç ve büyük kaya çarpışma yaratır.
- Çalı/ot hız ve görüş üzerinde hafif etki yapabilir.
- Çit/tabela gibi uygun nesneler sınırlı şekilde kırılıp devrilebilir.
- Su, çamur, kum ve çakıl farklı tutuş/partikül/ses davranışı verir.
- Küçük yaprakların veya her çimin ayrı rigid body olması gerekmez. Bu CPU, ağ ve performans maliyetini gereksiz büyütür.
- Her objenin fizik durumu multiplayer'da senkronize edilecekse gerçekten gameplay için gerekiyorsa yap. Dekoratif küçük hareketleri yerel tut.
## 13.4. Level art pass
Her segment için önce sürüş bloklaması ve collision, ardından gerçek varlık, ışık, materyal, partikül ve ses ekle. Sonunda debug mesh'lerini kaldır. Fakat yalnızca asset yığma: kompozisyon, uzak yakınlık katmanları, renk ve aydınlatma kontrollü olsun.

Her yol modülünü en az üç açıda test et: sürücü yaklaşımı, kavşak merkezinden görünüm, farklı rotadan geri bakış. Prosedürel birleşimlerde ağaç/rock mesh'leri yola taşmamalı, yüzeyler kesişmemeli, ışık veya atmosfer yol işaretlerini görünmez yapmamalı.
---
# 14. BİYOM, HAVA VE ZORLUK KURALLARI
## 14.1. Biyomlar
**Orman:** dar yol, sık çevre, çamur, su, kökler, ağaç görüş engeli, yağmur/sis için uygun.

**Çöl:** kum, gevşek gravel, toz, sıcak kuru atmosfer, kayalık geçit, toz fırtınası için uygun.

**Kayalık Dağ:** sert gravel, kaya duvarı, dar geçit, yükselti/değişen eğim, taş düşmesi riski, yağmur/sis/uygun yükseklikte kar.

Her biyom kendine ait yol kenarı varlık havuzu ve yüzey kuralları kullanmalı. Yalnızca skybox değiştirerek biyom değiştirme.
## 14.2. Hava
- Açık hava.
- Yağmur.
- Sis.
- Kar.
- Toz fırtınası.

Her koşulun fiziksel ve görsel etkisi olmalı:
- Yağmur: ıslak yüzey, su birikintisi, cam su damlaları/kir, sileceklerin faydası, bazı yüzeylerde düşük tutuş.
- Sis: görüş aralığı azalır; farlar anlamlı olur; tehlikeler yine adil görsel ipuçları verir.
- Kar: yalnızca uyumlu biyom/segmentlerde; yüzey tutuşu azalır ve kar parçacıkları oluşur.
- Toz fırtınası: çöl başta olmak üzere uygun kurak alanlarda; görüş, motor/araç sesi ve toz etkileri.
- Açık hava: temiz görüş, fakat toz/çakıl zemini hâlâ etkin.
## 14.3. Rastgele seçimi
- Her parametrenin tekil Rastgele seçeneği olmalı.
- Sürpriz Ralli bütün parametreleri uyumlu bir paket olarak seçer.
- Rastgele seçim önce seed ve uyumlu seçenek havuzuyla yapılır, sonra tüm oyunculara özet gösterilir.
- Geçersiz kombinasyonlar üretme: ör. her biyomda aynı şekilde kar fırtınası zorunlu değil. Kombinasyon uyumsuzsa reroll.
- Oyuncular start sırasında hangi ayarların seçildiğini görür. Rastgele seçim sürpriz olabilir ama gizlice oyunu haksızlaştırmamalı.
## 14.4. Zorluk isimleri ve etkiler
**Keşif:** geniş yollar, daha erken/ayrıntılı yol notları, daha az tehlike, daha okunur kavşak ve yumuşak ceza.

**Ralli:** normal genişlik/tehlike dengesi, standart not zamanlaması, orta seviye çevre ve yüzey zorluğu.

**Kırmızı Çizgi:** daha teknik/ince yollar, daha sık karar noktaları, daha geç/özet yol notu, daha fazla zemin/çarpışma riski ve kurtarmanın daha belirgin zaman kaybı.

**Rastgele:** oturum için geçerli zorluklardan biri seçilir.

Zorluk yalnızca aracı yapay olarak daha kaygan yapmak olmamalı. Yol genişliği, kavşak karmaşıklığı, görünürlük, not zamanlaması, tehlike yoğunluğu ve ceza toleransı gibi özellikler bir araya gelir. Aynı zorlukta bütün güzergâh modülleri imkânsız hale gelmemeli.
---
# 15. YARIŞ KURALLARI, KONTROL NOKTALARI VE KESTİRMELER
- Oda en fazla üç takım; her takım en fazla iki oyuncu.
- Yarış en fazla üç tur.
- Bir rota seed'i aynı yarış boyunca sabit.
- Başlangıç aralığı ralli hissini koruyabilir; ancak takımların yakınlaşıp karşılaşacağı kadar makul olmalı. Start aralığını sabitlemek yerine kolay ayarlanabilir konfigürasyon olarak tut.
- Kontrol noktaları yalnızca ideal yol çizgisine değil, bütün geçerli branch/loop seçeneklerine göre tasarlansın.
- Bir yol dalı meşru alternativaysa o dala giden oyuncuyu yalnızca ana merkez çizgiden saptı diye cezalandırma.
- Bir branch'in doğru sırayla devam ettiği graph/checkpoint sistemiyle doğrulansın.
- Geçersiz kontrol noktası atlama, duvarların içinden geçme, aracı harita dışına fırlatıp sonraki checkpoint'e ulaşma ve yarış bitişini erkenden tetikleme engellensin.
- Kurtarma aracı checkpoint'in ötesine koymasın. En yakın güvenli kurtarma konumu geçerli route graph'e/son güvenli yol segmentine göre seçilsin.
- Sıralama authoritative yarış sürelerinden hesaplansın; istemci gönderdiği zamanı kendisi belirleyemesin.
- Sonuç ekranında en az takım yeri, toplam süre, tamamlanan tur, kurtarma sayısı veya ceza ve finish durumu gösterilsin.
- MVP'de lig, puan tablosu, sezon veya kalıcı profil gerekmez.
---
# 16. PROFESYONEL R KURTARMA SİSTEMİ
Kurtarma sistemi hem komik hem güvenilir ve ağ üzerinde adil olmalı.
## 16.1. Tetikleme
- Araç ters dönmüş, hareket kabiliyeti ciddi kaybolmuş, fiziksel olarak sıkışmış veya kritik hasar nedeniyle ilerleyemez durumda olmalı.
- Basit şekilde durmak, frene basmak, dar virajda yavaşlamak veya yokuşta durmak tek başına kurtarma tetiklemesin.
- Otorite bu durumun en az 3 saniye sürdüğünü doğrular.
- Süre dolduğunda `R — Aracı Kurtar` göstergesi açılır. Bu, aracı otomatik ışınlamak değil, kurtarma seçeneği sunmaktır.
## 16.2. Onay
- İki oyunculu takımda sürücü ve navigatör ayrı ayrı R onayı verir.
- UI `1/2 onaylandı` / `2/2 onaylandı` gösterir.
- Belirlenmiş bir onay penceresi kullanılabilir; ilk oyuncu onay verip çok uzun süre beklerse onay eskisin/iptal olsun.
- Oyunculardan biri vazgeçerse veya araç yeniden hareket edebilir hale gelirse onay iptal edilsin.
- Tek oyunculu takım R'yi kısa bir süre basılı tutarak onay verebilir.
- Kurtarma onayı authoritative state olarak server/host tarafından işlenir.
## 16.3. Kurtarma konumu
1. Öncelikle mevcut konumda aracı güvenli ve dik duruma getirmek mümkün mü kontrol et.
2. Araç başka bir mesh'in içinde veya tehlikeli eğimde kalacaksa son geçerli segmentteki en yakın güvenli recovery anchor'ı seç.
3. Recovery anchor araç genişliği, yönü, ground raycast, yüzey eğimi ve collision boşluğu kontrolünden geçmeli.
4. Hiçbir uygun anchor yoksa segment başlangıcı veya doğrulanmış bir güvenli yol noktası fallback olsun.
5. Aracı düzeltirken checkpoint sırasını veya tur ilerlemesini değiştirme.
6. Aracın yönünü yol akışına makul şekilde hizala; dağın öbür tarafına veya bir sonraki checkpoint'in arkasına teleport etme.
7. Kısa, anlaşılır animasyon/ses ve kontrol kilidi kullan; ardından kontrolü geri ver.
8. Kurtarma küçük ve test edilebilir bir zaman kaybına neden olabilir. Ceza abartılı olmamalı.
9. Kurtarma fizik state'ini tüm istemciler aynı anda görmeli; bir istemcide dik, diğerinde ters araç bırakma.
10. Kurtarma mantığını debug tuşuyla her an tetiklenebilir ayrı bir test komutuna da bağla; bu komut production build'de kapalı olsun.
---
# 17. KONTROLLER VE UX
Kontroller yeniden atanabilir olmalı. Varsayılan tuşlar aşağıdaki gibi önerilebilir; mevcut projedeki Input Map'i inceleyerek tutarlı bir şema kur.
## 17.1. Sürücü varsayılanları
- W: gaz.
- S: fren/geri vites mantığı.
- A/D: direksiyon.
- Space: el freni.
- H: korna.
- F veya belirlenmiş tuş: selektör/far flaşı.
- Q/E: sürücü camını aç/kapat veya sağ/sol cam bağlamı; çakışan atamalar olmasın.
- R: kurtarma onayı, yalnızca kurtarma UI'si açıkken.
- Escape: duraklatma/menü; online yarışta yalnızca yerel menüyü açmalı, multiplayer oturumunu sebepsiz dondurmamalı.
## 17.2. Navigatör varsayılanları
- M: büyük kâğıt haritayı aç/kapat.
- Mouse wheel: haritada yakınlaştır/uzaklaştır.
- Mouse drag: harita üzerinde kaydır.
- F veya ayrı atanmış tuş: ön camı tekmeleyip çıkar. Sürücüdeki far flaşı ile aynı action adına bağlama; role-specific input context kullan.
- Q/E: sol/sağ yan pencereyi aç/kapat.
- Tab veya ayrı key: torpido etkileşimi.
- E: kutuyu al; left mouse veya atanmış tuş: fırlat. Bu atamaları kullanılabilir UI'da göster ve çakışmayı önle.
- R: ortak kurtarma onayı; yalnızca kurtarma penceresinde.
- ESC: haritayı/torpidoyu kapatma veya yerel menü, belirgin sıra.

Bu tuşlar sabit kodla farklı scriptlere serpiştirilmesin. Input Map ve rol context'leri üzerinden yönetilsin.
## 17.3. Ekranlar
- Ana menü: Play/Join, Create Room, Settings, Credits, Quit.
- Oda lobisi: room code, oyuncu listesi, takım/rol seçimi, ayarlar, hazır durumu ve start.
- Ayarlar: ses, voice input, voice output, mic test, push-to-talk, mute, kontrol rebind, kamera sarsıntısı, grafik ayarları, dil.
- Oyun HUD'u: hız; basit araç hasar/cam durumu; yakın ve gerekli kontrol ipuçları; tur/checkpoint; takım zamanı. Ekranı yüzlerce göstergelerle doldurma.
- Navigatör haritası: büyük, okunur, full route graph. Sürücünün görüşüne uygulama.
- Kurtarma UI'si: R, ekip onay sayısı, iptal durumu.
- Sesli sohbet göstergesi: yalnızca yakında konuşan oyuncular.
- Sonuç ekranı: sıralama, süre, ceza ve yeniden yarış/yeni rota.
- Oyun içi tuş rehberi rol bağlamına göre değişsin.
## 17.4. Kullanılabilirlik ve erişilebilirlik
- Pencere, cam, harita ve ses kontrolleri için kolay görülen input ipuçları ver.
- Kamera shake şiddeti ayarlanabilsin.
- Sesli sohbet ve oyun sesleri bağımsız ses slider'ları kullansın.
- Ekran efektleri (blood flash, bulanıklık, sarsıntı) yoğunluğu azaltılabilir olsun.
- Metin okunur, arayüz tutarlı ve 16:9/16:10 çözünürlüklerde taşmayan yapıda olsun.
- Oyuncunun mikrofon izinleri yoksa oyuna girmeyi engelleme; voice olmadan da oynanabilsin ve açıklayıcı mesaj verilsin.
- Minimum dil seti İngilizce ve Türkçe olabilir. String'leri sahne scriptlerine gelişigüzel gömme; basit localization yapısı oluştur. Global itch.io pazarı hedefleniyorsa İngilizce metinler kalitesiz makine çevirisi olmamalı.
---
# 18. SES TASARIMI
## 18.1. Temel sesler
- Motor ve RPM/hızla değişen motor sesi.
- Lastik/çakıl/çamur/kum/kar yüzey sesi.
- Gaz kesme, fren, el freni ve drift sesi.
- Tümsek, iniş, gövde sarsıntısı ve çarpışma sesleri.
- Ön/yan cam çatlama ve kırılma sesleri.
- Silecek motoru ve cam temizleme hissi.
- Açık pencere, kırık cam ve açık ön cam için rüzgâr katmanı.
- Çakılın gövdeye/cama vurması.
- Haritanın kâğıt hışırtısı, açılması, uçuş sesi ve yeni harita hazırlama.
- Torpido açılması, kutu alma, kutunun kabin/dış dünya çarpışma sesleri.
- Korna ve selektör/far flaşı feedback'i.
- Kurtarma ve bayılma feedback'i.
## 18.2. Karıştırma
- Motor, tekerlek/yüzey ve rüzgâr öncelikli katmanlar.
- Yakındaki rakip voice'u anlaşılır kalmalı; motor ve rüzgâr sesi onun üstünü tamamen kapatmasın.
- Camlar kapalı/açık/kırık olduğunda çevre ve diğer araç sesi değişsin.
- Sesler sadece her olayda yüksek ses çalmak gibi olmasın; olay başına cooldown/voice limit uygula.
- Voice chat için noise gate/codec/jitter buffering gerekiyorsa çalışan çözüm kullan; cızırtı, statik ve geri besleme testi yap.
- Telifsiz/uygun lisanslı sesler kullan ve kaynak manifestosuna yaz. Kaynağı bilinmeyen sesleri kullanma.
---
# 19. GÖRSEL YÖN VE 3D VARLIK POLİTİKASI
## 19.1. Görsel hedef
- İnandırıcı, sinematik, yoğun arazi ve kaliteli ışık.
- Oyunun mizahı gerçekçi görsel dünyanın içinde fizik olaylarından doğsun.
- Neon sci-fi HUD veya genel AI şablonu gibi görünen arayüz tasarlama.
- Araç kabini, büyük kâğıt harita, pencereler ve çevre siluetleri okunur olmalı.
- Görüntü fazla karanlık veya bloom ile yıkanmış olmasın; viraj ve yol işaretleri okunmalı.
- Her biyom aynı shader ve aynı birkaç ağaçla yapılmış gibi görünmesin.
## 19.2. Varlık edinme
Ücretsiz ve lisansı uygun gerçek asset modelleri kullan. Öncelikli kaynakları araştır:
- Poly Haven.
- ambientCG.
- Kenney.
- Quaternius.
- Lisansı açıkça uygun olan Sketchfab varlıkları.
- Resmi açık kaynak ve public-domain kaynaklar.

Bu örnekler önerilen kaynaklardır; herhangi bir spesifik modelin lisansını görmeden kullanma.

- Her asset için kaynak URL, author, lisans adı, gereken attribution, dosya yolu ve değişiklik bilgisi olan `ASSET_LICENSES.md` veya eşdeğer manifest oluştur.
- Ticari kullanım lisansını doğrula; “ücretsiz” olmak “ticari olarak serbest” olmak demek değildir.
- Telifli oyunların arabasını, logosunu, markalı UI'sini veya haritasını kopyalama.
- Oyunun marka kimliği RADDY'ye ait olsun. Rakip oyunların aynı UI düzenini, belirgin imza objesini ve sunumunu kopyalama.
- Araç asset'i bulunamazsa sıfırdan araç modellemeye başlama; uygun lisanslı genel ralli aracı kullan veya mevcut basit aracı kaliteli materyal/ışık/kamera ile iyileştir. Lisanssız model kullanma.
- Texture çözünürlüğü ve materyal sayısını kontrol et. Her asset için gereksiz 4K texture getirme.
- İçe aktarılan her modelde scale, pivot, normals, material slots ve collision kontrolü yap.
- Gerçek 3D assetlerle düzleştirilmiş görsel sprite'ları karıştırma; kaliteli 3D dünya tutarlı görünsün.
## 19.4. Özgünlük ve ilham kaynakları
- RADDY kendi adı, görsel dili, UI düzeni, oyuna özgü etkileşimleri ve pazarlama dili olan bağımsız bir ürün olarak sunulsun.
- Diğer co-op/ralli oyunlarından genel tür fikirleri öğrenilebilir; fakat belirli oyunun haritasını, HUD yerleşimini, ayırt edici animasyonlarını, nesne tasarımlarını, tanıtım cümlelerini veya markasını kopyalama.
- Özellikle RADDY'nin kimliğini yalnızca “sürücü ve harita tutan navigatör” şeklinde pazarlama. Prosedürel dallanan yol ağı, büyük fiziksel kâğıt harita, yalnızca yakındaki oyuncuların duyulduğu voice chat, cam/pencere state'i, harita uçması, fırlatılabilir kabin eşyaları ve ortak kurtarma kararının beraberliği öne çıkarılsın.
- `Left Left LEFT!`, `Rally Panic!` veya başka oyunları otomatik biçimde oyunun menüsünde “ilham alınan oyunlar” olarak yazma. Kullanıcı açıkça isterse, bunun yerine geliştirici günlüğünde doğru ve ölçülü bir ilham notu düşünülebilir. Bu not özgünlük iddiası ya da pazarlama numarası olarak kullanılmamalı.
- Yalnızca gerçekten projede kullanılan asset ve eklentilerin kaynak/lisans bilgileri Credits içinde yer alsın. Oyun kaynaklarına ait marka/logo/karakter görselini izinsiz kullanma.
## 19.3. Işık ve atmosfer
- Biyom başına uygun daylight/sky/atmosphere ayarları.
- Sis yalnızca atmosphere color olarak değil, görüş mesafesine anlamlı etki verebilsin.
- Yağmurda yüzey yansımaları kontrol altında olsun; her şey ayna gibi parlamasın.
- Çöldeki toz, ışıkta katmanlı görülsün; ancak yol ve araç kaybolmasın.
- Ağaç/çalı çeşitliliği, yol çevresi yoğunluğu ve uzak arazi silueti profesyonel kompozisyon oluşturmalı.
- FPS ve GPU frametime ölç. Güzel görünen fakat oynanışı durduran efekt kullanma.
---
# 20. MİMARİ VE KOD KALİTESİ — KISS
Projeyi küçük ve okunur alt sistemlere ayır. Tamamen data-driven dev framework veya gereksiz generic system kurma.

Önerilen bölümleme (mevcut projeye uyarla; boş yere birebir kopyalama):

- `scenes/menus/` — ana menü, oda, settings, sonuç.
- `scenes/vehicles/` — araç gövdesi, cockpit, camlar, torpido, pencereler.
- `scenes/world/` — route graph, segmentler, biome setleri ve environment.
- `scenes/ui/` — HUD, harita, kurtarma, voice indicator.
- `scripts/network/` — oda state'i, mesajlar, server/client authority ve bağlantı yönetimi.
- `scripts/gameplay/` — yarış state'i, checkpoint, hasar, recovery, item throw, cabin state.
- `scripts/procedural/` — seed, graph generator, validation ve map data.
- `scripts/audio/` — voice adapter, spatial audio routing, sound states.
- `data/` — segment metadata, difficulty config, biome/weather config, localization.
- `assets/` — model/texture/audio/fonts; lisans manifesti ile birlikte.
- `tests/` — route validation, multiplayer protocol, race progression ve smoke test.
- `tools/` — local test launcher, multi-client runner, server launch script, export helpers.

Bu öneriyi mevcut repo yapısı uygunsa kullan. Aşırı katman üretme. Tek tek game scriptlerine kopyalanmış hasar/hava/voice mantığı yazma.
## 20.1. Kod kuralları
- Anlamlı değişken/metot/scene adları.
- Sihirli sayıları config/resource sabitlerine al; her değer için gereksiz config yaratma.
- Gereksiz singleton ve Autoload kullanma. Gerçek global yaşam döngüsü olan manager'lar dışında global state'i sınırlı tut.
- `NodePath`/scene bağlantıları sağlam olsun; node adını değiştirince sessizce kırılan kodu kontrol et.
- Network mesajlarında version/type/validation ve hata yolu tanımlı olsun.
- Birden çok oyuncu aynı anda etkileşim yaptığında race condition ve çift tetiklenme olmasın.
- Object spawn/despawn temiz olsun; sahne değişince multiplayer bağlantıları veya audio stream'ler sızmasın.
- Her hata kullanıcıya anlaşılır şekilde gösterilsin; debug log ayrıntılı olabilir.
- Gelişmiş servisler interface/adaptor ile ayrılabilir; sırf ileride değiştirmek için altı katman oluşturma.
- Sabit test seed'leri ve debug komutları geliştirici build'inde bulunabilir; release build'de kullanıcıya açık hile/debug menüsü olmasın.
- `TODO`, `FIXME`, empty handler, işlev yapmayan button ve placeholder scene bırakma; zorunlu dış manuel adımlar dışında.
---
# 21. PERFORMANS VE STABİLİTE
Altı oyunculu bir oyun için performans hedefleri gerçekçi ve ölçülebilir olmalı.

- Hedef ilk olarak modern, orta seviye PC'de 1080p çözünürlükte akıcı deneyim. Ölçüm yapılmadan “60 FPS garanti” iddia etme.
- Foliage/tekrarlı varlıklar için instancing/MultiMesh uygun yerde kullanılabilir.
- Uzak nesneler için LOD veya sadeleştirilmiş mesh; fakat gereksiz pipeline karmaşası kurma.
- Çarpışma yalnızca oynanış etkili nesnelerde ayrıntılı olsun. Uzak dekoratif varlıklara pahalı collision ekleme.
- Fizik raycast/temas sayısını kontrol et.
- Partiküllerde maksimum sayım ve uzaklık limiti.
- Audio voices/voice packets için buffer limitleri ve temizleme.
- Herhangi bir oyuncu haritayı açtığında bütün dünyanın duplicate mesh kopyası oluşturulmasın; UI overlay veya kontrollü camera/UI layer kullan.
- Procedural generate sırasında ekranın uzun süre donmasını önle. MVP rotası kontrollü sayıda modülden oluşmalı; async generation gerekmeden de kabul edilebilir kısa sürede kurulmalı.
- Crash log, engine log ve multiplayer debug output bulunmalı.
- Altı istemcili yük testinde memory, CPU, packet traffic, voice traffic ve physics tutarlılığı ölçülsün.
---
# 22. TEST STRATEJİSİ — TEK BİLGİSAYAR YETERLİ OLMALI
Kullanıcının ikinci bir bilgisayarı olduğu varsayma. Geliştirme/test altyapısını tek PC üzerinde çalıştır.
## 22.1. Lokal test düzeni
- Bir server/host süreci.
- En az 2, hedefte 6 ayrı istemci süreç/instance.
- Her istemci için farklı test kullanıcısı/ID; aynı local save/settings dosyasının paylaşılması engellensin.
- Pencere örneklerini yönetmek için basit bir launch script veya dokümante edilmiş komutlar oluştur.
- GPU yetersizse altı tam 3D istemciyi eşzamanlı render etmek zorunlu olmasın: bir-iki gerçek istemci + headless/test botlarıyla ağ ve protokol yükünü test et; tam 6 oyunculu fizik ve ses testini imkan oldukça gerçek istemcilerle doğrula.
- Sesli sohbet altı süreçte test edilecekse loopback/aynı mikrofon feedback sorununa karşı kulaklık, farklı giriş cihazı veya kontrollü test kayıtları kullan. Gerçek internet testi daha sonra arkadaşlarla yapılabilir.
- Automated smoke test çalıştır: oda kur, bağlan, role seç, race state başlat, route generate et, checkpoint geç, item spawn/throw yap, glass state değiştir, recovery başlat, finish state'e ulaş.
## 22.2. Zorunlu gameplay testleri
1. Araç düzgün hızlanır, döner, frenler ve el freniyle kayar.
2. Düşük hızda dar ağaç/duvarla çarpışma, yüksek hızda kaya/ağaç çarpışması farklı hasar üretir.
3. Araba yan/ters yatar ve kontrolsüz şekilde sonsuza kadar fizik titreşimine girmez.
4. Üç saniye devrilmiş/sıkışmış kalınca R görünür.
5. İki oyunculu takımda yalnızca sürücü R'ye basarsa araç kurtarılmaz; her iki oyuncu onayladığında kurtarma olur.
6. Tek oyuncu takımında kurtarma çalışır.
7. Kurtarma aracı collision içine spawn etmez, checkpoint atlatmaz ve diğer istemcilerde aynı sonucu verir.
8. Silecekler cam kirliliğini gözle görülür biçimde azaltır.
9. Ön cam taş darbeleriyle çatlar; navigatör istediğinde tekmeleyip çıkarabilir.
10. Sağ/sol yan cam açılır, kapanır ve kırılabilir.
11. Kırık cam ve açık pencere rüzgâr/toz/çakıl davranışını değiştirir.
12. Harita M ile açılıp kapanır, zoom/pan çalışır; sürücünün görünümü etkilenmez.
13. Harita açıkken şiddetli rüzgâr ve açık cam şartları sağlanınca uyarı sonrası harita uçabilir.
14. Harita kaybından tam 6 saniye sonra yeni harita hazırlanır; daha önce navigatör full haritaya erişemez.
15. Harita yol ağı ile procedural dünyadaki ayrımlar birebir örtüşür.
16. Üç çıkışlı kavşaklara navigasyon notu oluşturulur; sağ/orta/sol seçimi değişken sonuç verir.
17. Meşru kestirme kullanımı çalışır ve haksız ceza üretmez.
18. Checkpoint atlama/finish exploit'i engellenir.
19. Torpidodan kutu alınır, fırlatılır, fiziksel olarak çarpar ve diğer istemcide aynı olay görülür.
20. Kutu cama çarparsa uygun hız eşiğinde cam hasarı oluşabilir; kaportaya vurması ağır arıza yaratmaz.
21. Yakındaki oyuncular birbirini duyabilir, uzak oyuncular duyamaz. Mesafe değişirken volume/pan yumuşak değişir.
22. Mikrofon izni reddedilirse UI hatayı açıklar, oyun çalışmaya devam eder.
23. Korna, selektör, silecek, cam, mapa ve recovery input'ları rol bazında doğru çalışır.
24. Rain/fog/snow/dust her biyomla uygun kurallarda seçilir.
25. Yeni yarış başka seed ile farklı rota üretebilir; mevcut yarışta herkes aynı seed'i görür.
26. 1/2/3 tur doğru sayılır; tur içinde harita/route seed'i değişmez.
27. Oyuncu bağlantısı kopunca diğer oyuncuların oyunu çökmemeli.
28. Yeniden yarış düğmesi gerçekten yeni match state başlatır.
29. Windows release export temiz makinede açılır ve gerekli DLL/GDExtension dosyaları pakette bulunur.
## 22.3. Profil ve regresyon
Her kritik düzeltmeden sonra proje çalıştırılır. Son aşamada temiz Windows export alınır ve debug run'la yetinilmez. Güncel Godot sürümünün resmi dokümanıyla export şablonları ve native extension paketleme uyumluluğu kontrol edilir.
---
# 23. SES, NETWORK VE HOSTING MALİYETİNİ SAKLAMA
- Kullanıcı ilk olarak arkadaşlarıyla ücretsiz test yapacak; gelir veya ücretli backend hesabı hazır varsayma.
- Prototip mümkün olduğunca ücretsiz/local test edilebilir olmalı.
- Arkadaşların evlerinden internet üzerinden katılabilmesi için gereken host/public IP/relay/TURN/server gereksinimlerini gerçekçi değerlendir.
- “İnternetten herkes bağlanabilir” demeden gerçek farklı ağlardan test edilmesi gerektiğini README'de yaz.
- Zorunlu sunucu varsa yerel geliştirme sunucusu launcher'ı, konfigürasyon dosyası, deploy talimatı ve yaklaşık aylık maliyet aralığı (güncel kaynakla doğrulanabiliyorsa) ver. Maliyet bilgisi araştırılmadıysa rakam uydurma.
- API key, token, voice credentials, TURN password veya secret'ları koda gömme. `.env.example` gibi örnek dosya ver; gerçek secret'lar Git'e girmesin.
- İstemci içine yönetici secret veya sunucu private key koyma.
- Oyuncu mikrofon verisi kaydedilmemeli; hesap sistemi yoksa kişisel veri gereksiz yere toplanmamalı.
- Oyuncu sessize alma ve report/block benzeri temel kontroller sunulabilir; karmaşık moderasyon backend'i MVP kapsamı değil.
---
# 24. YAYINLAMA PLANI VE ITCH.IO HAZIRLIĞI
## 24.1. Ücretsiz test build'i
- Windows için arkadaşlarla paylaşılabilir development/test export oluştur.
- Build sürüm numarası, date ve kısa changelog olsun.
- Oyunun ana menüsünde test build'i olduğu belirtilebilir.
- Testçiler için kontroller, oda kurma/katılma, ses ayarı ve test geri bildirim bilgileri README'de bulunsun.
- Arkadaş testinde kolayca tekrar build üretmek için otomatik export script'i/steps oluştur.
- Test sırasında toplanan kullanıcı verilerini gereksiz kaydetme. Sadece crash/network loglarını açık şekilde kaydet ve kişisel sesi asla kaydetme.
## 24.2. itch.io ücretli sürümü
- Amaç: yaklaşık 5,99 USD fiyatlı indirilebilir tam oyun.
- Ana hedef Windows x64 build.
- itch.io için temiz klasör, çalışır exe, gerekli native dependency'ler, README/credits/license ve version info.
- Başlangıç ekranında eksik dev debug butonları görünmesin.
- Oyuncuların host/oda oluşturma ve internet bağlantı gereksinimleri açıkça yazılsın.
- Ürün sayfası için kısa açıklama, uzun açıklama, sistem gereksinimleri, kontroller, multiplayer/voice chat açıklaması, ekran görüntüsü alma listesi ve asset attribution metni hazırla. Oyunda olmayan özellikleri tanıtımda vaat etme.
- Oyunun network/voice chat servis maliyeti ve uzun vadeli sürdürülebilirlik riski değerlendirilmeden halka açık ücretli release önerme.
- Satış öncesi bir arkadaş grubunun temiz build ile testini yap; host farklı bir ağdaysa bağlantıyı da doğrula.
- Ücretli yayın öncesi tüm debug/test cheat'leri kapalı olmalı.
---
# 25. UYGULAMA AŞAMALARI VE HER AŞAMANIN KABUL KRİTERİ
İşi aynı anda tüm sistemleri yazmaya çalışarak karmaşıklaştırma. Aşağıdaki sıra ile ilerle. Her aşama kendi içinde test edilmiş olmalı.
## Aşama 0 — Repo ve teknik risk denetimi
- Repo ve ortam incelemesi.
- Godot kurulu mu, hangi sürüm, export templates var mı, Windows export alınabiliyor mu?
- Gerçek voice çözümü ve multiplayer aktarımı için adayları güncel belgelerle araştır.
- Maksimum 1-2 günlük büyük mimari çalışmadan önce küçük ağ/voice prototipi oluştur.

**Kabul:** Gerekli platform teknik olarak doğrulanmış; belirsizlikler açıkça yazılmış ve bir mimari seçilmiş.
## Aşama 1 — Çalışan tek araç ve kaba yol
- Basit test sahnesi, araç kontrolü, kamera, yüzey, çarpışma.
- Debug gösterge ve yeniden başlatma.

**Kabul:** Araç her testte kullanılabilir, devrilme/kurtarma testini başlatabilecek kadar temel fizik vardır.
## Aşama 2 — Ağ ve oda
- Oda kurma/katılma, player IDs, takım ve rol seçimi.
- Bir sürücü + navigatörün aynı takımda çalışması.
- Üç takım/altı oyuncu sınırının server-side enforcement'ı.

**Kabul:** En az iki gerçek client; hedefte altı client join/leave/role state'i testi.
## Aşama 3 — Voice chat
- Mikrofon, push-to-talk, proximity range, panning/attenuation, mute, cihaz seçimi.
- Farklı mesafeler ve kabin/pencere filtreleri.

**Kabul:** İki istemci sesli konuşabiliyor; mesafe ve pozisyon hissediliyor; statik/cızırtı ve geri besleme kabul edilebilir sınırda.
## Aşama 4 — Temel yarış ve rota graph'i
- Seed, modüler yol, üçlü kavşak, branch/loop, checkpoint, yarış state.
- Harita graph'i ve route notes aynı data modelini kullanır.

**Kabul:** Aynı seed bütün istemcilerde aynı rota üretir; farklı seed farklı ama geçerli rota üretir.
## Aşama 5 — Navigatör, harita ve kabin eşyaları
- Fiziksel kâğıt harita, M, zoom/pan, map lost/6 sec respawn.
- Torpido, kutu alma/fırlatma ve multiplayer çarpışma.

**Kabul:** Etkileşimler yalnızca animasyon değildir; harita/nesne state'i networkte tutarlıdır.
## Aşama 6 — Cam, hava ve hasar
- Ön/yan cam, silecek, açık pencere, rüzgâr, toz, çakıl, yüz maruziyeti, bayılma.
- Hafif/orta/kritik hasar ve sürüş etkileri.

**Kabul:** Cam state'leri ve hasar davranışları server-authority mantığında çalışıyor; fizik ve efektler test edildi.
## Aşama 7 — Profesyonel level design ve biyomlar
- Modüler segmentleri gerçek asset'lerle tamamla.
- Orman, çöl, kayalık dağ; zorluk, hava, turn/branch varyasyonları.
- Yol kenarı detayları, çarpışma, visibility, landmarks.

**Kabul:** Tekrarlanan segmentler bile kompozisyon ve rota nedeniyle birbirinin aynısı gibi görünmüyor; oyuncu doğru ipuçlarını bulabiliyor.
## Aşama 8 — R kurtarma, yarış sonuçları ve QA
- Recovery anchors, ortak onay, safe-position teleports, checkpoint anti-exploit.
- HUD, lobby, results, rematch.

**Kabul:** Bütün kritik multiplayer, physics, route, voice senaryoları geçiyor.
## Aşama 9 — Polish ve export
- Performans, UI, sfx, localization, asset/license manifest, crash logs, release build.

**Kabul:** Windows export temiz açılır; README ile başka biri oyunu kurup odada oynayabilir; açık bilinen eksikler listelenmiş.

Her aşamada kullanıcıya kısa bir rapor ver, fakat bunu işin yerine koyma. Uygulama yeteneğin varken “bunu sen yapmalısın” diyerek kod yazmayı bırakma. Yalnızca gerçek harici credentials, hosting hesabı, donanım mikrofon izni veya fiziksel test gibi senin ortamından yapılamayacak manuel adımları kullanıcıya devret.
---
# 26. KALİTE KONTROL: YAPMA
Aşağıdakileri yapma:- “AAA” kelimesini kalite kanıtı gibi kullanma. Görsel ve oynanış kalitesini gerçekten artır.
- Navigatör rolünü yalnızca ikinci bir oyuncu avatarı yapma.
- Haritayı basit mini-map veya ana yolun parlak çizgisi haline getirme.
- Çevreyi iki yol kenarı ağacı ve düz araziye indirgeme.
- Bir kavşağın bütün seçeneklerini aynı sonucu veren dekoratif yollara dönüştürme.
- Rota generator'ını seed kontrollü test etmeden bırakma.
- Her fizik nesnesini her istemcide otoritesiz simüle etme.
- Takım ses kanalı veya global voice ekleme; yalnızca yakınlık tabanlı konuşma.
- Steam'i zorunlu kabul etme; hedef itch.io.
- Çalışmadığı kanıtlanmadan bir ses paketiyle aylarca ilerleme.
- Ağ gereksinimini son haftaya bırakma.
- Ücretli sunucu veya relay ihtiyacını saklama.
- Asset kaynağı/lisansı belirsiz modeller kullanma.
- Test edilmemiş rota, kurtarma, cam kırma veya eşya fırlatma sistemini tamamlandı ilan etme.
- Sınırsız nesne, partikül veya ağ mesajıyla performansı çöpe atma.
- Tamir ekonomisi, sezon, rank/league veya kalıcı ilerleme ekleyerek MVP'yi şişirme.
- İleride yapılabilir bir özelliği boş UI düğmesiyle varmış gibi gösterme.
- Kullanıcının mevcut projesini audit yapmadan silme/yeniden kurma.
- Yalnızca döküman ya da prototip mock-up üretip gerçek oyunu yapmaktan vazgeçme.
---
# 27. SON TESLİM PAKETİ
Son aşamada aşağıdaki teslimleri mevcut repo içinde oluştur ve doğrula:

1. Çalışır Godot proje kaynakları.
2. Windows x64 release/test build'i veya ortamda export mümkün değilse hazır export config'i ve net, minimum manuel export adımları.
3. Multiplayer server/host başlatma talimatları ve gerçek oda bağlantısı konfigürasyonu.
4. Voice chat bağımlılıkları, lisanslar, servis/hosting gereksinimi ve ayarları.
5. `README.md`: proje çalıştırma, Godot sürümü, kontrol listesi, oda oluşturma/katılma, mikrofon ayarları, test adımları, bilinen kısıtlar.
6. `ASSET_LICENSES.md`: bütün 3D/audio/font kaynakları, lisans ve attribution gereklilikleri.
7. `CHANGELOG.md`: test sürümündeki önemli değişiklikler.
8. `TEST_PLAN.md`: manuel ve otomatik test durumları, sonuçları, kalan bug'lar.
9. `ITCH_IO_RELEASE_CHECKLIST.md`: paketleme, sürüm, açıklama, özellik vaatleri, ekran görüntüsü listesi, sistem gereksinimleri.
10. Local multiplayer test runner/launch scripts ve deterministik procedural seed testleri.
11. `.env.example` gibi yalnızca placeholder içeren örnek config; gerçek key/secret commit edilmesin.
12. Known issues bölümü: test edilemeyen her nokta açıkça yazılsın.
13. Uygulama sonunda değiştirilen dosyalar ve önemli mimari kararlar kısa, anlaşılır raporla açıklansın.
---
# 28. DEFINITION OF DONE — OYUN HANGİ DURUMDA HAZIR SAYILIR?
RADDY MVP yalnızca aşağıdaki kriterler sağlandığında tamamlanmış sayılır:

- [ ] Godot projesi temiz açılıyor, sahneler ve assetler import hatası vermiyor.
- [ ] Windows test build'i açılıyor ve ana menü çalışıyor.
- [ ] Oyuncular oda kurabiliyor/katılabiliyor; en fazla 3 takım ve 6 oyuncu kuralı uygulanıyor.
- [ ] Her takımda bir sürücü zorunlu; ikinci slot navigatör.
- [ ] Temel sürüş, fren, el freni, drift, yol yüzeyi ve çarpışma fiziksel olarak hissediliyor.
- [ ] Aynı yarışın tüm oyuncuları aynı rotayı görüyor.
- [ ] Yeni yarışta yeni valid route üretilebiliyor.
- [ ] Branch, three-way junction, meşru kestirme, yanlış yol, yeniden birleşme ve checkpoint doğrulaması gerçekten çalışıyor.
- [ ] Yol notları ve fiziksel kâğıt harita aynı graph'tan üretiliyor.
- [ ] Navigatör M ile haritayı açıp büyütebiliyor, kaydırabiliyor, kapatabiliyor.
- [ ] Harita şartlar uygunsa uçabiliyor ve 6 saniyelik kayıp süresi çalışıyor.
- [ ] Ön cam kırılabiliyor ve navigatör istediği zaman tekmeleyip çıkarabiliyor.
- [ ] Sağ/sol cam açılıyor, kapanıyor, taş/nesne darbesiyle kırılabiliyor.
- [ ] Cam/pencere durumu rüzgâr, toz/çakıl, ses ve map-flight riskine etki ediyor.
- [ ] Silecekler çamur/yağmur etkisini görünür şekilde azaltıyor.
- [ ] Torpido açılıyor, kutu alınıyor, kutu fiziksel olarak fırlatılıyor ve diğer client'larda görülüyor.
- [ ] Kutu çarpışmaları küçük hasar/tepki yaratıyor; exploit/spam olmuyor.
- [ ] Hafif/orta/kritik araç hasarı hız/açı/bölgeyle makul ilişki gösteriyor.
- [ ] Araç kurtarma 3 saniye şartı, R UI'si ve çift onayı doğru çalışıyor.
- [ ] Kurtarma aracı güvenli konuma düzgün yerleştiriyor, checkpoint/finish atlatmıyor.
- [ ] Yakınlık sesli sohbeti gerçek mikrofonla çalışıyor; uzak oyuncu duyulmuyor; takım/global ses kanalı yok.
- [ ] Push-to-talk, mute, input device ve mic test seçenekleri çalışıyor.
- [ ] Orman/Çöl/Kayalık Dağ görünüş ve yüzey davranışı bakımından farklı.
- [ ] Hava, zorluk, 1-3 tur, bireysel Rastgele ve Sürpriz Ralli seçimleri gerçekten yarış üretimini etkiliyor.
- [ ] UI'da işlevsiz düğme ve placeholder içerik yok.
- [ ] Kritik test senaryoları belgelenmiş ve sonuçları raporlanmış.
- [ ] Lisans ve asset kaynakları belgelenmiş.
- [ ] Sunucu/voice maliyeti ve internet erişimi gereklilikleri saklanmamış.
- [ ] Kullanıcı tek bilgisayardan geliştirme/test edebiliyor; arkadaş testi için anlaşılır adımlar var.
- [ ] itch.io ücretli sürüm için kalan manuel işler ve yayın riskleri açıkça listelenmiş.
---
# 29. SON TALİMAT
Şimdi mevcut çalışma dizinini inceleyerek başla. İlk mesajında yalnızca tespit ettiğin mevcut durum, teknik riskler ve kısa faz planını paylaş; ardından gerçek uygulamaya geç. İlk teknik kapı olarak iki oyunculu bağlantı + proximity voice chat + basit araç state senkronizasyonunu doğrula. Sonra modüler yol graph'i, navigatör haritası, kabin fizikleri, hasar ve geri kalan MVP'yi sırayla geliştir.

Her aşamada çalıştır, test et, hataları gider ve bir sonraki aşamaya geç. Yeni bir sistemin çalışmadığını gördüğünde üzerine daha fazla özellik ekleme; önce temeli onar. Tasarım kararları için küçük ve mantıklı varsayımlar kullan. Gereksiz yere soru sorma. Sadece kod yazılmış görünmesine değil, oyuncunun gerçekten oynayabilmesine odaklan.

**Nihai hedef:** Üç takımın aynı prosedürel ve dallanan ralli güzergâhında yarıştığı; en fazla altı oyuncunun birbirine yalnızca yakındayken sesle ulaşabildiği; profesyonelce yoğun tasarlanmış arazinin navigatörü anlamlı kıldığı; dev kâğıt haritanın uçabildiği; pencerelerin açılıp kırıldığı; camın tekmeyle sökülebildiği; enerji içeceği kutularının fırlatılıp küçük hasarlar oluşturduğu; toz, çamur, çakıl, araç hasarı ve güvenli kurtarma sistemlerinin birlikte çalıştığı; komik ama inandırıcı bir RADDY MVP'si.

Hiçbir özelliği sadece listede bulunması için ekleme. Her özellik gerçek oynanışa bağlanmalı, ağda tutarlı olmalı, test edilebilmeli ve bu MVP'nin kapsamı içinde kalmalı.
