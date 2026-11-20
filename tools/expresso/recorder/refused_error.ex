defmodule Expresso.Recorder.RefusedError do
  @moduledoc """
  Reports that Chromium refused a screenshot

  Chromium can refuse a screenshot with the message `Unable to capture
  screenshot`. `Expresso.Recorder.record/4` then records the example again in
  a new page.
  """

  defexception [:error]

  @typedoc "The exception, with the error that Playwright returned"
  @type t :: %__MODULE__{error: term()}

  @impl true
  def message(%__MODULE__{error: error}), do: "Chromium refused the screenshot: #{inspect(error)}"
end
