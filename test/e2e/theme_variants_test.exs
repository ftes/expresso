defmodule Expresso.E2E.ThemeVariantsTest do
  use Expresso.E2E, async: true

  alias Expresso.Builder
  alias Expresso.Palette.Builtin

  defp deck(theme) do
    Builder.deck([Builder.slide("one", heading: "Variants")], theme: theme)
  end

  defp background(page),
    do: page |> js(~s|getComputedStyle(document.documentElement).backgroundColor|) |> rgb()

  defp background_of(name), do: Builtin.fetch!(name).roles.background |> hex()

  defp hex("#" <> hex) do
    [r, g, b] = for <<pair::binary-2 <- hex>>, do: String.to_integer(pair, 16)
    "rgb(#{r}, #{g}, #{b})"
  end

  # The window asks for a dark scheme.
  @tag Test.use(color_scheme: :dark)
  test "a dark screen gets the dark variant, the key t changes the variant, and paper gets the default theme",
       %{
         page: page,
         tmp_dir: tmp_dir
       } do
    page = open(page, render(deck(dark: :dracula, light: :default), tmp_dir))

    assert background(page) == background_of(:dracula)

    press(page, "t")
    assert background(page) == background_of(:default)
    assert js(page, "document.documentElement.dataset.scheme") == "light"

    press(page, "t")
    assert background(page) == background_of(:dracula)

    emulate(page, "print")
    assert background(page) == background_of(:default)
  end

  @tag Test.use(color_scheme: :light)
  test "a light screen gets the light variant", %{page: page, tmp_dir: tmp_dir} do
    page = open(page, render(deck(dark: :dracula, light: :default), tmp_dir))

    assert background(page) == background_of(:default)

    press(page, "t")
    assert background(page) == background_of(:dracula)
  end

  @tag Test.use(color_scheme: :light)
  test "the address chooses the variant at the load", %{page: page, tmp_dir: tmp_dir} do
    html = render(deck(dark: :dracula, light: :default), tmp_dir)
    page = open(page, html <> "?scheme=dark")

    assert background(page) == background_of(:dracula)

    press(page, "t")
    assert background(page) == background_of(:default)
  end

  test "the key t in either window changes the variant of the two windows", %{
    page: page,
    context: context,
    tmp_dir: tmp_dir
  } do
    slides = [Builder.slide("one", heading: "One"), Builder.slide("two", heading: "Two")]
    two = Builder.deck(slides, theme: [dark: :dracula, light: :default])
    audience = open(page, render(two, tmp_dir))
    dark = "document.documentElement.dataset.scheme === 'dark'"
    light = "document.documentElement.dataset.scheme === 'light'"

    # The speaker view opens in the variant of the present view.
    press(audience, "t")
    speaker = popup(context, fn -> press(audience, "s") end)
    assert js(speaker, "location.search") =~ "scheme=dark"
    wait_for(speaker, dark)
    assert background(speaker) == background_of(:dracula)

    press(speaker, "t")
    wait_for(audience, light)
    assert background(audience) == background_of(:default)

    press(audience, "t")
    wait_for(speaker, dark)

    # A move sends the variant again, and the two windows keep it.
    press(speaker, "j")
    wait_for(audience, "location.hash.startsWith('#2')")
    assert js(audience, dark)
    assert js(speaker, dark)
  end

  @tag Test.use(color_scheme: :dark)
  test "the key t changes nothing in a deck with one variant", %{
    page: page,
    tmp_dir: tmp_dir
  } do
    page = open(page, render(deck(:dracula), tmp_dir))

    press(page, "t")
    assert background(page) == background_of(:dracula)
    assert js(page, "document.documentElement.dataset.scheme") == nil
  end
end
