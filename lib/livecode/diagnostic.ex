defmodule LiveCode.Diagnostic do
  @moduledoc "A language diagnostic rendered below the editor."

  @enforce_keys [:message]
  defstruct [:message, severity: :error, line: nil, column: nil]

  @type severity :: :error | :warning | :info
  @type t :: %__MODULE__{
          message: String.t(),
          severity: severity(),
          line: non_neg_integer() | nil,
          column: non_neg_integer() | nil
        }
end
