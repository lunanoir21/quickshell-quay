# Değişiklik günlüğü

Quay'deki kayda değer değişiklikler, en yenisi en üstte olacak şekilde burada
listelenir. Biçim [Keep a Changelog](https://keepachangelog.com/tr-TR/1.1.0/)
düzenini, sürüm numaraları [Anlamsal Sürümleme](https://semver.org/lang/tr/)
kurallarını izler.

Sürüm notları yalnızca bu dosyaya ve [CHANGELOG.md](CHANGELOG.md) dosyasına
yazılır. `python3 scripts/changelog.py` son sürümü README'lere, tüm sürümleri
web sitesine kopyalar.

## [1.2.0] - 2026-09-15

### Eklenenler

- **Üç ray görünümü.** Appearance → Style, rayın ekran kenarıyla nasıl
  buluşacağını seçer. Varsayılan **Floating**, rayı ayarlanabilir bir
  boşlukla kenardan uzak tutar. **Flush**, tüm kenar boyunca uzanan ve iki
  ucunda ekranın içine doğru kıvrılan bir şerit çizer; masaüstü köşeleri
  yuvarlatılmış bir pencere gibi görünür. Yer ayıran bar'ların altına zaten
  oturur, ayırmayanlar için `frameInset` pay bırakır. **Bridge**, rayı içbükey
  birleşimlerle kenara kaynaştırır ve açılırken ince bir tutamaktan büyür —
  ray gizliyken tutamak kenarda kalır (0 yaparsan hiç kalmaz) ve tam ekranda
  rayla birlikte çekilir.
- **Stil ayarları:** `appearance` altında `edgeGap`, `fillet`, `handle` ve
  `frameInset`. Panel her birini yalnızca onu kullanan stilde gösterir,
  aralık dışı değerler sınırlanır.

### Değişenler

- **Floating ray varsayılan olarak kenardan 8px uzakta**; önceden sabit 4px
  idi, artık Edge gap olarak ayarlanabiliyor.
- **Dişli, panel kenardan içeri alındığında da kutucuk sütununda ortalı
  kalıyor.**

## [1.1.2] - 2026-09-15

### Eklenenler

- **Omarchy eklentisi olarak mevcut.** [quay-omarchy](https://github.com/lunanoir21/quay-omarchy),
  Quay'i Omarchy'nin eklenti pazarı için `background`, `lock` ve
  `notifications` gibi built-in'lerle aynı şekilde bir `service` olarak
  paketliyor: `omarchy plugin add https://github.com/lunanoir21/quay-omarchy.git --enable`.

### Değişenler

- **Toggle artık Hover modunda da çalışıyor.** IPC toggle/show/hide
  (örneğin bir kısayol) daha önce Shortcut modu dışında hiçbir şey
  yapmıyordu. Artık Always dışında her modda çalışıyor — Always'de rail'i
  geri getirecek hiçbir tetikleyici kalmıyor. Hover modunda bu, sıcak kenara
  ek bir manuel geçiş gibi davranıyor; rail'in üzerine gelip çekilmek yine
  normal hover zamanlayıcılarıyla kapatıyor.

### Düzeltilenler

- **Manuel kapatmanın Hover moduyla çakışması.** İmleç hâlâ sıcak kenarın
  ya da rail'in üzerindeyken kısayolla rail'i kapatmak, aynı imleç
  konumu yüzünden bir reveal delay içinde tekrar açılmasına sebep
  oluyordu — sanki ilk rail kapanacağına ikinci bir tane beliriyormuş gibi
  görünüyordu. Manuel kapatma/toggle artık imleç gerçekten ayrılana kadar
  hover açılışlarını durduruyor.
- **Kaçırılan hover açılışları.** Sıcak kenar 6px'ti — imleç hızlı
  vardığında, ekran sınırında tam durduğu an o kadar ince bir şeridin
  içine bir hareket olayı hiç denk gelmeyebiliyordu, bu yüzden rail ara
  sıra hiç açılmıyordu. 12px'e genişletildi.
- **Segmented butonların tıklamayı algılamaması.** Tema, trigger modu gibi
  pill tarzı seçenekler `TapHandler` kullanıyordu; bu, bırakma noktası
  sınırların dışına düşerse tap'i iptal ediyor — 22px yüksekliğindeki bir
  hedefte bazı pointer/ölçekleme kurulumlarında kolayca oluyor. Kaydırıcıların
  zaten kullandığı yöntemle, paddingli bir `MouseArea`'ya geçildi.
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

[1.2.0]: https://github.com/lunanoir21/quickshell-quay/compare/v1.1.2...v1.2.0
[1.1.2]: https://github.com/lunanoir21/quickshell-quay/compare/v1.1.1...v1.1.2
[1.1.1]: https://github.com/lunanoir21/quickshell-quay/compare/v1.1.0...v1.1.1
[1.1.0]: https://github.com/lunanoir21/quickshell-quay/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/lunanoir21/quickshell-quay/releases/tag/v1.0.0
