# RADDY — SUPPLEMENTARY MASTER PROMPT
## Half Grip Inspired Art Direction, Professional Godot Engineering, Repository Research, Automated Testing & Iterative Development

> Kullanıcının 2026-10-12 tarihinde verdiği ek talimat (kelimesi kelimesine). Ana şartname: `RADDY_MEGA_MASTER_PROMPT_FINAL.md`.

## 1. BU EK TALİMATIN AMACI
Bu belge, mevcut RADDY Mega Master Prompt dosyasına ek olarak uygulanacaktır. Önce ana şartnameyi eksiksiz oku. Mevcut oyun tasarımını, MVP kapsamını, oyuncu sınırlarını, ağ mimarisini ve oyun mekaniklerini koru.
Bu ek talimatın amacı:

1. RADDY'nin görsel ve oynanış kalitesini Half Grip'in atmosferinden ilham alarak geliştirmek.
2. Godot 4 konusunda profesyonel mühendislik standartlarını uygulamak.
3. İlgili GitHub projelerini ve resmi Godot dokümantasyonunu araştırmak.
4. Oyun sistemlerini gerçekten uygulamak, çalıştırmak, test etmek ve hatalarını gidermek.
5. Mevcut projeyi gereksiz yere baştan yazmadan iteratif biçimde geliştirmek.
6. Sonuçta yalnızca etkileyici görünen bir prototip değil, arkadaşlarla oynanabilir ve daha sonra ücretli yayıma hazırlanabilir bir MVP üretmek.

Bu belge yeni bir proje başlatma veya mevcut ana şartnameyi geçersiz kılma talimatı değildir. Mevcut repo varsa onu incele ve geliştir. Repo yoksa önce kontrollü bir proje iskeleti oluştur.

## 2. HALF GRIP REFERANSI: NEYİ AL, NEYİ KOPYALAMA?
Referans oyun: https://store.steampowered.com/app/4163270/Half_Grip/
Half Grip'i görsel atmosfer, sunum, araç hissi ve arcade ile gerçekçilik arasındaki denge bakımından incele.

### Alınacak tasarım ilkeleri
* Güçlü ve tutarlı görsel kimlik.
* Stilize, okunabilir ve karakterli araç tasarımı.
* Yoğun atmosferli çevreler ve kontrollü ışıklandırma.
* Yol yüzeylerinin sürüş davranışına gerçek etkisi.
* Görsel ve işitsel geri bildirimin sürüşü desteklemesi.
* Kısa sürede anlaşılabilen fakat ustalaşması zaman alan mekanikler.
* Her yarışın aynı hissettirmemesini sağlayan kontrollü çeşitlilik.
* Bağımsız bir oyunun bütçesine uygun, iyi optimize edilmiş sunum.
* Kazaların, araç davranışlarının ve beklenmedik olayların akılda kalıcı olması.

### Kopyalanmayacak unsurlar
* Half Grip'in özgün oyun tasarımı, arayüzü, sanat eserleri, araçları, sesleri veya kodları kopyalanmayacak.
* Silahlı roguelike yarış yapısı RADDY'ye taşınmayacak.
* RADDY'nin navigatör, fiziksel harita, ortak kurtarma, yakınlık sesli sohbet ve fiziksel komedi üzerine kurulu kimliği korunacak.
* Referans oyunun görselleri doğrudan oyun varlığı olarak kullanılmayacak.
* Görsel ilham, bağımsız bir sanat yönetimiyle yeniden yorumlanacak.

## 3. RADDY GÖRSEL SANAT YÖNETİMİ
Varsayılan hedef: stylized realism / stilize gerçekçilik.
Tam fotogerçekçi AAA grafikler hedeflenmeyecek. Tamamen basit, ayrıntısız low-poly görsellik de kullanılmayacak. Görsel kalite; sanat yönetimi, tutarlı materyaller, aydınlatma, kompozisyon, atmosfer, animasyon ve etkili geri bildirim üzerinden sağlanacak.

### Araçlar
* Gerçekçi oranlar ve güçlü siluetler.
* Kaporta, cam, lastik, metal ve plastik için birbirinden ayrılan materyaller.
* Hasarın görsel olarak anlaşılabilmesi.
* Kir, çamur, su ve tozun yüzeylerde okunabilir olması.
* Aracın yalnızca bir model değil, oynanışın merkezi olması.
* Kamera sarsıntısının kontrollü ve konforlu kullanılması.

