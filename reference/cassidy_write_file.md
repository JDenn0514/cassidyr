# Write Cassidy response to a file

Saves the full response from a Cassidy chat to a file without any
processing. Use
[`cassidy_write_code()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_write_code.md)
to separate code from explanations.

## Usage

``` r
cassidy_write_file(x, path, open = interactive(), append = FALSE)
```

## Arguments

- x:

  A `cassidy_chat` or `cassidy_response` object.

- path:

  Character. File path where to save the response.

- open:

  Logical. Whether to open the file after writing (default: TRUE in
  interactive sessions).

- append:

  Logical. Whether to append to existing file (default: FALSE).

## Value

Invisibly returns the file path.

## See also

Other chat-functions:
[`cassidy_chat()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_chat.md),
[`cassidy_continue()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_continue.md),
[`cassidy_session()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_session.md),
[`cassidy_write_code()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_write_code.md),
[`chat()`](https://jdenn0514.github.io/cassidyr/reference/chat.md),
[`chat_text()`](https://jdenn0514.github.io/cassidyr/reference/chat_text.md)

## Examples

``` r
if (FALSE) { # \dontrun{
result <- cassidy_chat("Write documentation for this function", context = ctx)

# Save full response (no separation)
cassidy_write_file(result, "notes/function-docs.md")
} # }
```
