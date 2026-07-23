defmodule LiveCode.Editor do
  @moduledoc "HEEx components for LiveCode editors."

  use Phoenix.Component

  alias LiveCode.{Context, Language}

  attr(:id, :string, required: true)
  attr(:language, :atom, default: LiveCode.Languages.SQL)
  attr(:value, :string, default: "")
  attr(:context, :map, default: %{})
  attr(:opts, :list, default: [])
  attr(:diagnostics, :list, default: [])
  attr(:name, :string, default: "value")
  attr(:form, :string, default: nil)
  attr(:rows, :integer, default: 8)
  attr(:class, :any, default: nil)

  attr(:preview, :atom,
    default: :auto,
    values: [:auto, :code, :split, :preview, :off],
    doc:
      "Initial view when the language is previewable. `:auto` uses the language's default; `:off` hides the preview UI entirely."
  )

  attr(:transform, :string,
    default: nil,
    doc:
      "Name of a client preview transform registered via `LiveCode.registerTransform/2` (applied to the source before the language renders it — e.g. resolve placeholders + sanitize)."
  )

  attr(:readonly, :boolean,
    default: false,
    doc:
      "Render a static, syntax-highlighted, non-editable block (no textarea, hook, completions, or diagnostics) — for showing code."
  )

  attr(:rest, :global)

  @doc "Render a textarea-backed LiveCode editor."
  def editor(%{readonly: true} = assigns) do
    assigns =
      assigns
      |> assign(:tokens, Language.tokenize(assigns.language, assigns.value, assigns.opts))
      |> assign(:line_numbers, line_numbers(assigns.value))

    ~H"""
    <div
      id={@id}
      class={["lc-editor", "lc-readonly", @class]}
      data-livecode-language={language_name(@language)}
      {@rest}
    >
      <div class="lc-body">
        <div class="lc-shell">
          <div class="lc-gutter" aria-hidden="true"><span :for={line <- @line_numbers}>{line}</span></div>
          <pre class="lc-highlight lc-highlight-static"><code><span :for={token <- @tokens} class={token_class(token.kind)}>{token.text}</span></code></pre>
        </div>
      </div>
    </div>
    """
  end

  def editor(assigns) do
    language_context = %Context{text: assigns.value, metadata: assigns.context}
    preview = Language.preview(assigns.language, assigns.opts)
    view = initial_view(preview, assigns.preview)
    language_diagnostics = Language.diagnostics(assigns.language, assigns.value, assigns.opts)
    diagnostics = assigns.diagnostics ++ language_diagnostics

    assigns =
      assigns
      |> assign(:tokens, Language.tokenize(assigns.language, assigns.value, assigns.opts))
      |> assign(
        :completions,
        Language.completions(assigns.language, language_context, assigns.opts)
      )
      |> assign(:external_diagnostics, assigns.diagnostics)
      |> assign(:language_diagnostics, language_diagnostics)
      |> assign(:has_diagnostics, diagnostics != [])
      |> assign(:invalid?, Enum.any?(diagnostics, &(&1.severity == :error)))
      |> assign(:line_numbers, line_numbers(assigns.value))
      |> assign(:preview_config, preview)
      |> assign(:view, view)

    ~H"""
    <div
      id={@id}
      class={[
        "lc-editor",
        @view && "lc-has-preview",
        @view && "lc-view-#{@view}",
        @invalid? && "lc-invalid",
        @class
      ]}
      phx-hook="LiveCode"
      phx-update="ignore"
      data-livecode-root
      data-livecode-language={language_name(@language)}
      data-livecode-preview={@view && to_string(@preview_config.mode)}
      data-livecode-sandbox={@view && to_string(@preview_config.sandbox)}
      data-livecode-view={@view}
      data-livecode-transform={@transform}
    >
      <div :if={@view} class="lc-toolbar" data-livecode-toolbar role="group" aria-label="Editor view">
        <button
          type="button"
          class="lc-tab"
          data-livecode-view-btn="code"
          aria-pressed={to_string(@view == :code)}
        >
          Code
        </button>
        <button
          type="button"
          class="lc-tab"
          data-livecode-view-btn="split"
          aria-pressed={to_string(@view == :split)}
        >
          Split
        </button>
        <button
          type="button"
          class="lc-tab"
          data-livecode-view-btn="preview"
          aria-pressed={to_string(@view == :preview)}
        >
          {@preview_config.label}
        </button>
      </div>
      <div class="lc-body">
        <div class="lc-shell">
          <div class="lc-gutter" aria-hidden="true" data-livecode-gutter>
            <span :for={line <- @line_numbers}>{line}</span>
          </div>
          <div class="lc-input-wrap">
            <pre class="lc-highlight" aria-hidden="true"><code data-livecode-highlight><span :for={token <- @tokens} class={token_class(token.kind)}>{token.text}</span></code></pre>
            <textarea
              id={"#{@id}-textarea"}
              name={@name}
              form={@form}
              rows={@rows}
              class="lc-textarea"
              spellcheck="false"
              autocomplete="off"
              autocapitalize="off"
              data-livecode-textarea
              aria-invalid={to_string(@invalid?)}
              aria-describedby={@has_diagnostics && "#{@id}-diagnostics"}
              phx-debounce="blur"
              {@rest}
            >{@value}</textarea>
            <div class="lc-completions" data-livecode-completions hidden>
              <button
                :for={completion <- @completions}
                type="button"
                class="lc-completion"
                data-livecode-insert={completion.insert_text || completion.label}
              >
                <span class="lc-completion-label">{completion.label}</span>
                <span :if={completion.kind} class="lc-completion-kind">{completion.kind}</span>
                <span :if={completion.detail} class="lc-completion-detail">{completion.detail}</span>
              </button>
            </div>
          </div>
        </div>
        <div :if={@view} class="lc-preview" data-livecode-preview-pane aria-label="Preview"></div>
      </div>
      <div
        id={"#{@id}-diagnostics"}
        class="lc-diagnostics"
        data-livecode-diagnostics
        aria-live="polite"
        hidden={not @has_diagnostics}
      >
        <div
          :for={diagnostic <- @external_diagnostics}
          class={["lc-diagnostic", "lc-diagnostic-#{diagnostic.severity}"]}
          data-livecode-persistent-diagnostic
        >
          <span class="lc-diagnostic-severity">{diagnostic.severity}</span>
          <span>{diagnostic.message}</span>
        </div>
        <div
          :for={diagnostic <- @language_diagnostics}
          class={["lc-diagnostic", "lc-diagnostic-#{diagnostic.severity}"]}
        >
          <span class="lc-diagnostic-severity">{diagnostic.severity}</span>
          <span>{diagnostic.message}</span>
        </div>
      </div>
    </div>
    """
  end

  # Resolve the initial view from the language's preview capability and the
  # `preview` attr. Returns nil when there is no preview UI (not previewable, or
  # explicitly turned `:off`).
  defp initial_view(nil, _requested), do: nil
  defp initial_view(_preview, :off), do: nil
  defp initial_view(preview, :auto), do: preview.default_view

  defp initial_view(_preview, requested) when requested in [:code, :split, :preview],
    do: requested

  defp line_numbers(""), do: [1]
  defp line_numbers(value), do: 1..(String.split(value, "\n") |> length())

  defp token_class(kind), do: "lc-token lc-token-#{kind}"

  defp language_name(LiveCode.Languages.SQL), do: "sql"
  defp language_name(LiveCode.Languages.JSON), do: "json"
  defp language_name(LiveCode.Languages.HTML), do: "html"
  defp language_name(LiveCode.Languages.HEEx), do: "heex"
  defp language_name(language), do: language |> Module.split() |> List.last() |> String.downcase()
end
