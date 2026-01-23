# Send a message within a session

Generic function for sending messages. Works with both `cassidy_session`
objects and directly with thread IDs.

## Usage

``` r
chat(x, message, ...)
```

## Arguments

- x:

  A `cassidy_session` object or character thread_id.

- message:

  Character. The message to send.

- ...:

  Additional arguments passed to methods.

## Value

A `cassidy_chat` object.

## See also

Other chat-functions:
[`cassidy_chat()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_chat.md),
[`cassidy_continue()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_continue.md),
[`cassidy_session()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_session.md),
[`cassidy_write_code()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_write_code.md),
[`cassidy_write_file()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_write_file.md),
[`chat_text()`](https://jdenn0514.github.io/cassidyr/reference/chat_text.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# With a session
session <- cassidy_session()
result <- chat(session, "Hello!")
result2 <- chat(session, "How are you?")

# With a thread_id directly
result <- chat("thread_abc123", "Hello!")
} # }
```
