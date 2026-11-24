import Config

# The property tests. The generators of `Expresso.Test.CSS` make many forms, and
# therefore each property needs more than the default of 100 runs.
config :stream_data, max_runs: 500

# Zigler writes a debug message each time the GIF encoder of `tools/` loads, and
# the message comes in the output of `mix test`. The compiler removes it.
config :logger,
  compile_time_purge_matching: [[module: Expresso.Gif.Nif, level_lower_than: :info]]

# The browser tests of `test/e2e/` run on the test runner of Playwright, and
# `Expresso.E2E` uses its case template. The driver is the CLI of the npm
# package `playwright`, which `package.json` pins. Each context emulates
# reduced motion, and a test with motion asks for no preference. An action or
# a wait stops after 10 seconds. A failed test keeps its trace and a
# screenshot in `test-results/`. The variable `EXPRESSO_CHROMIUM` gives the
# path of a Chromium executable, and the browser has 60 seconds to start,
# because `mix check` builds the release at the same time.
if config_env() == :test do
  config :playwright, :driver, executable: "node_modules/playwright/cli.js"

  config :playwright, :test,
    browser_name: :chromium,
    launch_options:
      [timeout: 60_000] ++
        if(path = System.get_env("EXPRESSO_CHROMIUM"), do: [executable_path: path], else: []),
    reduced_motion: :reduce,
    action_timeout: 10_000,
    navigation_timeout: 10_000,
    expect: [timeout: 10_000],
    trace: :retain_on_failure,
    screenshot: :only_on_failure
end
