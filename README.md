# FFF - Fucking Fast File Manager

Crystal ile yazılmış, terminal tabanlı hızlı bir dosya yöneticisi. Orijinal Bash versiyonunun Crystal'e port edilmiş halidir.

## Özellikler

- **Yüksek Performans**: `LS_COLORS` önbelleğe alma ve optimize edilmiş incremental çizim döngüsü.
- **Hızlı Navigasyon**: Klavye kısayolları ve favori dizinler (`1-9`).
- **Dosya İşlemleri**: Kopyalama, taşıma, silme (çöp kutusu), yeniden adlandırma.
- **Toplu İşlemler**: Toplu yeniden adlandırma (Bulk Rename) ve çoklu seçim.
- **Güvenlik**: Tüm harici komutlar `Process.run` ile (shell injection yok), işlem öncesi yazma izin kontrolü.
- **Arama**: Anlık filtreleme, arama sırasında navigasyon, ripgrep ile içerik arama (`!` öneki).
- **Önizleme**: `bat` → `less` → builtin fallback ile akıllı önizleme; dosya öznitelikleri (`stat`).
- **Dosya Seçici Modu**: Diğer araçlarla entegrasyon için `-p` bayrağı.
- **Özelleştirilebilir**: Environment variable ile tam kontrol.

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

# Dosya seçici modu (seçilen dosyayı cache'e yazar)
fff -p
```

### Klavye Kısayolları

| Tuş | İşlev | Tuş | İşlev |
|-----|-------|-----|-------|
| `j`/`k` | Aşağı/Yukarı | `l`/`h` | Gir/Geri |
| `q` | Çıkış | `/` | Ara (Navigasyon açık) |
| `space` | İşaretle | `m` | Tümünü işaretle |
| `y`/`v` | Kopyala/Kes | `p` | Yapıştır |
| `d` | Çöpe at | `t` | Çöp kutusuna git |
| `n` | Yeni dizin | `f` | Yeni dosya |
| `r` | Yeniden adlandır | `b` | Toplu yeniden adlandır |
| `i` | İçerik önizle | `x` | Özellikleri göster (`stat`) |
| `X` | Executable toggle | `s` | Kabuk (Shell) başlat |
| `g`/`G` | En üst/En alt | `↑`/`↓` | Sayfa yukarı/aşağı |
| `.` | Gizli dosyalar | `~` | Home dizini |
| `-` | Önceki dizin | `e` | Yenile (Refresh) |
| `1-9` | Favori dizinler | `:` | Dizine git |
| `S` | Sembolik link | | |

## Environment Variables

```bash
# Favoriler
export FFF_FAV1="$HOME/Documents"
export FFF_FAV2="$HOME/Downloads"

# Dosya açıcı (macOS'ta otomatik 'open')
export FFF_OPENER="xdg-open"

# Çöp kutusu
export FFF_TRASH="$HOME/.local/share/fff/trash"
```

## Geliştirme

### Proje Yapısı

```
.
├── src/
│   ├── fff.cr                  # Uygulama giriş noktası
│   └── fff/
│       ├── config.cr           # Çevre değişkenleri ve LS_COLORS ayarları
│       ├── directory_manager.cr# Dizin tarama, sıralama ve durum yönetimi
│       ├── draw_state.cr       # Render durumu struct (16 parametre yerine)
│       ├── file_manager.cr     # TUI olay döngüsü ve ana koordinasyon
│       ├── file_op_handlers.cr # Dosya işlemleri (FileManager include)
│       ├── file_operations.cr  # Dosya/dizin oluşturma, silme, taşıma
│       ├── file_service.cr     # Düşük seviye dosya sistemi işlemleri
│       ├── format_utils.cr     # Paylaşılan yardımcı fonksiyonlar
│       ├── input_mode.cr       # Arama/yeniden adlandırma giriş modları
│       ├── navigation_handlers.cr# Gezinme metodları (FileManager include)
│       ├── search_engine.cr    # Bulanık arama + ripgrep içerik arama
│       ├── terminal.cr         # crystal-term sarmalayıcısı
│       ├── ui_renderer.cr      # Incremental redraw arayüz çizici
│       └── view_handlers.cr    # Önizleme, öznitelik, shell (FileManager include)
```

### Mimari

- **FFF::Application**: Komut satırı argümanlarını işler, terminal ortamını başlatır.
- **FFF::Config**: `LS_COLORS` dahil tüm yapılandırmayı yönetir.
- **FFF::DirectoryManager**: Dizin tarama, sıralama, filtreleme — `@full_list` ile arama iptalinde tam listeyi geri getirir.
- **FFF::DrawState**: `redraw`'ın tüm parametrelerini tek bir struct'ta toplar.
- **FFF::FileManager**: Olay döngüsü ve TUI yönlendirici. `NavigationHandlers`, `FileOpHandlers`, `ViewHandlers` modüllerini include eder.
- **FFF::FileOperations**: Dosya/dizin oluşturma, kopyalama, silme, taşıma.
- **FFF::FileService**: `copy`, `move`, `trash`, `symlink` — yazma izni kontrollü.
- **FFF::InputMode**: Arama/yeniden adlandırma modlarında tuş vuruşu yönetimi, ESC/Enter işleme.
- **FFF::SearchEngine**: Bulanık dosya adı araması + ripgrep ile içerik arama (`!` öneki).
- **FFF::FormatUtils**: `human_size` gibi paylaşılan yardımcılar.
- **FFF::Terminal**: `crystal-term` shard'larını sarmalar, ANSI kontrol, raw mod.
- **FFF::UIRenderer**: Incremental redraw ile titreşimsiz arayüz çizimi.

## Önizleme

`i` tuşu ile dosya önizleme şu sırayla dener:

1. `bat --paging=always` (syntax highlighting, scroll)
2. `less` (sayfalama, arama)
3. Dahili builtin (ilk 50 satır)

Dizinler için her zaman dahili builtin kullanılır.

## Lisans

MIT License

