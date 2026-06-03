# LiveCode task contract

## Goal

Create LiveCode as a new open-source Elixir/Phoenix LiveView library that Lantern can later depend on for textarea-backed syntax highlighting, autocomplete, snippets, diagnostics, and formatting hooks.

## Decisions

- Package name: `livecode`.
- Main namespace: `LiveCode`.
- Core is not a Monaco/CodeMirror dependency and not a full IDE.
- Browser-native textarea remains the editor input surface.
- Elixir language modules own tokenization, completions, diagnostics, snippets, and formatting.
- JavaScript stays a thin browser-primitive hook for scroll sync, completion insertion, and shortcuts.
- First-party language modules: SQL and JSON.

## MVP cut

| Slice | Files |
|---|---|
| Mix package metadata | `mix.exs`, `README.md`, `LICENSE`, `CLAUDE.md` |
| Core structs/behaviour | `lib/livecode/{language,token,completion,diagnostic,snippet,context}.ex` |
| Component shell | `lib/livecode/editor.ex` |
| SQL language pack | `lib/livecode/languages/sql.ex` |
| JSON language pack | `lib/livecode/languages/json.ex` |
| Static assets | `priv/static/livecode/livecode.{js,css}` |
| Tests | `test/livecode_test.exs` |

## Acceptance criteria

- `mix format --check-formatted` passes.
- `mix compile --warnings-as-errors --force` passes.
- `mix test` passes.
- Public API supports custom `LiveCode.Language` modules.
- SQL language exposes keyword/table/column/snippet completions.
- JSON language exposes parse diagnostics and formatting.
- Component renders a textarea-backed shell with line numbers, highlights, completions, and diagnostics.

## Next integration task

After this MVP, add LiveCode as a path dependency to Lantern and replace the SQL workspace textarea with `LiveCode.Editor`, passing table/column schema context from Lantern.
