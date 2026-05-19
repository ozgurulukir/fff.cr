# FFF - Fucking Fast File Manager (Crystal Port)

Crystal programlama dilinde yazılmış, terminal tabanlı hızlı bir dosya yöneticisi. Orijinal Bash versiyonunun Crystal'e port edilmiş halidir.

## Özellikler

- **Hızlı Navigasyon**: Klavye kısayolları ile hızlı dosya/dizin gezintisi
- **Dosya İşlemleri**: Kopyalama, taşıma, silme, yeniden adlandırma
- **Çoklu Seçim**: Birden fazla dosyayı işaretleme ve toplu işlemler
- **Arama**: Dosya ve dizin arama
- **Önizleme**: Dosya içeriklerini görüntüleme
- **Renkli Arayüz**: crystal-term shard'ları ile renkli terminal arayüzü
- **Performans**: Büyük dizinler için sayfalama desteği
- **Özelleştirilebilir**: Environment variable ile klavye kısayolları
- **Kabuk**: Dahili kabuk başlatma (`s` tuşu)

## Kurulum

### Gereksinimler

- Crystal 1.20.1 veya üzeri
- Linux/macOS terminali

### Derleme

```bash
# Bağımlılıkları yükle
shards install

# Derle
make build

# İsteğe bağlı: Sistem geneline kur
sudo make install
```

## Kullanım

### Temel Komutlar

```bash
# Mevcut dizini aç
fff

# Belirli bir dizini aç
fff /path/to/directory

# Sürüm bilgisi
fff --version

# Yardım
fff --help
```

### Klavye Kısayolları

| Tuş | İşlev | Tuş | İşlev |
|-----|-------|-----|-------|
| `j` | Aşağı hareket | `k` | Yukarı hareket |
| `l` | Dizine gir / dosya aç | `h` | Üst dizine git |
| `q` | Çıkış | `/` | Dosya ara |
| `space` | Dosya işaretle | `m` | Tüm dosyaları işaretle |
| `y` | Kopyala (yank) | `v` | Taşı (cut) |
| `p` | Yapıştır | `d` | Sil |
| `n` | Yeni dizin oluştur | `r` | Yeniden adlandır |
| `i` | Dosya önizleme | `s` | Kabuk başlat |
| `g` | En üste git | `G` | En alta git |
| `↑` | Sayfa yukarı | `↓` | Sayfa aşağı |

Tüm kısayollar `FFF_KEY_*` environment variable'ları ile özelleştirilebilir.

### Dosya İşlemleri

1. **Kopyalama**: Dosyaları işaretleyip `y` tuşu ile panoya kopyala
2. **Taşıma**: Dosyaları işaretleyip `v` tuşu ile taşıma moduna al
3. **Yapıştırma**: Hedef dizine gidip `p` tuşu ile yapıştır
4. **Silme**: Dosyaları işaretleyip `d` tuşu ile sil (onay gerekir)
5. **Yeniden adlandırma**: Dosya üzerinde `r` tuşu ile yeni isim gir
6. **Yeni dizin**: `n` tuşu ile dizin adı gir

İşaretlenmemiş dosya üzerinde işlem yapılırsa sadece o dosya etkilenir.

### Çoklu Seçim

- `space` tuşu ile tek tek dosya işaretle
- `m` tuşu ile tüm dosyaları işaretle / işaretleri kaldır
- İşaretli dosyalar sarı renkle, panodaki dosyalar mor renkle gösterilir

### Arama

- `/` tuşuna bas, arama terimini gir
- **Tüm tuşlar (j, k dahil) arama terimine eklenir** (ranger/nnn standardı)
- Arama modunda navigasyon yok - arama yap → ESC → j/k ile gezin
- `Enter` ile aramadan çık, orijinal listeyi geri yükle
- `ESC` ile aramayı iptal et, termi temizle, orijinal listeyi geri yükle
- Büyük/küçük harf duyarsız arama
- Sonuçlar anında filtrelenir

### Önizleme

- `i` tuşu ile dosya içeriğini görüntüle
- Dosya adı, boyutu ve değiştirilme tarihi gösterilir
- 2MB altındaki dosyalar için ilk 30 satır gösterilir
- Herhangi bir tuşa basarak geri dön

### Kabuk

- `s` tuşu ile mevcut dizinde `$SHELL` başlatılır
- `exit` yazarak dosya yöneticisine dön

### Renk Kodları

