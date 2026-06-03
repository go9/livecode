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

## First-party languages

- `LiveCode.Languages.SQL`
- `LiveCode.Languages.JSON`

## Status

Early MVP. The current implementation proves the core API and shell, with SQL/JSON language packs and static assets. Browser hardening, richer completion context, diagnostics positioning, and Lantern integration are next.