### Çevre
* Sık ağaç kümeleri, çalılar, kayalar, hendekler, çitler, köprüler, toprak setleri ve yol işaretleri.
* Her biyom için ayrı siluetler, renk paleti, bitki örtüsü ve zemin materyalleri.
* Uzak görüşü sınırlayan doğal arazi geometrisi.
* Yolun önceden tamamen okunmasını engelleyen tepeler, virajlar ve görüş blokları.
* Gerektiğinde yoğun sis, yağmur, kar, toz ve çamur.
* Görsel gürültüden kaçınma; oyuncular ve yol seçenekleri çevre içinde okunabilir kalmalı.

### Teknik sanat yönetimi
* Gerçek modeller ve lisanslı materyaller kullan.
* Ücretsiz varlıkların kalitesini, ölçeğini, materyallerini ve stil uyumunu denetle.
* Farklı kaynaklardan gelen varlıkları tek bir görsel bütünlük içinde birleştir.
* Her varlığı oyuna eklemeden önce lisansını ve yeniden dağıtım koşullarını kontrol et.
* Ücretsiz olması, bir varlığın her koşulda ticari kullanım için serbest olduğu anlamına gelmez.
* Gereksiz yüksek poligonlu varlıklar, aşırı büyük dokular ve pahalı efektlerden kaçın.
* Hedef donanımda gerçek performans ölçümleri yap.

## 4. GODOT MÜHENDİSLİĞİ VE ARAŞTIRMA SÜRECİ
Godot 4'ü ana oyun motoru olarak kullan. Mevcut projenin kullandığı Godot sürümünü önce belirle. Sürüm yükseltmesini gerekçesiz yapma.
İlk aşamada aşağıdaki kaynakları incele:

* Resmi Godot dokümantasyonu: https://docs.godotengine.org/en/4.6/
* Godot araç fiziği örneği: https://github.com/Seerban/godot-vehicle
* Arcade araç fiziği çerçevesi: https://github.com/HaileNegash/godot4-vehicle-framework
* Godot çok oyunculu ve konumsal ses örneği: https://github.com/thegatesbrowser/godot-multiplayer
* Godot çok oyunculu ağlama örneği: https://github.com/bearlikelion/cooties

Bu depolar araştırma referansıdır; hepsini projeye ekleme zorunluluğu yoktur.
Her repo için şunları belirle:

1. Lisans ve ticari kullanım koşulları.
2. Son güncelleme ve bakım durumu.
3. Kullanılan Godot sürümü.
4. Harici eklentiler ve bağımlılıklar.
5. Kod kalitesi ve mimari yaklaşımı.
6. RADDY'nin gerçek gereksinimleriyle uyumu.
7. Mevcut projeye entegre edilirse ortaya çıkabilecek çakışmalar.
8. Sıfırdan küçük bir uyarlama yapmanın daha doğru olup olmadığı.

Kodları körlemesine kopyalama. Önce mevcut oyun mimarisini ve API uyumluluğunu değerlendir. Lisansı bilinmeyen veya uygun olmayan kodları kullanma.

## 5. ARAÇ FİZİĞİ: ÖNCE ÇALIŞAN BİR SÜRÜŞ PROTOTİPİ
Görsel içeriklerin büyük bölümünü üretmeden önce oynanabilir araç prototipi hazırla.
Prototip şu özellikleri içermeli:

* İleri ve geri hareket.
* Direksiyon tepkisi.
* Gaz ve fren.
* El freni ve kontrollü kayma.
* Farklı hızlarda farklı direksiyon davranışı.
* Çakıl, toprak, çamur ve ıslak yüzeyler arasında tutuş farkı.
* Tümseklerde aracın tepki vermesi.
* Devrilme ve tekrar düzeltme.
* Takip kamerası.
* Çarpışma ve araç hasarı için temel olaylar.

Fizik sistemini yalnızca aracın hareket ediyor olmasıyla başarılı kabul etme. Hızlanma, frenleme, viraj, kayma, çarpışma ve kurtarma durumlarını ayrı ayrı test et.
Araç fiziği sistemini değiştirmek gerekiyorsa bunu küçük, ölçülebilir adımlarla yap. Çalışan bir sistemin tamamını kanıtlanmamış yeni bir eklentiyle değiştirme.

## 6. ÇOK OYUNCULU MİMARİ
Ana şartnamedeki kapasite değiştirilmeyecek:

