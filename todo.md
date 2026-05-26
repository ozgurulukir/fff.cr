# todo.md — fff File Manager

## BFG Score: 95/100 after session fixes (Dep=100 · Coup=95 · Cog=95 · Arch=100 · Test=95 · Qual=77)

---

## 🔴 High Priority

### TODO-1 ✅ DONE | Replace bare `rescue` — `file_operations.cr` (×8)
- **Prior:** 🔴 High | **Çaba:** Orta | **Commit:** bac8031
- **Dosya:** `src/fff/file_operations.cr` — lines 37/52/66/80/95/109/129/163
- **Remedy:** `rescue e : Exception` → `rescue e : IO::Error | File::Error`

### TODO-2 ✅ DONE | Replace bare `rescue` — `file_service.cr` + `file_manager.cr`
- **Prior:** 🔴 High | **Çaba:** Küçük | **Commit:** bac8031
- **file_service.cr:88** — bare `rescue` → `rescue e : IO::Error | File::Error`
- **file_manager.cr:183** — bare `rescue` in `update_git_branch` → `rescue e : Exception`
- **file_manager.cr:410** — bare `rescue` in `mime_is_text?` → `rescue e : Exception`

### TODO-3 ✅ DONE | Add direct tests for `delete_files` + `paste_files`
- **Prior:** 🟡 Medium | **Çaba:** Orta | **Commit:** bac8031
- **Dosyalar:** `spec/integration/navigation_integration_spec.cr`
- **Added:** 3 new integration tests (`delete_files sends marked files to trash`, `returns nil when no files marked`, `paste_files copies files from clipboard to current directory (copy mode)`)
- Total suite: 131 → **134 examples**

## 🟡 Medium Priority

### ✅ 11. Narrow typed exceptions — file_operations + file_service + file_manager
- **Durum:** ✅ Done — commit bac8031
- **Dosyalar:** `src/fff/file_operations.cr`, `src/fff/file_service.cr`, `src/fff/file_manager.cr`
- **Açıklama:** 8× `rescue e : Exception` → `rescue e : IO::Error | File::Error` (file_operations); bare `rescue` → typed in file_service + file_manager.

### ✅ 12. Direct tests for delete_files + paste_files
- **Durum:** ✅ Done — commit bac8031
- **Dosyalar:** `spec/integration/navigation_integration_spec.cr`
- **Açıklama:** 3 new integration specs (delete_files sends to trash / no-files-returns-nil / paste_files copy-mode). Suite: 131 → **134 examples**.

### ✅ 13. Colorize git branch name in draw_topbar
- **Durum:** ✅ Done — commit 3557307
- **Dosya:** `src/fff/ui_renderer.cr:94`
- **Açıklama:** Branch name `(main)` → magenta; raw-left truncation prevents ANSI width corruption.

### TODO-5 | Extract `route_keypress` / `handle_key` from `file_manager.cr`
- **Prior:** 🟡 Medium | **Çaba:** Orta
- **Dosyalar:** `src/fff/file_manager.cr:316` (`handle_key` 78-line MATCH), `src/fff/file_manager.cr` (463 LOC total)
- **Açıklama:** `handle_key` has 30 branches in a single MATCH; every new key binding requires editing this function.
- **Remedy:** Break MATCH into per-action method group or a key-registry struct.

### TODO-7a | Split `file_operations.cr` (174 LOC)
- **Prior:** 🟢 Low | **Çaba:** Yüksek
- **Dosya:** `src/fff/file_operations.cr`
- **Bulgu:** 174 LOC concentrating all file-creation, deletion, rename logic in one module (FIND-7).
- **Remedy:** Split into `file_creation.cr`, `file_deletion.cr`, `file_rename.cr`.

### TODO-7b | Split `config.cr` (271 LOC)
- **Prior:** 🟢 Low | **Çaba:** Yüksek
- **Dosya:** `src/fff/config.cr`
- **Bulgu:** Env-var parsing, LS_COLORS cache, JSON config all in one (FIND-8).
- **Remedy:** Split into `env_config.cr`, `ls_colors_parser.cr`, `config_cache.cr`.

---

## ✅ Previously Done (UI/UX items 1–10)

| # | Item | Commit |
|---|------|--------|
| 1 | Loading Spinner | 67ce274 |
| 2 | Top Bar Zenginleştirme | 67ce274 |
| 3 | Status Bar Sectioning | 614a711 |
| 4 | Fuzzy Highlight (bold+underline) | 67ce274 |
| 5 | Directory/Symlink görsel ayırıcıları | 614a711 |
| 6 | Git Status Renk Kodlaması | 614a711 |
| 7 | Arama Modunda Navigasyon (j/k/↑/↓) | 7313b59 |
| 8 | Inline Confirm (TUI içi y/n onay) | a542d6d / 4ef328e |
| 9 | Inline Prompts (new/rename/go-to-dir) | 4ef328e |
| 10 | Perf cleanup (String.build, .ljust) | 6d1e1dd |

---

## BFG Trend
| Date | Overall | Dep | Coup | Cog | Arch | Test | Qual |
|------|---------|-----|------|-----|------|------|------|
| now | **95/100** | 100 | 95 | 95 | 100 | 95 | 77 |
| prev | 91/100 | 100 | 95 | 85 | 85 | 95 | 85 |
