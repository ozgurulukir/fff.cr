# FFF - Fucking Fast File Manager (Crystal Port)

Crystal programlama dilinde yazılmış, terminal tabanlı hızlı bir dosya yöneticisi. Orijinal Bash versiyonunun Crystal'e port edilmiş halidir.

## Özellikler

- ✅ **Hızlı Navigasyon**: Klavye kısayolları ile hızlı dosya/dizin gezintisi
- ✅ **Dosya İşlemleri**: Kopyalama, taşıma, silme işlemleri
- ✅ **Çoklu Seçim**: Birden fazla dosyayı işaretleme ve toplu işlemler
- ✅ **Arama**: Dosya ve dizin arama
- ✅ **Önizleme**: Dosya içeriklerini görüntüleme
- ✅ **Renkli Arayüz**: crystal-term shard'ları ile renkli terminal arayüzü
- ✅ **Performans**: Büyük dizinler için sayfalama desteği
- ✅ **Özelleştirilebilir**: Environment variable ile klavye kısayolları

## Kurulum

### Gereksinimler

- Crystal 1.0.0 veya üzeri
- Linux/macOS terminali

### Derleme

```bash
# Bağımlılıkları yükle
shards install

# Derle
crystal build src/fff.cr --release -o bin/fff

# İsteğe bağlı: Sistem geneline kur
sudo cp bin/fff /usr/local/bin/
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

| Tuş | İşlev |
|-----|-------|
| `K` | Yukarı hareket |
| `J` | Aşağı hareket |
| `L` | Dizine gir/dosya aç |
| `H` | Üst dizine git |
| `/` | Dosya ara |
| `Q` | Çıkış |
| `SPACE` | Dosya işaretle |
| `M` | Tüm dosyaları işaretle |
| `C` | İşaretli dosyaları kopyala |
| `V` | İşaretli dosyaları taşı |
| `P` | Dosyaları yapıştır |
| `D` | İşaretli dosyaları sil |
| `N` | Yeni dizin oluştur |
| `I` | Dosya önizleme |
| `SHIFT+K` | Sayfa yukarı |
| `SHIFT+J` | Sayfa aşağı |

### Environment Variables

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
export FFF_KEY_COPY="c"
export FFF_KEY_MOVE="v"
export FFF_KEY_PASTE="p"
export FFF_KEY_DELETE="d"
export FFF_KEY_NEW_DIR="n"
export FFF_KEY_PREVIEW="i"
export FFF_KEY_PAGE_UP="K"
export FFF_KEY_PAGE_DOWN="J"

# Dosya açıcı
export FFF_OPENER="xdg-open"

# Çıkışta son dizini kaydet
export FFF_CD_ON_EXIT=1
export FFF_CD_FILE="$HOME/.cache/fff/.fff_d"

# Çöp kutusu
export FFF_TRASH="$HOME/.local/share/fff/trash"
```

## Özellikler Detaylı

### Dosya İşlemleri

1. **Kopyalama**: `C` tuşu ile işaretli dosyaları panoya kopyala
2. **Taşıma**: `V` tuşu ile işaretli dosyaları taşıma moduna al
3. **Yapıştırma**: `P` tuşu ile panodaki dosyaları mevcut dizine yapıştır
4. **Silme**: `D` tuşu ile işaretli dosyaları sil

### Çoklu Seçim

- `SPACE` tuşu ile tek tek dosya işaretle
- `M` tuşu ile tüm dosyaları işaretle
- İşaretli dosyalar sarı renkle gösterilir

### Arama

- `/` tuşuna bas, arama terimini gir
- Sonuçlar anında gösterilir
- Boş arama ile tüm dosyaları görüntüle

### Önizleme

- `I` tuşu ile dosya içeriğini görüntüle
- Sadece metin dosyaları için (1MB altı)
- İlk 20 satır gösterilir

### Performans

- Büyük dizinler için otomatik sayfalama
- Sayfa başına maksimum dosya sayısı terminal boyuna göre ayarlanır
- Sayfa yukarı/aşağı ile hızlı gezinme

## Geliştirme

### Proje Yapısı

```
.
├── src/
│   └── fff.cr          # Ana kaynak kodu
├── shard.yml           # Bağımlılıklar
├── shard.lock          # Bağımlılık versiyonları
├── Makefile            # Derleme komutları
├── README.md           # Bu dosya
└── spec/
    └── fff_spec.cr     # Testler
```

### Bağımlılıklar

- `term-color`: Terminal renkleri için
- `term-screen`: Terminal boyutu bilgisi için
- `term-cursor`: İmleç kontrolü için

### Test

```bash
# Testleri çalıştır
crystal spec
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

## Sürüm Geçmişi

### v0.1.0 (2025)
- ✅ İlk Crystal port
- ✅ Temel dosya yönetimi özellikleri
- ✅ crystal-term shard'ları ile entegrasyon
- ✅ Performans optimizasyonları
- ✅ Çoklu seçim ve clipboard desteği