defmodule LiveCode.Languages.HTML do
  @moduledoc """
  HTML language module for LiveCode.

  Tokenizes markup into tags, attributes, attribute values, comments and
  text, and offers tag/attribute completions plus a few structural snippets.

  Live (as-you-type) highlighting is performed client-side by `highlightHtml`
  in `priv/static/livecode/livecode.js`; this module produces the matching
  server-rendered token stream (initial paint) and the completion list.

  Tokenizing is two-phase so quotes are only treated as attribute-value
  strings *inside* a tag — an apostrophe in body text (e.g. "doesn't") stays
  plain text rather than opening a bogus string that swallows the next words.

  Token kinds: `:comment`, `:bracket`, `:tag`, `:attribute`, `:string`,
  `:operator`, `:text`.
  """

  @behaviour LiveCode.Language

  alias LiveCode.Completion
  alias LiveCode.Context
  alias LiveCode.Snippet
  alias LiveCode.Token

  # Phase 1: peel comments and whole tags off the text. A tag is `<` up to the
  # next `>` (attribute values are expected to escape literal `>` as `&gt;`).
  @segment_pattern ~r/<!--[\s\S]*?-->|<[^>]*>/

  # Phase 2: inside a tag — punctuation, quoted values, names, `=`, runs of
  # whitespace, and a single-char catch-all last so concatenated token text
  # always reproduces the source (the highlight overlay can never desync).
  @tag_pattern ~r/<\/?|\/?>|"[^"]*"|'[^']*'|[A-Za-z_:][\w.:-]*|=|\s+|./

  @name_pattern ~r/^[A-Za-z_:][\w.:-]*$/

  @tags ~w(
    a abbr address article aside b blockquote br button code col colgroup dd
    details div dl dt em figure footer h1 h2 h3 h4 h5 h6 header hr i img li
    main mark nav ol p pre section small span strong sub summary sup table
    tbody td tfoot th thead time tr u ul
  )

  @attributes ~w(
    alt class colspan height href id rowspan src style target title width
  )

  @impl true
  def tokenize(text, _opts \\ []) do
    @segment_pattern
    |> Regex.split(text, include_captures: true, trim: false)
    |> Enum.reject(&(&1 == ""))
    |> Enum.flat_map(&tokenize_segment/1)
  end

  @impl true
  def completions(%Context{}, _opts \\ []) do
    tag_items =
      Enum.map(@tags, &%Completion{label: &1, kind: :tag, insert_text: &1})

    attribute_items =
      Enum.map(@attributes, &%Completion{label: &1, kind: :attribute, insert_text: &1})

    snippet_items =
      Enum.map(
        snippets(),
        &%Completion{
          label: &1.label,
          kind: :snippet,
          insert_text: &1.insert_text,
          detail: &1.detail
        }
      )

    tag_items ++ attribute_items ++ snippet_items
  end

  @impl true
  def diagnostics(_text, _opts \\ []), do: []

  @impl true
  def snippets(_opts \\ []) do
    [
      %Snippet{label: "link", insert_text: ~s(<a href="">text</a>), detail: "Anchor"},
      %Snippet{label: "image", insert_text: ~s(<img src="" alt="">), detail: "Image"},
      %Snippet{label: "list", insert_text: "<ul>\n  <li></li>\n</ul>", detail: "Unordered list"},
      %Snippet{label: "paragraph", insert_text: "<p></p>", detail: "Paragraph"},
      %Snippet{label: "heading", insert_text: "<h2></h2>", detail: "Heading"}
    ]
  end

  @impl true
  def format(_text, _opts \\ []), do: :noop

  defp tokenize_segment(<<"<!--", _rest::binary>> = segment),
    do: [%Token{kind: :comment, text: segment}]

  defp tokenize_segment(<<"<", _rest::binary>> = segment), do: tokenize_tag(segment)

  defp tokenize_segment(segment), do: [%Token{kind: :text, text: segment}]

  defp tokenize_tag(segment) do
    {tokens, _state} =
      @tag_pattern
      |> Regex.scan(segment)
      |> Enum.map(fn [match] -> match end)
      |> Enum.map_reduce(%{expect_name: true}, &classify_tag/2)

    tokens
  end

  # The first name after the opening `<`/`</` is the element name; later names
  # are attributes.
  defp classify_tag(part, state) when part in ["<", "</"],
    do: {%Token{kind: :bracket, text: part}, %{state | expect_name: true}}

  defp classify_tag(part, state) when part in [">", "/>"],
    do: {%Token{kind: :bracket, text: part}, state}

  defp classify_tag(<<?\", _rest::binary>> = part, state),
    do: {%Token{kind: :string, text: part}, state}

  defp classify_tag(<<?\', _rest::binary>> = part, state),
    do: {%Token{kind: :string, text: part}, state}

  defp classify_tag("=", state), do: {%Token{kind: :operator, text: "="}, state}

  defp classify_tag(part, %{expect_name: true} = state) do
    if name?(part) do
      {%Token{kind: :tag, text: part}, %{state | expect_name: false}}
    else
      {%Token{kind: :text, text: part}, state}
    end
  end

  defp classify_tag(part, state) do
    if name?(part) do
      {%Token{kind: :attribute, text: part}, state}
    else
      {%Token{kind: :text, text: part}, state}
    end
  end

  defp name?(part), do: String.match?(part, @name_pattern)
end
