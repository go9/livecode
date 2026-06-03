defmodule LiveCode.Languages.JSON do
  @moduledoc "JSON language module for LiveCode."

  @behaviour LiveCode.Language

  alias LiveCode.{Completion, Context, Diagnostic, Snippet, Token}

  @impl true
  def tokenize(text, _opts \\ []) do
    ~r/("(?:\\.|[^"])*"|-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?|true|false|null|[{}\[\]:,])/m
    |> Regex.split(text, include_captures: true, trim: false)
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(&token/1)
  end

  @impl true
  def completions(%Context{}, _opts \\ []) do
    [
      %Completion{label: "object", kind: :snippet, insert_text: "{\n  \"key\": \"value\"\n}"},
      %Completion{label: "array", kind: :snippet, insert_text: "[\n  \n]"},
      %Completion{label: "true", kind: :literal, insert_text: "true"},
      %Completion{label: "false", kind: :literal, insert_text: "false"},
      %Completion{label: "null", kind: :literal, insert_text: "null"}
    ]
  end

  @impl true
  def diagnostics(text, opts \\ [])
  def diagnostics("", _opts), do: []

  def diagnostics(text, _opts) do
    case Jason.decode(text) do
      {:ok, _} -> []
      {:error, error} -> [%Diagnostic{message: Exception.message(error), severity: :error}]
    end
  end

  @impl true
  def snippets(_opts \\ []) do
    [
      %Snippet{label: "object", insert_text: "{\n  \"key\": \"value\"\n}", detail: "JSON object"},
      %Snippet{label: "array", insert_text: "[\n  \n]", detail: "JSON array"}
    ]
  end

  @impl true
  def format(text, opts \\ [])
  def format("", _opts), do: {:ok, ""}

  def format(text, _opts) do
    with {:ok, decoded} <- Jason.decode(text),
         {:ok, encoded} <- Jason.encode(decoded, pretty: true) do
      {:ok, encoded}
    else
      _ -> :noop
    end
  end

  defp token(text) do
    cond do
      String.match?(text, ~r/^\s+$/) -> %Token{kind: :whitespace, text: text}
      String.starts_with?(text, "\"") -> %Token{kind: :string, text: text}
      text in ["true", "false"] -> %Token{kind: :boolean, text: text}
      text == "null" -> %Token{kind: :null, text: text}
      String.match?(text, ~r/^-?\d/) -> %Token{kind: :number, text: text}
      text in ["{", "}", "[", "]"] -> %Token{kind: :bracket, text: text}
      text in [":", ","] -> %Token{kind: :operator, text: text}
      true -> %Token{kind: :text, text: text}
    end
  end
end
