# Export a conversation as Markdown

Exports a saved conversation to a Markdown file for sharing or
archiving.

## Usage

``` r
cassidy_export_conversation(conv_id, path = NULL)
```

## Arguments

- conv_id:

  Character. The conversation ID to export.

- path:

  Character. Output file path. If NULL, creates a file in the current
  working directory with the conversation title as filename.

## Value

Path to exported file (invisibly).

## See also

Other chat-app:
[`cassidy_app()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_app.md),
[`cassidy_delete_conversation()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_delete_conversation.md),
[`cassidy_list_conversations()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_list_conversations.md)

## Examples

``` r
if (FALSE) { # \dontrun{
  # Export to default location
  cassidy_export_conversation("conv_20260116_1234")

  # Export to specific path
  cassidy_export_conversation(
    "conv_20260116_1234",
    "~/Documents/my_conversation.md"
  )
} # }
```
