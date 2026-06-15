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
  attr(:rest, :global)

  @doc "Render a textarea-backed LiveCode editor."
  def editor(assigns) do
    language_context = %Context{text: assigns.value, metadata: assigns.context}

    assigns =
      assigns
      |> assign(:tokens, Language.tokenize(assigns.language, assigns.value, assigns.opts))
      |> assign(
        :completions,
        Language.completions(assigns.language, language_context, assigns.opts)
      )
      |> assign(
        :diagnostics,
        assigns.diagnostics ++ Language.diagnostics(assigns.language, assigns.value, assigns.opts)
      )
      |> assign(:line_numbers, line_numbers(assigns.value))

    ~H"""
    <div
      id={@id}
      class={["lc-editor", @class]}
      phx-hook="LiveCode"
      phx-update="ignore"
      data-livecode-root
      data-livecode-language={language_name(@language)}
    >
      <div class="lc-shell">
        <div class="lc-gutter" aria-hidden="true">
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
      <div class="lc-diagnostics" data-livecode-diagnostics hidden={@diagnostics == []}>
        <div :for={diagnostic <- @diagnostics} class={["lc-diagnostic", "lc-diagnostic-#{diagnostic.severity}"]}>
          <span class="lc-diagnostic-severity">{diagnostic.severity}</span>
          <span>{diagnostic.message}</span>
        </div>
      </div>
    </div>
    """
  end

  defp line_numbers(""), do: [1]
  defp line_numbers(value), do: 1..(String.split(value, "\n") |> length())

  defp token_class(kind), do: "lc-token lc-token-#{kind}"

  defp language_name(LiveCode.Languages.SQL), do: "sql"
  defp language_name(LiveCode.Languages.JSON), do: "json"
  defp language_name(LiveCode.Languages.HTML), do: "html"
  defp language_name(language), do: language |> Module.split() |> List.last() |> String.downcase()
end
