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
  draw_state.cr     # DrawState struct — bundles 16 render params into one object
  file_manager.cr   # Core coordinator: event loop & high-level TUI router (~322 lines)
  file_op_handlers.cr# Extracted file operation methods (included by FileManager)
  file_operations.cr# Specialized file/directory creation and operations
  file_service.cr   # Low-level filesystem helpers with writability checks
  format_utils.cr   # Shared utilities (human_size) used across modules
  input_mode.cr     # Event controller for search/rename keystrokes and escape handling
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
- **File**: `lib/term-reader/src/term-reader.cr:154-158`
- **Bug**: `condition` lambda matches `\[27\]` (standalone ESC) against all escape code prefixes, entering an unnecessary nonblocking read loop. The nonblocking read can hang or return stale data.
- **Fix**: wrap condition body in `codes.last != 27 && (...)` so ESC byte immediately terminates reading.

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
| `q` | Quit | `/` | Search (Navigable) |
| `space` | Mark file | `m` | Mark all |
| `y` | Yank (copy) | `v` | Cut (move) |
| `p` | Paste | `d` | Delete (to trash) |
| `n` | New directory | `f` | New file |
| `r` | Rename | `b` | Bulk Rename |
| `i` | Preview (`bat`→`less`→builtin) | `s` | Spawn shell |
| `g` / `G` | Top / Bottom | `↑` / `↓` | Cursor up / down |
| `.` | Toggle hidden | `t` | Go to trash |
| `x` | Attributes | `X` | Toggle executable |
| `:` | Go to directory | `~` | Home directory |
| `-` | Previous directory| `e` | Refresh directory |
| `S` | Symlink | `=` / `+` | Cycle sort / Reverse |
| `1-9` | Favorites | | |

## Terminal Handling

- **Search Mode**: Navigable. `j/k` work while filter is active.
- **Incremental & State Redraws**: Uses dynamic `@force_full_redraw` to force clean clears only when transitioning into or out of search/rename modes. Normal state changes redraw incrementally to eliminate TUI flickering.
- **Color Caching**: Results cached by file path only (removed stale width dependency).
- **Scroll Region**: `\e[1;{max_items}r` keeps status line fixed.
- **Page Scroll**: `PgUp`/`PgDn` (`\e[5~`/`\e[6~`) scroll by one screenful. Configurable via `FFF_KEY_PAGE_UP`/`FFF_KEY_PAGE_DOWN`.
- **Arrow Key Safety**: Safe fallback lookup (`@config.key_bindings[key]? || key`) protects against unrecognized raw escape sequences raising `KeyError` crashes.
- **Input Mismatch Resilience**: Robust matching handles both raw characters (`\e`, `\r`, `\b`) and mapped TTY names (`"escape"`, `"enter"`, `"backspace"`, `"up"`, `"down"`) to ensure 100% terminal compatibility.

## File Operations

- **Bulk Rename**: Mark files → `b` → edit in `$EDITOR`.
- **Rename Abort Safety**: Safe Escape key cancellation during renames terminates the workflow cleanly without applying unintended edits.
- **Trash**: Moves to `~/.local/share/fff/trash` with conflict resolution.
- **Write Checks**: Proactive `File::Info.writable?` checks before mutation.
- **Picker Mode**: `-p` flag writes selection to `~/.cache/fff/opened_file`.
- **Shell Injection Free**: All external commands use `Process.run` with argv arrays — no `system()` or backticks.

## Performance

- **LS_COLORS**: Parsed once and cached in `Config`.
- **Redraw**: Optimized double-buffered incremental drawing loop.
- **Lazy Content Search**: Live search queries only update fuzzy file list scanning. Expensive content queries (triggered via `!`) are deferred until the user presses **Enter**, preventing TUI lag and freezes while typing.

