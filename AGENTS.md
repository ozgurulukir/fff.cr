# AGENTS.md

## Project Overview

**fff.cr** (Fucking Fast File Manager) — a terminal-based file manager written in Crystal.

- **Language**: Crystal 1.20.1
- **Source**: Multiple files in `src/fff/`
- **Version**: 0.3.0
- **Tests**: 205 examples (94 unit + 111 integration), 0 failures
- **Build**: `make build` or `crystal build src/fff.cr --release -o bin/fff-cr`

## Architecture

```text
src/fff.cr          # Application entry point (FFF::Application + ARGV parsing)
src/fff/
  config.cr         # Environment variable & LS_COLORS configuration, UI preference management
  directory_manager.cr# Directory reader, sorting mechanisms, and state manager
  draw_state.cr     # DrawState struct — bundles 30 render params into one object
  file_manager.cr   # Core coordinator: event loop, hash-table key dispatch (~610 lines)
  file_op_handlers.cr# Extracted file operation methods (included by FileManager)
  file_operations.cr# Specialized file/directory creation and operations with callback blocks
  file_service.cr   # Low-level filesystem helpers with writability checks
  format_utils.cr   # Shared utilities (human_size, date formatters, FFF::HOME)
  icon_provider.cr  # Nerd Font icons provider (extension and filename lookup mappings)
  input_mode.cr     # Search/rename text input with cursor control, insert/delete editing, search modes
  message_bus.cr    # Message queue managing notifications (Error/Success/Warning/Info)
  navigation_handlers.cr# Extracted navigation methods (included by FileManager)
  preview_panel.cr  # Side-panel rendering for file details and directory previews
  progress_bar.cr   # Console progress bar renderer for bulk actions
  search_engine.cr  # Fuzzy search engine, ripgrep content search, and recursive directory tree search
  terminal.cr       # Direct terminal ANSI control & cursor mapping
  theme.cr          # RGB central truecolor theme system with preconfigured styles
  ui_renderer.cr    # Incremental rendering, layout layout, truecolor styling, breadcrumb, columns
  view_handlers.cr  # Extracted preview/attributes/shell methods (included by FileManager)
```

### Module Architecture

`FileManager` includes three handler modules that share its instance state:

```text
FileManager
├── include NavigationHandlers  → cursor_up/down, go_*, jump_to_bookmark
├── include FileOpHandlers      → enter, new, rename, mark, yank, paste, delete
├── include ViewHandlers        → preview, attributes, spawn_shell
├── uses MessageBus             → queues toast/notification messages
└── (core)                      → event_loop, redraw, input_mode routing,
                                   @key_handlers hash dispatch (built in initialize)
```

State is managed within the `FileManager` instance, with `Config` and `Terminal` as dependencies. Directory items and structures are delegated to `DirectoryManager`, drawing to `UIRenderer` (via a single `DrawState` struct), and operations to `FileOperations`. Auxiliary systems (Theme, IconProvider, PreviewPanel, ProgressBar) are invoked statically or structurally during drawing or multi-file actions.

## Security

