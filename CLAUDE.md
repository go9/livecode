# LiveCode

@~/Sites/agent-conventions/CLAUDE.md

## What this is

LiveCode is a dependency-light LiveView-native syntax highlighting, autocomplete, snippets, and diagnostics layer for textareas. It is not a full IDE or Monaco clone: browser-native textarea editing remains the input surface while Elixir language modules provide tokens, completions, diagnostics, snippets, and formatting hooks.

## Repository

GitHub: `go9/livecode` (planned public open-source repo)
Tracker: self once the repository exists

## Running locally

```bash
cd ~/Sites/livecode
mix test
```

No `.env` file is required.

## Deploy

No deploy target. Publish later via Hex once API is stable.

## Architecture notes

- `LiveCode.Editor` is the HEEx component layer.
- `LiveCode.Language` defines language extension callbacks.
- `LiveCode.Languages.SQL` and `LiveCode.Languages.JSON` are first-party language packs.
- `priv/static/livecode/livecode.js` is intentionally a thin browser bridge for textarea-only primitives.
- `priv/static/livecode/livecode.css` provides default styles using `--lc-*` variables.

## Don'ts

- Do not introduce Monaco, CodeMirror, or a SPA editor runtime into the core package.
- Do not make the server own every keystroke; the textarea owns raw editing.
- Do not hardcode SQL assumptions into the editor shell; keep language meaning behind `LiveCode.Language`.
