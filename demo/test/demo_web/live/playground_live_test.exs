defmodule DemoWeb.PlaygroundLiveTest do
  use DemoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "selects every language and capability-gates editor features", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    for language <- ~w(html sql json heex) do
      assert has_element?(view, "#language-#{language}")
    end

    assert has_element?(view, "#editor-html-edit[data-livecode-preview=html]")
    assert has_element?(view, "#editor-html-edit textarea")

    view |> element("#language-heex") |> render_click()

    assert has_element?(view, "#editor-heex-readonly.lc-readonly")
    assert has_element?(view, "#mode-edit[disabled]")
    refute has_element?(view, "#editor-heex-readonly textarea")

    view |> element("#language-sql") |> render_click()
    view |> element("#mode-edit") |> render_click()

    assert has_element?(view, "#editor-sql-edit textarea")
    refute has_element?(view, "#editor-sql-edit [data-livecode-preview-pane]")

    view |> element("#language-json") |> render_click()
    view |> element("#mode-readonly") |> render_click()

    assert has_element?(view, "#editor-json-readonly.lc-readonly")
  end
end
