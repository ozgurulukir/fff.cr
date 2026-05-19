# FFF Crystal Port - Improvement Plan

## Phase 1: Stability & Correctness

### 1.1 Signal handling
- Trap `SIGINT`, `SIGTERM`, `SIGQUIT` → `leave_tui` + exit
- Trap `SIGWINCH` → refresh terminal size + redraw
- Ensure `leave_tui` runs on any exit path (at_exit hook)

### 1.2 Terminal resize
- `SIGWINCH` handler calls `@term.refresh_size` + `redraw`
- Clamp `@scroll` and `@page_offset` after resize
- Currently resize corrupts the display silently

### 1.3 Restore cursor position on parent navigation
- Track `OLDPWD` equivalent: when entering a child dir, store its name
- On `go_parent`, find that child in the parent listing and set `@scroll` to its index
- Bash does this via `find_previous` / `previous_index`

### 1.4 Empty directory indicator
- When `@list` is empty, show "(empty)" placeholder
- Prevents crash on operations that assume `@list[@scroll]?` exists

### 1.5 Write permission checks
- Before paste: check `File.writable?(Dir.current)`
- Before rename: check `File.writable?(old_path)`
- Before mkdir: check `File.writable?(Dir.current)`
- Before delete: check `File.writable?(path)` for each target
- Show error instead of letting `FileUtils` raise

### 1.6 Duplicate name checks
- Before rename: warn if target name already exists
- Before mkdir: warn if directory already exists
- Before mkfile: warn if file already exists

## Phase 2: Remove Slop

### 2.1 Remove unused methods
- `Terminal#clear_line` — never called
- `Terminal#flush` — replace 3 call sites with `STDOUT.flush`, inline into `enter_tui`/`leave_tui`/`redraw`
- `Terminal#clear` — inline into `redraw`
- `list_total` — replace with `@list.size` at all call sites

### 2.2 Remove unused config fields
- `@editor` — not used anywhere (will be used in Phase 4 when text file opening is added, so keep but document)
- `@trash_dir` — currently unused (will be used in Phase 3 trash feature, so keep but document)

### 2.3 Fix `ensure_dirs`
- Only create `cache/fff` dir when `cd_on_exit` is true
- Only create trash dir when trash feature is actually used
- Don't create dirs on every startup unconditionally

## Phase 3: Missing Bash Features (High Priority)

### 3.1 Hidden files toggle
- New key: `.` (configurable via `FFF_KEY_HIDDEN`)
- Toggle instance var `@show_hidden : Bool`
- `read_directory` filters or includes dotfiles based on flag
- Default: hidden (matching Bash default `FFF_HIDDEN=0`)

### 3.2 Trash instead of permanent delete
- `d` key moves to trash dir instead of `rm_rf`
- Implement `trash()` method: hardlink copy to trash, then remove original
- Fallback to `mv` if hardlink fails (cross-device)
- New key `t` to navigate to trash dir
- Support `FFF_TRASH_CMD` env var for custom trash command

### 3.3 Text files open in EDITOR
- On `enter_item` for files: detect MIME type
- If `text/*` or empty or JSON: open in `$EDITOR`
- Otherwise: open with `$FFF_OPENER`
- This is how Bash version works — currently Crystal opens everything with OPENER

### 3.4 Symlink creation
- New key: configurable, default `s` (move current shell spawn to another key)
- Mark files → press symlink key → creates `ln -s` in current dir
- Shell spawn moves to `!` key (matching Bash default)

### 3.5 Quick navigation keys
- `~` : go to `$HOME`
- `-` : go to previous dir (`OLDPWD`)
- `e` : refresh current directory
- `1`-`9` : go to favorite dir (`FFF_FAV1`..`FFF_FAV9`)

### 3.6 File creation
- New key: `f` (configurable via `FFF_KEY_MKFILE`)
- Creates empty file: `File.touch(path)`

### 3.7 File attributes view
- New key: `x` (configurable via `FFF_KEY_ATTRIBUTES`)
- Show `stat` output for selected file
- Wait for keypress, then return to TUI

### 3.8 Executable toggle
- New key: `X` (configurable via `FFF_KEY_EXECUTABLE`)
- Toggle `+x` / `-x` on selected file
- Only works on regular files with write permission

### 3.9 Bulk rename
- New key: `b` (configurable via `FFF_KEY_BULK_RENAME`)
- Write marked file names to temp file
- Open in `$EDITOR`
- Parse changes, generate `mv` commands
- Show commands for review, then execute

## Phase 4: TUI Improvements

