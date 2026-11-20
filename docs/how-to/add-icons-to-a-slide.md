# Add icons to a slide

This guide shows how to show icons in a row and how to put an icon into a line of text. It also
shows how to use an SVG file of your own as an icon. For each option, see
[The icon element](../reference/icon-element.md).

## Show a row of icons

Write an `icon` element with the name of a Lucide icon, such as `"rocket"`. The `label` goes
under the icon, and the `color` takes a role of the theme. Put the icons in the columns of a
`columns` element to show them in a row. Give each one a step with `at`:

```elixir
defmodule Examples.Icon do
  use Expresso

  root __DIR__
  icons espresso: "icons/espresso.svg"

  slide "pipeline" do
    heading "Commit to release"

    columns do
      column do
        icon "git-commit-horizontal" do
          label "Commit"
          color :accent
        end
      end

      column do
        icon "flask-conical" do
          label "Test"
          color :success
          at from: 2
        end
      end

      column do
        icon "rocket" do
          label "Release"
          color :emphasis
          at from: 3
        end
      end

      column do
        icon "espresso" do
          label "Relax"
          at from: 4
        end
      end
    end

    text_area(text: "Each push runs :icon:circle-check: the checks before a :icon:tag: release.")
  end
end

Examples.Icon
```

![Four icons show one at a time, and a line of text holds two small icons](https://raw.githubusercontent.com/rellen/expresso/media/icon.gif)

Find the name of an icon at [lucide.dev/icons](https://lucide.dev/icons). A name that no icon
has is an error, and the message gives three names that are near.

## Put an icon into a line of text

Write `:icon:name:` in the text of a `text_area` or an `item`. The icon has the size and the
color of the text, as `:icon:circle-check:` does in the example above. A screen reader does not
read an icon, so write the meaning of the icon in the text too.

## Use an SVG file of your own

Give the file a name in the `icons` option of the deck, such as `espresso` in the example above.
Then use the name as you use the name of a Lucide icon. Expresso replaces the colors of the file
with the color of the text. Thus the icon takes its color from the `color` option and the theme.
Give the file a `viewBox`, so the icon keeps its shape at each size.
