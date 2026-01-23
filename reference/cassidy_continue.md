# Continue an existing conversation

Convenience function to continue a conversation from a previous
[`cassidy_chat()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_chat.md)
result. Automatically uses the thread_id from the previous interaction.

## Usage

``` r
cassidy_continue(
  previous,
  message,
  api_key = Sys.getenv("CASSIDY_API_KEY"),
  timeout = 120
)
```

## Arguments

- previous:

  A `cassidy_chat` or `cassidy_session` object from a previous
  interaction.

- message:

  Character. The message to send.

- api_key:

  Character. Your CassidyAI API key. Defaults to the `CASSIDY_API_KEY`
  environment variable.

- timeout:

  Numeric. Request timeout in seconds. Default is 120.

## Value

A `cassidy_chat` object (same as
[`cassidy_chat()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_chat.md)).

## See also

Other chat-functions:
[`cassidy_chat()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_chat.md),
[`cassidy_session()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_session.md),
[`cassidy_write_code()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_write_code.md),
[`cassidy_write_file()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_write_file.md),
[`chat()`](https://jdenn0514.github.io/cassidyr/reference/chat.md),
[`chat_text()`](https://jdenn0514.github.io/cassidyr/reference/chat_text.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# Start conversation
result <- cassidy_chat("What is R?")

# Continue it
result2 <- cassidy_continue(result, "Tell me more")
result3 <- cassidy_continue(result2, "Show an example")

# Also works with sessions
session <- cassidy_session()
result <- chat(session, "Hello")
result2 <- cassidy_continue(session, "How are you?")
} # }
```
