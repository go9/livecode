defmodule DemoWeb.PlaygroundLive do
  @moduledoc """
  Public demo for the `livecode` library: pick a language and edit sample code
  in a LiveView-native, syntax-highlighted textarea (autocomplete + diagnostics
  included). No database, no accounts — just the editor.
  """
  use DemoWeb, :live_view

  @languages [
    %{id: "html", label: "HTML"},
    %{id: "sql", label: "SQL"},
    %{id: "json", label: "JSON"}
  ]

  @samples %{
    "html" => """
    <!DOCTYPE html>
    <html>
      <head>
        <title>Hello, world</title>
      </head>
      <body>
        <h1 style="color:#534AB7">Hello, world!</h1>
        <p>Edit me — <strong>livecode</strong> highlights HTML as you type.</p>
      </body>
    </html>
    """,
    "sql" => """
    -- Edit this query — keywords, strings and numbers highlight live.
    select id, name, email
    from users
    where active = true
    order by created_at desc
    limit 10;
    """,
    "json" => """
    {
      "message": "Hello, world!",
      "editor": "livecode",
      "languages": ["html", "sql", "json"],
      "awesome": true
    }
    """
  }

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, languages: @languages, current: "html", samples: @samples)}
  end

  @impl true
  def handle_event("select", %{"lang" => lang}, socket) when is_map_key(@samples, lang) do
    {:noreply, assign(socket, current: lang)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-zinc-50 text-zinc-900 py-12 px-4">
      <div class="max-w-3xl mx-auto">
        <header class="flex items-start justify-between gap-4">
          <div>
            <h1 class="text-3xl font-semibold tracking-tight">livecode</h1>
            <p class="text-zinc-500 mt-1">
              LiveView-native syntax highlighting, autocomplete & diagnostics — in a plain textarea.
            </p>
          </div>
          <a
            href="https://github.com/go9/livecode"
            class="shrink-0 text-sm font-medium text-zinc-600 hover:text-zinc-900 underline"
          >
            GitHub
          </a>
        </header>

        <div class="flex gap-2 mt-8 mb-3">
          <button
            :for={lang <- @languages}
            type="button"
            phx-click="select"
            phx-value-lang={lang.id}
            class={[
              "px-3 py-1.5 rounded-md text-sm font-medium border transition cursor-pointer",
              if(@current == lang.id,
                do: "bg-zinc-900 text-white border-zinc-900",
                else: "bg-white text-zinc-600 border-zinc-300 hover:bg-zinc-100"
              )
            ]}
          >
            {lang.label}
          </button>
        </div>

        <LiveCode.Editor.editor
          id={"editor-" <> @current}
          language={language_mod(@current)}
          value={Map.fetch!(@samples, @current)}
          rows={18}
        />

        <p class="text-xs text-zinc-500 mt-3">
          Type to highlight. Press <kbd class="px-1 border rounded">Ctrl</kbd>/<kbd class="px-1 border rounded">⌘</kbd>
          + <kbd class="px-1 border rounded">Space</kbd> for completions.
        </p>
      </div>
    </div>
    """
  end

  defp language_mod("sql"), do: LiveCode.Languages.SQL
  defp language_mod("json"), do: LiveCode.Languages.JSON
  defp language_mod(_), do: LiveCode.Languages.HTML
end
