# Retrieve conversation history from a thread

Gets the full message history from an existing CassidyAI thread,
including both user messages and assistant responses. This is an **API
function** that queries Cassidy's servers, not your local conversation
storage.

## Usage

``` r
cassidy_get_thread(thread_id, api_key = Sys.getenv("CASSIDY_API_KEY"))
```

## Arguments

- thread_id:

  Character. The **Cassidy API thread ID** (not a local conversation
  ID). This looks like a UUID from Cassidy's system. If you have a
  conversation ID from
  [`cassidy_list_conversations()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_list_conversations.md),
  use
  [`cassidy_get_thread_id()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_get_thread_id.md)
  to get the corresponding thread_id first.

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

## Details

### Understanding Thread IDs vs Conversation IDs

- **Thread ID**: Cassidy API identifier - use with this function

- **Conversation ID**: Local app identifier - use with
  [`cassidy_export_conversation()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_export_conversation.md),
  [`cassidy_delete_conversation()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_delete_conversation.md)

To convert between them, use
[`cassidy_get_thread_id()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_get_thread_id.md).

## See also

- [`cassidy_list_conversations()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_list_conversations.md)
  to see your saved conversations

- [`cassidy_get_thread_id()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_get_thread_id.md)
  to get a thread_id from a conversation_id

- [`cassidy_list_threads()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_list_threads.md)
  to list all threads from the Cassidy API

Other api-functions:
[`cassidy_create_thread()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_create_thread.md),
[`cassidy_list_threads()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_list_threads.md),
[`cassidy_send_message()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_send_message.md)

## Examples

``` r
if (FALSE) { # \dontrun{
  # From a locally saved conversation
  convs <- cassidy_list_conversations()
  thread_id <- convs$thread_id[1]  # Get the thread_id column
  thread <- cassidy_get_thread(thread_id)
  print(thread)

  # Or use the helper function
  thread_id <- cassidy_get_thread_id("conv_20260131_1234")
  thread <- cassidy_get_thread(thread_id)

  # Access messages
  thread$messages
} # }
```
