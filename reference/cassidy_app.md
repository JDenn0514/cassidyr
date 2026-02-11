# Launch Cassidy Interactive Chat Application

Opens an interactive Shiny-based chat interface for conversing with
Cassidy AI assistants. The app automatically gathers project context and
supports conversation persistence.

## Usage

``` r
cassidy_app(
  assistant_id = Sys.getenv("CASSIDY_ASSISTANT_ID"),
  api_key = Sys.getenv("CASSIDY_API_KEY"),
  new_chat = FALSE,
  context_level = c("standard", "minimal", "comprehensive"),
  include_data = TRUE,
  include_files = NULL,
  timeout = 300,
  theme = NULL
)
```

## Arguments

- assistant_id:

  Character. The Cassidy assistant ID to use. Defaults to
  `CASSIDY_ASSISTANT_ID` environment variable.

- api_key:

  Character. The Cassidy API key. Defaults to `CASSIDY_API_KEY`
  environment variable.

- new_chat:

  Logical. If `TRUE`, starts a fresh conversation with new context. If
  `FALSE` (default), resumes the most recent conversation.

- context_level:

  Character. Level of context to include when starting a new chat:
  "minimal", "standard", or "comprehensive". Default is "standard".
  Ignored when `new_chat = FALSE`.

- include_data:

  Logical. Whether to include data frame context from the global
  environment when starting a new chat. Default is TRUE. Ignored when
  `new_chat = FALSE`.

- include_files:

  Character vector of file paths to include in initial context when
  starting a new chat. Ignored when `new_chat = FALSE`.

- timeout:

  Numeric. API timeout in seconds. Default is 300.

- theme:

  A bslib theme object. Default uses a clean modern theme.

## Value

Launches a Shiny app (called for side effects).

## Details

The app provides:

- Real-time chat with Cassidy AI

- Automatic project context injection (on new chats)

- Conversation history with sidebar navigation

- Ability to switch between multiple conversations

- Mobile-responsive design

### Continuing vs Starting New

By default (`new_chat = FALSE`), the app resumes your most recent
conversation. This is useful when you close the app to run code and want
to continue discussing results.

Use `new_chat = TRUE` when you want to start fresh with updated project
context. This is recommended when:

- You've made significant changes to your code

- You're starting a new task or topic

- You want to include different files in context

## See also

- [`cassidy_list_conversations()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_list_conversations.md)
  to view saved conversations

- [`cassidy_export_conversation()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_export_conversation.md)
  to export a conversation as Markdown

- [`cassidy_delete_conversation()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_delete_conversation.md)
  to remove old conversations

Other chat-app:
[`cassidy_delete_conversation()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_delete_conversation.md),
[`cassidy_export_conversation()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_export_conversation.md),
[`cassidy_get_thread_id()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_get_thread_id.md),
[`cassidy_list_conversations()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_list_conversations.md)

## Examples

``` r
if (FALSE) { # \dontrun{
  # Resume most recent conversation (default)
  cassidy_app()

  # Start a new conversation with standard context
  cassidy_app(new_chat = TRUE)

  # Start new with comprehensive context
  cassidy_app(new_chat = TRUE, context_level = "comprehensive")

  # Start new with specific files
  cassidy_app(
    new_chat = TRUE,
    include_files = c("R/my-analysis.R", "data/codebook.md")
  )
} # }
```
