defmodule LiveCode.LanguageTest do
  use ExUnit.Case, async: true

  alias LiveCode.Language

  test "preview/2 returns a Preview struct for a previewable language" do
    assert %LiveCode.Preview{mode: :html, sandbox: true} =
             Language.preview(LiveCode.Languages.HTML)
  end

  test "preview/2 returns nil for languages that don't implement preview/1" do
    assert Language.preview(LiveCode.Languages.SQL) == nil
    assert Language.preview(LiveCode.Languages.JSON) == nil
  end

  test "preview/2 returns nil for an unknown / unloaded module" do
    assert Language.preview(NotALanguage) == nil
  end
end
