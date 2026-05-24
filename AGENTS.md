# AGENTS.md

## Project Overview

**fff** (Fucking Fast File Manager) — a terminal-based file manager written in Crystal.

- **Language**: Crystal 1.20.1
- **Source**: Multiple files in `src/fff/`
- **Branch**: `crystal-port` (Bash source removed — pure Crystal)
- **Build**: `make build` or `crystal build src/fff.cr --release -o bin/fff`

## Architecture

```
src/fff.cr          # Application entry point (FFF::Application + ARGV parsing)
src/fff/
  config.cr         # Environment variable & LS_COLORS configuration
  directory_manager.cr# Directory reader, sorting mechanisms, and state manager
   draw_state.cr     # DrawState struct — bundles 19 render params into one object
  file_manager.cr   # Core coordinator: event loop & high-level TUI router (~322 lines)
  file_op_handlers.cr# Extracted file operation methods (included by FileManager)
  file_operations.cr# Specialized file/directory creation and operations
  file_service.cr   # Low-level filesystem helpers with writability checks
  format_utils.cr   # Shared utilities (human_size) used across modules
   input_mode.cr     # Search/rename text input with cursor control, insert/delete editing
  navigation_handlers.cr# Extracted navigation methods (included by FileManager)
  search_engine.cr  # Fuzzy search engine & ripgrep integration (Process.run, no shell)
  terminal.cr       # Direct terminal ANSI control & cursor mapping
  ui_renderer.cr    # Incremental rendering and presentation manager
  view_handlers.cr  # Extracted preview/attributes/shell methods (included by FileManager)
```

### Module Architecture

`FileManager` includes three handler modules that share its instance state:

```
FileManager
├── include NavigationHandlers  → cursor_up/down, go_*, jump_to_bookmark
├── include FileOpHandlers      → enter, new, rename, mark, yank, paste, delete
├── include ViewHandlers        → preview, attributes, spawn_shell
└── (core)                      → event_loop, redraw, input_mode routing
```

State is managed within the `FileManager` instance, with `Config` and `Terminal` as dependencies. Directory items and structures are delegated to `DirectoryManager`, drawing to `UIRenderer` (via a single `DrawState` struct), and operations to `FileOperations`.

## Security

All external command execution uses `Process.run` with explicit argv arrays — no shell interpolation. Backtick and `system()` calls were eliminated in Phase 7 refactor. Commands affected: ripgrep (`rg`), `file --mime-type`, shell spawn, editor/open invocations, bulk rename, `bat`, `less`.

## Dependencies (crystal-term shards)

| Shard | Version | Usage |
|---|---|---|
| `term-color` | ~> 0.4.0 | `Term::Color.color(:blue)`, `Term::Color.truecolor_string(text, fore:, back:)` |
| `term-screen` | ~> 0.3.0 | `Term::Screen.width`, `Term::Screen.height` — returns `{rows, cols}` |
| `term-cursor` | ~> 0.3.0 | `Term::Cursor.hide` / `.show` / `.clear_line` — **return ANSI strings, must be `print`ed** |
| `term-reader` | ~> 0.3.0 | `Term::Reader#read_keypress` for keyboard input |
| `term-prompt` | ~> 0.3.0 | `Term::Prompt#ask`, `#yes?`, `#keypress` for interactive dialogs |

## Known Shard Bugs (patched in lib/)

These are fixed via `sed` in `lib/` after `shards install`. Patches are **not** persistent — re-running `shards install` overwrites them.

### 1. `term-reader` — `sync=` type mismatch
- **File**: `lib/term-reader/src/term-reader.cr:102`
- **Fix**: change `@output.as(IO::FileDescriptor).sync = buffering` to `@output.as(IO::FileDescriptor).sync = buffering || false`

### 2. `term-reader` — `get_codes` ESC loop hangs
- **File**: `lib/term-reader/src/reader/console.cr:28-30`
- **Bug**: `@input.blocking = !nonblock` doesn't reliably make `read_char` nonblocking on TTY, causing the escape code detection loop to hang.
- **Fix**: replace `@input.blocking = !nonblock` with a fiber-based timeout using `Channel(Char?)` + `spawn { sleep 5.milliseconds }` race. If no data arrives within 5ms, returns nil instead of blocking. This avoids the nonblocking IO that Crystal doesn't support on TTY.

### 3. `term-prompt` — `Regex.escape` type mismatch
- **File**: `lib/term-prompt/src/prompt/confirm_question.cr:95`
- **Fix**: change `positive.to_s[0]` to `positive.to_s[0].to_s`

### 4. `term-cursor` — `move_to` swaps row/col
- **Workaround**: use raw ANSI `\e[row;colH` directly (implemented in `Terminal#move_to`)

### 5. `term-reader` — `Mode#raw` inverted semantics
- **Workaround**: call `read_keypress(raw: false)` to actually get raw mode

