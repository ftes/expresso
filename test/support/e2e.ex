defmodule Expresso.E2E do
  @moduledoc """
  Defines the case template of the browser tests

  A browser test renders a deck to an HTML file, opens the file in Chromium
  with Playwright, and operates the presenter as the user does. `use
  Expresso.E2E` tags each test of the module with `:e2e`. `test_helper.exs`
  excludes that tag, so `mix test` does not start a browser. `mix test --only
  e2e` runs these tests. `docs/development/browser-tests.md` gives the setup.

  The template uses `Playwright.Case`, the case template of the test runner
  of Playwright. Each module gets a browser from the pool of the runner, and
  each test gets a new browser context and a new page, so no state goes from
  one test to the next. The options of the runner are in `config/config.exs`.
  Each context emulates reduced motion, and the theme then sets each duration
  to zero. Therefore a test can read a style immediately after a key press.

  A module, a describe block or a test with other options of the context
  gives them as Playwright Test does: in the options of `use Expresso.E2E`,
  in `@describetag Test.use(...)` or in `@tag Test.use(...)`. A test with
  motion asks for `reduced_motion: :no_preference`, and it reads a change
  with `slow_motion/2`, `pause_animations/3` and `finish_animations/2`. A
  test that needs a second window with other options makes it with
  `new_page/2`.

  The environment variable `EXPRESSO_CHROMIUM` gives the path of a Chromium
  executable. Without it, Playwright uses its own browser, which
  `npx playwright install chromium` installs.
  """

  use ExUnit.CaseTemplate

  alias Playwright.{
    Browser,
    BrowserContext,
    Clock,
    Expect,
    Keyboard,
    Locator,
    Mouse,
    Page,
    Touchscreen
  }

  using opts do
    quote do
      use Playwright.Case, unquote(opts)

      import Expresso.E2E

      @moduletag :e2e
      @moduletag :tmp_dir
    end
  end

  @doc """
  Make a page with its own browser context, for a test that needs a second
  window with other options than its page

  The options are the options of a context of Playwright, such as
  `viewport: %{width: 640, height: 360}`, `forced_colors: :active`,
  `color_scheme: :dark` or `contrast: :more`. The context starts from the
  options of the test, and the runner closes it at the end of the test.
  """
  @spec new_page(map(), keyword()) :: map()
  def new_page(browser, options) do
    browser |> Browser.new_context!(options) |> BrowserContext.new_page!()
  end

  @doc """
  Render a deck to an HTML file in the directory of the test, and give its
  address. The deck is a module of the DSL or an `Expresso.Deck` struct.
  """
  @spec render(module() | Expresso.Deck.t(), String.t(), String.t()) :: String.t()
  def render(deck, tmp_dir, name \\ "deck") do
    {:ok, deck} = Expresso.to_deck(deck)
    path = Path.join(tmp_dir, name <> ".html")
    directory = Expresso.MediaFiles.directory(path)
    {html, files} = Expresso.MediaFiles.collect(directory, fn -> Expresso.Deck.render(deck) end)
    File.write!(path, html)
    # A `video` or an `audio` element with `external true` keeps its file next
    # to the document.
    :ok = Expresso.MediaFiles.write(files, path)
    "file://" <> path
  end

  @doc """
  Open an address in a page, and wait for the load of the document
  """
  @spec open(map(), String.t()) :: map()
  def open(page, url) do
    Page.goto!(page, url)
    page
  end

  @doc """
  Press one key in a page, such as `"j"`, `"ArrowRight"` or `"Shift+Slash"`
  """
  @spec press(map(), String.t()) :: map()
  def press(page, key) do
    page |> Page.locator("body") |> Locator.press!(key)
    page
  end

  @doc """
  Press each key of a list in a page, in sequence
  """
  @spec keys(map(), [String.t()]) :: map()
  def keys(page, keys), do: Enum.reduce(keys, page, &press(&2, &1))

  @doc """
  Give the focus to the window of a page, as the presenter does before a key

  `press/2` sends a key to a page that does not have the focus. Chrome Headless
  Shell 159 and later refuse full screen to a window without the focus.
  """
  @spec front(map()) :: map()
  def front(page) do
    Page.bring_to_front!(page)
    page
  end

  @doc """
  Click the main mouse button at a point of the viewport of a page
  """
  @spec click(map(), number(), number()) :: map()
  def click(page, x, y) do
    mouse = Page.mouse(page)
    Mouse.move!(mouse, x, y)
    Mouse.down!(mouse)
    Mouse.up!(mouse)
    page
  end

  @doc """
  Click the main mouse button at a point of the viewport of a page, with the
  Alt key down
  """
  @spec alt_click(map(), number(), number()) :: map()
  def alt_click(page, x, y) do
    Keyboard.down!(Page.keyboard(page), "Alt")
    click(page, x, y)
    Keyboard.up!(Page.keyboard(page), "Alt")
    page
  end

  @doc """
  Press one key in the element of a page that has the focus

  `press/2` sends a key to the `body`. This function sends it to the element
  with the focus, such as an element in a dialog.
  """
  @spec press_focused(map(), String.t()) :: map()
  def press_focused(page, key) do
    Keyboard.press!(Page.keyboard(page), key)
    page
  end

  @doc """
  Set the clock of each page of a browser context to a fixed time

  `time` is a number of milliseconds from the start of 1970. The timers of a
  page run as before, and `Date.now()` returns the fixed time. A test moves
  the clock with a second call. The recorder of the GIFs does the same.
  """
  @spec fix_clock(map(), non_neg_integer()) :: map()
  def fix_clock(context, time) do
    Clock.set_fixed_time!(BrowserContext.clock(context), time)
    context
  end

  @doc """
  Tap a point of the viewport of a page with a finger

  The context of the page must have `has_touch: true`.
  """
  @spec tap(map(), number(), number()) :: map()
  def tap(page, x, y) do
    Touchscreen.tap!(Page.touchscreen(page), x, y)
    page
  end

  @doc """
  Move one finger across a page from one point to another point

  Playwright has a tap but no swipe, so the page gets the touch events from a
  script. Each point is a tuple `{x, y}` in the viewport.
  """
  @spec swipe(map(), {number(), number()}, {number(), number()}) :: map()
  def swipe(page, {x1, y1}, {x2, y2}) do
    js(page, """
    (() => {
      const target = document.elementFromPoint(#{x1}, #{y1}) ?? document.body;
      const touch = (x, y) =>
        new Touch({ identifier: 1, target, clientX: x, clientY: y });
      const start = touch(#{x1}, #{y1});
      const end = touch(#{x2}, #{y2});
      const send = (type, touches, changed) =>
        target.dispatchEvent(new TouchEvent(type, {
          bubbles: true, cancelable: true, touches, targetTouches: touches,
          changedTouches: changed
        }));
      send("touchstart", [start], [start]);
      send("touchmove", [end], [end]);
      send("touchend", [], [end]);
    })()
    """)

    page
  end

  @doc """
  Give the value of a JavaScript expression in a page
  """
  @spec js(map(), String.t()) :: term()
  def js(page, expression), do: Page.evaluate!(page, expression)

  @doc """
  Write a computed color as `rgb(r, g, b)`

  The browser writes the result of `color-mix()` as `color(srgb r g b)`, with
  each channel from 0 to 1. The function returns such a color as `rgb()`, so
  a test can compare it with the other colors. It returns another color
  unchanged.
  """
  @spec rgb(String.t()) :: String.t()
  def rgb("color(srgb " <> channels) do
    [r, g, b] =
      channels
      |> String.trim_trailing(")")
      |> String.split()
      |> Enum.take(3)
      |> Enum.map(&round(String.to_float(normal(&1)) * 255))

    "rgb(#{r}, #{g}, #{b})"
  end

  def rgb(color), do: color

  # `String.to_float/1` needs a digit before and after the point.
  defp normal(number), do: if(String.contains?(number, "."), do: number, else: number <> ".0")

  @position """
  (() => {
    const slide = [...document.querySelectorAll("section.slide")]
      .find((section) => section.style.display === "flex");
    return slide.id.replace("slide-", "") + "." + slide.dataset.step;
  })()
  """

  @doc """
  Give the position of the present view, such as `"2.3"`: the number of the
  slide that shows and its step
  """
  @spec position(map()) :: String.t()
  def position(page), do: js(page, @position)

  @doc """
  Give the pages of the handout view that a reader sees, such as `["1.1", "2.3"]`
  """
  @spec shown_pages(map()) :: [String.t()]
  def shown_pages(page) do
    js(page, """
    [...document.querySelectorAll(".handout-page")]
      .filter((page) => getComputedStyle(page).display !== "none")
      .map((page) => page.dataset.slide + "." + page.dataset.step)
    """)
  end

  @doc """
  Wait until the present view shows a position, such as `"2.1"`

  With motion, the presenter changes the slide in a view transition, and the
  browser applies the change after the key press returns.
  """
  @spec wait_for_position(map(), String.t()) :: map()
  def wait_for_position(page, position),
    do: wait_for(page, "#{@position} === #{JSON.encode!(position)}")

  @doc """
  Wait until the elements of a selector show the texts of a list, in document
  order
  """
  @spec wait_for_texts(map(), String.t(), [String.t()]) :: map()
  def wait_for_texts(page, selector, texts) do
    page |> Page.locator(selector) |> Expect.to_have_text!(texts)
    page
  end

  @doc """
  Give each change of a page a duration in seconds, also on an element with
  the option `speed`

  A long change cannot end before `pause_animations/3` pauses it, also when
  the browser stops for some seconds.
  """
  @spec slow_motion(map(), number()) :: map()
  def slow_motion(page, seconds) do
    js(page, """
    document.head.append(Object.assign(document.createElement("style"), {
      textContent: ":root, [data-speed] { --dur: #{seconds}s !important; }"
    }))
    """)

    page
  end

  # The animations of each element of a selector and of their descendants.
  defp animations_js(selector) do
    """
    [...document.querySelectorAll(#{JSON.encode!(selector)})]
      .flatMap((element) => element.getAnimations({ subtree: true }))
    """
  end

  @doc """
  Give the number of animations of the elements of a selector and of their
  descendants
  """
  @spec animations(map(), String.t()) :: non_neg_integer()
  def animations(page, selector), do: js(page, "#{animations_js(selector)}.length")

  @doc """
  Pause each animation of the elements of a selector and of their descendants
  at a time in milliseconds

  The function waits until an animation exists. The page then keeps the state
  of that time, so a test can read a change before its end on a slow computer
  too. `finish_animations/2` moves the animations to their end.
  """
  @spec pause_animations(map(), String.t(), number()) :: map()
  def pause_animations(page, selector, time) do
    wait_for(page, """
    (() => {
      const animations = #{animations_js(selector)};
      for (const animation of animations) {
        animation.pause();
        animation.currentTime = #{time};
      }
      return animations.length > 0;
    })()
    """)
  end

  @doc """
  Move each animation of the elements of a selector and of their descendants
  to its end
  """
  @spec finish_animations(map(), String.t()) :: map()
  def finish_animations(page, selector) do
    js(page, "#{animations_js(selector)}.forEach((animation) => animation.finish())")
    page
  end

  @doc """
  Reload a page, and wait for the load of the document
  """
  @spec reload(map()) :: map()
  def reload(page) do
    Page.reload!(page)
    page
  end

  @doc """
  Print a page to PDF with the media of a printer, and give the number of
  pages of the PDF

  The function counts the page objects of the PDF, so it needs no PDF tool.
  The page then gets the media of a screen again.
  """
  @spec pdf_pages(map()) :: non_neg_integer()
  def pdf_pages(page) do
    emulate(page, :print)
    pdf = Page.pdf!(page, landscape: true)
    emulate(page, :screen)
    ~r{/Type\s*/Page\b(?!s)} |> Regex.scan(pdf) |> length()
  end

  @doc """
  Give a page the media of a printer or of a screen
  """
  @spec emulate(map(), :print | :screen) :: map()
  def emulate(page, media) do
    Page.emulate_media!(page, media: media)
    page
  end

  @doc """
  Run a function that opens a second window, and give the page of that window

  The function waits for the load of the document of the new page.
  """
  @spec popup(map(), (-> term())) :: map()
  def popup(context, action) do
    page = BrowserContext.expect_page!(context, action)
    Page.wait_for_load_state!(page, :load)
    page
  end

  @doc """
  Wait until a JavaScript expression in a page gives a true value
  """
  @spec wait_for(map(), String.t()) :: map()
  def wait_for(page, expression) do
    Page.wait_for_function!(page, expression, nil, polling: 50)
    page
  end
end
