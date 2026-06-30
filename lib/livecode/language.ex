defmodule LiveCode.Language do
  @moduledoc """
  Behaviour for LiveCode language modules.

  A language module describes meaning. The editor shell owns browser mechanics;
  language modules own tokens, completions, snippets, diagnostics, and optional
  formatting.
  """

  alias LiveCode.{Completion, Context, Diagnostic, Preview, Snippet, Token}

  @callback tokenize(text :: String.t(), opts :: keyword()) :: [Token.t()]
  @callback completions(context :: Context.t(), opts :: keyword()) :: [Completion.t()]
  @callback diagnostics(text :: String.t(), opts :: keyword()) :: [Diagnostic.t()]
  @callback snippets(opts :: keyword()) :: [Snippet.t()]
  @callback format(text :: String.t(), opts :: keyword()) :: {:ok, String.t()} | :noop
  @callback preview(opts :: keyword()) :: Preview.t() | nil

  @optional_callbacks completions: 2, diagnostics: 2, snippets: 1, format: 2, preview: 1

  @doc "Safely tokenize text with a language module."
  @spec tokenize(module(), String.t(), keyword()) :: [Token.t()]
  def tokenize(language, text, opts \\ []) when is_atom(language) and is_binary(text) do
    if exported?(language, :tokenize, 2), do: language.tokenize(text, opts), else: []
  end

  @doc "Safely ask a language module for completions."
  @spec completions(module(), Context.t(), keyword()) :: [Completion.t()]
  def completions(language, %Context{} = context, opts \\ []) when is_atom(language) do
    if exported?(language, :completions, 2), do: language.completions(context, opts), else: []
  end

  @doc "Safely ask a language module for diagnostics."
  @spec diagnostics(module(), String.t(), keyword()) :: [Diagnostic.t()]
  def diagnostics(language, text, opts \\ []) when is_atom(language) and is_binary(text) do
    if exported?(language, :diagnostics, 2), do: language.diagnostics(text, opts), else: []
  end

  @doc "Safely ask a language module for snippets."
  @spec snippets(module(), keyword()) :: [Snippet.t()]
  def snippets(language, opts \\ []) when is_atom(language) do
    if exported?(language, :snippets, 1), do: language.snippets(opts), else: []
  end

  @doc "Safely format text with a language module."
  @spec format(module(), String.t(), keyword()) :: {:ok, String.t()} | :noop
  def format(language, text, opts \\ []) when is_atom(language) and is_binary(text) do
    if exported?(language, :format, 2), do: language.format(text, opts), else: :noop
  end

  @doc """
  Ask a language module for its preview descriptor, or `nil` if it doesn't
  support preview. A language is previewable iff it exports `preview/1` and that
  returns a `LiveCode.Preview` struct.
  """
  @spec preview(module(), keyword()) :: Preview.t() | nil
  def preview(language, opts \\ []) when is_atom(language) do
    case exported?(language, :preview, 1) && language.preview(opts) do
      %Preview{} = preview -> preview
      _ -> nil
    end
  end

  defp exported?(language, function, arity) do
    Code.ensure_loaded?(language) and function_exported?(language, function, arity)
  end
end
