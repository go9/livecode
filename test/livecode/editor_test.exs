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
end