### 6. `term-color` — `Cor` undefined constant in `pretty_print`
- **File**: `lib/term-color/src/color/color.cr:359`
- **Bug**: `Cor.truecolor_string(...)` references undefined constant `Cor` — should be `Color.truecolor_string(...)`
- **Fix**: change `Cor.truecolor_string` to `Color.truecolor_string`

## Build & Run

```bash
shards install                    # install dependencies
make build                        # release build → bin/fff
make debug                        # debug build (faster compile, no optimizations)
make test                         # run test suite
make format                       # crystal tool format
make lint                         # ameba static analysis
make run                          # build + run
./bin/fff                         # launch in current directory
./bin/fff /path/to/dir            # launch in specific directory
```

## Key Bindings (defaults, all configurable via `FFF_KEY_*` env vars)

| Key | Action | Key | Action |
|---|---|---|---|
| `j`/`k` | Down/Up | `l`/`h` | Enter/Parent |
| `q` | Quit | `?` | Help overlay |
| `/` | Search | `space` | Mark file |
| `m` | Mark all | `y` | Yank (copy) |
| `v` | Cut (move) | `p` | Paste |
| `d` | Delete (to trash) | `n` | New directory |
| `f` | New file | `r` | Rename |
| `b` | Bulk Rename | `i` | Preview (`bat`→`less`→builtin) |
| `s` | Spawn shell | `g` / `G` | Top / Bottom |
| `↑` / `↓` | Cursor up / down | `PgUp` / `PgDn` | Page up / down |
| `.` | Toggle hidden | `t` | Go to trash |
| `x` | Attributes | `X` | Toggle executable |
| `:` | Go to directory | `~` | Home directory |
| `-` | Previous directory| `e` | Refresh directory |
| `S` | Symlink | `=` / `+` | Cycle sort / Reverse |
| `1-9` | Favorites | | |

In search and rename modes:
| `←` / `→` | Move cursor | `Home` / `End` | Jump start/end |
| `Backspace` | Delete before cursor | `Delete` | Delete at cursor |

## Terminal Handling

- **Search Mode**: Navigable. `j/k` work while filter is active.
- **Cursor Editing**: Both search and rename modes support `←`/`→` cursor movement, `Home`/`End`, `Backspace`/`Delete`, and insert-at-cursor typing.
- **Incremental & State Redraws**: Uses dynamic `@force_full_redraw` to force clean clears only when transitioning into or out of search/rename modes. Normal state changes redraw incrementally to eliminate TUI flickering.
- **Color Caching**: Results cached by file path only (removed stale width dependency).
- **Scroll Region**: `\e[1;{max_items}r` keeps status line fixed.
- **Page Scroll**: `PgUp`/`PgDn` (`\e[5~`/`\e[6~`) scroll by one screenful. Configurable via `FFF_KEY_PAGE_UP`/`FFF_KEY_PAGE_DOWN`.
- **Arrow Key Safety**: Safe fallback lookup (`@config.key_bindings[key]? || key`) protects against unrecognized raw escape sequences raising `KeyError` crashes.
- **Input Mismatch Resilience**: Robust matching handles both raw characters (`\e`, `\r`, `\b`) and mapped TTY names (`"escape"`, `"enter"`, `"backspace"`, `"up"`, `"down"`) to ensure 100% terminal compatibility.

## File Operations

- **Bulk Rename**: Mark files → `b` → edit in `$EDITOR`.
- **Rename Abort Safety**: Safe Escape key cancellation during renames terminates the workflow cleanly without applying unintended edits.
- **Cursor Editing**: Rename mode supports cursor movement, insert-at-cursor, backspace/delete, Home/End.
- **Trash**: Moves to `~/.local/share/fff/trash` with conflict resolution.
- **Write Checks**: Proactive `File::Info.writable?` checks before mutation.
- **Picker Mode**: `-p` flag writes selection to `~/.cache/fff/opened_file`.
- **Shell Injection Free**: All external commands use `Process.run` with argv arrays — no `system()` or backticks.

## Performance

- **LS_COLORS**: Parsed once and cached in `Config`.
- **Redraw**: Optimized double-buffered incremental drawing loop.
- **Lazy Content Search**: Live search queries only update fuzzy file list scanning. Expensive content queries (triggered via `!`) are deferred until the user presses **Enter**, preventing TUI lag and freezes while typing.
- **Hot-path string building**: `draw_status`, `draw_topbar`, `draw_help_overlay` use `String.build` instead of `parts = [] + join`.
- **Per-char rendering**: `draw_fuzzy_name` and `colorize_git_status` use `String.build { |s| s << char }` instead of `char.to_s`.
- **Anti-patterns avoided**:
  - `.ljust()` + `[0...n]` slice pair → replaced with single `String.build` + gap math
  - `.chars.map { ... }.join` → replaced with `String.build` + `.each_char`

## Test Infrastructure & Lessons Learned

