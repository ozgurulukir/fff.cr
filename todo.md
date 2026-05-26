# todo.md — fff File Manager

## BFG Score: 95/100 after session fixes (Dep=100 · Coup=95 · Cog=95 · Arch=100 · Test=95 · Qual=77)

---

## 🔴 CRITICAL — Race Conditions / Data Corruption

### FIND-1 ✅ DONE | SearchEngine: uninitialized Process race on timeout
- **File:** `src/fff/search_engine.cr:59,87`
- **Claim:** `the_proc = uninitialized Process` is assigned in worker fiber, but timeout fiber reads `the_proc.pid` at line 87. If timeout fires before worker sets `the_proc`, undefined behavior.
- **Verify:** `grep -n 'uninitialized Process\|the_proc' src/fff/search_engine.cr` — confirmed at lines 59,65,87.
- **Act:** Use `Channel(Process)` to pass spawned process from worker to timeout fiber. Timeout fiber only signals kill after receiving the Process object.
- **Status:** ✅ Done — `proc_chan = Channel(Process).new(1)`, timeout fiber waits for process via channel.

### FIND-2 ✅ DONE | SearchEngine: pipe leak + zombie process on timeout
- **File:** `src/fff/search_engine.cr:64-80`
- **Claim:** When timeout fiber closes `pipe_rd`/`pipe_err_rd`, worker may be mid-IO. Process is killed but never reaped (`wait`). Zombie accumulates.
- **Verify:** `grep -n 'Process.signal\|pipe_rd\|pipe_wr' src/fff/search_engine.cr` — confirmed at lines 69-70,87-89.
- **Act:** Add `Process#wait` call in timeout fiber after SIGTERM. Close write-end pipes in timeout too. Add `ensure { the_proc.wait rescue nil }`.
- **Status:** ✅ Done — timeout fiber calls `the_proc.wait rescue nil` after SIGTERM.

---

## 🟠 HIGH — Bugs / Crashes

### FIND-4 ✅ DONE | FFF_LEVEL non-numeric crash
- **File:** `src/fff/file_manager.cr:84`
- **Claim:** `ENV["FFF_LEVEL"]?.try(&.to_i)` raises `ArgumentError` if env var contains non-numeric.
- **Verify:** `grep -n 'FFF_LEVEL' src/fff/file_manager.cr` — line 84: `.to_i` (not `.to_i?`).
- **Act:** Change `.to_i` → `.to_i?` with fallback `0`.
- **Status:** ✅ Done — `.to_i?` applied.

### FIND-5 ✅ DONE | STDIN.raw blocks forever on non-TTY
- **File:** `src/fff/view_handlers.cr:57,75`
- **Claim:** `STDIN.raw(&.read_char)` in `builtin_preview` and `show_attributes` blocks indefinitely if stdin is piped.
- **Verify:** `grep -n 'STDIN.raw' src/fff/view_handlers.cr` — confirmed at lines 57,75.
- **Act:** Guard with `STDIN.tty?` check — if not TTY, skip keypress wait or use a timed read.
- **Status:** ✅ Done — `STDIN.raw(&.read_char) if STDIN.tty?` in both methods.

### FIND-7 ✅ DONE | Double leave_tui on exception
- **File:** `src/fff/file_manager.cr:160,168,323`
- **Claim:** `at_exit { @term.leave_tui if @running }` (line 160) runs on exception. But `run` rescue also calls `leave_tui` (line 168), then `perform_shutdown` also calls it (line 323). If exception occurs after `quit` sets `@running=false`, at_exit skips. If exception occurs *before*, both fire.
- **Verify:** `grep -n 'leave_tui' src/fff/file_manager.cr` — lines 160,168,323,413.
- **Act:** Remove `at_exit` hook. Instead, ensure `run` always calls `leave_tui` in its rescue/ensure block. Add `@term_entered` flag to prevent double-entry.
- **Status:** ✅ Done — removed `at_exit`, added `ensure { @term.leave_tui }` in `run`. `perform_shutdown` no longer calls `leave_tui`.

### FIND-9 ✅ DONE | delete_files ignores config.trash_dir
- **File:** `src/fff/file_op_handlers.cr:134`
- **Claim:** Hardcodes trash path instead of using `@config.trash_dir`. Users who set `FFF_TRASH` env or config.json `trash_dir` are ignored.
- **Verify:** `grep -n 'trash' src/fff/file_op_handlers.cr` — line 134: `File.join(ENV["HOME"], ".local", "share", "fff", "trash")`.
- **Act:** Change to `@config.trash_dir`. Same fix in `navigation_handlers.cr:95`.
- **Status:** ✅ Done — both files use `@config.trash_dir`.

