defmodule Expresso.E2E.PointerTest do
  use Expresso.E2E, async: true

  # Two slides. Slide 1 has one step, and slide 2 has two steps. The viewport
  # is 1280 pixels wide, so the left third ends at about 427.
  defmodule Deck do
    use Expresso

    name "pointer deck"

    slide "one" do
      text_box do
        text_area(text: "One")
      end
    end

    slide "two" do
      steps 2

      text_box do
        text_area(text: "Two")
      end
    end
  end

  setup %{page: page, tmp_dir: tmp_dir} do
    url = render(Deck, tmp_dir)
    %{page: open(page, url), url: url}
  end

  test "a click on the right two thirds goes forward, and on the left third goes back", %{
    page: page
  } do
    page |> click(1000, 360)
    assert position(page) == "2.1"

    page |> click(500, 600)
    assert position(page) == "2.2"

    page |> click(100, 360)
    assert position(page) == "2.1"
    assert js(page, "location.hash") == "#2.1"
  end

  test "a click closes a black screen, and it does nothing more", %{page: page} do
    page |> press("b") |> click(1000, 360)

    assert js(page, "document.body.dataset.blank") == nil
    assert position(page) == "1.1"
  end

  test "a click in the handout view does not move", %{page: page} do
    page |> press("p") |> click(1000, 360)

    assert js(page, "location.hash") == "#1.1"
    page |> press("p")
    assert position(page) == "1.1"
  end

  test "a swipe to the left goes forward, and a swipe to the right goes back", %{page: page} do
    page |> swipe({900, 360}, {600, 380})
    assert position(page) == "2.1"

    page |> swipe({900, 360}, {600, 340})
    assert position(page) == "2.2"

    page |> swipe({300, 360}, {700, 360})
    assert position(page) == "2.1"

    # A vertical movement is not a swipe.
    page |> swipe({600, 100}, {620, 600})
    assert position(page) == "2.1"
  end

  @tag Test.use(has_touch: true)
  test "a tap on a touch screen goes forward", %{page: touch, url: url} do
    touch |> open(url) |> tap(1000, 360)
    assert position(touch) == "2.1"

    touch |> tap(100, 360)
    assert position(touch) == "1.1"
  end

  test "f puts the document in full screen, and f again takes it out", %{page: page} do
    page |> press("f")
    wait_for(page, "document.fullscreenElement === document.documentElement")

    page |> press("f")
    wait_for(page, "document.fullscreenElement === null")
    assert position(page) == "1.1"
  end

  # Each test below starts at step 1 of slide 2. A click on either side then
  # changes the position, so a click that the presenter does not ignore makes
  # the test fail.
  describe "a click that goes to the browser" do
    setup %{page: page} do
      %{page: press(page, "j")}
    end

    test "a click on a link does not move", %{page: page} do
      js(page, """
      (() => {
        const link = document.createElement("a");
        link.id = "link";
        link.href = "#";
        link.textContent = "A link";
        link.style = "position: fixed; left: 1000px; top: 100px; width: 100px; z-index: 20;";
        link.addEventListener("click", (event) => event.preventDefault());
        document.body.append(link);
      })()
      """)

      page |> click(1020, 110)

      assert js(page, "document.elementFromPoint(1020, 110).id") == "link"
      assert position(page) == "2.1"
    end

    test "a click with Shift does not move", %{page: page} do
      Keyboard.down!(Page.keyboard(page), "Shift")
      page |> click(1000, 360)
      Keyboard.up!(Page.keyboard(page), "Shift")

      assert position(page) == "2.1"
    end

    test "a click that ends a selection of text does not move", %{page: page} do
      # The box of the text "Two" of slide 2.
      box =
        js(page, """
        (() => {
          const walker = document.createTreeWalker(document.getElementById("slide-2"), NodeFilter.SHOW_TEXT);
          let node;
          while ((node = walker.nextNode()) && node.textContent.trim() !== "Two") {}
          const range = document.createRange();
          range.selectNodeContents(node);
          const box = range.getBoundingClientRect();
          return { left: box.left, right: box.right, y: box.top + box.height / 2 };
        })()
        """)

      Mouse.move!(Page.mouse(page), box["left"] - 2, box["y"])

      Mouse.down!(Page.mouse(page))

      Mouse.move!(Page.mouse(page), box["right"] + 2, box["y"], steps: 5)

      Mouse.up!(Page.mouse(page))

      assert js(page, "getSelection().toString()") =~ "Two"
      assert position(page) == "2.1"
    end
  end

  test "the list of keys shows f, the clicks and the swipes, and a click closes it", %{
    page: page
  } do
    page |> press("Shift+Slash")
    page |> Page.locator("body") |> Expect.to_have_attribute!("data-help", "true")

    help = js(page, "document.getElementById('help').innerText")
    assert help =~ "Full screen on or off"
    assert help =~ "Click or tap the right two thirds, or swipe left"
    assert help =~ "Click or tap the left third, or swipe right"

    # A click outside the dialog closes it.
    page |> click(1250, 360)

    # The browser fires the event `close` in a later task, so wait for it.
    page |> Page.locator("body") |> Expect.not_to_have_attribute!("data-help")
    assert position(page) == "1.1"
  end
end
