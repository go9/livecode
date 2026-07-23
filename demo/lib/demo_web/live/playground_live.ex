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
    %{id: "json", label: "JSON"},
    %{id: "heex", label: "HEEx"}
  ]

  @modes [
    %{id: "edit", label: "Editable"},
    %{id: "readonly", label: "Read only"}
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
    -- Scroll, add a line, or remove one. The gutter stays aligned.
    with recent_orders as (
      select
        customer_id,
        total_cents,
        created_at
      from orders
      where created_at >= current_date - interval '30 days'
        and status = 'paid'
    ),
    customer_totals as (
      select
        customer_id,
        count(*) as order_count,
        sum(total_cents) as lifetime_cents
      from recent_orders
      group by customer_id
    )
    select
      users.id,
      users.name,
      users.email,
      customer_totals.order_count,
      customer_totals.lifetime_cents
    from users
    join customer_totals on customer_totals.customer_id = users.id
    where users.active = true
    order by customer_totals.lifetime_cents desc
    limit 10;
    """,
    "json" => """
    {
      "message": "Hello, world!",
      "editor": "livecode",
      "languages": ["html", "sql", "json", "heex"],
      "awesome": true
    }
    """,
    "heex" => ~S"""
    <.form for={@form} id="profile-form" phx-submit="save">
      <.input field={@form[:name]} label="Name" />
      <.input field={@form[:email]} type="email" label="Email" />

      <div :if={@form.source.action} class="text-red-600">
        Please check the highlighted fields.
      </div>

      <.button disabled={@saving}>
        <%= if @saving do %>
          Saving…
        <% else %>
          Save profile
        <% end %>
      </.button>
    </.form>
    """
  }

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       languages: @languages,
       modes: @modes,
       current: "html",
       mode: "edit",
       samples: @samples
     )}
  end

  @impl true
  def handle_event("select-language", %{"lang" => lang}, socket)
      when is_map_key(@samples, lang) do
    mode = if lang == "heex", do: "readonly", else: socket.assigns.mode
    {:noreply, assign(socket, current: lang, mode: mode)}
  end

  @impl true
  def handle_event("select-mode", %{"mode" => "readonly"}, socket) do
    {:noreply, assign(socket, mode: "readonly")}
  end

  def handle_event("select-mode", %{"mode" => "edit"}, %{assigns: %{current: "heex"}} = socket) do
    {:noreply, socket}
  end

  def handle_event("select-mode", %{"mode" => "edit"}, socket) do
    {:noreply, assign(socket, mode: "edit")}
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

        <div class="grid gap-3 mt-8 mb-3 sm:grid-cols-[1fr_auto] sm:items-end">
          <div>
            <p id="language-selector-label" class="mb-1 text-xs font-semibold text-zinc-500">
              Language
            </p>
            <div
              class="flex flex-wrap gap-2"
              role="group"
              aria-labelledby="language-selector-label"
            >
              <button
                :for={lang <- @languages}
                id={"language-#{lang.id}"}
                type="button"
                phx-click="select-language"
                phx-value-lang={lang.id}
                aria-pressed={to_string(@current == lang.id)}
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
          </div>

          <div>
            <p id="feature-selector-label" class="mb-1 text-xs font-semibold text-zinc-500">
              Feature
            </p>
            <div class="flex gap-2" role="group" aria-labelledby="feature-selector-label">
              <button
                :for={mode <- @modes}
                id={"mode-#{mode.id}"}
                type="button"
                phx-click="select-mode"
                phx-value-mode={mode.id}
                aria-pressed={to_string(@mode == mode.id)}
                disabled={mode.id == "edit" and @current == "heex"}
                class={[
                  "px-3 py-1.5 rounded-md text-sm font-medium border transition",
                  (mode.id == "edit" and @current == "heex") && "cursor-not-allowed opacity-40",
                  (mode.id != "edit" or @current != "heex") && "cursor-pointer",
                  if(@mode == mode.id,
                    do: "bg-zinc-900 text-white border-zinc-900",
                    else: "bg-white text-zinc-600 border-zinc-300 hover:bg-zinc-100"
                  )
                ]}
              >
                {mode.label}
              </button>
            </div>
          </div>
        </div>

        <LiveCode.Editor.editor
          id={"editor-#{@current}-#{@mode}"}
          language={language_mod(@current)}
          value={Map.fetch!(@samples, @current)}
          preview={:split}
          readonly={@mode == "readonly"}
          rows={18}
        />

        <p class="text-xs text-zinc-500 mt-3">
          <%= if @mode == "edit" do %>
            Type to highlight. Press <kbd class="px-1 border rounded">Ctrl</kbd>/<kbd class="px-1 border rounded">⌘</kbd> +
            <kbd class="px-1 border rounded">Space</kbd>
            for completions.
          <% else %>
            Read-only mode renders highlighted, copyable code without editor JavaScript.
          <% end %>
          <span class="block mt-1">
            HTML also exposes <strong>Code / Preview / Split</strong>. SQL and JSON stay code-only.
            HEEx currently showcases the server-rendered read-only mode used by the Lantern demo.
          </span>
        </p>
      </div>
    </div>
    """
  end

  defp language_mod("sql"), do: LiveCode.Languages.SQL
  defp language_mod("json"), do: LiveCode.Languages.JSON
  defp language_mod("heex"), do: LiveCode.Languages.HEEx
  defp language_mod(_), do: LiveCode.Languages.HTML
end
