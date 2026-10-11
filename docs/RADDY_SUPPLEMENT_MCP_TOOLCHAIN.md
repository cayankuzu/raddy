# RADDY — GODOT MCP & AI DEVELOPMENT TOOLCHAIN SUPPLEMENT

> Kullanıcının 2026-10-12 tarihinde verdiği ek talimat (kelimesi kelimesine). Ana şartname: `RADDY_MEGA_MASTER_PROMPT_FINAL.md`.

## 1. Ana hedef
RADDY geliştirilirken Claude Code yalnızca kod yazan bir asistan olarak kalmasın. Godot editörüyle bağlantı kurabilsin; sahneleri ve node'ları inceleyebilsin, değişiklik yapabilsin, oyunu çalıştırabilsin, ekran görüntülerini ve logları analiz edebilsin, hataları düzeltebilsin ve sonuçları tekrar test edebilsin.
Mevcut RADDY projesini ve ana master promptu koru. Bu ek talimatı uygularken projeyi sıfırdan oluşturma veya çalışan sistemleri gereksiz yere yeniden yazma.

## 2. İncelenecek GitHub repoları
1. Beckett Godot MCP — https://github.com/beckettlab/beckett-godot-mcp
   Öncelikli aday. Godot editörüne gömülü MCP yaklaşımı; sahne ve script düzenleme, oyunu çalıştırma, çalışma zamanı sahnesini inceleme, ekran görüntüsü alma ve log inceleme özelliklerini değerlendir. Önce ücretsiz, MIT lisanslı Lite sürümünü değerlendir. Ücretli Full özelliklerini ücretsizmiş gibi varsayma.
2. slangwald/godot-mcp — https://github.com/slangwald/godot-mcp
   Editör ve çalışan oyun üzerinde işlem yapma, sahne ağacını inceleme, ekran görüntüsü alma ve arayüzle etkileşim özelliklerini değerlendir. Godot sürümü ve Python/uv gereksinimlerini kontrol et.
3. Fulviuus/godot-mcp — https://github.com/Fulviuus/godot-mcp
   Proje inceleme, script/sahne analizi, oyunu çalıştırma, runtime kontrolü ve ekran görüntüsü alma özelliklerini değerlendir. Hedef Godot sürümüyle uyumluluğunu özellikle doğrula.

Bu liste zorunlu olarak hepsini kuracağın anlamına gelmez. Güncel README, lisans, son güncellemeler, açık hatalar, sürüm uyumluluğu, güvenlik ve bağımlılıkları incele. Gerekirse benzer güncel repoları da araştır.

## 3. Kurulum ve seçim kuralları
* Önce bilgisayardaki Godot sürümünü, proje yapısını ve Claude Code MCP yapılandırmasını incele.
* Projenin Godot sürümüyle uyumlu, güvenilir ve en az ek bağımlılık gerektiren seçeneği tercih et.
* İlk tercih olarak Beckett Lite'ı değerlendir; ancak uyumsuzsa sırf tercih edildiği için kurmaya zorlama.
* Birbirinin işlevini tekrarlayan birden fazla MCP sunucusunu aynı anda kurma. Önce tek bir çözümle gerçek bir uçtan uca test yap.
* MCP bağlantısı ve araçları gerçekten çalışmadan kurulumun başarılı olduğunu varsayma.
* Kullanıcı yapılandırmalarını, proje dosyalarını veya `.mcp.json` dosyasını kontrolsüz biçimde üzerine yazarak değiştirme. Önce yedek al; mevcut ayarları koru.
* Yerel geliştirme bağlantısını tercih et. Harici servislere, buluta veya gereksiz hesaplara bağımlılığı güvenlik ve maliyet açısından değerlendir.
* Tokenları, anahtarları ve hassas yapılandırmaları koda veya Git deposuna yazma.
* MCP'nin düzenleme ve dosya silme yetkilerini gereksiz yere genişletme. Büyük veya yıkıcı değişikliklerden önce yedek ve geri dönüş yolu oluştur.
* MCP eklentilerinin geliştirme araçları olduğunu unutma; gereksiz MCP dosyalarını ve editör eklentilerini dağıtılacak oyun paketine dahil etme.

## 4. Gerçek geliştirme-doğrulama döngüsü
MCP kurulduktan sonra aşağıdaki iş akışını küçük ve güvenli bir testle doğrula:

1. Godot projesini aç ve doğru projenin bağlı olduğunu doğrula.
2. Ana sahneyi, node ağacını, scriptleri ve proje ayarlarını incele.
3. Küçük bir test değişikliği yap, kaydet ve Godot hata kontrolünü çalıştır.
4. Oyunu gerçekten başlat; mümkünse çalışan oyunun ekran görüntüsünü, runtime sahne ağacını ve loglarını al.
5. Hataları yalnızca tahmin ederek değil, gerçek çıktıları inceleyerek teşhis et.
6. Düzeltme yap ve aynı testi yeniden çalıştır.
7. Beklenen davranışı, ekran görüntüsünü ve hata çıktısını kontrol et.
8. Sonuçları doğrulamadan tamamlandı deme.

MCP aracı tek başına bütün oyun testlerini gerçekleştiremiyorsa eksik yeteneği açıkça bildir ve uygun manuel veya otomatik test yöntemi kullan.

## 5. RADDY için öncelikli doğrulama senaryoları
* Aracın sürüşü, direksiyon, fren, el freni ve yüzey tutuşu.
* Üç yönlü kavşaklar, alternatif rotalar ve fiziksel haritayla oyun dünyasının eşleşmesi.
* İki oyunculu sürücü/navigatör iş akışı ve daha sonra altı oyuncuya ölçeklenme.
* Multiplayer senkronizasyonu, araç hareketi ve fiziksel nesnelerin eşleşmesi.
* Yakınlık tabanlı sesin mesafeye göre değişmesi.
* Cam, harita, kutu/teneke ve kurtarma mekanikleri.
* Farklı hava koşullarında okunabilirlik, performans ve hata günlükleri.

Önce temel oynanabilir prototipi doğrula; daha sonra kapsamı büyüt. Aynı anda bütün sistemleri kurup test etmeye çalışma.

## 6. Zorunlu teslim raporu
Her önemli geliştirme aşamasında kısa bir rapor sun:

* Hangi MCP/repo seçildi ve neden?
* Hangi sürüm ve lisans kullanılıyor?
* Kurulum ve Claude Code bağlantısı gerçekten doğrulandı mı?
* Hangi sahneler veya sistemler değiştirildi?
* Hangi testler çalıştırıldı ve sonuçları ne oldu?
* Hangi hatalar bulundu, nasıl düzeltildi?
* Bilinen sorunlar ve sıradaki en önemli adım nedir?

Temel kural: Sadece plan, kod parçası veya başarılı göründüğünü söyleyen bir yanıt verme. Mümkün olan her aşamada projeyi gerçekten çalıştır, sonucu incele, hataları düzelt ve yeniden test et. Doğrulanamayan şeyleri doğrulanmış gibi sunma.
