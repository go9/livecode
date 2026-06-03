defmodule LiveCode do
  @moduledoc """
  LiveView-native syntax highlighting, autocomplete, snippets, and diagnostics
  for textareas.

  LiveCode is not a browser IDE. It keeps the browser's native `<textarea>` as
  the editing surface, then layers syntax highlighting, suggestions,
  diagnostics, and language-aware helpers around it with a small LiveView hook.

  Use `LiveCode.Editor.editor/1` in HEEx and provide a language module that
  implements `LiveCode.Language`.
  """

  @doc "Returns the bundled JavaScript hook source path."
  @spec hook_path() :: String.t()
  def hook_path, do: Path.join(:code.priv_dir(:livecode), "static/livecode/livecode.js")

  @doc "Returns the bundled CSS source path."
  @spec css_path() :: String.t()
  def css_path, do: Path.join(:code.priv_dir(:livecode), "static/livecode/livecode.css")
end
