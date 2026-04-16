# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

`markdown.nvim` is a Neovim plugin (requires Neovim 0.11+) that renders a "pretty" in-buffer preview of markdown files. It does not export HTML; it replaces the source buffer's contents in a non-modifiable preview buffer, styled via extmarks.

## Commands

```bash
make deps          # Clone mini.nvim into .deps/ (one-time, required for tests)
make test          # Run the full MiniTest suite headlessly
make test-file FILE=tests/test_render_heading.lua   # Run a single test file
```

Tests use the `mini.test` framework (vendored via `make deps`). The bootstrap entrypoint is `tests/minimal_init.lua`, which prepends the repo root and `.deps/mini.nvim` to the runtime path.

Lua formatting is governed by `stylua.toml` (120 col, 4-space indent, `AutoPreferDouble` quotes, `call_parentheses = Always`, `sort_requires` enabled). Do not run lint/format unless asked — rely on editor plugins and CI.

## Architecture

### Entry and Lifecycle

- `plugin/markdown.lua` — guard (`vim.g.loaded_markdown_preview`) and Neovim version check. No runtime logic.
- `lua/markdown/init.lua` — public API: `setup`, `open`, `close`, `edit`, `split`, `toggle`. Owns the `BufEnter`/`BufLeave`/`TextChanged`/`BufDelete`/`WinClosed` autocmds, the debounce timer, and the render→extmark pipeline.
- `lua/markdown/commands.lua` — user commands `:MarkdownPreview`, `:MarkdownEdit`, `:MarkdownSplit`.
- `lua/markdown/state.lua` — single-instance mutable state (`source_buffer`, `preview_buffer`, `source_window`, `preview_window`, `mode`, `debounce_timer`, `autocmd_group`). `mode` is `"pretty" | "edit" | "split"`. Only one preview is active at a time.
- `lua/markdown/config.lua` — defaults and `vim.tbl_deep_extend` setup. Exposes `MarkdownConfig` / `MarkdownHighlights` LuaCATS classes.

### Rendering Pipeline

1. `treesitter.lua` parses the source buffer with the `markdown` parser (and `markdown_inline` for inline spans). Missing parsers surface via `vim.notify` and abort render.
2. `render/init.lua` walks the tree with `render_children` / `render_section`, dispatching each named child to a type-specific renderer (`heading`, `code`, `list`, `table`, `blockquote`, `horizontal_rule`, `inline`, plus `html_block` routed through `code`). Every renderer returns a `RenderResult { lines: string[], highlights: RenderHighlight[] }`. `append_result` concatenates results while rebasing `highlight.line` by the accumulated `line_offset`; `apply_padding` then prefixes each non-empty line with `config.padding` spaces and shifts every highlight's columns to match.
3. `init.render_and_update` writes `result.lines` into the preview buffer, clears the `markdown_preview` namespace, and re-emits each highlight as an extmark. `column_end == -1` is the convention for "highlight to end of line" and gets translated to `hl_eol = true` with `end_row = line`.

When adding a renderer:
- Register the node type in the `render_node` dispatch in `render/init.lua`.
- Return a `RenderResult` with `line` values that are **0-indexed relative to the renderer's own output** — `append_result` rebases them.
- Highlights use `column_start` 0-indexed inclusive, `column_end` exclusive, or `-1` for "to end of line".

### UI

- `ui/init.lua` — `open_pretty` swaps the source buffer for a scratch preview buffer in the same window; `open_split` creates a vertical split with the preview on the right. `switch_to_edit` / `close` teardown is mode-aware.
- `ui/highlights.lua` — registers `Markdown*` highlight groups from `config.highlights` at `setup()` time.
- `ui/scroll.lua` — binds `scrollbind` between source and preview windows in split mode.

### Modes

- `pretty`: preview replaces the source buffer in the same window.
- `split`: source stays put; preview lives in a vertical split, with scrollbind.
- `edit`: preview torn down, source re-shown (transient — `state` is reset afterwards).

Auto-open behavior (on `BufEnter *.md`) is gated by `config.auto_open` and `config.ignore_patterns`. Re-entering an already-active source buffer is a no-op.

### Debouncing

`TextChanged`/`TextChangedI` calls `schedule_render`, which resets a `vim.uv` timer (`config.debounce_ms`, default 150) and re-runs the full pipeline on fire. The timer is closed in `state.reset()`.

## Testing Conventions

Test files live in `tests/test_*.lua` and use `MiniTest.new_set()` nested tables. Shared helpers in `tests/helpers.lua` provide `create_markdown_buffer`, `delete_buffer`, `filter_highlights`, and `capture_notifications`. Renderer tests typically parse a small markdown snippet, walk to the target node, call the renderer directly, and assert on `lines` + filtered highlights — they do not go through `M.open()`.
