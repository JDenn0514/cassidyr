# Changelog

## cassidyr 0.0.0.9000

### New Features

- Added agentic task system with
  [`cassidy_agentic_task()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_agentic_task.md)
  for autonomous tool use
  - 7 built-in tools: read_file, write_file, execute_code, list_files,
    search_files, get_context, describe_data
  - Safe mode by default with interactive approval for risky operations
  - Custom approval callbacks for programmatic control
  - Working directory support for all file operations
- Added interactive Shiny chat interface with
  [`cassidy_app()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_app.md)
  - Conversation persistence with auto-save/load
  - Multiple conversation management
  - Nested file tree for project exploration
  - Data frame selection and context integration
  - Export conversations as markdown
- Comprehensive context system
  - Project context with
    [`cassidy_context_project()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_context_project.md)
  - Data frame descriptions with
    [`cassidy_context_data()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_context_data.md)
  - Git repository status with
    [`cassidy_context_git()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_context_git.md)
  - File context with automatic tiering based on size
  - Support for CASSIDY.md configuration files
- Core API functionality
  - Create threads with
    [`cassidy_create_thread()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_create_thread.md)
  - Send messages with
    [`cassidy_send_message()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_send_message.md)
  - Retrieve thread history with
    [`cassidy_get_thread()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_get_thread.md)
  - List threads with
    [`cassidy_list_threads()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_list_threads.md)

### Documentation

- Initial CRAN submission
