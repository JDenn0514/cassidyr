# Chat with CassidyAI

Send a message to a CassidyAI assistant and get a response. This is the
main function for interacting with CassidyAI in a conversational way.

## Usage

``` r
cassidy_chat(
  message,
  assistant_id = Sys.getenv("CASSIDY_ASSISTANT_ID"),
  thread_id = NULL,
  context = NULL,
  api_key = Sys.getenv("CASSIDY_API_KEY"),
  timeout = 120
)
```

## Arguments

- message:

  Character. The message to send to the assistant.

- assistant_id:

  Character. The CassidyAI assistant ID. Defaults to the
  `CASSIDY_ASSISTANT_ID` environment variable.

- thread_id:

  Character or NULL. An existing thread ID to continue a conversation.
  If NULL (default), a new thread is created.

- context:

  Optional context object from
  [`cassidy_context_project()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_context_project.md),
  [`cassidy_describe_df()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_describe_df.md),
  or a custom context object with a `text` element. Context is sent once
  at thread creation for efficiency.

- api_key:

  Character. Your CassidyAI API key. Defaults to the `CASSIDY_API_KEY`
  environment variable.

- timeout:

  Numeric. Request timeout in seconds. Default is 120.

## Value

A `cassidy_chat` S3 object containing:

- thread_id:

  The thread ID (save this to continue the conversation)

- response:

  The assistant's response (a `cassidy_response` object)

- message:

  Your original message

## Details

If no `thread_id` is provided, a new conversation thread is created
automatically. To continue an existing conversation, pass the
`thread_id` from a previous call.

## See also

Other chat-functions:
[`cassidy_continue()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_continue.md),
[`cassidy_session()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_session.md),
[`cassidy_write_code()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_write_code.md),
[`cassidy_write_file()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_write_file.md),
[`chat()`](https://jdenn0514.github.io/cassidyr/reference/chat.md),
[`chat_text()`](https://jdenn0514.github.io/cassidyr/reference/chat_text.md)

## Examples

``` r
if (FALSE) { # \dontrun{
  # Simple one-off question
  result <- cassidy_chat("What is the tidyverse?")
  print(result)

  # With project context
  ctx <- cassidy_context_project()
  result <- cassidy_chat("Help me understand this project", context = ctx)

  # With data frame context
  desc <- cassidy_describe_df(mtcars)
  result <- cassidy_chat("What analyses would you recommend?", context = desc)

  # Continue the conversation (context already set)
  result2 <- cassidy_continue(result, "Tell me more")
} # }
```
