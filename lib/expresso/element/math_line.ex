defmodule Expresso.Element.MathLine do
  @moduledoc """
  Describes a line of a derivation in a `math` element

  The `line` entity takes the relation of the line as its first argument, such
  as `"="` or `~S"\\to_\\beta"`, in LaTeX. The `tex` option gives the term of
  the line in LaTeX, and the `why` option gives the reason as plain text.
  `Expresso.Element.Math.check/1` writes the lines into one formula of the
  environment `aligned`, so the lines align on their relations. In this
  formula, each line becomes a part with the name `line1`, `line2` and so on,
  or with its `name`.

  The `steps` option takes 1 or 2. With 2, the links of the line move at its
  first step, and the other symbols of the line show at the next step.

  A line from a `rewrite` entity has a step for each group of its phases. When
  the rewrite gives no `why`, the field `why_tex` holds the reason in LaTeX.
  The field `rewrite` holds the colors of the line's parts and the steps when
  the line's copies move. `Expresso.Element.Math.Rewrite.expand/1` writes the
  steps and the fields `why_tex` and `rewrite`.
  """

  @typedoc "The struct of a line of a derivation"
  @type t :: %__MODULE__{}

  defstruct [
    :relation,
    :tex,
    :why,
    :why_tex,
    :name,
    :rewrite,
    steps: 1,
    __spark_metadata__: nil
  ]
end
