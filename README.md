# FFF — Fucking Fast File Manager

[![Crystal](https://img.shields.io/badge/Crystal-1.20.1-000?labelColor=eee&logo=crystal)](https://crystal-lang.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A terminal-based file manager written in **Crystal**. Ported from the original Bash version for performance, safety, and maintainability.

## Features

- **Fast**: `LS_COLORS` caching, optimized incremental render loop, no flicker
- **Navigable Search**: Fuzzy filename filtering + ripgrep content search (`!` prefix), all while keeping cursor navigation live. `←`/`→` to move within the search query, `Backspace`/`Delete` to edit.
- **Inline Prompts**: New file/directory, rename, and go-to-dir inputs stay inside the TUI — no full-screen dialog pop-out.
- **Inline Confirm**: Delete and permission-toggle confirmations stay inside the TUI with a `[y/N]` prompt at the bottom.
- **File Operations**: Copy, move, delete (trash), rename, bulk rename, symlink
- **Smart Preview**: `bat` → `less` → builtin fallback chain; file attributes via `File::Info`/`stat`
- **Picker Mode**: `-p` flag writes selection to `~/.cache/fff/opened_file` for external tool integration
- **Secure**: All external commands via `Process.run` (no shell injection), pre-operation writability checks
- **Customizable**: Full keybinding control via environment variables or `~/.config/fff/config.json`

## Installation

### Requirements

- Crystal 1.20.1+
- Linux or macOS terminal (with true-color support recommended)

### Build

```bash
make deps       # install shards
make build      # release build → bin/fff
make debug      # debug build (faster compile)
make run        # build + run
make test       # run test suite

# Optional: system-wide install (including man page)
sudo make install
```

## Usage

```bash
fff                    # open current directory
fff /path/to/dir       # open specific directory
fff -p                 # picker mode (writes to opened_file cache)
```

### Key Bindings

| Key | Action | Key | Action |
|---|---|---|---|
| `j`/`k` | Down/Up | `l`/`h` | Enter/Parent |
| `q` | Quit | `?` | Help overlay |
| `/` | Search (Navigable) | `space` | Mark |
| `m` | Mark all | `y`/`v` | Copy/Cut |
| `p` | Paste | `d` | Delete (trash) |
| `t` | Go to trash | `n` | New dir |
| `f` | New file | `r` | Rename |
| `b` | Bulk rename | `i` | Preview |
| `x` | Attributes | `X` | Toggle executable |
| `s` | Spawn shell | `g`/`G` | Top/Bottom |
| `↑`/`↓` | Cursor | `PgUp`/`PgDn` | Page up/down |
| `.` | Toggle hidden | `~` | Home |
| `-` | Previous dir | `e` | Refresh |
| `=` / `+` | Cycle sort / Reverse | `:` | Go to dir |
| `S` | Symlink | `1-9` | Favorites |

In search and rename modes, `←`/`→` move within the input text, `Backspace`/`Delete` edit, `Home`/`End` jump to start/end.

All bindings are configurable via `FFF_KEY_*` environment variables.

## Configuration

fff reads from environment variables first, then falls back to `~/.config/fff/config.json`.

### Key variables

```bash
export FFF_OPENER="xdg-open"              # file opener
export FFF_FAV1="$HOME/Documents"         # favorite dirs 1-9
export FFF_CD_ON_EXIT="1"                 # save cwd on exit
export FFF_TRASH="$HOME/.local/share/fff/trash"
```

Full list of `FFF_KEY_*` variables: `UP`, `DOWN`, `ENTER`, `QUIT`, `SEARCH`, `PARENT`, `MARK`, `MARK_ALL`, `COPY`, `MOVE`, `PASTE`, `DELETE`, `NEW_DIR`, `MKFILE`, `RENAME`, `BULK_RENAME`, `PREVIEW`, `SHELL`, `HIDDEN`, `HOME`, `PREVIOUS`, `REFRESH`, `ATTRIBUTES`, `EXECUTABLE`, `GO_DIR`, `GO_TRASH`, `SYMLINK`, `TOP`, `BOTTOM`, `PAGE_UP`, `PAGE_DOWN`.

```json
{
  "editor": "vim",
  "opener": "xdg-open",
  "trash_dir": "/path/to/trash",
  "favorites": { "1": "/home/user/Documents" },
  "keys": { "up": "k", "down": "j" },
  "bookmarks": { "proj": "/home/user/projects" }
}
```

## Preview

Press `i` to preview a file. The preview chain tries:

1. `bat --paging=always` — syntax-highlighted, scrollable
2. `less` — paged, searchable
3. Built-in — plain text with full scroll support

Directories always use the built-in preview.

## Project Structure

```
.
├── bin/fff                  # compiled binary
├── man/fff.1                # man page
├── src/
│   ├── fff.cr               # entry point
│   └── fff/
│       ├── config.cr
│       ├── directory_manager.cr
│       ├── draw_state.cr
│       ├── file_manager.cr
│       ├── file_op_handlers.cr
│       ├── file_operations.cr
│       ├── file_service.cr
│       ├── format_utils.cr
│       ├── input_mode.cr
│       ├── navigation_handlers.cr
│       ├── search_engine.cr
│       ├── terminal.cr
│       ├── ui_renderer.cr
│       └── view_handlers.cr
├── spec/                    # test suite
│   ├── spec_helper.cr
│   ├── fff/
│   └── integration/
├── Makefile
├── shard.yml
├── .ameba.yml               # linter config
└── LICENSE
```

## Architecture

- **FFF::Application** — CLI argument parsing, terminal setup
- **FFF::Config** — env var & JSON config management, `LS_COLORS` parsing
- **FFF::DirectoryManager** — directory reading, sorting, hidden-file filtering
- **FFF::DrawState** — bundles all redraw parameters into one struct
- **FFF::FileManager** — event loop and TUI router; includes `NavigationHandlers`, `FileOpHandlers`, `ViewHandlers`
- **FFF::FileOperations** — file/directory creation, deletion, copying
- **FFF::FileService** — low-level `copy`/`move`/`trash`/`symlink` with writability checks
- **FFF::InputMode** — search/rename text input with cursor control and editing
- **FFF::SearchEngine** — fuzzy filename matching + ripgrep content search
- **FFF::Terminal** — `crystal-term` shard wrapper
- **FFF::UIRenderer** — incremental, flicker-free drawing
- **FFF::FormatUtils** — shared helpers (`human_size`)

## Development

```bash
make test       # run all specs
make format     # crystal tool format
make lint       # ameba static analysis
```

### Running Tests

```bash
make test           # all specs
crystal spec spec/integration/navigation_integration_spec.cr
crystal spec spec/integration/advanced_integration_spec.cr
```

#### Test Architecture
- **91 unit tests** across 6 modules (config, directory_manager, file_service, input_mode, search_engine, ui_renderer)
- **40 integration tests** across 2 suites (navigation: 30, advanced: 10) — use `MockTerminal` to simulate keyboard input and prompts without a real TTY
- Both specs run headless; no terminal or display required

### Patches

The project patches several `crystal-term` shard bugs in `lib/` after `shards install`. See `AGENTS.md` for details.

## License

MIT. See [LICENSE](LICENSE).
