# FFF - Fucking Fast File Manager

Crystal ile yazılmış, terminal tabanlı hızlı bir dosya yöneticisi. Orijinal Bash versiyonunun Crystal'e yeniden yazılmış halidir.

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
make deps

# Release derlemesi (önerilir)
make build

# Debug derlemesi (hızlı derleme, optimizasyon yok)
make debug

# Derle ve çalıştır
make run

# Test
make test

# Format kontrolü
make format

# Temizlik
make clean

# İsteğe bağlı: Sistem geneline kur (man sayfası dahil)
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
| `g`/`G` | En üst/En alt | `↑`/`↓` | İmleç yukarı/aşağı |
| `.` | Gizli dosyalar | `~` | Home dizini |
| `-` | Önceki dizin | `e` | Yenile (Refresh) |
| `=` | Sıralama modu değiştir | `+` | Sıralama ters çevir |
| `1-9` | Favori dizinler | `:` | Dizine git |
| `S` | Sembolik link | | |

## Yapılandırma

fff, `~/.config/fff/config.json` dosyasından ve environment variable'lardan yapılandırılır. Environment variable'lar JSON'dan önceliklidir.

### Environment Variables

```bash
# Favori dizinler (1-9 arası)
export FFF_FAV1="$HOME/Documents"
export FFF_FAV2="$HOME/Downloads"

# Dosya açıcı (varsayılan: Linux'ta xdg-open, macOS'te open)
export FFF_OPENER="xdg-open"

# Editör (varsayılan: $EDITOR veya vi)
export EDITOR="vim"

# Çöp kutusu dizini
export FFF_TRASH="$HOME/.local/share/fff/trash"

# Çıkışta dizin kaydetme
export FFF_CD_ON_EXIT="1"
export FFF_CD_FILE="$HOME/.cache/fff/.fff_d"

# Tüm tuş atamaları FFF_KEY_* ile değiştirilebilir:
# FFF_KEY_UP, FFF_KEY_DOWN, FFF_KEY_ENTER, FFF_KEY_QUIT,
# FFF_KEY_SEARCH, FFF_KEY_PARENT, FFF_KEY_MARK, FFF_KEY_MARK_ALL,
# FFF_KEY_COPY, FFF_KEY_MOVE, FFF_KEY_PASTE, FFF_KEY_DELETE,
# FFF_KEY_NEW_DIR, FFF_KEY_MKFILE, FFF_KEY_RENAME, FFF_KEY_BULK_RENAME,
# FFF_KEY_PREVIEW, FFF_KEY_SHELL, FFF_KEY_HIDDEN, FFF_KEY_HOME,
# FFF_KEY_PREVIOUS, FFF_KEY_REFRESH, FFF_KEY_ATTRIBUTES,
# FFF_KEY_EXECUTABLE, FFF_KEY_GO_DIR, FFF_KEY_GO_TRASH,
# FFF_KEY_SYMLINK, FFF_KEY_TOP, FFF_KEY_BOTTOM,
# FFF_KEY_PAGE_UP, FFF_KEY_PAGE_DOWN
```

### JSON Yapılandırma

```json
{
  "editor": "vim",
  "opener": "xdg-open",
  "trash_dir": "/path/to/trash",
  "cd_on_exit": "true",
  "favorites": {
    "1": "/home/user/Documents",
    "2": "/home/user/Downloads"
  },
  "keys": {
    "up": "k", "down": "j", "enter": "l", "quit": "q"
  },
  "bookmarks": {
    "proj": "/home/user/projects"
  }
}
```

## Geliştirme

### Proje Yapısı

```
.
├── Makefile                    # Derleme, kurulum, test hedefleri
├── shard.yml                   # Crystal bağımlılıkları
├── shard.lock
├── ameba.yml                   # Ameba linter yapılandırması
├── .gitignore
├── .travis.yml                 # CI yapılandırması
├── AGENTS.md                   # AI asistan bağlamı
├── LICENSE.md
├── README.md
├── fff.1                       # Man sayfası
├── bin/
│   └── fff                    # Derlenmiş binary
└── src/
    ├── fff.cr                  # Uygulama giriş noktası
    └── fff/
        ├── config.cr           # Environment variable ve LS_COLORS
        ├── directory_manager.cr# Dizin tarama, sıralama, durum
        ├── draw_state.cr       # Render durumu struct
        ├── file_manager.cr     # TUI olay döngüsü, ana koordinasyon
        ├── file_op_handlers.cr # Dosya işlemleri (include)
        ├── file_operations.cr  # Dosya/dizin oluşturma, silme
        ├── file_service.cr     # Düşük seviye dosya işlemleri
        ├── format_utils.cr     # Paylaşılan yardımcılar
        ├── input_mode.cr       # Arama/yeniden adlandırma modu
        ├── navigation_handlers.cr# Gezinme (include)
        ├── search_engine.cr    # Bulanık arama + ripgrep
        ├── terminal.cr         # crystal-term sarmalayıcı
        ├── ui_renderer.cr      # Incremental redraw
        └── view_handlers.cr    # Önizleme, shell (include)
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

