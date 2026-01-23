# Create a stateful chat session

Creates a persistent chat session with a CassidyAI assistant. Unlike
[`cassidy_chat()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_chat.md),
which can be used for one-off interactions, a session object maintains
conversation state and makes it easy to have back-and-forth
conversations.

## Usage

``` r
cassidy_session(
  assistant_id = Sys.getenv("CASSIDY_ASSISTANT_ID"),
  context = NULL,
  api_key = Sys.getenv("CASSIDY_API_KEY")
)
```

## Arguments

- assistant_id:

  Character. The CassidyAI assistant ID. Defaults to the
  `CASSIDY_ASSISTANT_ID` environment variable.

- context:

  Optional context object from
  [`cassidy_context_project()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_context_project.md),
  [`cassidy_describe_df()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_describe_df.md),
  or similar. Context is sent with the first message for efficiency.

- api_key:

  Character. Your CassidyAI API key. Defaults to the `CASSIDY_API_KEY`
  environment variable.

## Value

A `cassidy_session` S3 object containing:

- thread_id:

  The conversation thread identifier

- assistant_id:

  The assistant this session is connected to

- messages:

  List of messages in this session

- created_at:

  When the session was created

- context:

  Stored context (sent with first message)

## See also

Other chat-functions:
[`cassidy_chat()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_chat.md),
[`cassidy_continue()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_continue.md),
[`cassidy_write_code()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_write_code.md),
[`cassidy_write_file()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_write_file.md),
[`chat()`](https://jdenn0514.github.io/cassidyr/reference/chat.md),
[`chat_text()`](https://jdenn0514.github.io/cassidyr/reference/chat_text.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# Create a session with project context
ctx <- cassidy_context_project()
session <- cassidy_session(context = ctx)

# Use the session
chat(session, "What should I work on next?")
chat(session, "How do I implement that?")

# View session info
print(session)
} # }
```
