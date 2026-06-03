defmodule LiveCode.Token do
  @moduledoc "A syntax token returned by a `LiveCode.Language`."

  @enforce_keys [:kind, :text]
  defstruct [:kind, :text]

  @type kind :: atom()
  @type t :: %__MODULE__{kind: kind(), text: String.t()}
end
