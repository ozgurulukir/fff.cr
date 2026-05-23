# UI/UX Bump — fff File Manager

## Öncelikli (🔴 Yüksek Etki / Düşük Çaba)

### ✅ 1. Loading Spinner
- [x] **Durum:** Pending
- **Dosya:** `src/fff/ui_renderer.cr` — `draw_all_lines`
- **Açıklama:** Statik `"Loading..."` yerine dönen spinner karakterleri çiz. 10 karelik braille spinner (`⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏`), zaman tabanlı animasyon.
- **Çaba:** Küçük
- **Bağımlılık:** Yok

### ✅ 2. Top Bar Zenginleştirme
- [x] **Durum:** Pending
- **Dosyalar:** `src/fff/draw_state.cr`, `src/fff/file_manager.cr`, `src/fff/ui_renderer.cr`
- **Açıklama:** Top bar'a toplam dosya sayısı, gizli dosya sayısı, toplam boyut ekle. Örn: `~/proj (main)  47 files  12.4k  ↓`. `DirectoryManager`'da hesaplanır, `DrawState`'e alan eklenir.
- **Çaba:** Orta
- **Bağımlılık:** Yok

### ✅ 3. Status Bar Sectioning
- [ ] **Durum:** Pending
- **Dosya:** `src/fff/ui_renderer.cr` — `draw_status`
- **Açıklama:** Sol tarafta dosya adı + meta, sağda clipboard + mark + git durumu. Zaten `|` ile ayrılıyor, sağ tarafı `ljust` ile sağa yasla.
- **Çaba:** Orta
- **Bağımlılık:** Yok

### ✅ 4. Fuzzy Highlight Geliştirme
- [x] **Durum:** Pending
- **Dosya:** `src/fff/ui_renderer.cr` — `draw_fuzzy_name`
- **Açıklama:** Eşleşen karakterleri sadece renk değil, **kalın + altı çizili** yap. `Term::Color.truecolor_string` bold parametresi var mı kontrol et; yoksa ANSI `\e[1m` + `\e[4m` escape kodları ekle.
- **Çaba:** Küçük
- **Bağımlılık:** Yok

---

## Orta Öncelik (🟡 Orta Etki / Orta Çaba)

### 5. Directory/Symlink Görsel Ayırıcıları
- [ ] **Durum:** Pending
- **Dosya:** `src/fff/ui_renderer.cr` — `draw_line`
- **Açıklama:** Klasörler için `📁`, çalıştırılabilir dosyalar için `*` ekle. Mevcut `/` (dir) ve `@` (symlink) korunsun.
- **Çaba:** Orta

### 6. Git Status Renk Kodlaması
- [ ] **Durum:** Pending
- **Dosya:** `src/fff/ui_renderer.cr` — `draw_status`
- **Açıklama:** `+` (staged) → green, `~` (modified) → yellow, `?` (untracked) → cyan, `-` (deleted) → red.
- **Çaba:** Orta

### 7. Error Auto-expire Animasyonu
- [ ] **Durum:** Pending
- **Dosya:** `src/fff/ui_renderer.cr` — `draw_error`
- **Açıklama:** Hata mesajı 2sn sonra ani kaybolmaktan ziyade kademeli sil (fade-out).
- **Çaba:** Orta

---

## Düşük Öncelik (🟢 Düşük Etki / Yüksek Çaba)

### 8. Multi-column Layout
- [ ] **Durum:** Pending
- **Dosyalar:** `src/fff/ui_renderer.cr`, `src/fff/draw_state.cr`, `src/fff/directory_manager.cr`
- **Açıklama:** Terminal genişliğine göre dosyaları 2-3 sütuna yerleştir.
- **Çaba:** Yüksek

### 9. File Type Badges
- [ ] **Durum:** Pending
- **Dosya:** `src/fff/ui_renderer.cr` — `draw_line`
- **Açıklama:** `.cr` → `[CRYSTAL]`, `.json` → `[JSON]` gibi küçük etiketler.
- **Çaba:** Yüksek

### 10. Cursor Trail / Highlight Flash
- [ ] **Durum:** Pending
- **Dosya:** `src/fff/ui_renderer.cr` — `redraw`, `draw_line`
- **Açıklama:** Yukarı/aşağı hareket ederken eski satırı kısa süre farklı renkle göster.
- **Çaba:** Yüksek
