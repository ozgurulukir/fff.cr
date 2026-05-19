# AGENTS.md

## Project Overview

**fff** (Fucking Fast File Manager) — a terminal-based file manager, originally written in Bash (~1,146 lines), ported to Crystal on the `crystal-port` branch.

- **Language**: Crystal 1.20.1
- **Source**: single file `src/fff.cr` (~688 lines)
- **Branch**: `crystal-port` (Bash source preserved on `master` as `fff`)
- **Build**: `make build` or `crystal build src/fff.cr --release -o bin/fff`

## Architecture

```
src/fff.cr          # Entire application (single file)
  FFF::Application  # CLI entry point (--version, --help, start_dir)
  FFF::Config       # Environment variable configuration
  FFF::Terminal     # Terminal I/O wrapper (cursor, screen, reader, prompt)
  FFF::FileManager  # Core: event loop, drawing, navigation, file ops
```

No separate modules or files. All state lives in `FileManager` instance vars.

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
- **Error**: `IO::FileDescriptor#sync=` expects `Bool`, gets `Bool | Nil`
- **Fix**: change `@output.as(IO::FileDescriptor).sync = buffering` to `@output.as(IO::FileDescriptor).sync = buffering || false`

### 2. `term-prompt` — `Regex.escape` type mismatch
- **File**: `lib/term-prompt/src/prompt/confirm_question.cr:95`
- **Error**: `Regex.escape` expects `String`, gets `Char`
- **Fix**: change `positive.to_s[0]` to `positive.to_s[0].to_s`

### 3. `term-cursor` — `move_to` swaps row/col
- **File**: `lib/term-cursor/src/term-cursor.cr` (the `move_to` method)
- **Bug**: `move_to(row, col)` generates `\e[col+1;row+1H` — parameters are swapped in the ANSI output
- **Workaround**: use raw ANSI `\e[row;colH` directly instead of the shard method

### 4. `term-reader` — `Mode#raw` inverted semantics
- **File**: `lib/term-reader/src/reader/mode.cr`
- **Bug**: `raw: true` means "don't change mode" (just yields), `raw: false` means "enter raw mode" (calls `@input.raw`)
- **Workaround**: call `read_keypress(raw: false)` to actually get raw mode

## Build & Run

```bash
shards install                    # install dependencies
make build                        # release build → bin/fff
make debug                        # debug build (faster compile, no optimizations)
make run                          # build + run
./bin/fff                         # launch in current directory
./bin/fff /path/to/dir            # launch in specific directory
./bin/fff --version               # print version
./bin/fff --help                  # print help
```

## Key Bindings (defaults, all configurable via `FFF_KEY_*` env vars)

| Key | Action | Key | Action |
|---|---|---|---|
| `j` | Down | `k` | Up |
| `l` | Enter dir / open file | `h` | Parent dir |
| `q` | Quit | `/` | Search |
| `space` | Mark file | `m` | Mark all |
| `y` | Yank (copy) | `v` | Cut (move) |
| `p` | Paste | `d` | Delete |
| `n` | New directory | `r` | Rename |
| `i` | Preview file | `s` | Spawn shell |
| `g` | Go to top | `G` | Go to bottom |
| `↑` | Page up | `↓` | Page down |

## Terminal Handling

The app uses alternate screen buffer (`\e[?1049h`/`\e[?1049l`) so the TUI doesn't destroy shell history.

**Flow**:
1. `enter_tui` — hide cursor, switch to alt screen, clear
2. Event loop: `redraw` → `read_keypress` → `handle_key` → repeat
3. For dialogs (search, rename, delete confirm): `leave_tui` → use `term-prompt` → `enter_tui`
4. `quit` — `leave_tui`, optionally save cwd to `$FFF_CD_FILE`

**Cursor positioning**: raw ANSI `\e[row;colH` (1-indexed internally, methods accept 0-indexed).

## File Operations

- **Copy/Move**: mark files → `y` (copy) or `v` (cut) → navigate to target → `p` (paste)
- **Delete**: mark files → `d` → confirmation via `term-prompt`
- **Rename**: `r` on a file → `term-prompt` ask dialog
- **New dir**: `n` → `term-prompt` ask dialog
- **Shell**: `s` → `leave_tui` → `Process.run($SHELL)` → `enter_tui` on exit

## Environment Variables

All `FFF_KEY_*` vars override keybindings. Other vars:

| Variable | Default | Purpose |
|---|---|---|
| `FFF_OPENER` | `xdg-open` | Command to open files |
| `FFF_TRASH` | `~/.local/share/fff/trash` | Trash directory |
| `FFF_CD_ON_EXIT` | unset | Set to `1` to save last dir on exit |
| `FFF_CD_FILE` | `~/.cache/fff/.fff_d` | File to save last directory |
| `FFF_DEBUG` | unset | Set to `1` for backtrace on crash |

## Testing

```bash
make test     # crystal spec (no specs yet)
```

No test suite exists yet. Manual testing only.

## Common Pitfalls

- **After `shards install`**: re-apply the two lib patches (term-reader sync bug, term-prompt Regex bug)
- **`Term::Cursor` methods return strings**: always `print` the result, never call without printing
- **`Term::Cursor.move_to` swaps params**: use raw ANSI instead
- **`read_keypress(raw: false)`**: the `raw:` flag has inverted semantics in term-reader
- **`File.executable?` is deprecated**: use `File.info(path).permissions.includes?(File::Permissions::OtherExecute)`
- **Alternate screen buffer**: TUI output won't appear in shell scrollback — that's intentional
