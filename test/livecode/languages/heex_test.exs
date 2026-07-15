defmodule LiveCode.Languages.HEExTest do
  use ExUnit.Case, async: true

  alias LiveCode.Languages.HEEx

  describe "tokenize/2" do
    test "preserves input exactly for representative HEEx" do
      inputs = [
        ~s(<div class="a">hi</div>),
        ~s(<.button :if={@ok} phx-click="go">{@label}</.button>),
        ~s(<%= @user.name %>),
        ~s(<%!-- a comment --%>),
        ~s(<span>{%{a: 1, b: [2, 3]}}</span>),
        ~s(before {@a} after),
        ~s(<div class={if @ok, do: "a > b", else: "c"}>ok</div>),
        ~s(<!-- html comment -->)
      ]

      for input <- inputs do
        assert HEEx.tokenize(input) |> Enum.map_join(& &1.text) == input
      end
    end

    test "tokenizes HTML tags and attributes" do
      tokens = HEEx.tokenize(~s(<div class="a">hi</div>))

      assert_token(tokens, :tag, "div")
      assert_token(tokens, :attribute, "class")
      assert_token(tokens, :string, ~s("a"))
      assert_token(tokens, :text, "hi")
      assert_token(tokens, :tag, "div")
    end

    test "tokenizes HEEx directives and interpolations" do
      tokens = HEEx.tokenize(~s(<.button :if={@ok} phx-click="go">{@label}</.button>))

      assert_token(tokens, :tag, ".button")
      assert_token(tokens, :directive, ":if")
      assert_token(tokens, :interpolation, "{@ok}")
      assert_token(tokens, :attribute, "phx-click")
      assert_token(tokens, :string, ~s("go"))
      assert_token(tokens, :interpolation, "{@label}")
      assert_token(tokens, :tag, ".button")
    end

    test "tokenizes an EEx block as one token" do
      input = ~s(<%= @user.name %>)

      assert [%{kind: :eex, text: ^input}] = HEEx.tokenize(input)
    end

    test "tokenizes an EEx comment as one token" do
      input = ~s(<%!-- a comment --%>)

      assert [%{kind: :comment, text: ^input}] = HEEx.tokenize(input)
    end

    test "depth-matches nested interpolation braces" do
      tokens = HEEx.tokenize(~s(<span>{%{a: 1, b: [2, 3]}}</span>))

      assert_token(tokens, :interpolation, "{%{a: 1, b: [2, 3]}}")
    end

    test "tokenizes body text around interpolation" do
      tokens = HEEx.tokenize(~s(before {@a} after))

      assert [
               %{kind: :text, text: "before "},
               %{kind: :interpolation, text: "{@a}"},
               %{kind: :text, text: " after"}
             ] = tokens
    end
  end

  test "non-token callbacks are inert for read-only highlighting" do
    assert HEEx.completions(%LiveCode.Context{}) == []
    assert HEEx.diagnostics("bad?") == []
    assert HEEx.format("anything") == :noop
    assert HEEx.preview() == nil
    assert length(HEEx.snippets()) in 3..4
  end

  defp assert_token(tokens, kind, text) do
    assert Enum.any?(tokens, &(&1.kind == kind and &1.text == text)),
           "expected #{inspect(kind)} token with text #{inspect(text)} in #{inspect(tokens)}"
  end
end
