defmodule Expresso.E2E.DocumentTagsTest do
  use Expresso.E2E, async: true

  alias Expresso.Builder

  # The tag `color-scheme` tells the browser the scheme of the theme. The
  # color `Canvas` of the system then follows the theme, and so do the scroll
  # bars. The test reads the color from an element with that color.
  @canvas """
  (() => {
    const probe = document.createElement("div");
    probe.style.backgroundColor = "Canvas";
    document.body.append(probe);
    const color = getComputedStyle(probe).backgroundColor;
    probe.remove();
    return color;
  })()
  """

  # The relative luminance of a color is high for a light color.
  defp light?(color) do
    [red, green, blue] =
      ~r/\d+/ |> Regex.scan(color) |> Enum.take(3) |> Enum.map(fn [n] -> String.to_integer(n) end)

    red + green + blue > 382
  end

  defp deck(theme), do: Builder.deck([Builder.slide("one", heading: "One")], theme: theme)

  # The scheme of the screen is the opposite of the theme, so the color comes
  # from the tag and not from the screen.
  @tag Test.use(color_scheme: :dark)
  test "the colors of the system follow a light theme and a dark theme", %{
    browser: browser,
    page: page,
    tmp_dir: tmp_dir
  } do
    light = open(page, render(deck(:default), tmp_dir, "light"))

    dark =
      browser |> new_page(color_scheme: :light) |> open(render(deck(:dracula), tmp_dir, "dark"))

    assert light?(js(light, @canvas))
    refute light?(js(dark, @canvas))
  end

  @tag Test.use(color_scheme: :dark)
  test "with two variants, the colors of the system follow the screen and the key t", %{
    page: page,
    tmp_dir: tmp_dir
  } do
    address = render(deck(dark: :dracula, light: :default), tmp_dir)

    page = open(page, address)
    refute light?(js(page, @canvas))

    press(page, "t")
    page |> Page.locator("html") |> Expect.to_have_attribute!("data-scheme", "light")
    assert light?(js(page, @canvas))

    press(page, "t")
    page |> Page.locator("html") |> Expect.to_have_attribute!("data-scheme", "dark")
    refute light?(js(page, @canvas))
  end

  test "the document has the description and the author of the deck", %{
    page: page,
    tmp_dir: tmp_dir
  } do
    deck =
      Builder.deck([Builder.slide("one", heading: "One")],
        name: "tags",
        description: "A talk about tags.",
        author: "Ada Lovelace"
      )

    page = open(page, render(deck, tmp_dir))

    assert js(page, "document.querySelector('meta[name=description]').content") ==
             "A talk about tags."

    assert js(page, "document.querySelector('meta[name=author]').content") == "Ada Lovelace"
    assert js(page, "document.characterSet") == "UTF-8"
  end

  test "the browser reads the address of the deck and the icon of the tab", %{
    page: page,
    tmp_dir: tmp_dir
  } do
    deck =
      Builder.deck([Builder.slide("one", heading: "One")],
        name: "tags",
        url: "https://example.com/talk/",
        card: "test/fixtures/dot.png",
        favicon: "test/fixtures/badge.svg"
      )

    page = open(page, render(deck, tmp_dir))

    assert js(page, "document.querySelector('link[rel=canonical]').href") ==
             "https://example.com/talk/"

    assert js(page, "document.querySelector('link[rel=icon]').href") =~
             ~r/\Adata:image\/svg\+xml;base64,/

    # The render wrote the copy of the picture next to the document.
    name = Expresso.MediaFiles.name("dot.png", File.read!("test/fixtures/dot.png"))
    assert File.ls!(Path.join(tmp_dir, "deck_files")) == [name]

    assert js(page, "document.querySelector('meta[property=\"og:image\"]').content") ==
             "https://example.com/talk/deck_files/" <> name
  end
end