* En fazla 6 oyuncu.
* En fazla 3 takım.
* Takım başına en fazla 2 oyuncu.
* Bir sürücü ve isteğe bağlı navigatör.
* Yakınlık tabanlı, mekânsal sesli sohbet.
* Ayrı bir takım ses kanalı oluşturulmayacak.
* Yarış durumu ve kritik fizik etkileşimleri bütün oyuncularda tutarlı olacak.

Ağ mimarisini baştan doğrula.
Özellikle şunları test et:

* Oda oluşturma ve katılma.
* Oyuncu kimlikleri ve takım atamaları.
* Sürücü ve navigatör rolleri.
* Araç hareketlerinin senkronizasyonu.
* Fırlatılan nesnelerin ve çarpışmaların tutarlılığı.
* Cam kırılma ve pencere durumları.
* Fiziksel haritanın düşmesi ve yeniden alınması.
* Ortak kurtarma onayları.
* Oyuncu ayrılması ve yeniden bağlanması.
* Gecikme, paket kaybı ve bağlantı kopması.

Sunucu tarafından doğrulanması gereken kritik olayları istemciye bırakma. Aynı fiziksel olayın farklı oyuncularda farklı sonuç vermesini engelle.

## 7. YAKINLIK SESLİ SOHBET
Sesli sohbeti ayrı bir prototip olarak doğrula.
Gereksinimler:

* Oyuncular yalnızca yeterince yakındaki oyuncuları duyabilmeli.
* Ses uzaklığa göre azalmalı.
* Sesin yönü ve mesafesi anlaşılabilir olmalı.
* Açık ve kırık pencereler sesin niteliğini değiştirebilmeli.
* Motor, rüzgâr ve çevre sesleri konuşmayı doğal biçimde maskeleyebilmeli.
* Mikrofon izni, sessize alma ve ses seviyesi kontrolleri bulunmalı.
* Bağlantı kopması veya mikrofon izninin reddedilmesi oyunun çökmesine neden olmamalı.
* Varsayılan ses ayarları rahatsız edici derecede yüksek olmamalı.

Godot'un ağ desteğiyle bir sesli sohbet çözümünün otomatik olarak uyumlu olduğunu varsayma. Gerçek bağlantı, ses iletimi, konumsal ses ve gecikme testleri yap.

## 8. PROFESYONEL LEVEL DESIGN
RADDY'nin rotaları sıradan, iki yanında boş alan bulunan düz yarış pistlerinden oluşmamalı.
Yol parçaları kontrollü biçimde birleştirilmeli. Örnek parçalar:

* Dar orman yolu.
* Keskin viraj.
* Kör tepe.
* Üçlü kavşak.
* Riskli kestirme.
* Köprü.
* Dere geçişi.
* Kayalık geçit.
* Çamurlu bölüm.
* Geniş ve güvenli alternatif rota.
* Yanlış yön veya daha uzun döngü.
* Daha ileride yeniden birleşen yollar.

Her yol parçasının giriş ve çıkış geometrisi uyumlu olmalı. Yol ağı, navigatörün haritası ve gerçek sürüş alanı aynı rota verisinden oluşturulmalı.
Her rota için kontrol et:

* Oyuncu araçla gerçekten geçebilir mi?
* Yolun genişliği ve eğimi araca uygun mu?
* Çevre çarpışmaları doğru mu?
* Alternatif yol gerçekten farklı risk ve süre sunuyor mu?
* Navigatörün verdiği yön bilgisi doğru mu?
* Kestirme kontrol noktalarını atlamaya izin veriyor mu?
* Rastgele birleşimlerde kopuk yollar veya erişilemeyen alanlar oluşuyor mu?

Navigatörün rolünü güçlendirmek için sürücünün önündeki bütün yol ağını aynı anda görmesini engelle. Ancak bunu haksız, görünmez engeller veya aniden ortaya çıkan kaçınılmaz tehlikelerle yapma.

## 9. HASAR, CAMLAR VE FİZİKSEL NESNELER
Mevcut ana şartnamedeki hasar sistemi korunacak.

* Hafif, orta ve kritik araç hasarı.
* Çarpışma hızı ve yönüne göre hasar.
* Ön camın çatlaması ve çıkarılması.
* Sağ ve sol yan camların açılması, kapanması ve kırılması.
* Cam durumuna göre rüzgâr, toz, çamur ve ses etkileri.
* Navigatörün ön camı isteyerek tekmeleyip çıkarabilmesi.
* Torpidodan enerji içeceği kutusu alınması.
* Kutunun fiziksel olarak fırlatılması ve diğer araçlara çarpabilmesi.
* Çarpışma etkilerinin ağda tutarlı olması.
* Fiziksel kâğıt haritanın sallanması, düşmesi, uçması ve yeniden alınması.
* Harita kaybolduğunda yedek haritanın 6 saniye sonra kullanılabilir olması.
* Araç üç saniye boyunca gerçekten kurtarılamaz durumdaysa R kurtarma seçeneği.
* İki oyunculu takımda kurtarma için iki oyuncunun da onayı.
* Kurtarma sonrası güvenli konum, korunmuş yarış ilerlemesi ve adil zaman kaybı.

