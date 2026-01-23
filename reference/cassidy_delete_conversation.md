# Delete a saved conversation

Permanently removes a conversation from disk.

## Usage

``` r
cassidy_delete_conversation(conv_id)
```

## Arguments

- conv_id:

  Character. The conversation ID to delete.

## Value

TRUE if deleted successfully, FALSE otherwise (invisibly).

## See also

Other chat-app:
[`cassidy_app()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_app.md),
[`cassidy_export_conversation()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_export_conversation.md),
[`cassidy_list_conversations()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_list_conversations.md)

## Examples

``` r
if (FALSE) { # \dontrun{
  # Delete a conversation
  cassidy_delete_conversation("conv_20260116_1234")
} # }
```
