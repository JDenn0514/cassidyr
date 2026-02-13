# cassidyr 0.0.0.9000

## Breaking Changes

* Skills now use YAML frontmatter instead of bold markdown metadata
  - Skills must start with `---` and include YAML block
  - Required field: `description`
  - Optional fields: `name`, `auto_invoke`, `requires`
  - Existing skills need to be converted to new format

## New Features

* **Enhanced file rendering** in `cassidy_app()` chat interface
  - Markdown, Quarto, and R Markdown files now display as styled blocks with raw content
  - Files no longer rendered as HTML (prevents nested chunk issues)
  - File blocks include header bar with filename, file icon, and action buttons
  - Copy button for one-click copying of entire file content
  - Download button integrated into file header (moved from bottom)
  - Visual distinction between AI explanation and file content
  - Preserves R code chunks and YAML frontmatter as raw text
  - Scrollable content area (max 500px height) for large files
  - Support for multiple files in single response

* **Unified console chat interface** with automatic conversation management
  - `cassidy_chat()` now automatically continues conversations without tracking thread IDs
  - Package-level state management for seamless interactive use
  - Automatic conversation persistence to disk
  - Three helper functions: `cassidy_conversations()`, `cassidy_current()`, `cassidy_reset()`
  - Context levels: minimal, standard (default), comprehensive
  - Easy conversation switching: `cassidy_chat(msg, conversation = conv_id)`
  - Fully backward compatible with `thread_id` parameter (legacy mode)
  - Session-based `cassidy_session()` objects remain available for programmatic use

* Enhanced `cassidy_create_skill()` with custom metadata parameters
  - `description` parameter for custom skill description
  - `auto_invoke` parameter to control automatic invocation
  - `requires` parameter for skill dependencies
  - `open` parameter to automatically open file in editor
  - Templates now generate valid YAML frontmatter

* Added agentic task system with `cassidy_agentic_task()` for autonomous tool use
  - 7 built-in tools: read_file, write_file, execute_code, list_files, search_files, get_context, describe_data
  - Safe mode by default with interactive approval for risky operations
  - Custom approval callbacks for programmatic control
  - Working directory support for all file operations

* Added interactive Shiny chat interface with `cassidy_app()`
  - Conversation persistence with auto-save/load
  - Multiple conversation management
  - Nested file tree for project exploration
  - Data frame selection and context integration
  - Export conversations as markdown

* Comprehensive context system
  - Project context with `cassidy_context_project()`
  - Data frame descriptions with `cassidy_context_data()`
  - Git repository status with `cassidy_context_git()`
  - File context with automatic tiering based on size
  - Support for CASSIDY.md configuration files

* Core API functionality
  - Create threads with `cassidy_create_thread()`
  - Send messages with `cassidy_send_message()`
  - Retrieve thread history with `cassidy_get_thread()`
  - List threads with `cassidy_list_threads()`

## Documentation

* Initial CRAN submission
