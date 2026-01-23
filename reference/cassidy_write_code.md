# Write Cassidy code to file and show explanation in console

Extracts code blocks from a Cassidy response and writes them to a file,
while displaying the explanatory text (non-code parts) in the console.
This allows you to see what was done while the actual code is saved to
disk.

## Usage

``` r
cassidy_write_code(
  x,
  path,
  open = interactive(),
  append = FALSE,
  show_explanation = TRUE
)
```

## Arguments

- x:

  A `cassidy_chat` or `cassidy_response` object.

- path:

  Character. File path where to save the code.

- open:

  Logical. Open file after writing (default: TRUE in interactive).

- append:

  Logical. Append to existing file (default: FALSE).

- show_explanation:

  Logical. Show explanatory text in console (default: TRUE).

## Value

Invisibly returns the file path.

## See also

Other chat-functions:
[`cassidy_chat()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_chat.md),
[`cassidy_continue()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_continue.md),
[`cassidy_session()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_session.md),
[`cassidy_write_file()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_write_file.md),
[`chat()`](https://jdenn0514.github.io/cassidyr/reference/chat.md),
[`chat_text()`](https://jdenn0514.github.io/cassidyr/reference/chat_text.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# Ask Cassidy to write code
result <- cassidy_chat(
  "Write the cassidy_app() function with UI and server logic",
  context = ctx
)

# Code goes to file, explanation to console
cassidy_write_code(result, "R/chat-ui.R")

# Quiet mode - no explanation shown
cassidy_write_code(result, "R/chat-ui.R", show_explanation = FALSE)
} # }
```
