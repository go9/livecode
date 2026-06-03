defmodule LiveCode.Completion do
  @moduledoc "A completion item shown by the LiveCode suggestion popup."

  @enforce_keys [:label]
  defstruct [:label, :kind, :insert_text, :detail]

  @type t :: %__MODULE__{
          label: String.t(),
          kind: atom() | nil,
          insert_text: String.t() | nil,
          detail: String.t() | nil
        }
end