Bu sistemleri sınırsız sayıda fizik nesnesi veya aşırı karmaşık deformasyonlarla uygulama. Küçük, tutarlı ve performanslı sistemler kur.

## 10. KOD MİMARİSİ VE KALİTE
* Mevcut mimariyi incelemeden yeniden yazma.
* KISS prensibini uygula.
* Gereksiz soyutlama ve aşırı parçalanmış sahneler oluşturma.
* Aynı işlevi yapan birden fazla sistem bırakma.
* Ağ, araç fiziği, yarış rotası, UI ve fiziksel etkileşimler için açık sorumluluk sınırları belirle.
* Kritik sistemleri test edilebilir tut.
* Sabit değerleri mümkün olduğunca merkezi yapılandırma kaynaklarından yönet.
* Oyuncu girdilerini, ağ durumunu ve fizik simülasyonunu birbirinden ayır.
* Kullanılmayan kodları ve geçici test içeriklerini temizle.
* Hataları sessizce yutma; anlamlı günlükler ve hata mesajları oluştur.
* Büyük değişikliklerden önce ilgili testleri çalıştır ve geri dönüş yolu oluştur.
* Çalışan sistemleri gereksiz yere değiştirme.

## 11. TEST VE HATA GİDERME DÖNGÜSÜ
Yalnızca kod üretmek yeterli değildir. Her özellik şu döngüden geçmelidir:

1. Gereksinimi belirle.
2. Küçük bir uygulama yap.
3. Godot editöründe veya komut satırında projeyi doğrula.
4. İlgili sahneyi gerçekten çalıştır.
5. Hata günlüklerini incele.
6. Etkileşimi normal ve sınır koşullarında test et.
7. Çok oyunculu sistemse birden fazla istemciyle doğrula.
8. Hatayı düzelt.
9. Aynı testi tekrar çalıştır.
10. Sonucu kaydet ve sonraki özelliğe geç.

Mümkün olduğunda otomatik testler, headless Godot testleri ve ayrı istemciler kullan. Ancak headless testin görsel kaliteyi, sesli sohbeti veya gerçek oyuncu deneyimini doğrulamadığını unutma.

### Zorunlu test senaryoları
* Araç düz yolda hızlanır ve frenler.
* Araç çakıl ve çamurda farklı tepki verir.
* Araç devrilir ve kurtarılır.
* Ön cam çatlar ve çıkarılır.
* Yan cam açılır ve kırılır.
* Navigatör enerji içeceği kutusunu alıp fırlatır.
* Kutu başka bir araca çarpar.
* Harita açık pencereden uçar.
* Yeni harita altı saniye sonra gelir.
* Üç yol ayrımı ve alternatif rotalar çalışır.
* Kontrol noktaları atlanamaz.
* Üç takım ve altı oyuncu aynı yarışa katılabilir.
* Yakındaki oyuncular duyulur, uzaktakiler uygun biçimde duyulmaz.
* Bir oyuncu bağlantıyı kaybettiğinde yarış durumu bozulmaz.
* Kurtarma her istemcide aynı sonucu üretir.
* Yarış sonuçları geçerli rota ilerlemesine dayanır.

## 12. PERFORMANS VE GÖRSEL QA
Hedef donanım ve gerçek test ortamında ölçüm yap. FPS, bellek kullanımı, ağ trafiği, fizik güncelleme maliyeti ve ses gecikmesini gözlemle.
Özellikle altı oyuncu, araçlar, çevre nesneleri, cam kırılmaları ve fırlatılabilir nesneler birlikte çalışırken test et.

* Gereksiz fizik simülasyonlarını azalt.
* Görünmeyen nesnelerin maliyetini kontrol et.
* Uygun seviyede detay ve görünürlük mesafesi kullan.
* Uzak çevre için maliyeti düşük temsil yöntemleri değerlendir.
* Pahalı parçacık ve şeffaflık efektlerini ölçerek kullan.
* Ses ve ağ senkronizasyonunu görsel performanstan bağımsız da test et.

