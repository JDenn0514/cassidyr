# Send Message to Cassidy Thread

Sends a message to an existing Cassidy thread and retrieves the
assistant's response.

## Usage

``` r
cassidy_send_message(
  thread_id,
  message,
  api_key = Sys.getenv("CASSIDY_API_KEY"),
  timeout = 120
)
```

## Arguments

- thread_id:

  Character. The thread ID from
  [`cassidy_create_thread()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_create_thread.md).

- message:

  Character. The message content to send.

- api_key:

  Character. Cassidy API key. Defaults to `CASSIDY_API_KEY` environment
  variable.

- timeout:

  Numeric. Request timeout in seconds. Default is 120.

## Value

A `cassidy_response` object containing:

- `content`: The assistant's response text

- `thread_id`: The thread ID

- `timestamp`: When the response was received

## See also

Other api-functions:
[`cassidy_create_thread()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_create_thread.md),
[`cassidy_get_thread()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_get_thread.md),
[`cassidy_list_threads()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_list_threads.md)
