<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/logo-dark.svg">
  <img src="docs/logo-light.svg" width="96" alt="Quay logosu">
</picture>

# Quickshell için Quay

Wayland'de Quickshell için dikey, telefon ana ekranı tarzında bir uygulama
başlatıcı — sabitlenen uygulamalar, klasörler ve açık pencereler, her tekerlek
adımında bir satır kayan tek bir rayda.

[![Quickshell](https://img.shields.io/badge/Quickshell-0.3%2B-111111?style=flat-square)](https://quickshell.outfoxxed.me/)
[![Wayland](https://img.shields.io/badge/Wayland-wlr--layer--shell-111111?style=flat-square)](https://wayland.app/protocols/wlr-layer-shell-unstable-v1)
[![Lisans](https://img.shields.io/badge/Lisans-MIT-111111?style=flat-square)](LICENSE)

**[Web sitesi](https://lunanoir21.github.io/quickshell-quay/)** · [English README](README.md)

<img src="docs/screenshots/rail.png" width="640" alt="Ekranın sağ kenarına yerleşmiş ray, siyah ve beyaz temada">

</div>

---

## Nedir

Quay bir görev değiştirici değil. *Seçtiğin uygulamaları*, seçtiğin sırayla
ekranın bir kenarında tutar ve hangilerinin çalıştığını işaretler — bir telefon
ana ekranı gibi, yalnızca yan yatırılmış. Tekerleğin bir adımı bir satır kaydırır.

Kendi kendine yeten bir Quickshell modülüdür: kendi ayar dosyası, kendi ayar
paneli, kendi uygulama dizini vardır. Bir shell'e eklemek bir import ve bir
satır sürer.

## Özellikler

- **Dikey tekerlekle gezinme.** Bir adım, bir satır, yerine oturarak — ray hangi
  kenara yerleşmiş olursa olsun.
- **Sabitlenenler ve istediğin başka her şey.** Sabitlenenlerden sonra ray hiçbir
  şey, diğer tüm açık pencereleri ya da en son kullandığın uygulamaları
  gösterebilir.
- **Bir bakışta okunur.** Kısa işaret çalışıyor, uzun işaret odakta demek; sayı
  bir uygulamanın pencerelerini sayar, kenardaki noktalar sayfayı gösterir.
- **Canlı pencere önizlemesi.** Birden fazla penceresi olan bir uygulamanın
  üzerinde imleci bekletince her pencereyi canlı görür, doğrudan birini seçersin —
  rayın yanında daha büyük küçük resimlerle ya da rayın içinde. Normal tıklama
  yine pencereler arasında döner.
- **Sürükle-bırak ile klasörler.** Bir kutucuğu taşımak için sürükle; klasör
  yapmak için başka birinin üstüne bırak.
- **Üç görünme biçimi.** Her zaman ekranda, imleç kenara gelince kayarak ya da
  bir tuşla.
- **Asla yer kaplamaz.** Quay pencerelerinin üzerinde durur ve özel alan ayırmaz;
  açıldığında hiçbir pencere küçülmez.
- **İki tema.** Saf siyah ya da saf beyaz.
- **Kendi ayar paneli.** Her şey rayın üstündeki dişli simgesinden ayarlanır —
  ayrı bir ayarlar uygulaması gerekmez.
- **Kare süresine göre hareket.** Sürüklerken otomatik kaydırma gerçek kare
  süresiyle hesaplanır; 60 Hz ve 165 Hz ekranda aynı hızda ilerler.

## Yakından

<p align="center">
  <img src="docs/screenshots/preview.png" height="360" alt="Rayın içinde açık duran terminal pencere önizlemeleri">
  &nbsp;
  <img src="docs/screenshots/settings.png" height="360" alt="Quay'in ayar paneli, Görünüm bölümünde">
</p>

İki terminal penceresi olan bir uygulamanın pencere önizlemeleri ve Quay'in
kendi ayar paneli. Hyprland'de 1920×1080 çözünürlükte çekildi.

## Gereksinimler

- [Quickshell](https://quickshell.outfoxxed.me) 0.3 veya daha yenisi
- `wlr-layer-shell` destekleyen bir compositor; geliştirildiği ortam Hyprland
- `python3`, `jq`, `bash` ve `flock` (util-linux)
- İsteğe bağlı: ayar panelindeki kopyala düğmesi için `wl-copy`

## Kurulum

### Kendi Quickshell yapılandırmana

```sh
cd ~/.config/quickshell
git submodule add https://github.com/lunanoir21/quickshell-quay.git vendor/quay
```

Ardından shell kökünden yükle:

```qml
import Quickshell
import "vendor/quay" as QuayModule

ShellRoot {
    // ... kendi widget'ların
    QuayModule.QuayHost {}
}
```

Entegrasyonun tamamı bu kadar.

### Tek başına

```sh
git clone https://github.com/lunanoir21/quickshell-quay.git
quickshell -p quickshell-quay/Main.qml
```

### Kısayol modu için tuş

Quay global tuşları kendisi yakalamaz; tuş bağlamak compositor'ın işidir. IPC
çağrısı, Quickshell'in başlatıldığı yapılandırmayı göstermek zorunda — Quay'in
ayar paneli bunu kendisi bulur ve **Tetikleme → Kısayol** altında kopyala
düğmesiyle birlikte tam satırı gösterir. Hyprland'de şöyle görünür:

```
bind = SUPER SHIFT, D, exec, qs -p ~/.config/quickshell/shell.qml ipc call quay toggle
```

### İsteğe bağlı: Hyprland'de rayın arkasına bulanıklık

```
layerrule {
    match:namespace = ^(quay|quay-settings)$
    blur = on
    ignore_alpha = 0.2
}
```

## Kullanım

| Hareket | Sonuç |
| --- | --- |
| Tekerlek | Bir satır kaydırır |
| Tıklama | Uygulamayı açar ya da öne getirir; tekrar tıklamak pencereleri arasında döner |
| İmleci bir uygulamada bekletmek | Birden fazla penceresi varsa her birini canlı gösterir |
| Klasöre tıklama | Yerinde açar |
| Sağ tıklama | Sabitler ya da sabitlemeyi kaldırır |
| Kutucuğu sürüklemek | Yerini değiştirir |
| Kutucuğu başka birinin üstüne bırakmak | Klasör yapar ya da klasöre ekler |
| Üstteki dişli | Quay'in ayarlarını açar |

## Yapılandırma

Ayarlar `~/.config/quickshell/quay/settings.json` dosyasında durur (başka bir
yol için `QUAY_SETTINGS_FILE` ayarla). Quay dosyayı ilk çalışmada oluşturur ve
elle yapılan değişiklikleri anında uygular. Tanımadığı değerleri yok sayar,
boyutları sınırlar; bir yazım hatası rayı ulaşılamaz hale getiremez.

```jsonc
{
  "schemaVersion": 1,
  "appearance": {
    "theme": "black"              // "black" | "white"
  },
  "trigger": {
    "mode": "hover",              // "always" | "hover" | "shortcut"
    "edge": "right",              // "left" | "right" | "top" | "bottom"
    "hoverRevealDelayMs": 90,     // ray kaymadan önce imlecin bekleme süresi
    "hoverHideDelayMs": 400       // imleç ayrıldıktan sonraki bekleme süresi
  },
  "layout": {
    "columns": 1,                 // raydaki sütun sayısı
    "rows": 6,                    // kaydırma yönünde sayfa başına kutucuk
    "iconSize": 52,               // kutucuk boyutu (px)
    "spacing": 10                 // kutucuklar arası boşluk (px)
  },
  "content": {
    "extras": "running",          // sabitlenenlerden sonra: "pinned" (hiçbir şey) | "running" | "recent"
    "recentLimit": 4
  },
  "previews": {
    "mode": "beside",             // "off" | "inside" (ızgaranın üstünde) | "beside" (rayın yanında)
    "delayMs": 400                // önizleme açılmadan önce imlecin kutucukta bekleme süresi
  },
  "items": [
    { "type": "app", "id": "firefox", "position": 0 },
    {
      "type": "folder",
      "id": "folder-abc123",
      "name": "Medya",
      "position": 1,
      "children": [
        { "type": "app", "id": "spotify" },
        { "type": "app", "id": "mpv" }
      ]
    }
  ],
  "recent": []                    // Quay tutar
}
```

`id`, bir masaüstü girdisinin kimliğidir — `.desktop` dosyasının uzantısız adı
(`firefox.desktop` → `firefox`). Bir uygulamanın çalışıp çalışmadığı, aynı
kimliğin compositor'ın app id'siyle, sonra girdinin `StartupWMClass` değeriyle
karşılaştırılmasıyla anlaşılır.

Her yazma işlemi `scripts/quay_store.sh` üzerinden geçer; script oku-değiştir-yaz
döngüsünün tamamında `flock` tutar, böylece panelden gelen bir değişiklik ile
aynı anda biten bir sürükleme birbirini ezemez. Doğrudan da kullanabilirsin:

```sh
scripts/quay_store.sh get
scripts/quay_store.sh set-option layout.iconSize 64
scripts/quay_store.sh get-items
```

## IPC

| Çağrı | Etkisi |
| --- | --- |
| `ipc call quay toggle` | Kısayol modunda rayı açar ya da kapatır |
| `ipc call quay show` / `hide` | Kısayol modunda rayı zorla açar ya da kapatır |
| `ipc call quay settings` | Ayar panelini açar ya da kapatır |
| `ipc call quay refreshApps` | Kurulu uygulamaları yeniden tarar |

## Yazarın diğer projesi

[Quickshell için Dynamic Island](https://github.com/lunanoir21/quickshell-dynamic-island)
— medya, zamanlayıcılar, bildirimler ve piksel sanatı bir saat, tek bir monokrom
katmanda.

## Lisans

MIT — bkz. [LICENSE](LICENSE). Sitedeki yazı tipleri Big Shoulders Stencil ve
JetBrains Mono, SIL Open Font License altındadır; lisansları `docs/fonts/`
içinde font dosyalarının yanında durur.