Bir ekran görüntüsünün güzel olması oyunun tamamlandığı anlamına gelmez. Araç kullanımı, kamera, çarpışmalar, yol geometrisi ve UI gerçek oynanışta kontrol edilmelidir.

## 13. AŞAMALI GELİŞTİRME
Aşama 1 — Proje denetimi: repo, Godot sürümü, mevcut sahneler ve bağımlılıklar; mevcut kodun ve testlerin durumu; eksikler ve teknik riskler; en küçük uygulanabilir geliştirme planı.

Aşama 2 — Teknik prototipler: tek araç sürüş fiziği; iki oyunculu ağ bağlantısı; yakınlık sesli sohbet; bir yol parçası ve bir kavşak; basit fiziksel nesne ve çarpışma.

Aşama 3 — Oynanabilir çekirdek: sürücü ve navigatör rolleri; harita sistemi; alternatif yollar; cam ve araç hasarı; kurtarma sistemi.

Aşama 4 — Altı oyunculu MVP: üç takım; yarış odası ve rol ataması; ortak yarış durumu; kontrol noktaları ve sonuçlar; ağ hata senaryoları.

Aşama 5 — Sanat ve içerik: biyomlar; gerçek ve lisansı uygun 3D varlıklar; materyaller, ışıklandırma, hava durumu; sesler, animasyonlar ve kullanıcı arayüzü.

Aşama 6 — QA ve yayın hazırlığı: tekrarlanabilir testler; performans ve kararlılık; hata giderme; temiz, indirilebilir test derlemesi; arkadaşlarla ücretsiz test; geri bildirimlerin önceliklendirilmesi.

Bir aşama başarısızsa sonraki aşamanın üzerine yeni özellikler ekleyerek problemi gizleme. Önce temel sorunu çöz.

## 14. YAYINLAMA HEDEFİ
İlk hedef ücretsiz arkadaş testi. Daha sonraki hedef, yeterince tamamlanmış sürümü itch.io'da yaklaşık 5,99 USD fiyatla yayımlamak.
Ücretli sürümden önce:

* Temiz bir Windows derlemesi oluştur.
* Başka bir klasörde veya temiz test ortamında açılışını doğrula.
* Oyuncuların aynı odaya bağlanmasını test et.
* Mikrofon izinlerini ve yakınlık sohbetini test et.
* Altı oyunculu yarışın tamamlanabildiğini doğrula.
* Eksik dosya, bozuk kaynak yolu veya geliştirici makinesine bağımlılık olmadığını kontrol et.
* Lisans ve üçüncü taraf varlık bildirimlerini hazırla.
* Kurulum ve oynama talimatlarını yaz.
* Bilinen sorunları açıkça belgeleyip kritik hataları çöz.

5,99 USD bir fiyat hedefidir; ürünün bu fiyatı hak ettiğine karar vermeden önce gerçek test sonuçlarını değerlendir.

## 15. SON TALİMAT
Kullanıcıya yalnızca öneriler, planlar veya örnek kodlar sunmakla yetinme. Yetkili olduğun geliştirme ortamında gerçek dosyaları oluştur, değiştir, projeyi çalıştır, testleri yürüt ve hataları düzelt.
Ancak bir testi gerçekten çalıştırmadıysan çalıştırılmış gibi raporlama. Bir özelliği doğrulamadıysan tamamlandı olarak işaretleme. Teknik engel varsa engeli, nedenini, etkisini ve en küçük uygulanabilir çözümü açıkla.
Her geliştirme aşamasının sonunda şu bilgileri raporla: tamamlanan özellikler; değiştirilen dosyalar; çalıştırılan testler ve sonuçları; bilinen hatalar; performans bulguları; sonraki en önemli adım.

Öncelik sırası:
1. Çalışan oyun.
2. Doğru sürüş ve fizik.
3. Kararlı çok oyunculu bağlantı ve yakınlık sesli sohbet.
4. Eğlenceli, adil ve okunabilir level design.
5. Birbiriyle tutarlı fiziksel etkileşimler.
6. Görsel kalite ve atmosfer.
7. Performans, kararlılık ve yayın hazırlığı.

RADDY'nin hedefi, büyük bütçeli AAA bir oyunu taklit etmek değil; küçük bir bağımsız oyunun sınırları içinde profesyonelce tasarlanmış, cilalı, komik ve arkadaşlarla tekrar tekrar oynanmak istenen bir co-op ralli deneyimi oluşturmaktır.
