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
    <div style="font-family:system-ui,sans-serif;max-width:420px;margin:24px auto;
                border:1px solid #e5e7eb;border-radius:14px;overflow:hidden;">
      <div style="background:#534AB7;color:#fff;padding:20px 24px;">
        <h1 style="margin:0;font-size:22px;">livecode</h1>
        <p style="margin:6px 0 0;opacity:.85;font-size:14px;">Edit the HTML — the preview updates live.</p>
      </div>
      <div style="padding:20px 24px;color:#334155;">
        <p style="margin:0 0 12px;">Try <strong>Split</strong> to see code + preview side by side.</p>
        <a href="#" style="display:inline-block;background:#534AB7;color:#fff;
           text-decoration:none;padding:9px 16px;border-radius:8px;font-size:14px;">A button</a>
      </div>
    </div>
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
          preview={:split}
          rows={18}
        />

        <p class="text-xs text-zinc-500 mt-3">
          Type to highlight. Press <kbd class="px-1 border rounded">Ctrl</kbd>/<kbd class="px-1 border rounded">⌘</kbd> +
          <kbd class="px-1 border rounded">Space</kbd>
          for completions.
          <span class="block mt-1">
            HTML is <strong>previewable</strong>
            — toggle <strong>Code / Preview / Split</strong>
            above the editor
            (SQL and JSON stay code-only). Preview and highlighting are per-language extensions.
          </span>
        </p>
      </div>
    </div>
    """
  end

  defp language_mod("sql"), do: LiveCode.Languages.SQL
  defp language_mod("json"), do: LiveCode.Languages.JSON
  defp language_mod(_), do: LiveCode.Languages.HTML
end
