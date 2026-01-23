# Extract text content from a chat result

Convenience function to extract just the text content from a chat
result, useful for programmatic use or piping.

## Usage

``` r
chat_text(x)
```

## Arguments

- x:

  A `cassidy_chat` or `cassidy_response` object.

## Value

Character. The text content of the response.

## See also

Other chat-functions:
[`cassidy_chat()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_chat.md),
[`cassidy_continue()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_continue.md),
[`cassidy_session()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_session.md),
[`cassidy_write_code()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_write_code.md),
[`cassidy_write_file()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_write_file.md),
[`chat()`](https://jdenn0514.github.io/cassidyr/reference/chat.md)

## Examples

``` r
if (FALSE) { # \dontrun{
result <- cassidy_chat("What is 2+2?")
text <- chat_text(result)
cat(text)
} # }
```
