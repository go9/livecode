defmodule LiveCode.Context do
  @moduledoc "Context passed to language completion providers."

  defstruct text: "", cursor: nil, metadata: %{}

  @type t :: %__MODULE__{
          text: String.t(),
          cursor: non_neg_integer() | nil,
          metadata: map()
        }
end