### MockTerminal — No `instance_variable_get/set` in Crystal
Crystal lacks Ruby-style `instance_variable_get/set`. All test-visible state must be exposed via `property`/`getter` declarations. `FileManager` exposes `scroll`, `page_offset`, `marked`, `clipboard`, `error_msg`, `renderer`, `dir_manager`, `input_mode`, and `error_expires`. Handler methods (`NavigationHandlers`, `FileOpHandlers`, `ViewHandlers`) are declared `def` instead of `private def` to allow test invocation.

### MockTerminal Construction
Both integration specs use `MockTerminal < FFF::Terminal` with an internal `@read_buffer` key queue (overrides `read_keypress`) and `@answer_queue` prompt queue. `FileManager.initialize` accepts an optional `term : Terminal?` parameter for injection. The advanced spec previously used a standalone class with struct-based input — refactored to subclass `FFF::Terminal` to avoid type-acceptance issues in inheritance-sensitive methods.

### `File.chmod` Bitwise Operations Broken (Crystal 1.20.1)
`File.chmod(Int32, Path)` with union-type or permission bitwise OR fails at compile time. **Fix**: `Process.run("chmod", ["+x"/"-x", path])` used in both `file_operations.cr` and all specs that manipulate permissions.

### `File.executable?` Deprecated
Crystal 1.20 deprecates `File.executable?`. **Fix**: `File::Info.executable?(path)` — class method that opens and checks the bit internally.

### `Process.kill` Deprecated
`Process.kill(signal, pid)` is removed. **Fix**: `Process.signal(Signal::TERM, pid)` (and `Signal::KILL` for forceful terminations).

### `dir.entries` Double-Filtering Bug (`.`/`..` + Hidden)
`Dir.entries` returns `"."` and `".."`. If both are filtered first and `hidden_count` runs afterward, `"."` and `".."` match `starts_with?('.')` → hidden count inflated by 2. **Fix**: filter `"."` + `".."` in a single guard before `hidden_count` increment; `@hidden_count += 1` was also moved inside the `else` branch so directories are not counted in `hidden_count` (only regular files carry that metadata).

### `make clean` Removes `bin/` Directory
`Makefile.clean` uses `rm -rf bin/` which removes the directory itself, causing `make build` linker to fail on subsequent invocation. **Workaround**: `mkdir -p bin` before `make build`.

### Build Order Matters
`make build` → new binary replaces `bin/fff` atomically. Always rebuild (`make clean` + `make build`) after renaming `property` declarations that affect layout, since incremental builds may not link correctly after struct field order changes.

### Search Mode Navigation — Mode-Specific Key Routing
Arama modunda (`/`) `j`/`k`/`↑`/`↓` tuşları text input'e değil navigasyon handler'larına yönlendirilmelidir. **Fix**: `InputMode`'da `navigating : Bool` flag eklendi; up/down search modunda `@navigating = true` yapılıyor, `FileManager.handle_input_mode` bu bayrağı yakalayıp `cursor_up`/`cursor_down` çağırıyor, `live_search` atlanıyor. `InputMode.handle_key` hala `false` döndürüyor (text input tarafı "tamamlama" olarak görmüyor).

### `draw_status` Hot-Path: Avoid `.ljust` + `[0...n]` Slice Pair
`.ljust` zaten yeni bir string kopyası üretir, sonra `[0...n]` yine yeni bir kopya üretir → her frame'de iki gereksiz allocation. **Fix**: `String.build { |s| s << left << " " * gap << right }` ile tek adımda birleştir, gap hesaplamasını doğrudan yap.

### `colorize_git_status`: Avoid `.chars.map(...).join` Anti-Pattern
`.chars.map { ... }.join` her karakter için bir Array<String> elementi oluşturur, sonra tümünü tekrar birleştirir. **Fix**: `String.build do |s| status.each_char { |c| s << colored_char } end` — per-char `String.build` ile doğrudan yaz, ara Array oluşturma.

### Crystal Macro `previous_def` in Submodules
`include` edilen modüllerde (ör. `NavigationHandlers`) `getter`/`property` macro'ları `FileManager`'ın scope'unda çalışır. Alt modülde ivar tanımlamak için `def initialize` içinde `@ivar = value` kullan — bu, üst modüldeki macro ile oluşturulan getter'ları tetikler. `@ivar = nil` tipini tetikleyerek nilability uyarısı verebilir, ancak doğruysa sorun değil.

### Crystal 1.20 `String#[]` Slice-Copy Semantics
`str[a...b]` her zaman yeni bir string kopyası üretir. Hot-path'lerde (ör. `draw_line` her karakter) bunu `String.build { |s| s << char }` ile değiştir. Tek seferlik işlerde (ESC tespit, config parsing) etkisi yoktur, scoped doğrudan içinde doğal iterasyon kullan.

### Crystal `getter` vs `property` in Test Context
Crystal'da `getter` sadece okunur, `property` okunur+yazılır. Test'lerde mock injection veya state reset için `property` kullan. `FileManager.renderer` örneği: önce `getter` idi, test'de mock renderer set edilemedi → `property`'a çevrildi.


