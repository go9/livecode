defmodule LiveCodeTest do
  use ExUnit.Case, async: true

  alias LiveCode.{Context, Language}

  test "exposes bundled asset paths" do
    assert LiveCode.hook_path() =~ "livecode.js"
    assert LiveCode.css_path() =~ "livecode.css"
  end

  test "SQL language tokenizes keywords and strings" do
    tokens = LiveCode.Languages.SQL.tokenize("SELECT 'Ada' FROM users")

    assert Enum.any?(tokens, &(&1.kind == :keyword and String.upcase(&1.text) == "SELECT"))
    assert Enum.any?(tokens, &(&1.kind == :string and &1.text == "'Ada'"))
  end

  test "SQL language returns schema completions" do
    completions =
      Language.completions(
        LiveCode.Languages.SQL,
        %Context{metadata: %{tables: [%{schema: "public", name: "users"}], columns: ["id"]}}
      )

    assert Enum.any?(completions, &(&1.kind == :table and &1.label == "public.users"))
    assert Enum.any?(completions, &(&1.kind == :column and &1.label == "id"))
  end

  test "JSON language reports parse diagnostics" do
    assert [%{severity: :error}] = LiveCode.Languages.JSON.diagnostics("{")
    assert [] = LiveCode.Languages.JSON.diagnostics(~s({"ok": true}))
  end

  test "JSON language formats valid JSON" do
    assert {:ok, formatted} = LiveCode.Languages.JSON.format(~s({"ok":true}))
    assert formatted =~ ~s("ok")
  end
end
