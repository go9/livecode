defmodule LiveCode.Languages.HEEx do
  @moduledoc """
  HEEx language module for LiveCode.

  Tokenizes Phoenix templates into HTML tokens plus HEEx-specific EEx blocks,
  directives, and brace interpolations. The tokenizer preserves the exact input
  text across all token text fields so read-only highlight overlays stay aligned.
  """

  @behaviour LiveCode.Language

  alias LiveCode.Context
  alias LiveCode.Snippet
  alias LiveCode.Token

  @name_prefix ~r/^[.A-Za-z_:][A-Za-z0-9_.:-]*/

  @impl true
  def tokenize(text, _opts \\ []) do
    text
    |> tokenize_text([])
    |> Enum.reverse()
  end

  @impl true
  def completions(%Context{}, _opts \\ []), do: []

  @impl true
  def diagnostics(_text, _opts \\ []), do: []

  @impl true
  def snippets(_opts \\ []) do
    [
      %Snippet{label: "if", insert_text: ~S(<div :if={}></div>), detail: "Conditional"},
      %Snippet{label: "for", insert_text: ~S(<div :for={item <- @items}></div>), detail: "Loop"},
      %Snippet{
        label: "case",
        insert_text: "<%= case @value do %>\n<% end %>",
        detail: "Case block"
      },
      %Snippet{label: "slot", insert_text: ~S(<:inner_block></:inner_block>), detail: "Slot"}
    ]
  end

  @impl true
  def format(_text, _opts \\ []), do: :noop

  @impl true
  def preview(_opts \\ []), do: nil

  defp tokenize_text("", acc), do: acc

  defp tokenize_text(<<"<%!--", _rest::binary>> = text, acc) do
    {comment, rest} = split_through(text, "--%>")
    tokenize_text(rest, [%Token{kind: :comment, text: comment} | acc])
  end

  defp tokenize_text(<<"<!--", _rest::binary>> = text, acc) do
    {comment, rest} = split_through(text, "-->")
    tokenize_text(rest, [%Token{kind: :comment, text: comment} | acc])
  end

  defp tokenize_text(<<"<%", _rest::binary>> = text, acc) do
    {eex, rest} = split_through(text, "%>")
    tokenize_text(rest, [%Token{kind: :eex, text: eex} | acc])
  end

  defp tokenize_text(<<"<", _rest::binary>> = text, acc) do
    {tag, rest} = split_tag(text)
    tokenize_text(rest, Enum.reverse(tokenize_tag(tag)) ++ acc)
  end

  defp tokenize_text(<<"{", _rest::binary>> = text, acc) do
    {interpolation, rest} = split_interpolation(text)
    tokenize_text(rest, [%Token{kind: :interpolation, text: interpolation} | acc])
  end

  defp tokenize_text(text, acc) do
    {plain, rest} = split_plain_text(text)
    tokenize_text(rest, [%Token{kind: :text, text: plain} | acc])
  end

  defp tokenize_tag(tag) do
    {tokens, rest, expect_name} =
      cond do
        String.starts_with?(tag, "</") ->
          {[%Token{kind: :bracket, text: "</"}], binary_part(tag, 2, byte_size(tag) - 2), true}

        String.starts_with?(tag, "<") ->
          {[%Token{kind: :bracket, text: "<"}], binary_part(tag, 1, byte_size(tag) - 1), true}

        true ->
          {[], tag, true}
      end

    rest
    |> tokenize_tag_parts(tokens, expect_name)
    |> Enum.reverse()
  end

  defp tokenize_tag_parts("", acc, _expect_name), do: acc

  defp tokenize_tag_parts(<<"/>", rest::binary>>, acc, expect_name) do
    tokenize_tag_parts(rest, [%Token{kind: :bracket, text: "/>"} | acc], expect_name)
  end

  defp tokenize_tag_parts(<<">", rest::binary>>, acc, expect_name) do
    tokenize_tag_parts(rest, [%Token{kind: :bracket, text: ">"} | acc], expect_name)
  end

  defp tokenize_tag_parts(<<"=", rest::binary>>, acc, expect_name) do
    tokenize_tag_parts(rest, [%Token{kind: :operator, text: "="} | acc], expect_name)
  end

  defp tokenize_tag_parts(<<"\"", _rest::binary>> = text, acc, expect_name) do
    {string, rest} = split_quoted(text, ?")
    tokenize_tag_parts(rest, [%Token{kind: :string, text: string} | acc], expect_name)
  end

  defp tokenize_tag_parts(<<"'", _rest::binary>> = text, acc, expect_name) do
    {string, rest} = split_quoted(text, ?')
    tokenize_tag_parts(rest, [%Token{kind: :string, text: string} | acc], expect_name)
  end

  defp tokenize_tag_parts(<<"{", _rest::binary>> = text, acc, expect_name) do
    {interpolation, rest} = split_interpolation(text)

    tokenize_tag_parts(
      rest,
      [%Token{kind: :interpolation, text: interpolation} | acc],
      expect_name
    )
  end

  defp tokenize_tag_parts(text, acc, expect_name) do
    cond do
      whitespace_start?(text) ->
        {whitespace, rest} = split_while(text, &whitespace?/1)
        tokenize_tag_parts(rest, [%Token{kind: :text, text: whitespace} | acc], expect_name)

      name_start?(text) ->
        {name, rest} = split_name(text)
        kind = tag_name_kind(name, expect_name)
        tokenize_tag_parts(rest, [%Token{kind: kind, text: name} | acc], false)

      true ->
        {char, rest} = split_char(text)
        tokenize_tag_parts(rest, [%Token{kind: :text, text: char} | acc], expect_name)
    end
  end

  defp tag_name_kind(_name, true), do: :tag
  defp tag_name_kind(<<":", _rest::binary>>, false), do: :directive
  defp tag_name_kind(_name, false), do: :attribute

  defp split_through(text, marker) do
    case :binary.match(text, marker) do
      {index, length} ->
        size = index + length
        {binary_part(text, 0, size), binary_part(text, size, byte_size(text) - size)}

      :nomatch ->
        {text, ""}
    end
  end

  defp split_tag(text) do
    size = find_tag_end(text, 1, :normal)
    {binary_part(text, 0, size), binary_part(text, size, byte_size(text) - size)}
  end

  defp find_tag_end(text, position, _state) when position >= byte_size(text), do: byte_size(text)

  defp find_tag_end(text, position, {:quote, quote}) do
    if :binary.at(text, position) == quote do
      find_tag_end(text, position + 1, :normal)
    else
      find_tag_end(text, position + 1, {:quote, quote})
    end
  end

  defp find_tag_end(text, position, {:interpolation, depth}) do
    case :binary.at(text, position) do
      ?{ ->
        find_tag_end(text, position + 1, {:interpolation, depth + 1})

      ?} when depth == 1 ->
        find_tag_end(text, position + 1, :normal)

      ?} ->
        find_tag_end(text, position + 1, {:interpolation, depth - 1})

      _ ->
        find_tag_end(text, position + 1, {:interpolation, depth})
    end
  end

  defp find_tag_end(text, position, :normal) do
    case :binary.at(text, position) do
      ?" -> find_tag_end(text, position + 1, {:quote, ?"})
      ?' -> find_tag_end(text, position + 1, {:quote, ?'})
      ?{ -> find_tag_end(text, position + 1, {:interpolation, 1})
      ?> -> position + 1
      _ -> find_tag_end(text, position + 1, :normal)
    end
  end

  defp split_interpolation(text) do
    size = find_interpolation_end(text, 1, 1)
    {binary_part(text, 0, size), binary_part(text, size, byte_size(text) - size)}
  end

  defp find_interpolation_end(text, position, _depth) when position >= byte_size(text),
    do: byte_size(text)

  defp find_interpolation_end(text, position, depth) do
    case :binary.at(text, position) do
      ?{ ->
        find_interpolation_end(text, position + 1, depth + 1)

      ?} when depth == 1 ->
        position + 1

      ?} ->
        find_interpolation_end(text, position + 1, depth - 1)

      _ ->
        find_interpolation_end(text, position + 1, depth)
    end
  end

  defp split_quoted(text, quote) do
    size = find_quote_end(text, 1, quote)
    {binary_part(text, 0, size), binary_part(text, size, byte_size(text) - size)}
  end

  defp find_quote_end(text, position, _quote) when position >= byte_size(text),
    do: byte_size(text)

  defp find_quote_end(text, position, quote) do
    if :binary.at(text, position) == quote do
      position + 1
    else
      find_quote_end(text, position + 1, quote)
    end
  end

  defp split_plain_text(text) do
    size = find_plain_text_end(text, 0)
    {binary_part(text, 0, size), binary_part(text, size, byte_size(text) - size)}
  end

  defp find_plain_text_end(text, position) when position >= byte_size(text), do: byte_size(text)

  defp find_plain_text_end(text, position) do
    case :binary.at(text, position) do
      ?< -> position
      ?{ -> position
      _ -> find_plain_text_end(text, position + 1)
    end
  end

  defp split_while(text, predicate), do: split_while(text, predicate, 0)

  defp split_while(text, _predicate, position) when position >= byte_size(text) do
    {text, ""}
  end

  defp split_while(text, predicate, position) do
    if predicate.(:binary.at(text, position)) do
      split_while(text, predicate, position + 1)
    else
      {binary_part(text, 0, position), binary_part(text, position, byte_size(text) - position)}
    end
  end

  defp split_name(text) do
    [name] = Regex.run(@name_prefix, text)
    size = byte_size(name)
    {name, binary_part(text, size, byte_size(text) - size)}
  end

  defp split_char(<<char::utf8, rest::binary>>), do: {<<char::utf8>>, rest}

  defp whitespace_start?(<<char, _rest::binary>>), do: whitespace?(char)

  defp whitespace?(char), do: char in [?\s, ?\t, ?\n, ?\r, ?\f]

  defp name_start?(<<char, _rest::binary>>) do
    char == ?. or char == ?: or char == ?_ or letter?(char)
  end

  defp letter?(char), do: char in ?A..?Z or char in ?a..?z
end