| Renk | Anlam |
|------|-------|
| Kırmızı | Seçili dosya |
| Sarı | İşaretli dosya |
| Mor | Panodaki dosya |
| Mavi | Dizin |
| Yeşil | Çalıştırılabilir dosya |
| Beyaz | Normal dosya |

## Environment Variables

```bash
# Klavye kısayolları
export FFF_KEY_UP="k"
export FFF_KEY_DOWN="j"
export FFF_KEY_ENTER="l"
export FFF_KEY_QUIT="q"
export FFF_KEY_SEARCH="/"
export FFF_KEY_PARENT="h"
export FFF_KEY_MARK=" "
export FFF_KEY_MARK_ALL="m"
export FFF_KEY_COPY="y"
export FFF_KEY_MOVE="v"
export FFF_KEY_PASTE="p"
export FFF_KEY_DELETE="d"
export FFF_KEY_NEW_DIR="n"
export FFF_KEY_PREVIEW="i"
export FFF_KEY_RENAME="r"
export FFF_KEY_SHELL="s"
export FFF_KEY_TOP="g"
export FFF_KEY_BOTTOM="G"
export FFF_KEY_PAGE_UP="\e[A"
export FFF_KEY_PAGE_DOWN="\e[B"

# Dosya açıcı
export FFF_OPENER="xdg-open"

# Çıkışta son dizini kaydet
export FFF_CD_ON_EXIT=1
export FFF_CD_FILE="$HOME/.cache/fff/.fff_d"

# Çöp kutusu
export FFF_TRASH="$HOME/.local/share/fff/trash"

# Hata ayıklama
export FFF_DEBUG=1
```

## Geliştirme

### Proje Yapısı

```
.
├── src/
│   └── fff.cr          # Tüm kaynak kodu (tek dosya)
├── shard.yml           # Bağımlılıklar
├── shard.lock          # Bağımlılık versiyonları
├── Makefile            # Derleme komutları
├── fff.1               # Man sayfası
└── README.md           # Bu dosya
```

### Mimari

```
FFF::Application  # CLI giriş noktası (--version, --help, start_dir)
FFF::Config       # Environment variable yapılandırması
FFF::Terminal     # Terminal I/O (cursor, screen, reader, prompt)
FFF::FileManager  # Olay döngüsü, çizim, navigasyon, dosya işlemleri
```

### Bağımlılıklar (crystal-term shard'ları)

| Shard | Versiyon | Kullanım |
|-------|----------|----------|
| `term-color` | ~> 0.4.0 | Dosya tipi renklendirmesi, durum çubuğu |
| `term-screen` | ~> 0.3.0 | Terminal genişliği/yüksekliği |
| `term-cursor` | ~> 0.3.0 | İmleç gizle/göster |
| `term-reader` | ~> 0.3.0 | Tuş basımı okuma |
| `term-prompt` | ~> 0.3.0 | Etkileşimli diyaloglar (arama, silme onayı, yeniden adlandırma) |

### Bilinen Shard Hataları

`shards install` sonrası `lib/` dizininde elle düzeltilmesi gereken hatalar:

1. **term-reader** (`lib/term-reader/src/term-reader.cr:102`): `sync=` `Bool` bekler, `Bool | Nil` alır
2. **term-prompt** (`lib/term-prompt/src/prompt/confirm_question.cr:95`): `Regex.escape` `String` bekler, `Char` alır
3. **term-cursor** `move_to`: satır/sütun parametrelerini yer değiştirir — ham ANSI kullanılır
4. **term-reader** `Mode#raw`: `raw: true` raw mode'a geçmez, `raw: false` geçer

### Komutlar

```bash
make build      # Release derleme
make debug      # Debug derleme (hızlı derleme, optimizasyonsuz)
make run        # Derle ve çalıştır
make test       # Testleri çalıştır
make format     # Kodu formatla
make clean      # Derleme artefaktlarını temizle
make deps       # Bağımlılıkları yükle
```

## Katkıda Bulunma

1. Fork yapın
2. Feature branch oluşturun (`git checkout -b feature/amazing-feature`)
3. Commit yapın (`git commit -m 'Add amazing feature'`)
4. Branch'i push edin (`git push origin feature/amazing-feature`)
5. Pull Request açın

## Lisans

MIT License - Orijinal proje lisansına uygun olarak

## Teşekkürler

- Orijinal FFF projesi için [dylanaraps](https://github.com/dylanaraps/fff)
- Crystal-term shard'ları için [crystal-term](https://github.com/crystal-term) organizasyonu
