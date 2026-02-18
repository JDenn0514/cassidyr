# cassidyr 0.0.0.9000

## Breaking Changes

* Skills now use YAML frontmatter instead of bold markdown metadata
  - Skills must start with `---` and include YAML block
  - Required field: `description`
  - Optional fields: `name`, `auto_invoke`, `requires`
  - Existing skills need to be converted to new format

## New Features

* **Automatic timeout recovery** in `cassidy_send_message()`
  - Detects 524 Gateway Timeout errors from complex tasks or large inputs
  - Automatically retries once with chunking guidance to prevent timeout
  - Complex task detection for tasks like "implementation plan" or "comprehensive analysis"
  - Input size validation warns about large messages (>100k characters)
  - Clear user notifications during timeout and retry
  - Helper functions: `.is_complex_task()`, `.validate_message_size()`, `.add_chunking_guidance()`
  - Timeout prevention prompt encourages incremental responses
  - No user action required - all automatic

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

* **Context Engineering System**: Comprehensive token management for unlimited conversations
  - **Token Estimation** (`R/context-tokens.R`): Character-to-token conversion with 15% safety buffer
  - **Session Tracking** (`cassidy_session()`): Token tracking fields (token_estimate, token_limit, compact_at, auto_compact)
  - **Manual Compaction** (`cassidy_compact()`): Summarize old messages, preserve recent context
  - **Automatic Compaction**: Triggers at 85% token usage (customizable threshold)
  - **Shiny UI Integration**: Color-coded token display (green/yellow/red) with compact button
  - **Memory System** (`R/context-memory.R`): Persistent storage for workflow state and learned insights
  - **Timeout Management**: Automatic retry with chunking guidance for complex tasks
  - 200+ tests covering all token management and memory functionality
  - See `vignette("managing-long-conversations")` for complete guide

* **Memory system** for unlimited conversation length (`R/context-memory.R`)
  - Persistent file storage in `~/.cassidy/memory/` with subdirectory support
  - 6 memory functions: `cassidy_list_memory_files()`, `cassidy_format_memory_listing()`,
    `cassidy_read_memory_file()`, `cassidy_write_memory_file()`,
    `cassidy_delete_memory_file()`, `cassidy_rename_memory_file()`
  - Security: Path validation prevents directory traversal attacks
  - Progressive disclosure: Lightweight directory listing (~100 tokens) in context
  - On-demand file reading: Files loaded only when requested
  - Memory tool added to agentic registry with 5 commands (view, read, write, delete, rename)
  - Integration with `cassidy_context_project()` via `include_memory` parameter
  - Clear separation: Memory (dynamic state) vs Rules (static config) vs Skills (methodologies)
  - Memory persists across conversation compaction for truly unlimited conversations
  - 76 comprehensive tests including security validation

* **Token management for sessions** (`cassidy_session()`)
  - Automatic token tracking for all messages and context
  - Auto-compaction enabled by default (triggers at 85% token usage)
  - Customizable compaction threshold via `compact_at` parameter
  - Manual compaction with `cassidy_compact()` preserves recent messages
  - Custom summarization prompts for domain-specific compaction
  - Detailed statistics with `cassidy_session_stats()`
  - Print method shows token usage with percentage and warnings
  - Tracks compaction count and timestamps
  - 59 tests for session token tracking and auto-compaction

* **Token display in Shiny app** (`cassidy_app()`)
  - Color-coded token usage alerts (green <60%, yellow 60-80%, red >80%)
  - Visual progress display with percentage
  - Compact conversation button in token section
  - Warning notifications when exceeding 80% threshold
  - Token tracking in message handler (user + assistant + context)
  - Token tracking in context apply handler
  - Progress modal during compaction with success/error notifications
  - Token estimate persisted in conversation objects

* **Token tracking for console chat** in `cassidy_chat()`
  - Automatic token estimation for all messages and context (enabled by default)
  - Warning messages when approaching token limit (default: 80% threshold)
  - New parameters: `track_tokens` (default TRUE), `warn_at` (default 0.80), `auto_compact` (default FALSE)
  - Conversation objects now include `token_estimate` and `token_limit` fields
  - Individual messages track token counts for detailed diagnostics
  - `cassidy_current()` displays token usage with percentage and warnings
  - Suggests using `cassidy_session()` for long conversations with auto-compaction
  - Customizable warning threshold via `warn_at` parameter
  - Fully backward compatible with existing conversations
  - 13 tests for console chat token tracking

* Enhanced `cassidy_create_skill()` with custom metadata parameters
  - `description` parameter for custom skill description
  - `auto_invoke` parameter to control automatic invocation
  - `requires` parameter for skill dependencies
  - `open` parameter to automatically open file in editor
  - Templates now generate valid YAML frontmatter

* Added agentic task system with `cassidy_agentic_task()` for autonomous tool use
  - 8 built-in tools: read_file, write_file, execute_code, list_files, search_files, get_context, describe_data, memory
  - Safe mode by default with interactive approval for risky operations
  - Custom approval callbacks for programmatic control
  - Working directory support for all file operations
  - Memory tool enables persistent knowledge storage across tasks

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
