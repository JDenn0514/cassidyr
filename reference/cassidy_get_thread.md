# Retrieve conversation history from a thread

Gets the full message history from an existing CassidyAI thread,
including both user messages and assistant responses. Useful for
reviewing past conversations or resuming work.

## Usage

``` r
cassidy_get_thread(thread_id, api_key = Sys.getenv("CASSIDY_API_KEY"))
```

## Arguments

- thread_id:

  Character. The thread ID to retrieve.

- api_key:

  Character. Your CassidyAI API key. Defaults to the `CASSIDY_API_KEY`
  environment variable.

## Value

A `cassidy_thread` S3 object with:

- thread_id:

  The thread identifier

- messages:

  List of messages, each with role, content, and timestamp

- assistant_id:

  The assistant this thread belongs to

- created_at:

  When the thread was created

- message_count:

  Number of messages in the thread

## See also

Other api-functions:
[`cassidy_create_thread()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_create_thread.md),
[`cassidy_list_threads()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_list_threads.md),
[`cassidy_send_message()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_send_message.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# Retrieve a thread's history
thread <- cassidy_get_thread("thread_abc123")
print(thread)

# Access messages
thread$messages
} # }
```
