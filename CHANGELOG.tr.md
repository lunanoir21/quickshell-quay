# Değişiklik günlüğü

Quay'deki kayda değer değişiklikler, en yenisi en üstte olacak şekilde burada
listelenir. Biçim [Keep a Changelog](https://keepachangelog.com/tr-TR/1.1.0/)
düzenini, sürüm numaraları [Anlamsal Sürümleme](https://semver.org/lang/tr/)
kurallarını izler.

Sürüm notları yalnızca bu dosyaya ve [CHANGELOG.md](CHANGELOG.md) dosyasına
yazılır. `python3 scripts/changelog.py` son sürümü README'lere, tüm sürümleri
web sitesine kopyalar.

## [Yayınlanmadı]

### Düzeltilenler

- **Segmented ayarlar** (tema, trigger modu/kenarı, tam ekran davranışı,
  pencere önizlemeleri, ekstralar) artık ayar dosyası round-trip'ini
  beklemeden hemen uygulanıyor. Bu round-trip herhangi bir sebeple
  başarısız olduğunda (`jq` eksik, yazma izni yok, dosya sistemi izleme
  desteklenmiyor) butonlar tamamen ölü görünüyordu; kaydırıcılar ise önce
  bellekte güncellediği için çalışmaya devam ediyordu. Bu düzeltme aynı
  zamanda Shortcut trigger modunun kendi bind-satırı panelini de açığa
  çıkarıyor — Mode seçici değiştirilemediği için o panel hiç
  ulaşılamıyordu.

## [1.1.1] - 2026-09-13

### Düzeltilenler

- **Tek başına kurulum.** Kendi yapılandırması olarak çalıştırıldığında
  (`quickshell -p Main.qml`) Quay script yollarını ayraç olmadan kuruyordu; bu
  yüzden ayarlar hiç okunmuyor, kaydedilmiyor ve hiç uygulama bulunmuyordu.
  Boşluk içeren kurulum yolları da artık çalışır.
- **Terminal uygulamaları** (btop ya da Vim gibi `Terminal=true` olanlar) bir
  terminalde açılır: önce `$TERMINAL`, sonra `xdg-terminal-exec`, sonra yüklü
  ilk yaygın terminal. Önceden hiçbir şey görünmüyordu.

### Değişenler

- README'ler Quay'in compositor'dan neye ihtiyaç duyduğunu, pencere
  önizlemelerinin Quickshell 0.3 ile yalnızca Hyprland'de çalıştığını ve arayüz
  simgelerinin bir Nerd Font'tan geldiğini belirtir.

## [1.1.0] - 2026-09-13

### Eklenenler

- **Kutucuk menüsü.** Bir kutucuğa sağ tıklayınca uygulamanın kendi kısayolları
  (gizli pencere, profil yöneticisi gibi), yeni pencere, sabitleme, klasöre
  taşıma ve pencerelerini kapatma çıkar. Klasörlerde Aç ve Grubu çöz bulunur.
  Klavyeyle de kullanılır.
- **Rayın yanında pencere önizlemesi.** Önizlemeler rayın yanında daha büyük
  canlı küçük resimlerle, eskisi gibi rayın içinde ya da hiç açılmayabilir;
  açılmadan önceki bekleme süresi ayarlanır.
- **Önizlemeden pencere kapatma.** Küçük resmin üzerine gelince kapatma düğmesi
  çıkar.
- **Dosya bırakma.** Bir dosyayı uygulamanın üstüne bırakınca o uygulamayla
  açılır. Hover modunda dosyayı kenara getirmek rayı çıkarır.
- **Orta tık** uygulamanın yeni bir penceresini açar.
- **Açılış geri bildirimi.** Kutucuk, başlattığı uygulamanın penceresi gelene
  kadar nabız atar; bu arada yapılan ikinci tıklama onu iki kez açmaz.
- **Tam ekranda kenara çekilir.** Odaktaki pencere tam ekranken ray ve sıcak
  kenarı devre dışı kalır (`trigger.hideOnFullscreen`).
- **Sistem teması.** `"theme": "auto"`, sistemin açık/koyu tercihini
  xdg-desktop-portal üzerinden anında izler.
- **Ayarlarda Pencereler bölümü**, önizlemenin nereye açılacağını gösteren küçük
  bir şemayla.
- **Bu değişiklik günlüğü**; son sürüm README'lerde, tüm sürümler web sitesinde.

### Değişenler

- Sağ tık artık doğrudan sabitlemek yerine kutucuk menüsünü açar; sabitleme
  menünün içindedir.
- Önizleme, uygulamanın hâlâ penceresi varken açık kalır; birini kapatınca
  diğerleri görünmeye devam eder.
- Ayar paneli hareketlendi: açılıp kapanırken ölçeklenir, tek bir vurgu
  bölümler arasında kayar, içerik gidilen yönden kayarak gelir, seçim
  düğmelerinde tek bir işaret kayar.
- Ayar bölümleri listesi sabit genişlikte kalır; bölüm değiştirmek düzeni artık
  kaydırmaz.
- Yeni klasörler Türkçe yerine İngilizce adlandırılır ("New folder").

## [1.0.0] - 2026-09-13

### Eklenenler

- **Dikey ray**; ekranın herhangi bir kenarına yerleşir, her tekerlek adımında
  bir satır ilerler, sayfa işaretleri vardır.
- **Üç görünme biçimi:** her zaman ekranda, hover'da kenardan kayarak ya da IPC
  üzerinden bir tuşla.
- **Sürükle-bırak ile sabitleme ve klasörler**, ayarlarda da sürükle-bırak
  sabitleme panosu.
- **Bir bakışta çalışma durumu:** kısa işaret çalışıyor, uzun işaret odakta
  demek; birden fazla penceresi olan uygulamalarda sayı.
- **Sabitlenenlerin yanında** ray hiçbir şey, diğer açık pencereleri ya da son
  kullanılan uygulamaları gösterir.
- **Canlı pencere önizlemesi**, birden fazla penceresi olan uygulamalar için.
- **Kendi ayar paneli**, raydaki dişliyle bir tık uzakta; kurulumuna göre tam
  kısayol satırını çıkaran bir yardımcıyla.
- **Siyah ve beyaz temalar.**
- **Asla yer ayırmaz:** Quay pencerelerin üzerinde durur, hiçbir şey küçülmez.
- **Kare süresine göre hareket:** sürüklerken otomatik kaydırma 60 Hz'de de
  165 Hz'de de aynı hızdadır.
- **IPC:** `toggle`, `show`, `hide`, `settings` ve `refreshApps`.

[1.1.1]: https://github.com/lunanoir21/quickshell-quay/compare/v1.1.0...v1.1.1
[1.1.0]: https://github.com/lunanoir21/quickshell-quay/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/lunanoir21/quickshell-quay/releases/tag/v1.0.0
