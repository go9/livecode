defmodule LiveCode.Snippet do
  @moduledoc "A reusable snippet exposed by a language module."

  @enforce_keys [:label, :insert_text]
  defstruct [:label, :insert_text, :detail]

  @type t :: %__MODULE__{
          label: String.t(),
          insert_text: String.t(),
          detail: String.t() | nil
        }
end
