defmodule LiveCode.EditorTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest
  import LiveCode.Editor

  test "renders textarea, line numbers, tokens, completions, and diagnostics" do
    html =
      render_component(&editor/1,
        id: "json-editor",
        language: LiveCode.Languages.JSON,
        value: "{",
        context: %{},
        opts: [],
        name: "payload",
        rows: 4,
        class: nil
      )

    assert html =~ ~s(id="json-editor")
    assert html =~ ~s(name="payload")
    assert html =~ "lc-token-bracket"
    assert html =~ "lc-completion"
    assert html =~ "lc-diagnostic-error"
  end

  test "gutter carries the scroll-sync hook target" do
    html = render_component(&editor/1, id: "g", language: LiveCode.Languages.SQL, value: "a\nb")
    assert html =~ "data-livecode-gutter"
  end

  test "a previewable language renders the Code/Preview/Split toolbar + preview pane" do
    html =
      render_component(&editor/1,
        id: "html-editor",
        language: LiveCode.Languages.HTML,
        value: "<h1>hi</h1>"
      )

    assert html =~ "lc-has-preview"
    assert html =~ "lc-view-code"
    assert html =~ "lc-toolbar"
    assert html =~ ~s(data-livecode-view-btn="code")
    assert html =~ ~s(data-livecode-view-btn="split")
    assert html =~ ~s(data-livecode-view-btn="preview")
    assert html =~ "data-livecode-preview-pane"
    assert html =~ ~s(data-livecode-preview="html")
    assert html =~ ~s(data-livecode-sandbox="true")
  end

  test "non-previewable languages render no preview UI" do
    html =
      render_component(&editor/1,
        id: "sql-editor",
        language: LiveCode.Languages.SQL,
        value: "select 1"
      )

    refute html =~ "lc-toolbar"
    refute html =~ "data-livecode-preview-pane"
    refute html =~ "lc-has-preview"
  end

  test "preview: :off hides preview UI even for a previewable language" do
    html =
      render_component(&editor/1,
        id: "html-off",
        language: LiveCode.Languages.HTML,
        value: "<p>x</p>",
        preview: :off
      )

    refute html =~ "lc-toolbar"
    refute html =~ "data-livecode-preview-pane"
  end

  test "transform attr is wired to the root for consumer preview transforms" do
    html =
      render_component(&editor/1,
        id: "html-tx",
        language: LiveCode.Languages.HTML,
        value: "<p>x</p>",
        transform: "ebay"
      )

    assert html =~ ~s(data-livecode-transform="ebay")
  end
end
