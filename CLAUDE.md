# cassidyr Package Development

## Project Overview

**cassidyr** is an R package that provides a client for the CassidyAI
API, enabling seamless integration of AI-powered assistants into R
workflows. The package is designed with a security-first approach,
tidyverse-style conventions, and follows R package development best
practices.

## Package Information

- **Name:** cassidyr
- **Purpose:** R client for CassidyAI API with context-aware chat
  capabilities
- **Target Audience:** R users who want to integrate AI assistance into
  their workflows
- **Current Status:** Phase 3 complete (Interactive Shiny Chatbot),
  ready for Phase 4 (IDE Integration)

## Architecture & Design Philosophy

### Core Principles

1.  **Security First**
    - No credentials in code - always use environment variables
    - Credentials stored in `.Renviron` (gitignored)
    - No real data in automated tests
    - Manual tests separate in `tests/manual/` (excluded from builds)
2.  **Tidyverse Style**
    - All functions use snake_case
    - Pipe-friendly design
    - Clear, descriptive function names
    - Use native pipe `|>` in examples
3.  **Naming Conventions**
    - All exported functions use `cassidy_` prefix
    - Layer-specific organization:
      - `cassidy_create_*`, `cassidy_send_*` (API functions)
      - [`cassidy_chat()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_chat.md),
        [`cassidy_session()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_session.md)
        (chat interface)
      - `cassidy_context_*()` (context gathering)
      - `cassidy_describe_*()` (context description functions)
      - [`cassidy_app()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_app.md)
        (Shiny chat interface)
      - [`cassidy_read_context_file()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_read_context_file.md),
        [`use_cassidy_md()`](https://jdenn0514.github.io/cassidyr/reference/use_cassidy_md.md)
        (config files)
    - Internal helpers use `.` prefix (e.g., `.detect_ide()`,
      [`.get_env_dataframes()`](https://jdenn0514.github.io/cassidyr/reference/dot-get_env_dataframes.md))
4.  **User-Friendly Errors**
    - Use
      [`cli::cli_abort()`](https://cli.r-lib.org/reference/cli_abort.html)
      for errors with helpful messages
    - Validate inputs early and clearly
    - Provide actionable error messages
5.  **Sensible Defaults**
    - Environment variables for credentials
    - Automatic fallbacks (e.g., codebook → skim → basic)
    - Works out of the box when possible

## Key Design Patterns

### S3 Objects

- `cassidy_response` - Single API response
- `cassidy_thread` - Thread with message history
- `cassidy_thread_list` - List of threads
- `cassidy_session` - Stateful chat session
- `cassidy_chat` - Chat result with thread info
- `cassidy_context` - Project context
- `cassidy_df_description` - Data frame description
- `cassidy_data_issues` - Data quality issues

### S7 Classes

- `ConversationManager` - Manages Shiny chat state with reactive values
  - Methods: `conv_get_all`, `conv_get_current`, `conv_update_current`,
    `conv_create_new`, `conv_switch_to`, `conv_delete`,
    `conv_add_message`, `conv_save_current`, `conv_load_and_set`

### Print Methods

- All S3 classes have print methods
- Use `cli` for formatted output (goes to stderr)
- Use [`cat()`](https://rdrr.io/r/base/cat.html) for actual content
  (goes to stdout)
- Always return invisibly: `invisible(x)`

## Important Context

- This package is **self-documenting** - it can use its own context
  system to help build itself
- When working on cassidyr, gather context with
  `cassidy_context_project(level = "comprehensive")`
- The package uses a **modular structure** - handlers and context
  functions are split into focused files
- **Incremental context** - only new/changed items are sent to avoid
  redundancy
- **Smart tiering** - file context automatically adjusts based on total
  size
- **Configuration files** - Both CASSIDY.md (for the package) and
  CLAUDE.md (for development) use modular structure
- **xyz.R** contains development helpers like `update_package_imports()`
  for managing dependencies

## Working with This Package

When providing help with cassidyr development:

1.  **Follow established patterns** - consistency matters across the
    codebase
2.  **Provide complete code blocks** - ready to copy and use
3.  **Include tests** - always provide corresponding tests for new
    functions
4.  **Update documentation** - include roxygen2 comments with all code
5.  **Explain design decisions** - briefly help understand the “why”
    behind choices
6.  **Consider edge cases** - think about what could go wrong and handle
    it
7.  **Keep it simple** - prefer clear over clever code
8.  **Use raw encoding for symbols** - never use icons/emojis directly
    (use `"\u2713"` instead of ✓)

## Meta: Documentation Structure

This package uses **dual modular documentation**:

- **CASSIDY.md + .cassidy/rules/** - For the package’s own context
  system (used by
  [`cassidy_app()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_app.md))
- **CLAUDE.md + .claude/rules/** - For Claude Code development (what
  you’re reading now)

Both use identical modular structures to demonstrate the pattern the
package implements.

------------------------------------------------------------------------

## Additional Documentation

Detailed reference documentation is in `.claude/rules/`:

- **`file-structure.md`** - Complete R/ directory listing and modular
  organization
- **`development-workflow.md`** - Adding functions, testing, code review
  checklist
- **`testing-standards.md`** - Testing approach, code style, common
  pitfalls, dependencies
- **`package-usage.md`** - How to use package dependencies (fs, gert,
  httr2, cli, rlang, jsonlite)
- **`context-system.md`** - Context system details, API information,
  persistence
- **`roadmap.md`** - Development phases, status, IDE support
