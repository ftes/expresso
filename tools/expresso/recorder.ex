defmodule Expresso.Recorder do
  @moduledoc """
  Records the frames of a deck in Chromium while it does the keys of an example

  `mix expresso.gifs` uses this module. `start/0` starts Playwright and one
  browser, `record/4` returns the frames of one example, and `stop/1` closes
  the browser. `Expresso.Gif` then encodes the frames as a GIF.

  A GIF must show each animation in the same way on each run. Therefore the
  recorder pauses the animations of the page after each key. It moves each
  animation to the time of each frame, and it takes a screenshot of each
  frame. The time of the computer then has no effect on the frames. The
  recorder also fixes the clock of the page, so the timer of the speaker view
  shows the same time on each run. An action can move the clock.
  """

  alias Expresso.Recorder.{Frames, RefusedError}
  alias Playwright.{Browser, BrowserContext, BrowserType, Clock, Keyboard, Mouse, Page}

  @timeout 30_000

  # The runs of an example, and the time before a new run, in milliseconds.
  @tries 3
  @pause 1000

  # The time of the clock of the page at the start of each example.
  @epoch DateTime.to_unix(~U[2026-01-01 09:00:00Z], :millisecond)

  @typedoc "The browser and the browser context of the recorder"
  @type t :: %{browser: map(), context: map()}

  @typedoc """
  A key, such as `"j"`, a move of the clock of the page by a number of
  milliseconds, or a move of the mouse to a part of the window. The speaker
  view shows a later time after a move of the clock, and the present view of
  a deck with the `advance` option goes to the next step when the time of its
  step ends. A move of the clock must change one of the two. `{:point, 0.25, 0.5}`
  puts the mouse at a quarter of the width and at one half of the height, as
  for the laser pointer. `{:drag, [{0.2, 0.3}, {0.6, 0.3}]}` presses the main
  button at the first point, moves the mouse through each next point, and
  releases the button, as for a line of the drawing. `{:alt_click, 0.5, 0.6}`
  clicks the main button at a part of the window with the Alt key down, as
  for the zoom. The recorder takes the frames of the animations after a key
  and after such a click.
  """
  @type action ::
          String.t()
          | {:advance, pos_integer()}
          | {:point, number(), number()}
          | {:drag, [{number(), number()}]}
          | {:alt_click, number(), number()}

  @typedoc "A PNG image and the time that the GIF shows it, in milliseconds"
  @type frame :: Expresso.Gif.frame()

  @doc """
  Start Playwright and one Chromium for the recorder

  The GIF is 800 by 450 pixels. The slides have the layout of a window of
  1280 by 720 pixels, and the scale of 0.625 makes each frame smaller.

  The environment variable `EXPRESSO_CHROMIUM` gives the path of a Chromium
  executable, as it does for the browser tests.
  """
  @spec start() :: t()
  def start do
    # The browser tests start Playwright before they run the task.
    case Playwright.Supervisor.start_link(executable: "node_modules/playwright/cli.js") do
      {:ok, _supervisor} -> :ok
      {:error, {:already_started, _supervisor}} -> :ok
    end

    launch = [timeout: @timeout, headless: true]

    launch =
      case System.get_env("EXPRESSO_CHROMIUM") do
        nil -> launch
        path -> Keyword.put(launch, :executable_path, path)
      end

    browser = Playwright.instance() |> Playwright.chromium() |> BrowserType.launch!(launch)

    context =
      Browser.new_context!(browser,
        viewport: %{width: 1280, height: 720},
        device_scale_factor: 0.625,
        reduced_motion: :no_preference
      )

    BrowserContext.set_default_timeout(context, @timeout)

    %{browser: browser, context: context}
  end

  @doc "Close the browser of the recorder"
  @spec stop(t()) :: :ok
  def stop(recorder) do
    Browser.close!(recorder.browser)
  end

  @doc """
  Open the address in a new page, do each action, and return the frames

  The first frame shows the page before the actions. Each key adds a frame
  for each step of its animations, then a frame after them. `height` is the
  height of each frame, in the layout of a window of 1280 by 720 pixels. A
  height that is more than the height of the window reaches below the window,
  so a still of the handout view shows several pages.

  When Chromium refuses a screenshot, the function waits one second and
  records the example again in a new page, up to three runs in total. It
  writes a line for each new run.
  """
  @spec record(t(), String.t(), [action()], pos_integer()) :: [frame(), ...]
  def record(recorder, url, actions, height) do
    retry(
      fn -> record_once(recorder, url, actions, height) end,
      fn ->
        Mix.shell().info(
          "#{Path.basename(url)}: Chromium refused a screenshot. " <>
            "The recorder records the example again in a new page."
        )

        Process.sleep(@pause)
      end,
      @tries
    )
  end

  @doc """
  Run `attempt`, and run it again when Chromium refuses a screenshot

  `attempt` records an example in a new page. When it raises
  `Expresso.Recorder.RefusedError`, the function calls `wait` and runs
  `attempt` again, up to `tries` runs in total. A different error, or a
  refusal in the last run, raises.
  """
  @spec retry((-> result), (-> term()), pos_integer()) :: result when result: term()
  def retry(attempt, wait, tries) do
    attempt.()
  rescue
    error in RefusedError ->
      if tries > 1 do
        wait.()
        retry(attempt, wait, tries - 1)
      else
        reraise error, __STACKTRACE__
      end
  end

  defp record_once(recorder, url, actions, height) do
    page = BrowserContext.new_page!(recorder.context)

    try do
      fix_clock(recorder, @epoch)
      Page.goto!(page, url)
      evaluate(page, "async () => { await document.fonts.ready; }")
      # The progress bar can move after the load. The first frame shows its end.
      finish(page)

      first = %{png: shot(page, height), delay: Frames.start()}
      last = length(actions) - 1

      {frames, _now} =
        actions
        |> Enum.with_index()
        |> Enum.flat_map_reduce(@epoch, fn {action, index}, now ->
          {frames, now} = act(recorder, page, height, action, now)
          {frames ++ [%{png: shot(page, height), delay: Frames.hold(index == last)}], now}
        end)

      [first | frames]
    after
      Page.close(page)
    end
  end

  # A move of the clock can end the time of a step of a deck with the
  # `advance` option. The present view then goes to the next step, so the
  # recorder takes the frames of that change.
  defp act(recorder, page, height, {:advance, milliseconds}, now) do
    now = now + milliseconds
    advance(recorder, page, now)
    {animation(page, height), now}
  end

  # The window is 1280 pixels wide. Its height is 720 pixels, also for an
  # example whose picture is higher.
  defp act(_recorder, page, _height, {:point, x, y}, now) do
    Mouse.move!(Page.mouse(page), x * 1280, y * 720)
    {[], now}
  end

  defp act(_recorder, page, _height, {:drag, [first | rest]}, now) do
    mouse = Page.mouse(page)
    move = fn {x, y} -> Mouse.move!(mouse, x * 1280, y * 720) end

    move.(first)
    Mouse.down!(mouse)
    Enum.each(rest, move)
    Mouse.up!(mouse)
    {[], now}
  end

  defp act(_recorder, page, height, {:alt_click, x, y}, now) do
    mouse = Page.mouse(page)
    Keyboard.down!(Page.keyboard(page), "Alt")
    Mouse.move!(mouse, x * 1280, y * 720)
    Mouse.down!(mouse)
    Mouse.up!(mouse)
    Keyboard.up!(Page.keyboard(page), "Alt")
    {animation(page, height), now}
  end

  defp act(_recorder, page, height, key, now) do
    press(page, key)
    {animation(page, height), now}
  end

  # The frames of the animations that an action started. The function moves
  # each animation to its end after the last frame.
  defp animation(page, height) do
    frames =
      for time <- Frames.times(started(page)) do
        seek(page, time)
        %{png: shot(page, height), delay: div(1000, Frames.fps())}
      end

    finish(page)
    frames
  end

  # The picture of the page, from its top.
  defp shot(page, height) do
    capture(fn ->
      Page.screenshot(page,
        type: :png,
        full_page: true,
        clip: %{x: 0, y: 0, width: 1280, height: height}
      )
    end)
  end

  @doc """
  Return the PNG of a screenshot

  `screenshot` returns the result of `Playwright.Page.screenshot/2`. When
  Chromium refuses the screenshot with the message `Unable to capture
  screenshot`, the function raises `Expresso.Recorder.RefusedError`. A
  different error raises a `RuntimeError`.
  """
  @spec capture((-> {:ok, binary()} | {:error, term()})) :: binary()
  def capture(screenshot) do
    case screenshot.() do
      {:ok, png} ->
        png

      {:error, error} ->
        if refused?(error),
          do: raise(RefusedError, error: error),
          else: raise("the screenshot failed: #{inspect(error)}")
    end
  end

  defp refused?(%{message: message}), do: message =~ "Unable to capture screenshot"
  defp refused?(_error), do: false

  defp press(page, key) do
    Keyboard.press!(Page.keyboard(page), key)
  end

  defp fix_clock(recorder, now) do
    Clock.set_fixed_time!(BrowserContext.clock(recorder.context), now)
  end

  # Wait for the animations of a key, pause them, and return the time of the
  # longest one in milliseconds. A key with no animation returns 0. The page
  # looks at each animation frame, and it pauses each animation at once, so an
  # animation runs for one frame at most before the pause. The seek then sets
  # the exact time of each frame. The page waits two more frames, because the
  # browser can start a transition of the slide after the transitions of the
  # overlays.
  defp started(page) do
    evaluate(page, """
    async () => {
      const frame = () => new Promise((resolve) => requestAnimationFrame(resolve));
      const pause = () => {
        const all = document.getAnimations();
        for (const animation of all) {
          animation.pause();
        }
        return all;
      };
      let waited = 0;
      while (pause().length === 0) {
        if (waited > 500) {
          return 0;
        }
        const before = performance.now();
        await frame();
        waited += performance.now() - before;
      }
      await frame();
      await frame();
      const ends = pause().map((animation) =>
        Number(animation.effect?.getComputedTiming().endTime ?? 0),
      );
      return Math.max(0, ...ends);
    }
    """)
  end

  # Move each paused animation to a time, and wait for two animation frames,
  # so the compositor paints the new time before the screenshot.
  defp seek(page, time) do
    evaluate(
      page,
      """
      async (time) => {
        for (const animation of document.getAnimations()) {
          animation.currentTime = time;
        }
        for (let count = 0; count < 2; count++) {
          await new Promise((resolve) => requestAnimationFrame(resolve));
        }
      }
      """,
      time
    )
  end

  # Move each animation to its end, and wait until the page has no animation.
  defp finish(page) do
    evaluate(page, """
    () => {
      for (const animation of document.getAnimations()) {
        animation.finish();
      }
    }
    """)

    wait_for(page, "() => document.getAnimations().length === 0", nil)
  end

  # Move the clock of the page, and wait until the page shows the new time:
  # the timer of the speaker view has a new text, or the present view shows a
  # different step. The speaker view and the present view each read the clock
  # four times each second.
  defp advance(recorder, page, now) do
    shown = ~s|document.getElementById("speaker-timer")?.textContent + location.hash|
    before = evaluate(page, "() => #{shown}")
    fix_clock(recorder, now)
    wait_for(page, "(before) => #{shown} !== before", before)
  end

  defp evaluate(page, function, arg \\ nil), do: Page.evaluate!(page, function, arg)

  defp wait_for(page, function, arg) do
    Page.wait_for_function!(page, function, arg, polling: :raf)
    :ok
  end
end
