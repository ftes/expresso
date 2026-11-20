defmodule Expresso.LinkPreviewVerifier do
  @moduledoc """
  Makes sure, as a Spark verifier, that a deck with a `card` option has a `url` option

  The `card` option gives the picture of a link preview, and the tag `og:image`
  holds its absolute address. The address comes from the `url` option, so a
  deck with a card and with no address is an error at compile time.
  `Expresso.LinkPreview` holds the rules of the options.
  """

  use Spark.Dsl.Verifier

  alias Spark.Dsl.Verifier

  @doc """
  Return an error for a deck with the `card` option and no `url` option
  """
  @impl Verifier
  @spec verify(map()) :: :ok | {:error, Spark.Error.DslError.t()}
  def verify(dsl_state) do
    card = Verifier.get_option(dsl_state, [:deck], :card)
    url = Verifier.get_option(dsl_state, [:deck], :url)

    if card != nil and url == nil do
      {:error,
       Spark.Error.DslError.exception(
         module: Verifier.get_persisted(dsl_state, :module),
         path: [:deck, :card],
         message: Expresso.LinkPreview.card_needs_url()
       )}
    else
      :ok
    end
  end
end