### FIND-11 ✅ DONE | Git check runs every frame in non-repo directories
- **File:** `src/fff/file_manager.cr:231-253`
- **Claim:** When `git rev-parse` fails, `@git_dir_cache = ""` resets the cache (line 248). Next `redraw` call runs `git` again. In non-git directories, `Process.run("git",...)` executes every keypress.
- **Verify:** `grep -n 'git_dir_cache' src/fff/file_manager.cr` — line 248 clears on failure.
- **Act:** Set `@git_dir_cache = dir` even on failure (cache the miss). Add `@git_available : Bool?` flag, or just keep the cache set.
- **Status:** ✅ Done — removed `@git_dir_cache = ""` from the failure branch. Non-git dirs are cached.

---

## 🟡 MEDIUM — Reliability / UX

### FIND-8 ✅ DONE | Predictable temp file path in bulk_rename
- **File:** `src/fff/file_operations.cr:137`
- **Claim:** `"/tmp/fff_bulk_rename_#{Process.pid}.txt"` is predictable. Container PID reuse can cause collision.
- **Verify:** `grep -n 'temp_file' src/fff/file_operations.cr` — line 137.
- **Act:** Use `File.tempfile("fff_bulk_rename")` or add random suffix: `#{Process.pid}_#{Random.rand(99999)}.txt`.
- **Status:** ✅ Done — `Dir.tempdir/fff_bulk_rename_#{pid}_#{random}.txt`.

### FIND-10 ✅ DONE | go_prev doesn't reset prev_dir/prev_child
- **File:** `src/fff/navigation_handlers.cr:65-71`
- **Claim:** After pressing `-` (go_prev), `@prev_dir` and `@prev_child` are not cleared. Pressing `-` again navigates to the same directory repeatedly instead of being a no-op or going further back.
- **Verify:** `grep -n 'prev_dir\|prev_child' src/fff/navigation_handlers.cr` — lines 51,65,67,68 — no assignment clearing them.
- **Act:** After successful `go_prev`, save current dir as new `@prev_dir` and clear `@prev_child` (or build a directory history stack).
- **Status:** ✅ Done — `@prev_child = nil` after go_prev, `@prev_dir` set to old prev.

### FIND-12 ✅ DONE | ENV["HOME"] nil crash (multiple locations)
- **Files:** `config.cr:87,100,102`, `file_manager.cr:176,465,473`, `file_op_handlers.cr:134`, `navigation_handlers.cr:95`
- **Claim:** `ENV["HOME"]` can be nil if HOME is unset. `File.join(nil, ...)` raises compile error or `NilAssertionError` at runtime.
- **Verify:** 8 occurrences of `ENV["HOME"]` without nil guard across 4 files.
- **Act:** Add `HOME = ENV["HOME"]? || "/tmp"` constant in Config or a utility module. Use it everywhere.
- **Status:** ✅ Done — `FFF::HOME` constant in `format_utils.cr`. All 8 occurrences replaced.

### FIND-15 | Status line ANSI truncation corruption
- **File:** `src/fff/ui_renderer.cr:199-202`
- **Claim:** `draw_status` builds `right` with ANSI escapes (colorize_git_status), then calculates `left.size` as visible width but `right` string includes invisible ANSI bytes. `gap` calculation is wrong — status line overflows or truncates mid-escape.
- **Verify:** `grep -n 'line\[0\.\.\.@term.width\]' src/fff/ui_renderer.cr` — line 202 slices with ANSI bytes inside.
- **Act:** Calculate visible width of `right` (strip ANSI for measurement), or build `right` without ANSI for width math, then substitute the colored version.

---

## 🟢 LOW — Code Quality / Minor

### FIND-3 ✅ DONE | hidden_count excludes hidden directories
- **File:** `src/fff/directory_manager.cr:51`
- **Claim:** `@hidden_count` only incremented for files (in `else` branch). Hidden dirs like `.git` not counted. UX shows "(N hidden)" but N is only files.
- **Verify:** `grep -n 'hidden_count' src/fff/directory_manager.cr` — line 51 inside `else` (files-only branch).
- **Act:** Move `@hidden_count += 1 if entry.starts_with?('.')` before the `if File.directory?` check, or increment in both branches.
- **Status:** ✅ Done — `@hidden_count += 1 if !@show_hidden && entry.starts_with?('.')` moved before `next` guard. Test updated.

### FIND-6 ✅ DONE | Backtick shell execution in default_opener
- **File:** `src/fff/config.cr:151`
- **Claim:** `case \`uname\`.strip` uses shell backtick execution, contradicting the security posture (all external commands should use `Process.run`).
- **Verify:** `grep -n 'uname' src/fff/config.cr` — line 151: backtick usage confirmed.
- **Act:** Replace with `Process.run("uname", output: output).to_s.strip`.
- **Status:** ✅ Done — backtick replaced with `Process.run("uname", output: output)`.

