defmodule LiveCode.Languages.SQL do
  @moduledoc "PostgreSQL-oriented language module for LiveCode."

  @behaviour LiveCode.Language

  alias LiveCode.{Completion, Context, Snippet, Token}

  @keywords MapSet.new(~w(
    alter analyze and as asc begin by case cast check column commit constraint create
    delete desc distinct drop else end except explain false foreign from full group having
    in index inner insert intersect into is join key left limit not null on or order outer
    primary references returning right rollback select set table then true union unique update
    values view where with
  ))

  @operators MapSet.new([
               "+",
               "-",
               "*",
               "/",
               "=",
               "<",
               ">",
               "<=",
               ">=",
               "<>",
               "!=",
               "||",
               "::",
               ".",
               ",",
               ";",
               "(",
               ")"
             ])

  @impl true
  def tokenize(text, _opts \\ []) do
    ~r/(--.*$|\/\*[\s\S]*?\*\/|'(?:''|[^'])*'|"(?:""|[^"])*"|\b\d+(?:\.\d+)?\b|[A-Za-z_][A-Za-z0-9_$]*|<=|>=|<>|!=|\|\||::|[+\-*\/=<>.,;()])/m
    |> Regex.split(text, include_captures: true, trim: false)
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(&token/1)
  end

  @impl true
  def completions(%Context{metadata: metadata}, _opts \\ []) do
    keyword_items =
      @keywords
      |> Enum.sort()
      |> Enum.map(
        &%Completion{label: String.upcase(&1), kind: :keyword, insert_text: String.upcase(&1)}
      )

    schema_items =
      metadata
      |> Map.get(:schemas, Map.get(metadata, "schemas", []))
      |> Enum.map(&%Completion{label: to_string(&1), kind: :schema, insert_text: quote_ident(&1)})

    table_items =
      metadata
      |> Map.get(:tables, Map.get(metadata, "tables", []))
      |> Enum.map(&table_completion/1)

    column_items =
      metadata
      |> Map.get(:columns, Map.get(metadata, "columns", []))
      |> Enum.map(&column_completion/1)

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

    schema_items ++ table_items ++ column_items ++ keyword_items ++ snippet_items
  end

  @impl true
  def diagnostics(_text, _opts \\ []), do: []

  @impl true
  def snippets(_opts \\ []) do
    [
      %Snippet{label: "select template", insert_text: "SELECT *\nFROM", detail: "Basic SELECT"},
      %Snippet{
        label: "count template",
        insert_text: "SELECT count(*)\nFROM",
        detail: "Count rows"
      },
      %Snippet{label: "join template", insert_text: "JOIN ON", detail: "JOIN clause"},
      %Snippet{label: "where template", insert_text: "WHERE", detail: "WHERE clause"},
      %Snippet{label: "group by template", insert_text: "GROUP BY", detail: "GROUP BY clause"}
    ]
  end

  @impl true
  def format(_text, _opts \\ []), do: :noop

  defp token(<<"--", _rest::binary>> = text), do: %Token{kind: :comment, text: text}
  defp token(<<"/*", _rest::binary>> = text), do: %Token{kind: :comment, text: text}
  defp token(<<"'", _rest::binary>> = text), do: %Token{kind: :string, text: text}
  defp token(<<"\"", _rest::binary>> = text), do: %Token{kind: :identifier, text: text}

  defp token(text) do
    down = String.downcase(text)

    cond do
      String.match?(text, ~r/^\d+(?:\.\d+)?$/) -> %Token{kind: :number, text: text}
      MapSet.member?(@keywords, down) -> %Token{kind: :keyword, text: text}
      MapSet.member?(@operators, text) -> %Token{kind: :operator, text: text}
      String.match?(text, ~r/^\s+$/) -> %Token{kind: :whitespace, text: text}
      String.match?(text, ~r/^[A-Za-z_][A-Za-z0-9_$]*$/) -> %Token{kind: :identifier, text: text}
      true -> %Token{kind: :text, text: text}
    end
  end

  defp table_completion(%{schema: schema, name: name}) do
    %Completion{
      label: "#{schema}.#{name}",
      kind: :table,
      insert_text: "#{quote_ident(schema)}.#{quote_ident(name)}"
    }
  end

  defp table_completion(%{"schema" => schema, "name" => name}),
    do: table_completion(%{schema: schema, name: name})

  defp table_completion(name),
    do: %Completion{label: to_string(name), kind: :table, insert_text: quote_ident(name)}

  defp column_completion(%{table: table, name: name}) do
    %Completion{
      label: "#{table}.#{name}",
      kind: :column,
      insert_text: quote_ident(name),
      detail: to_string(table)
    }
  end

  defp column_completion(%{"table" => table, "name" => name}),
    do: column_completion(%{table: table, name: name})

  defp column_completion(name),
    do: %Completion{label: to_string(name), kind: :column, insert_text: quote_ident(name)}

  defp quote_ident(value), do: ~s("#{String.replace(to_string(value), "\"", "\"\"")}")
end
