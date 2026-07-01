defmodule DemoWeb.PageControllerTest do
  use DemoWeb.ConnCase

  test "GET / renders the livecode playground with a previewable HTML editor", %{conn: conn} do
    conn = get(conn, ~p"/")
    html = html_response(conn, 200)

    assert html =~ "LiveView-native syntax highlighting"
    # HTML is previewable → the editor renders the Code/Preview/Split toolbar.
    assert html =~ "data-livecode-preview=\"html\""
    assert html =~ "data-livecode-view-btn=\"split\""
  end
end
