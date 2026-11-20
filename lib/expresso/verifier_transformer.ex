defmodule Expresso.VerifierTransformer do
  @moduledoc """
  Runs the checks that return only errors, as a Spark transformer

  The transformer runs one time for each deck module at compile time, and an
  error stops the compile.

  The checks change nothing. They run in a transformer and not as verifiers,
  because Spark raises an error from a transformer, and the compile stops.
  Spark runs a verifier in an `@after_verify` callback, and it reports the
  error of a verifier as a warning. `Expresso.PlacementTransformer` is a
  transformer for the same reason. The checks that return only warnings stay
  verifiers of `Expresso.Extension`.
  """

  use Spark.Dsl.Transformer

  alias Spark.Dsl.Transformer
  alias Spark.Error.DslError

  # The checks that give only errors, in the sequence that they run.
  @checks [
    Expresso.GotoVerifier,
    Expresso.Overlay.Verifier,
    Expresso.Overlay.EffectVerifier,
    Expresso.TransitionVerifier
  ]

  @doc """
  Return the modules of the checks that this transformer runs

      iex> Expresso.Overlay.EffectVerifier in Expresso.VerifierTransformer.checks()
      true
  """
  @spec checks() :: [module()]
  def checks, do: @checks

  @doc """
  Run this transformer after each other transformer

  The checks read the steps and the names of the style sheet, which the other
  transformers write.
  """
  @impl Transformer
  @spec after?(module()) :: boolean()
  def after?(_transformer), do: true

  @doc """
  Run each check on the state of the DSL, and return an error for each error of a check

  The function calls `verify/1` of each module in `checks/0`. For more than
  one error, it returns one `Spark.Error.DslError` with the message of each
  error.
  """
  @impl Transformer
  @spec transform(map()) :: {:ok, map()} | {:error, DslError.t()}
  def transform(dsl_state) do
    errors =
      Enum.flat_map(@checks, fn check ->
        case check.verify(dsl_state) do
          :ok -> []
          {:error, error} -> List.wrap(error)
        end
      end)

    case errors do
      [] -> {:ok, dsl_state}
      [error] -> {:error, error}
      errors -> {:error, combined(errors)}
    end
  end

  # The message of each error names the module and the path, so the combined
  # error gives neither. It gives the location of the first error.
  defp combined([first | _others] = errors) do
    DslError.exception(
      location: Map.get(first, :location),
      message:
        "#{length(errors)} errors occurred:\n\n" <>
          Enum.map_join(errors, "\n\n", &Exception.message/1)
    )
  end
end
