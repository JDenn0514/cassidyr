# List all saved conversations

Returns metadata for all saved conversations, sorted by last update
time.

## Usage

``` r
cassidy_list_conversations(n = 8)
```

## Arguments

- n:

  Integer. Maximum number of conversations to return. Default is 8.

## Value

Data frame with columns: id, title, created_at, updated_at,
message_count

## See also

Other chat-app:
[`cassidy_app()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_app.md),
[`cassidy_delete_conversation()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_delete_conversation.md),
[`cassidy_export_conversation()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_export_conversation.md)

## Examples

``` r
if (FALSE) { # \dontrun{
  # List recent conversations
  convs <- cassidy_list_conversations()
  print(convs)
} # }
```
