# List all saved conversations

Returns metadata for all saved conversations, sorted by last update
time. This function lists your **locally saved** conversations from the
cassidyr app, not threads from the Cassidy API.

## Usage

``` r
cassidy_list_conversations(n = 8)
```

## Arguments

- n:

  Integer. Maximum number of conversations to return. Default is 8.

## Value

Data frame with columns:

- id:

  Local conversation ID (e.g., "conv_20260131_1234")

- thread_id:

  Cassidy API thread ID for this conversation

- title:

  Conversation title (first message preview)

- created_at:

  When the conversation was created

- updated_at:

  When the conversation was last updated

- message_count:

  Number of messages in the conversation

## Details

### Understanding IDs

This package uses two types of identifiers:

- **Conversation ID** (`id`): Your local app's identifier (e.g.,
  "conv_20260131_1234"). Use this with
  [`cassidy_export_conversation()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_export_conversation.md),
  [`cassidy_delete_conversation()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_delete_conversation.md),
  and
  [`cassidy_get_thread_id()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_get_thread_id.md).

- **Thread ID** (`thread_id`): The Cassidy API's identifier for the
  conversation on their servers. Use this with API functions like
  [`cassidy_get_thread()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_get_thread.md),
  [`cassidy_send_message()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_send_message.md),
  etc.

To get the thread_id from a conversation_id, use
[`cassidy_get_thread_id()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_get_thread_id.md).

## See also

Other chat-app:
[`cassidy_app()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_app.md),
[`cassidy_delete_conversation()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_delete_conversation.md),
[`cassidy_export_conversation()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_export_conversation.md),
[`cassidy_get_thread_id()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_get_thread_id.md)

## Examples

``` r
if (FALSE) { # \dontrun{
  # List recent conversations
  convs <- cassidy_list_conversations()
  print(convs)

  # Export the most recent conversation (use conversation ID)
  cassidy_export_conversation(convs$id[1])

  # Get API thread details (use thread ID)
  thread <- cassidy_get_thread(convs$thread_id[1])
} # }
```
