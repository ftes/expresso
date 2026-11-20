defmodule Expresso.Element.Lines do
  @moduledoc """
  Defines a group of lines in a code element

  `Expresso.Element.Code.build/1` makes one group for each item of the
  `reveal` option, with the specification `[from: :next]`. The groups are the
  children of the code element. Thus the transformer gives each group its
  steps, and the verifier compares each group with the code element. A group
  is not an entity of the DSL.

  A token group of the `highlight` option has the text of its tokens in
  `each`, and no line numbers.
  """

  @typedoc "The struct of a group of lines"
  @type t :: %__MODULE__{}

  defstruct [:each, numbers: []] ++ Expresso.Overlay.fields()
end
