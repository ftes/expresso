defmodule Expresso.Element.Frame do
  @moduledoc """
  Defines a frame of a chart or of a tree: its data at one point in time

  The `frame` entity takes a label as its argument, such as `"2024"`, and it
  holds one `series` entity for each series of the chart. Each frame after
  the first takes one step. The marks of the chart move from the values of
  one frame to the values of the next. `Expresso.Element.Chart` makes sure
  that the frames are valid and draws them, and
  `docs/reference/chart-element.md` gives the rules.

  The transform of the chart puts the series of the first frame into the
  `elements` field of the chart. It does this so that `reveal` and `dim` work
  as for a chart without frames. `Expresso.Overlay.Expand` writes the steps of
  each frame into its `steps` field.

  A frame in a chart of flows can hold `flow` entities in place of a series.
  `Expresso.Element.Chart.check/1` changes them into one series.

  A frame of a tree holds `node` entities in place of a series: the whole
  tree at that point in time. `Expresso.Element.Hierarchy` makes sure that
  they are valid and draws them.
  """

  @typedoc "The struct of a frame"
  @type t :: %__MODULE__{
          label: String.t(),
          elements: [Expresso.Element.Series.t() | Expresso.Element.Node.t()],
          at: Expresso.Overlay.t() | nil,
          steps: [pos_integer()] | nil
        }

  defstruct [:label, :at, :steps, elements: [], flows: [], __spark_metadata__: nil]
end
