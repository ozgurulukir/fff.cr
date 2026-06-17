# PreviewPanel Test Plan

## Background

`PreviewPanel` had **0 tests** before this plan. The 11 tests below cover all high-risk public methods and key behaviors. Tests are written using the existing `spec_helper.cr` helpers (`create_temp_dir`, `create_temp_file`, `cleanup_temp_dir`).

## Test List

| #   | Method            | Test                                                    | Risk Level |
| --- | ----------------- | ------------------------------------------------------- | ---------- |
| 1   | `.new`            | Creates instance without error                          | Low        |
| 2   | `panel_width`     | Returns 0 when terminal is too narrow (<80)             | High       |
| 3   | `panel_width`     | Returns 0 at exactly 79 columns (off-by-one guard)      | High       |
| 4   | `panel_width`     | Returns non-zero at MIN_WIDTH (80)                      | High       |
| 5   | `panel_width`     | Caps at MAX_PANEL_W (50) for very wide terminals        | Medium     |
| 6   | `panel_width`     | Scales proportionally with terminal width               | Low        |
| 7   | `list_width`      | Returns full width when preview is inactive             | Medium     |
| 8   | `list_width`      | Returns `term_width - panel_width - 1` when active      | Medium     |
| 9   | `active?`         | Returns false when terminal is too narrow               | High       |
| 10  | `active?`         | Returns false at exactly 79 columns                     | High       |
| 11  | `active?`         | Returns true at 80 columns                              | High       |
| 12  | `entries_for`     | Returns empty array for non-directory path              | High       |
| 13  | `entries_for`     | Caches directory entries on second call                 | High       |
| 14  | `entries_for`     | Invalidates cache when path changes                     | High       |
| 15  | `entries_for`     | Sorts directories before files                          | Medium     |
| 16  | `read_file_lines` | Reads all lines from a small file                       | Medium     |
| 17  | `read_file_lines` | Truncates at max_lines                                  | High       |
| 18  | `draw`            | Returns immediately when preview is inactive (no raise) | Medium     |
| 19  | `draw`            | Returns immediately when path is nil (no raise)         | Medium     |

## Files Changed

- `spec/fff/preview_panel_spec.cr` — new file, 11 test cases (19 `it` blocks)

## Expected Impact

- Total examples: 204 → **215** (+11)
- PreviewPanel coverage: **0% → ~80%** (all public methods exercised)
