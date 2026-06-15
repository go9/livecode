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

  test "HTML language tokenizes tags, attributes, values, and comments" do
    source = ~s(<a href="/x">hi</a><!-- c -->)
    tokens = LiveCode.Languages.HTML.tokenize(source)

    assert Enum.any?(tokens, &(&1.kind == :tag and &1.text == "a"))
    assert Enum.any?(tokens, &(&1.kind == :attribute and &1.text == "href"))
    assert Enum.any?(tokens, &(&1.kind == :string and &1.text == ~s("/x")))
    assert Enum.any?(tokens, &(&1.kind == :comment and &1.text == "<!-- c -->"))

    # Lossless: concatenated token text must reproduce the source exactly,
    # or the highlight overlay would drift out of sync with the textarea.
    assert Enum.map_join(tokens, & &1.text) == source
  end

  test "HTML language offers tag and attribute completions" do
    completions = Language.completions(LiveCode.Languages.HTML, %Context{})

    assert Enum.any?(completions, &(&1.kind == :tag and &1.label == "div"))
    assert Enum.any?(completions, &(&1.kind == :attribute and &1.label == "href"))
  end

  test "HTML language keeps body-text apostrophes as text, not strings" do
    source = "<p>we'll make it right &mdash; doesn't it?</p>"
    tokens = LiveCode.Languages.HTML.tokenize(source)

    # The apostrophes are in body text, so no :string token should appear and
    # the words between them must stay intact.
    refute Enum.any?(tokens, &(&1.kind == :string))
    assert Enum.map_join(tokens, & &1.text) == source
  end
end
