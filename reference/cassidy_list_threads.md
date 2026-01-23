# List all threads for an assistant

Retrieves a list of all conversation threads for a specified assistant.
Useful for finding and resuming previous conversations.

## Usage

``` r
cassidy_list_threads(
  assistant_id = Sys.getenv("CASSIDY_ASSISTANT_ID"),
  api_key = Sys.getenv("CASSIDY_API_KEY"),
  limit = 100
)
```

## Arguments

- assistant_id:

  Character. The CassidyAI assistant ID. Defaults to the
  `CASSIDY_ASSISTANT_ID` environment variable.

- api_key:

  Character. Your CassidyAI API key. Defaults to the `CASSIDY_API_KEY`
  environment variable.

- limit:

  Integer. Maximum number of threads to return (if supported by API).
  Default is 100.

## Value

A `cassidy_thread_list` S3 object containing:

- threads:

  A data frame with thread_id, created_at, last_message, and
  message_count

- assistant_id:

  The assistant these threads belong to

- total:

  Total number of threads

## See also

Other api-functions:
[`cassidy_create_thread()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_create_thread.md),
[`cassidy_get_thread()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_get_thread.md),
[`cassidy_send_message()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_send_message.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# List all threads
threads <- cassidy_list_threads()
print(threads)

# Access as data frame
threads$threads

# Get most recent thread
recent <- threads$threads[1, ]
cassidy_get_thread(recent$thread_id)
} # }
```
