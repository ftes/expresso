defmodule Expresso.Element.MathReduce do
  @moduledoc """
  Describes a line of a derivation that one β-reduction makes from a line before it

  The `reduce` entity takes the redex as its first argument. The argument is
  the name of a `\\part` in the old line that holds the redex, or `:leftmost`
  for the leftmost outermost redex. The entity makes its line from the line
  before it, or from the line that `from` names. The default relation is
  `\\to_\\beta`, and the default reason is the variable, `:=` and the argument.

  A reduction takes four steps: `:redex`, `:bound`, `:body` and `:argument`.
  `steps` takes a list of groups, and each group is one step, such as
  `[[:redex, :bound], :body, :argument]`.

  `Expresso.Element.Math.Rewrite.expand/1` makes a line from each reduce with
  `Expresso.Element.Math.Reduce.prepare/3`. `docs/beta-reductions.md` gives
  the design.
  """

  @typedoc "The struct of a β-reduction of a derivation"
  @type t :: %__MODULE__{}

  defstruct [:redex, :relation, :from, :why, :name, :steps, __spark_metadata__: nil]
end
