# LiveCode — agent instructions

LiveCode is an Elixir Hex package (`livecode`, MIT, source
github.com/go9/livecode) providing LiveView-native syntax highlighting,
autocomplete, snippets, diagnostics, and an optional sandboxed live preview
**for plain `<textarea>`s**. It is deliberately *not* a browser IDE: the native
textarea stays the editing surface, and LiveCode layers a highlight mirror,
line numbers, a completion popup, diagnostics, and language-aware helpers
around it via one small LiveView JS hook. Elixir language modules own *meaning*
(tokens, completions, diagnostics, snippets, formatting); the JS bridge owns
only browser-only primitives (scroll sync, cursor insertion, client-side
highlight/preview rendering). Consumed by any Phoenix/LiveView app that wants
code editing without shipping Monaco or CodeMirror. Status is early MVP and the
package is **not yet published to Hex** — the version on `main` is still
`0.1.0` and unreleased.

## Dev commands

```bash
mix deps.get
mix test
mix format --check-formatted
mix compile --warnings-as-errors --force
node --test test/livecode_hook_test.mjs   # JS hook tests — plain node test runner, no npm
```

Elixir `~> 1.18`, OTP 27 in CI. Deps: `phoenix_live_view >= 1.0.0`,
`jason >= 1.4.0`, `ex_doc` (dev only). No `.env`, no database, no `mix setup`
alias, and **no demo app** — the standalone demo was retired (flicker #1001),
so this repo is the library only. `.github/workflows/ci.yml` runs exactly the
five commands above on `pull_request` and on push to `main`; run them locally
before opening a PR. Note the JS hook has its own `node --test` suite that
`mix test` does **not** cover — changes to
`priv/static/livecode/livecode.js` need both.

## Release

Hex package, **no deploy on push**. There is no server; pushing to `main` only
runs CI. Publishing is manual and explicit:

```bash
mix hex.publish      # requires Hex auth — NEVER run this without human approval
```

Ritual for a release:

1. Bump `@version` in `mix.exs` — it is the single source of truth and also
   feeds `docs/0`'s `source_ref: "v#{@version}"`, so the generated docs' source
   links only resolve if you also tag `v<version>`.
2. Tag the commit `v<version>`.
3. `mix hex.publish`.

There is no `CHANGELOG.md` in this repo yet; if you add one, use Keep a
Changelog format and add it to the `files:` list in `package/0` so it ships in
the tarball.

## Durable gotchas (the public API is a contract)

- **Public API surface** — a consumer app breaks if any of these change:
  - `LiveCode.Editor.editor/1` — the HEEx component. Its `attr`s are the API:
    `id` (required), `language`, `value`, `context`, `opts`, `diagnostics`,
    `name`, `form`, `rows`, `class`, `preview`
    (`:auto | :code | :split | :preview | :off`), `transform`, `readonly`,
    plus `:rest` as a global.
  - `LiveCode.Language` — the behaviour. **`tokenize/2` is the only required
    callback**; `completions/2`, `diagnostics/2`, `snippets/1`, `format/2`, and
    `preview/1` are optional. The safe dispatch wrappers
    (`LiveCode.Language.tokenize/3` and friends) check `function_exported?`
    first so a partial language module never crashes the editor — keep that
    guarantee.
  - The structs consumers construct: `LiveCode.Token`, `LiveCode.Completion`,
    `LiveCode.Diagnostic`, `LiveCode.Snippet`, `LiveCode.Context`,
    `LiveCode.Preview`.
  - First-party language packs `LiveCode.Languages.{SQL,JSON,HTML,HEEx}` —
    HTML is the previewable one; HEEx returns `nil` from `preview/1`.
  - `LiveCode.hook_path/0` and `LiveCode.css_path/0` — asset paths consumers
    use to vendor the JS/CSS.
  - The JS module surface of `priv/static/livecode/livecode.js`: named exports
    `LiveCode` (the hook), `registerLanguage/2`, `registerTransform/2`, plus
    the default export.
  - CSS custom properties in `priv/static/livecode/livecode.css` are named
    `--lc-*`; consumers theme by overriding them, so renaming one is a
    breaking change.
- **`package/0` ships only `lib priv .formatter.exs mix.exs README.md
  LICENSE`.** Any new top-level file or directory a consumer needs at runtime
  must be added to that `files:` list or it silently won't be in the Hex
  tarball.
- **A language is a pair**, and adding one touches three places:
  1. the Elixir `LiveCode.Language` module (meaning),
  2. a `language_name/1` clause in `lib/livecode/editor.ex` — this produces the
     `data-livecode-language` attribute that selects the client renderer; the
     fallback is the downcased last module segment,
  3. an optional JS `registerLanguage(name, {highlight, preview, diagnostics})`
     registration (rendering).
  `sql`, `json`, and `html` are auto-registered on the JS side; **`heex` is
  not** — it is server-tokenized only. Adding a language must never require
  patching the hook itself.
- **Preview is opt-in and sandboxed.** A language is previewable iff it exports
  `preview/1` returning a `%LiveCode.Preview{}`; rendering goes into a
  sandboxed `<iframe>` (no script execution, isolated styles). Do not relax the
  sandbox — the previewed text is user input. `transform` names a
  client-registered transform applied to the source before rendering.
- **`readonly` is a separate render path.** `editor(%{readonly: true})` emits a
  static, server-highlighted block with **no textarea, hook, completions, or
  diagnostics**. Changes to the editable path do not automatically apply to it,
  and the HEEx tokenizer deliberately preserves the exact input text across all
  token text fields so the read-only overlay stays aligned — don't "normalize"
  token text.
- **Architectural don'ts** (these are the reason the package exists):
  - Do not introduce Monaco, CodeMirror, or any SPA editor runtime into the
    core package.
  - Do not make the server own every keystroke — the textarea owns raw editing;
    server round-trips are for meaning, not typing.
  - Do not hardcode SQL (or any single language's) assumptions into the editor
    shell; language meaning stays behind `LiveCode.Language`.
  - Keep `livecode.js` a thin browser bridge for textarea-only primitives.
- **Known doc drift:** `README.md` still lists only SQL / JSON / HTML under
  "First-party languages" and does not document `LiveCode.Languages.HEEx` or
  the `readonly` attr. Trust the code; fix the README when you touch it.

## Workflow

- Tracker = **Flicker Tickets** (`flicker` CLI). GitHub is code-only —
  branches, PRs, review. Never file tickets or plans on GitHub.
- `flicker ticket start <id>` before writing code; `flicker ticket complete`
  when merged. Pick up only `selected_for_dev` work unless told otherwise.
- Plans/decisions/status → ticket documents, not new markdown files in this
  repo. (`.go9/` holds legacy pre-Flicker artifacts; don't add to it.)
- Work in a dedicated git worktree + branch (`git worktree add
  ../livecode-<task> -b <branch>`); never switch branches in a shared checkout.
- Never push without explicit approval, and **never run `mix hex.publish`**
  without it — this is a public repo and a would-be public package.
