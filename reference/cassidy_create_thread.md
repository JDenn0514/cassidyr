# Create a new CassidyAI conversation thread

Creates a new conversation thread with a specified CassidyAI assistant.
Each thread maintains its own conversation history, allowing context to
persist across multiple messages within that thread.

## Usage

``` r
cassidy_create_thread(
  assistant_id = Sys.getenv("CASSIDY_ASSISTANT_ID"),
  api_key = Sys.getenv("CASSIDY_API_KEY"),
  is_verbose = FALSE
)
```

## Arguments

- assistant_id:

  Character. The CassidyAI assistant ID. Defaults to the
  `CASSIDY_ASSISTANT_ID` environment variable. Find this in your
  assistant's External Deployments settings.

- api_key:

  Character. Your CassidyAI API key. Defaults to the `CASSIDY_API_KEY`
  environment variable.

- is_verbose:

  Logical. Determines if the thread_id should be printed. Default is
  `FALSE`.

## Value

Character. The thread ID for the new conversation. Save this to continue
the conversation with
[`cassidy_send_message()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_send_message.md).

## See also

Other api-functions:
[`cassidy_get_thread()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_get_thread.md),
[`cassidy_list_threads()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_list_threads.md),
[`cassidy_send_message()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_send_message.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# Create a new thread
thread_id <- cassidy_create_thread()

# Or specify assistant explicitly
thread_id <- cassidy_create_thread(assistant_id = "asst_abc123")
} # }
```