All external command execution uses `Process.run` with explicit argv arrays — no shell interpolation. Backtick and `system()` calls were eliminated (including `default_opener`'s backtick for `uname` in Phase 8). Commands affected: ripgrep (`rg`), `file --mime-type`, `uname`, shell spawn, editor/open invocations, bulk rename, `bat`, `less`.

## Dependencies (crystal-term shards)

| Shard         | Version  | Usage                                                                                      |
| ------------- | -------- | ------------------------------------------------------------------------------------------ |
| `term-color`  | ~> 0.4.0 | `Term::Color.color(:blue)`, `Term::Color.truecolor_string(text, fore:, back:)`             |
| `term-screen` | ~> 0.3.0 | `Term::Screen.width`, `Term::Screen.height` — returns `{rows, cols}`                       |
| `term-cursor` | ~> 0.3.0 | `Term::Cursor.hide` / `.show` / `.clear_line` — **return ANSI strings, must be `print`ed** |
| `term-reader` | ~> 0.3.0 | `Term::Reader#read_keypress` for keyboard input                                            |
| `term-prompt` | ~> 0.3.0 | `Term::Prompt#ask`, `#yes?`, `#keypress` for interactive dialogs                           |

## Known Shard Bugs (patched in lib/)

These are known issues in `crystal-term` shards. Bugs 1, 3, and 6 are patched by `scripts/patch_shards.cr` after `shards install` (called automatically by `make deps`). Bugs 2, 4, and 5 are handled via workarounds in the main source code. The patch script is idempotent and cross-platform (Crystal runs on both Linux and Windows). Patches are **not** persistent — re-running `shards install` overwrites `lib/` contents, but `make deps` or `crystal run scripts/patch_shards.cr` re-applies them.

### 1. `term-reader` — `sync=` type mismatch

- **File**: `lib/term-reader/src/term-reader.cr:102`
- **Fix**: change `@output.as(IO::FileDescriptor).sync = buffering` to `@output.as(IO::FileDescriptor).sync = buffering || false`

### 2. `term-reader` — `get_codes` ESC loop hangs

- **File**: `lib/term-reader/src/reader/console.cr:28-30`
- **Bug**: `@input.blocking = !nonblock` doesn't reliably make `read_char` nonblocking on TTY, causing the escape code detection loop to hang.
- **Fix**: On POSIX, replace `@input.blocking = !nonblock` with a fiber-based timeout using `Channel(Char?)` + `spawn { sleep 5.milliseconds }` race. On Windows, since Crystal is single-threaded and blocking TTY reads pause the scheduler, we use a native `LibMSVCRT.kbhit` check to immediately return `nil` if no input is queued in the console, preventing lagging/hanging.

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

**On Linux/macOS:**

```bash
shards install                    # install dependencies
make build                        # release build → bin/fff-cr
make debug                        # debug build (faster compile, no optimizations)
make test                         # run test suite
make format                       # crystal tool format
make lint                         # ameba static analysis
make run                          # build + run
./bin/fff-cr                      # launch in current directory
./bin/fff-cr /path/to/dir         # launch in specific directory
```

**On Windows 11 (PowerShell):**

```powershell
shards install                              # install dependencies
crystal run scripts/patch_shards.cr         # patch known shard bugs
crystal build src/fff.cr -o bin/fff-cr.exe  # build fff-cr.exe
crystal spec spec/fff/                      # run unit tests
.\bin\fff-cr.exe                            # run the app
```

## Key Bindings (defaults, all configurable via `FFF_KEY_*` env vars)

| Key       | Action             | Key             | Action                         |
| --------- | ------------------ | --------------- | ------------------------------ |
| `j`/`k`   | Down/Up            | `l`/`h`         | Enter/Parent                   |
| `q`       | Quit               | `?`             | Help overlay                   |
| `/`       | Search             | `space`         | Mark file                      |
| `m`       | Mark all           | `y`             | Yank (copy)                    |
| `v`       | Cut (move)         | `p`             | Paste                          |
| `d`       | Delete (to trash)  | `n`             | New directory                  |
| `f`       | New file           | `r`             | Rename                         |
| `b`       | Bulk Rename        | `i`             | Preview (`bat`→`less`→builtin) |
| `s`       | Spawn shell        | `g` / `G`       | Top / Bottom                   |
| `↑` / `↓` | Cursor up / down   | `PgUp` / `PgDn` | Page up / down                 |
| `.`       | Toggle hidden      | `t`             | Go to trash                    |
| `x`       | Attributes         | `X`             | Toggle executable              |
| `:`       | Go to directory    | `~`             | Home directory                 |
| `-`       | Previous directory | `e`             | Refresh directory              |
| `S`       | Symlink            | `=` / `+`       | Cycle sort / Reverse           |
| `1-9`     | Favorites          |                 |                                |

In search and rename modes:
| `←` / `→` | Move cursor | `Home` / `End` | Jump start/end |
| `Backspace` | Delete before cursor | `Delete` | Delete at cursor |

## Terminal Handling

- **Search Mode**: Navigable. `j/k` work while filter is active. Typing in search mode resets the viewport scroll and page offset to `0` to keep matching results visible.
- **Search ESC Position Persistence**: Canceling search with `ESC` preserves your selection. If you navigated the search results, pressing `ESC` drops your cursor directly onto the selected item in the restored full list. If you did not navigate, it restores your pre-search scroll position.
- **Normal Mode ESC**: Pressing `ESC` in normal mode clears active search filters and marks, restoring the full directory list while keeping the cursor focused on the current item.
- **Cursor Editing**: Both search and rename modes support `←`/`→` cursor movement, `Home`/`End`, `Backspace`/`Delete`, and insert-at-cursor typing.
- **Incremental & State Redraws**: Uses dynamic `@force_full_redraw` to force clean clears only when transitioning into or out of search/rename modes. Normal state changes redraw incrementally to eliminate TUI flickering.
- **Color Caching**: Results cached by file path, cleared on directory change to prevent unbounded growth.
- **Scroll Region**: `\e[1;{max_items}r` keeps status line fixed.
- **Page Scroll**: `PgUp`/`PgDn` (`\e[5~`/`\e[6~`) scroll by one screenful. Configurable via `FFF_KEY_PAGE_UP`/`FFF_KEY_PAGE_DOWN`.
- **Arrow Key Safety**: Safe fallback lookup (`@config.key_bindings[key]? || key`) protects against unrecognized raw escape sequences raising `KeyError` crashes.
- **Hash-Table Dispatch**: `@key_handlers : Hash(String, Proc(Nil))` built once in `initialize`. `handle_key` performs single lookup: `@key_handlers[key]?.try(&.call)`. Arrow keys (`\e[A/B/C/D`) and dynamic page keys resolved at init time. `config.key_bindings` memoized via `@key_bindings_cache`.
- **Input Mismatch Resilience**: Robust matching handles both raw characters (`\e`, `\r`, `\b`) and mapped TTY names (`"escape"`, `"enter"`, `"backspace"`, `"up"`, `"down"`) to ensure 100% terminal compatibility.

## UI / UX Enhancements Architecture

### 1. RGB Truecolor Theme System

The `Theme` module provides truecolor palette styling using raw ANSI sequences (`\e[38;2;R;G;Bm` for foreground, `\e[48;2;R;G;Bm` for background).

- Modifying themes does not require changing render logic; the `UIRenderer` queries the active theme (`Config#theme`) for style classes like `Normal`, `Selection`, `Accent`, `Success`, `Warning`, etc.
- Standard Unix `LS_COLORS` syntax-highlight symbols are dynamically resolved to matching RGB colors inside `UIRenderer#colorize_by_extension`.

### 2. Nerd Font Icons

The `IconProvider` translates extension matching (e.g. `.cr`, `.json`, `.md`) and full filenames (e.g. `LICENSE`, `Makefile`) into appropriate unicode Nerd Font glyphs.

- Icon support is toggled via `FFF_ICONS=1` or the `"icons": true` JSON property.
- When active, directory items are rendered with custom folders, and files with their respective filetype icons, prefixed with custom theme coloration.

### 3. Split-Pane Preview Panel

If terminal width is sufficient (>= 80 columns) and `FFF_PREVIEW=1` is configured, `UIRenderer` splits the screen.

- Left half displays the standard navigable file listing.
- Right half displays the `PreviewPanel`. It renders directory statistics (total items, files, folders, writability status) or the preview contents of the highlighted file (first 40 lines).

### 4. Message Bus & Toast Notifications

The old `@error_msg`/`@error_expires` fields have been replaced by a dedicated `MessageBus` instance in `FileManager`.

- Allows queuing messages of varying severity: `Error` (red), `Success` (green), `Warning` (yellow), and `Info` (blue).
- Toast messages are rendered dynamically in the status area with custom symbols.
- Each message maintains an expiry timestamp and is automatically cleared on timeout.

### 5. Multi-File Action Progress Bar

Bulk copy and delete operations (5+ items) invoke the `ProgressBar` utility:

- Draws an incremental progress bar: `██████░░░░ 60% Copying (3/5) filename` directly in the prompt area.
- Executed via block-callbacks inside `FileOperations.paste_files_with_progress` and `delete_files_with_progress` to keep the UI responsive during blocking filesystem operations.

### 6. Selection Indicator & Icon Highlighting

Rather than drawing a flat, single-color selection background that overrides file type coloration, the selected line retains its native colors (e.g. green for executables, blue for directories) and displays them bolded.
- A vertical selection block indicator (`▌`) rendered in `theme.accent` is prepended to the line prefix.
- Under search queries, the fuzzy matching highlighting is active on the selected line.

### 7. Status & Topbar Badges

Critical indicators such as clipboard contents, marked files count, sort criteria, git branch, folders/files counts, and total directory size are rendered as pill-shaped colored badges.
- Badges use `Theme.fg_bg(...)` with the `theme.selection_bg` background to stand out from the default status/topbar background colors.
- Right-side layout alignment calculates lengths based on color-stripped visible characters (`right_visible_len`), avoiding cursor offsets or line wrapping.

### 8. Empty Directory Placeholder

When directory listings are empty and not in a loading state, `draw_all_lines` renders a centered, dim placeholder: `  Empty Directory / Dizin Boş`.
- Center position calculations dynamically adapt based on the left panel's current width (`list_w`).

### 9. Persistent Details Columns

File details columns (size and date) are kept visible even when a line is selected, drawing seamlessly on `theme.selection_bg`.
- `format_column` has been enhanced to accept an optional background color parameter (`bg_color`) to prevent background leakage.

## File Operations

- **Auto-Advance Navigation**: Toggling marks (`space`) automatically moves the cursor down to the next file, enabling fluid multi-file selections.
- **Bulk Actions with Progress Bar**: Pasting (`p`) or deleting (`d`) 5+ files triggers the interactive `ProgressBar` to show incremental execution metrics.

- **Bulk Rename**: Mark files → `b` → edit in `$EDITOR`.
- **Rename Abort Safety**: Safe Escape key cancellation during renames terminates the workflow cleanly without applying unintended edits.
- **Cursor Editing**: Rename mode supports cursor movement, insert-at-cursor, backspace/delete, Home/End.
- **Trash**: Moves to configurable trash dir (`FFF_TRASH` env or config.json `trash_dir`, default `~/.local/share/fff/trash`) with conflict resolution.
- **Write Checks**: Proactive `File::Info.writable?` checks before mutation.
- **Picker Mode**: `-p` flag writes selection to `~/.cache/fff/opened_file`.
- **Shell Injection Free**: All external commands use `Process.run` with argv arrays — no `system()` or backticks.

## Performance

- **LS_COLORS**: Parsed once and cached in `Config`.
- **key_bindings**: Memoized via `@key_bindings_cache` — hash built once, not per-keypress.
- **Git Branch**: Cached per directory (including non-git dirs) — `Process.run("git",...)` called only on directory change, not every frame.
- **Redraw**: Optimized double-buffered incremental drawing loop.
- **Lazy Content Search**: Live search queries only update fuzzy file list scanning. Expensive content queries (triggered via `!`) are deferred until the user presses **Enter**, preventing TUI lag and freezes while typing.
- **Recursive Tree Search Performance Guards**: Recursive tree search (`>` prefix) limits folder recursion to a depth of 5 and caps maximum results at 200 items. In addition, typing matches are not updated live; the search is deferred until the user presses **Enter** to prevent event loop blocking.
- **Fuzzy Search Scoring**: `SearchEngine.fuzzy_score` uses consecutive matching bonus (`score += consecutive * 5`) and a substring inclusion bonus (`+50`) at the end, ensuring that exact substring matches outrank distant fuzzy matches.
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

### `File.chmod` Bitwise Operations (Crystal 1.20.1)

`File.chmod(Int32, Path)` with union-type or permission bitwise OR fails at compile time. `File.chmod(String, File::Permissions)` works correctly and is used in `file_operations.cr`. Specs also use `File.chmod(path, File.info(path).permissions & ~File::Permissions::OwnerExecute)`.

### `File.executable?` Deprecated

Crystal 1.20 deprecates `File.executable?`. **Fix**: `File::Info.executable?(path)` — class method that opens and checks the bit internally.

### `Process.kill` Deprecated

`Process.kill(signal, pid)` is removed. **Fix**: `Process.signal(Signal::TERM, pid)` (and `Signal::KILL` for forceful terminations).

### `dir.entries` Double-Filtering Bug (`.`/`..` + Hidden)

`Dir.entries` returns `"."` and `".."`. If both are filtered first and `hidden_count` runs afterward, `"."` and `".."` match `starts_with?('.')` → hidden count inflated by 2. **Fix**: filter `"."` + `".."` in a single guard before `hidden_count` increment. `hidden_count` now counts both hidden files and directories that are not currently displayed.

### `FFF::HOME` Constant (nil-safe)

`ENV["HOME"]` can be nil if HOME is unset. **Fix**: `FFF::HOME = ENV["HOME"]? || Path.home.to_s rescue File.join(Dir.tempdir, "fff-#{Random::Secure.hex(16)}")` constant defined in `format_utils.cr`. All `ENV["HOME"]` usages across 4 files replaced with `FFF::HOME`.

### SearchEngine Fiber Synchronization

`content_search` spawns ripgrep in a worker fiber with a 2-second timeout fiber. Original code used `uninitialized Process` — if timeout fired before worker assigned the process, undefined behavior. **Fix**: `Channel(Process)` passes the spawned process safely from worker to timeout fiber. Timeout fiber calls `Process#wait` after SIGTERM to reap zombies.

### Lifecycle: `run` ensure block

`run` uses `rescue e : Exception` + `ensure { @term.leave_tui }` — Crystal requires `rescue` before `ensure`. The old `at_exit` hook was removed to prevent double `leave_tui`. `perform_shutdown` no longer calls `leave_tui` — the `ensure` block handles it.

### Config `key_bindings` Memoization

`def key_bindings : Hash(String, String)` was building a new Hash on every call (every keypress). **Fix**: `@key_bindings_cache : Hash(String, String)?` with `@key_bindings_cache ||= { ... }` — built once on first access.

### `make clean` Removes `bin/` Directory

`Makefile.clean` uses `rm -rf bin/` which removes the directory itself, causing `make build` linker to fail on subsequent invocation. **Workaround**: `mkdir -p bin` before `make build`.

### Build Order Matters

`make build` → new binary replaces `bin/fff` atomically. Always rebuild (`make clean` + `make build`) after renaming `property` declarations that affect layout, since incremental builds may not link correctly after struct field order changes.

### Search Mode Navigation — Mode-Specific Key Routing

Arama modunda (`/`) `j`/`k`/`↑`/`↓` tuşları text input'e değil navigasyon handler'larına yönlendirilmelidir. **Fix**: `InputMode`'da `navigating : Bool` flag eklendi; up/down search modunda `@navigating = true` yapılıyor, `FileManager.handle_input_mode` bu bayrağı yakalayıp `cursor_up`/`cursor_down` çağırıyor, `live_search` atlanıyor. `InputMode.handle_key` hala `false` döndürüyor (text input tarafı "tamamlama" olarak görmüyor).

### `draw_status` Hot-Path: Avoid `.ljust` + `[0...n]` Slice Pair

`.ljust` zaten yeni bir string kopyası üretir, sonra `[0...n]` yine yeni bir kopya üretir → her frame'de iki gereksiz allocation. **Fix**: `String.build { |s| s << left << " " * gap << right }` ile tek adımda birleştir, gap hesaplamasını doğrudan yap.

### `colorize_git_status`: Avoid `.chars.map(...).join` Anti-Pattern

`.chars.map { ... }.join` her karakter için bir Array(String) elementi oluşturur, sonra tümünü tekrar birleştirir. **Fix**: `String.build do |s| status.each_char { |c| s << colored_char } end` — per-char `String.build` ile doğrudan yaz, ara Array oluşturma.

### Crystal Macro `previous_def` in Submodules

`include` edilen modüllerde (ör. `NavigationHandlers`) `getter`/`property` macro'ları `FileManager`'ın scope'unda çalışır. Alt modülde ivar tanımlamak için `def initialize` içinde `@ivar = value` kullan — bu, üst modüldeki macro ile oluşturulan getter'ları tetikler. `@ivar = nil` tipini tetikleyerek nilability uyarısı verebilir, ancak doğruysa sorun değil.

### Crystal 1.20 `String#[]` Slice-Copy Semantics

`str[a...b]` her zaman yeni bir string kopyası üretir. Hot-path'lerde (ör. `draw_line` her karakter) bunu `String.build { |s| s << char }` ile değiştir. Tek seferlik işlerde (ESC tespit, config parsing) etkisi yoktur, scoped doğrudan içinde doğal iterasyon kullan.

### Crystal `getter` vs `property` in Test Context

Crystal'da `getter` sadece okunur, `property` okunur+yazılır. Test'lerde mock injection veya state reset için `property` kullan. `FileManager.renderer` örneği: önce `getter` idi, test'de mock renderer set edilemedi → `property`'a çevrildi.

### Windows 11 Cross-Platform Solutions

- **POSIX-Specific Signal Traps**: Traps for `Signal::TERM`, `Signal::QUIT`, and `Signal::WINCH` are conditionally compiled using `{% unless flag?(:windows) %}`.
- **Process Terminate**: In search engine timeouts, `Process#terminate` is called on Windows instead of sending raw `Signal::TERM` signals to other process PIDs.
- **Opener & Shell Dynamic Resolution**: On Windows, system opener defaults to `explorer` and the TUI shell spawn defaults to `COMSPEC` or `powershell.exe` rather than executing Unix commands (`uname`, `bash`).
- **Writable Directory and Executable Checks**: POSIX permission checks and executable toggles are bypassed on Windows using platform macros, returning clean error or fallback messages.

### Test Infrastructure on Windows (Case-Sensitivity & Redirected TTY Size)

- **Case-Insensitive Paths**: Windows is case-insensitive, which means drive letter differences (`C:` vs `c:`) cause `Dir.current.starts_with?(temp_dir)` checks to fail. Path comparisons in `spec_helper.cr` are now downcased to avoid directory locks.
- **Dir.tempdir Cleanup**: Replaced Unix-hardcoded `/tmp` with `Dir.tempdir` to support proper workspace cleanup across platforms.
- **Windows Glob Backslash Escape**: Backslashes in path combinations behave as glob escape characters. Glob queries in specs are normalized using `.gsub('\\', '/')`.
- **term-screen non-TTY buffer overflow**: In spec runs, stdout is redirected to non-TTY pipes, causing Win32 `GetConsoleScreenBufferInfo` to fail and return uninitialized coordinates. The `term-screen` library has been patched to check the Win32 API return code to avoid arithmetic overflow crashes.

## Inline Confirm Pattern (TUI içi y/n onayı)

Confirm/yes-no soruları TUI ekranından çıkmadan, ekranın en altına sarı renkli `[y/N]` prompt'u çizilerek gerçekleştirilir. `with_tui_restored` (TUI'dan çık → ana ekrana dön → prompt → TUI'ya geri dön → full redraw) yerine `confirm_inline` kullanılır:

```crystal
def confirm_inline(message : String) : Bool
  row = @height - 2
  move_to(row, 0)
  print "\e[K"
  print Term::Color.truecolor_string("#{message} [y/N] ", fore: :yellow, back: :blue)
  STDOUT.flush
  loop do
    key = @reader.read_keypress(raw: false) rescue nil
    case key
    when "y", "Y" then clear_prompt(row); return true
    when "n", "N", "\e", nil then clear_prompt(row); return false
    end
  end
end
```

- Prompt, TUI durumunu korur, ekran tamamen silinmez
- `\e[K]` ile satır temizlenir, geri dönerken boş satır bırakılmaz

## Prompt Inline Pattern (TUI içi text input)

`ask` (term-prompt tabanlı, TUI'dan çıkar) yerine `prompt_inline` kullanılır. TUI'dan çıkmadan en altına sarı prompt çizer, kullanıcı girdisini alır:

```crystal
def prompt_inline(message : String, default : String? = nil) : String?
  # default: kullanıcı boş geçerse döndürülecek değer
  # ← → Home End Backspace Delete Esc desteklenir
  # nil → iptal, String? → giriş veya default
end
```

- `Esc` → `nil` döndürür (iptal)
- `Enter` boş → `default` döndürür, dolu → girilen değeri döndürür
- Arrow keys: `←`/`→` cursor hareketi, `Home`/`End` uçtan uca
- Kullanılan handler'lar: `new_file`, `new_directory`, `rename_item`, `go_to_dir`

Mock test'leri için `MockTerminal`'da `prompt_inline` override edilmelidir — `@answer_queue`'dan cevap çeker, boşsa `nil` döndürür.