### FIND-13 ✅ DONE | prompt_inline nil semantics confusion
- **File:** `src/fff/terminal.cr:136,148`
- **Claim:** `text = default.to_s` converts nil to "", but `return text.empty? ? default : text` returns original `nil` (not ""). Inconsistent: caller can't distinguish "user pressed Enter on empty" from "user pressed Esc".
- **Verify:** Lines 136,148 — confirmed.
- **Act:** Return `""` for empty Enter (not nil). Only return nil for Esc/Ctrl+C.
- **Status:** ✅ Done — `return text.empty? ? (default || "") : text`.

### FIND-14 ✅ DONE | Color cache grows unbounded
- **File:** `src/fff/ui_renderer.cr:39,362-375`
- **Claim:** `@color_cache` is populated for every file path visited. `clear_cache` method exists but is never called. Long sessions accumulate thousands of entries.
- **Verify:** `grep -n '@color_cache\|clear_cache' src/fff/ui_renderer.cr` — lines 9,39,79,362,375. `clear_cache` at line 79 never invoked externally.
- **Act:** Call `clear_cache` on directory change (in `redraw` when `current_dir` changes), or use a capped Hash with eviction.
- **Status:** ✅ Done — `@color_cache.clear` on directory change in `UIRenderer.redraw`.

### FIND-16 | Error message forces full redraw per frame
- **File:** `src/fff/file_manager.cr:196`
- **Claim:** `full_draw` condition includes `!@error_msg.nil?` — while error is displayed, every keystroke triggers full redraw even if nothing else changed.
- **Verify:** Line 196: `full_draw = ... || !@error_msg.nil? || ...`.
- **Act:** Track `@prev_error_msg` and only force full redraw when error state changes.
- **Status:** DEFERRED — current behavior is correct for error visibility; optimization is minor.

### FIND-17 ✅ DONE | 6 files fail crystal tool format
- **Files:** `directory_manager.cr`, `file_op_handlers.cr`, `file_operations.cr`, `config.cr`, `ui_renderer.cr`, `file_manager.cr`
- **Claim:** `crystal tool format --check src/` reports formatting violations.
- **Verify:** Ran `crystal tool format --check src/` — 6 files listed.
- **Act:** Run `crystal tool format src/`.
- **Status:** ✅ Done — all files formatted, `--check` passes clean.

### FIND-18 ✅ DONE | Dead code: yank_files/cut_files in FileOperations
- **File:** `src/fff/file_operations.cr:14-20`
- **Claim:** `yank_files` and `cut_files` methods are defined but never called. Clipboard management is done directly in `file_op_handlers.cr:105-113`.
- **Verify:** `grep -rn 'yank_files\|cut_files' src/` — only defined in `file_operations.cr`, never called.
- **Act:** Remove dead methods.
- **Status:** ✅ Done — removed `yank_files` and `cut_files` from `file_operations.cr`.

### FIND-19 ✅ DONE | key_bindings hash rebuilt on every keypress
- **File:** `src/fff/config.cr:220-231`
- **Claim:** `def key_bindings : Hash(String, String)` creates a new Hash on every call. Called from `handle_key` on every keypress.
- **Verify:** Line 220-231: literal Hash constructed in method body, no memoization.
- **Act:** Memoize as `@key_bindings_cache : Hash(String, String)?` with lazy init, or build once in `initialize`.
- **Status:** ✅ Done — `@key_bindings_cache ||= { ... }` with lazy memoization.

---

## ✅ Previously Done (earlier sessions)

### TODO-1 ✅ DONE | Replace bare `rescue` — `file_operations.cr` (×8)
- **Commit:** bac8031

### TODO-2 ✅ DONE | Replace bare `rescue` — `file_service.cr` + `file_manager.cr`
- **Commit:** bac8031

### TODO-3 ✅ DONE | Add direct tests for `delete_files` + `paste_files`
- **Commit:** bac8031 · Suite: 134 examples

### TODO-5 ✅ DONE | Section `handle_key` with key grouping → hash dispatch
- **Commit:** b7731e1

### TODO-6 ✅ DONE | Hash-table dispatch for key bindings
- **Commit:** b7731e1

### ✅ 11. Narrow typed exceptions
- **Commit:** bac8031

### ✅ 12. Direct tests for delete_files + paste_files
- **Commit:** bac8031

### ✅ 13. Colorize git branch name in draw_topbar
- **Commit:** 3557307

### TODO-7a | Split `file_operations.cr` (174 LOC)
- **Prior:** 🟢 Low | **Çaba:** Yüksek | **Status:** Deferred

### TODO-7b | Split `config.cr` (271 LOC)
- **Prior:** 🟢 Low | **Çaba:** Yüksek | **Status:** Deferred

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
