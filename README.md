# LiveCode

LiveCode is a LiveView-native syntax highlighting, autocomplete, snippets, and diagnostics layer for textareas.

It is intentionally **not** a full code editor. The browser's native `<textarea>` remains the editing surface, while LiveCode layers language-aware UI around it:

- syntax highlighting mirror
- line numbers
- completion popup
- snippets
- diagnostics
- formatting hooks
- extensible language modules
- tiny JavaScript hook for browser-only primitives like scroll sync and cursor insertion

## Installation

```elixir
def deps do
  [
    {:livecode, "~> 0.1.0"}
  ]
end
```

## Usage

Register the hook in your LiveSocket setup:

```javascript
import {LiveCode} from "../vendor/livecode/livecode"

let liveSocket = new LiveSocket("/live", Socket, {
  hooks: {LiveCode}
})
```

Include the CSS from `priv/static/livecode/livecode.css` in your app.

Render the component:

```elixir
import LiveCode.Editor

<.editor
  id="sql-editor"
  language={LiveCode.Languages.SQL}
  value={@sql}
  context={%{tables: @tables, columns: @columns}}
  phx-change="sql_changed"
/>
```

## Custom languages

Implement `LiveCode.Language`:

```elixir
defmodule MyApp.CELLanguage do
  @behaviour LiveCode.Language

  alias LiveCode.{Completion, Context, Token}

  def tokenize(text, _opts) do
    [%Token{kind: :text, text: text}]
  end

  def completions(%Context{metadata: metadata}, _opts) do
    metadata.variables
    |> Enum.map(&%Completion{label: &1, kind: :variable, insert_text: &1})
  end

  def diagnostics(_text, _opts), do: []
  def snippets(_opts), do: []
  def format(_text, _opts), do: :noop
end
```

## Live preview & view modes

A language can opt into a **live preview**. When it does, the editor shows a
`Code` / `Preview` / `Split` toggle and renders the source — debounced, as you
type — into a **sandboxed `<iframe>`** (no script execution, isolated styles).

Opt in from the Elixir language module with `preview/1`:

```elixir
@impl true
def preview(_opts), do: %LiveCode.Preview{mode: :html, sandbox: true, label: "Preview"}
```

and register the matching client renderer in JS (see below). Languages that
don't implement `preview/1` render code-only exactly as before.

Control the initial view (and turn it off) per editor:

```elixir
<.editor id="html" language={LiveCode.Languages.HTML} value={@html} preview={:split} />
<.editor id="plain" language={LiveCode.Languages.HTML} value={@html} preview={:off} />
```

### Consumer preview transforms

Pre-process the source before it's rendered (resolve placeholders, sanitize,
inject sample data…) by registering a named transform and referencing it:

```javascript
import { registerTransform } from "../vendor/livecode/livecode"

registerTransform("ebay", (text, ctx) => sanitize(resolvePlaceholders(text)))
```

```elixir
<.editor id="ebay" language={LiveCode.Languages.HTML} value={@template} transform="ebay" />
```

## Client-side language rendering (highlight + preview)

A language is a **pair**: an Elixir `LiveCode.Language` module (meaning) and an
optional JS registration (rendering). Highlighting and preview are resolved from
a client registry, so a new language ships its own renderers without patching
the hook:

```javascript
import { registerLanguage } from "../vendor/livecode/livecode"

registerLanguage("mylang", {
  highlight(text) { return htmlString },               // optional
  preview(text, ctx) { return { srcdoc: "<...>" } },   // optional
  diagnostics(text) { return [{ severity, message }] }  // optional
})
```

Built-in `sql`, `json`, and `html` renderers are registered automatically
(`html` is previewable).

## First-party languages

- `LiveCode.Languages.SQL`
- `LiveCode.Languages.JSON`
- `LiveCode.Languages.HTML` (previewable)

## Status

Early MVP. The current implementation proves the core API and shell, with SQL/JSON language packs and static assets. Browser hardening, richer completion context, diagnostics positioning, and Lantern integration are next.
