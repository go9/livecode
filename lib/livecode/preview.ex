defmodule LiveCode.Preview do
  @moduledoc """
  Describes how a language renders a live preview in the editor.

  A language opts into preview by implementing `c:LiveCode.Language.preview/1`
  and returning one of these structs (return `nil` for "no preview"). The editor
  component uses it to decide whether to show the Code / Preview / Split view
  toggle, and the client hook uses `mode` to pick the matching preview renderer
  registered in JS (`LiveCode.registerLanguage(name, { preview })`).

  Fields:

    * `:mode` — the client renderer key (e.g. `:html`). Matches the `preview`
      function registered for the language in `livecode.js`.
    * `:sandbox` — render the preview inside a sandboxed `<iframe srcdoc>`
      (isolates styles, blocks script execution). Recommended for any preview
      that renders untrusted/markup content. Default `true`.
    * `:label` — label for the Preview toggle button. Default `"Preview"`.
    * `:default_view` — which view the editor opens in: `:code`, `:split`, or
      `:preview`. Default `:code`.
  """

  @type view :: :code | :split | :preview

  @type t :: %__MODULE__{
          mode: atom(),
          sandbox: boolean(),
          label: String.t(),
          default_view: view()
        }

  defstruct mode: :html, sandbox: true, label: "Preview", default_view: :code
end
