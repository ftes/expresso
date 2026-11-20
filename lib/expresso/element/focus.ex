defmodule Expresso.Element.Focus do
  @moduledoc """
  Defines a group in the `highlight` option of a chart

  `Expresso.Element.Chart.check/1` makes one group for each item of the
  option, with the specification `:next`. The groups go into the `focus`
  field of the chart, and not into its series. `Expresso.Overlay.Expand`
  gives each group one step from the counter of the slide. At that step,
  `Expresso.Element.Chart.rules/1` dims each part of the chart that is not in
  the group. A group is not an entity of the DSL.

  A group holds series or categories, and not both:

  - The `series` field holds the color number of each series in the group,
    from 1. The `data-series` attribute of the series also holds the color
    number.
  - The `keys` field holds the key of each category in the group, such as
    `"c2"` for the second category. A key can also be `"p3"` for the part or
    the group with the id 3 in a treemap or a sunburst. Each mark of a
    category has its key in its `data-keys` attribute. A chart of flows takes
    nodes in place of categories, such as `"n2"` for the second node.
  """

  @typedoc "The struct of a group of the highlight option"
  @type t :: %__MODULE__{}

  defstruct [series: [], keys: []] ++ Expresso.Overlay.fields()
end
