defmodule Expresso.Presenter.Dsl do
  @moduledoc """
  Lets a module write a presenter definition in the presenter DSL

  `use Expresso.Presenter.Dsl` adds the DSL of `Expresso.Presenter.Extension`
  to a module. `Expresso.Presenter.Default` uses it.
  """

  use Spark.Dsl,
    default_extensions: [extensions: [Expresso.Presenter.Extension]]
end