### 4.1 Incremental redraw
- Current: `redraw` clears entire screen and redraws everything on every keypress
- Target: only redraw changed lines (like Bash's `print_line` approach)
- On single cursor move: clear old line, draw new line, update status
- On page scroll: only redraw visible area
- Massive performance improvement for large directories

### 4.2 In-TUI search (live filtering) ✅ DONE
- ✅ Implemented: draws `/` prompt on status line, filters list on each keystroke
- ✅ Custom key reading loop during search mode
- ✅ ESC/Enter cancels/accepts, Backspace deletes
- ✅ Case-insensitive search by file basename
- Original issue: `leave_tui` → `ask` → `enter_tui` (leaves alternate screen)

### 4.3 In-TUI rename ✅ DONE
- ✅ Implemented: draws prompt, shows current name, allows inline editing
- ✅ Custom key reading loop, no leave_tui
- ✅ ESC/Enter cancels/accepts, Backspace deletes
- Original plan: same approach as search, draw prompt on last line

### 4.4 In-TUI command line
- General-purpose single-line input at bottom of screen
- Used by: search, rename, mkdir, mkfile, go-to-dir
- Tab completion for paths
- ESC to cancel

### 4.5 Scroll region ✅ DONE
- ✅ Implemented: `\e[1;{max_items}r` in `enter_tui`
- ✅ Status line stays fixed at bottom during file list scroll

### 4.6 Window title ✅ DONE
- ✅ Implemented: `\e]2;fff: #{cwd}\e\\` in `enter_tui` and `read_directory`
- ✅ Updates on directory change

### 4.7 Multiple key bindings per action
- Bash supports `CHILD1..4`, `PARENT1..5` etc.
- Allow comma-separated keys in env vars: `FFF_KEY_ENTER=l,\e[C,`
- Or separate vars: `FFF_KEY_ENTER1=l`, `FFF_KEY_ENTER2=\e[C`

### 4.8 LS_COLORS support ✅ DONE
- ✅ Implemented: parse `LS_COLORS` env var in Config#parse_ls_colors
- ✅ Color files by extension (`.cr` → one color, `.md` → another)
- ✅ Fallback to current simple color scheme if `LS_COLORS` is empty

## Phase 5: Code Quality

### 5.1 Error display ✅ DONE
- ✅ Implemented: show error on status line, clear on next keypress
- ✅ Non-blocking, no forced wait
- ✅ Uses @error_msg and @error_expires (2 second timeout)

### 5.2 `human_size` precision ✅ DONE
- ✅ Implemented: show one decimal place (e.g., `1.5M`)
- ✅ Trailing zeros stripped: `1.0M` → `1M`

### 5.3 Color caching ✅ DONE
- ✅ Implemented: @color_cache Hash(Tuple(String, Symbol), String)
- ✅ Caches Term::Color.truecolor_string results by (label, color) tuple
- ✅ Avoids repeated color computations per redraw

### 5.4 FFF_LEVEL tracking ✅ DONE
- ✅ Implemented: export FFF_LEVEL env var at startup
- ✅ Increment on shell spawn, decrement on shell exit
- ✅ Allows shell config to detect fff nesting

### 5.5 File picker mode
- `-p` flag: on file open, write path to `~/.cache/fff/opened_file` and exit
- Enables using fff as a file picker in other tools (vim, etc.)

### 5.6 OS detection
- Detect macOS: use `open` instead of `xdg-open`
- Detect Haiku: use `trash` command
- Simple `case` on `uname` output

## Phase 6: Testing

### 6.1 Unit tests
- `Config`: env var parsing, defaults
- `human_size`: byte formatting
- `adjust_page_offset`: scroll math
- `marked_or_current`: selection logic
- `read_directory`: file listing and sorting

### 6.2 Integration tests
- Launch with piped input, verify output
- Test key sequences: navigate, mark, quit
- Test edge cases: empty dir, single file, permission denied

## Implementation Order

```
Phase 1  →  Phase 2  →  Phase 4.1  →  Phase 3  →  Phase 4  →  Phase 5  →  Phase 6
stability    cleanup     perf          features     TUI         quality     tests
```

Phase 1 and 2 are non-negotiable — fix what's broken, remove what's unused.
Phase 4.1 (incremental redraw) before Phase 3 because adding features to a full-redraw loop makes performance worse.
Phase 3 features can be implemented in any order after that.
Phase 4.2-4.8 (in-TUI dialogs) can be done incrementally alongside Phase 3.
Phase 5 and 6 are ongoing.
