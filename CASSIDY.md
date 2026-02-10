# cassidyr Package Development Context

## Project Overview

**cassidyr** is an R package that provides a client for the CassidyAI API,
enabling seamless integration of AI-powered assistants into R workflows. The
package is designed with a security-first approach, tidyverse-style conventions,
and follows R package development best practices.

## Package Information

- **Name:** cassidyr
- **Purpose:** R client for CassidyAI API with context-aware chat capabilities
- **Target Audience:** R users who want to integrate AI assistance into their
  workflows
- **Current Status:** Phase 3 complete (Interactive Shiny Chatbot), ready for
  Phase 4 (IDE Integration)

## Architecture & Design Philosophy

### Core Principles

1. **Security First**
   - No credentials in code - always use environment variables
   - Credentials stored in `.Renviron` (gitignored)
   - No real data in automated tests
   - Manual tests separate in `tests/manual/` (excluded from builds)

2. **Tidyverse Style**
   - All functions use snake_case
   - Pipe-friendly design
   - Clear, descriptive function names
   - Use native pipe `|>` in examples

3. **Naming Conventions**
   - All exported functions use `cassidy_` prefix
   - Layer-specific organization:
     - `cassidy_create_*`, `cassidy_send_*` (API functions)
     - `cassidy_chat()`, `cassidy_session()` (chat interface)
     - `cassidy_context_*()` (context gathering)
     - `cassidy_describe_*()` (context description functions)
     - `cassidy_app()` (Shiny chat interface)
     - `cassidy_read_context_file()`, `use_cassidy_md()` (config files)
   - Internal helpers use `.` prefix (e.g., `.detect_ide()`, `.get_env_dataframes()`)

4. **User-Friendly Errors**
   - Use `cli::cli_abort()` for errors with helpful messages
   - Validate inputs early and clearly
   - Provide actionable error messages

5. **Sensible Defaults**
   - Environment variables for credentials
   - Automatic fallbacks (e.g., codebook → skim → basic)
   - Works out of the box when possible


## Package Structure

cassidyr/
├── R/
│   ├── api-core.R                      ✓ Complete (API layer)
│   ├── cassidy-classes.R               ✓ Complete (S3 print methods)
│   ├── cassidyr-package.R              ✓ Complete (package docs)
│   │
│   ├── chat-core.R                     ✓ Complete (chat interface)
│   ├── chat-ui.R                       ✓ Complete (Shiny app main)
│   ├── chat-ui-components.R            ✓ Complete (UI components)
│   ├── chat-conversation.R             ✓ Complete (S7 ConversationManager)
│   ├── chat-persistence.R              ✓ Complete (Save/load conversations)
│   ├── chat-context-gather.R           ✓ Complete (Context gathering logic)
│   ├── chat-helpers.R                  ✓ Complete (Write code/files)
│   ├── chat-utils.R                    ✓ Complete (File tree, data frame utils)
│   ├── chat-css.R                      ✓ Complete (App styling + copy code button)
│   ├── chat-js.R                       ✓ Complete (App JavaScript + copy code button)
│   │
│   ├── chat-handlers-message.R         ✓ Complete (Message handling)
│   ├── chat-handlers-conversation.R    ✓ Complete (Conversation management)
│   ├── chat-handlers-context-apply.R   ✓ Complete (Apply context to messages)
│   ├── chat-handlers-context-data.R    ✓ Complete (Data frame context handlers)
│   ├── chat-handlers-context-files.R   ✓ Complete (File context handlers)
│   │
│   ├── context-project.R               ✓ Complete (project context)
│   ├── context-data.R                  ✓ Complete (data frame context)
│   ├── context-env.R                   ✓ Complete (environment context)
│   ├── context-file.R                  ✓ Complete (file context)
│   ├── context-file-parse.R            ✓ Complete (R file parsing for context)
│   ├── context-combine.R               ✓ Complete (combine contexts)
│   ├── context-config.R                ✓ Complete (read CASSIDY.md files)
│   ├── context-git.R                   ✓ Complete (Git status context)
│   ├── context-tools.R                 ✓ Complete (internal helpers)
│   │
│   ├── scripts.R                       ✓ Complete (script-to-quarto, commenting)
│   ├── utils.R                         ✓ Complete (%||% operator)
│   └── xyz.R                           ✓ Complete (dev helpers - update imports)
│
├── tests/
│   ├── testthat/
│   │   ├── test-api-core.R           ✓ Complete
│   │   ├── test-chat-core.R          ✓ Complete
│   │   ├── test-context-project.R    ✓ Complete
│   │   ├── test-context-data.R       ✓ Complete
│   │   ├── test-context-environment.R ✓ Complete
│   │   └── test-context-tools.R      ✓ Complete
│   └── manual/
│       ├── test-api-live.R
│       ├── test-chat-live.R
│       └── test-context-live.R       ✓ Complete
│
└── man/ (generated by roxygen2)

## Development Preferences

### Documentation Standards

- **roxygen2 with markdown** (@md in DESCRIPTION)
- All exported functions must have:
  - Complete parameter documentation
  - @return descriptions
  - @examples (with `\dontrun{}` for API calls)
  - @export tag for public functions
- Use markdown formatting in documentation
- Link related functions with @seealso
- Include usage examples that are realistic

### Testing Standards

- **testthat 3e** for all tests
- **Simplified testing approach** (not httptest2):
  - Unit tests validate R code logic without API calls
  - Mocking used sparingly (only when needed)
  - Manual tests verify real API integration
  - CRAN-compatible (no required API credentials)
- Test structure:
  - Use `withr::with_tempdir()` for file operations
  - Use `skip_if()` for environment-dependent tests
  - Use `skip_on_cran()` for system command tests
  - Test error handling and edge cases
- **Important**: Don't test cli output text directly
  - cli functions write to stderr, not stdout
  - Use `expect_no_error()` instead of `expect_output()` for cli messages
  - Test structure and behavior, not exact formatting

### Code Style

- Follow tidyverse style guide
- Use `paste0()` for string concatenation (not `sprintf()`)
- Prefer `|>` pipe for R >= 4.1 examples
- Maximum line length: 80 characters
- Use meaningful variable names
- Comment complex logic

### Dependencies

- **Minimize dependencies** where reasonable
- Current imports:
  - httr2 (>= 1.0.0) - HTTP requests
  - cli (>= 3.6.0) - User interface
  - rlang (>= 1.1.0) - Programming tools
  - shiny - Chat UI
  - bslib - Modern theming
  - S7 - OOP for ConversationManager
  - commonmark - Render chat messages
  - skimr (for data summaries)
  - fs - For file system operations
  - gert (for Git operations)
- Suggested packages:
  - testthat (>= 3.0.0)
  - withr
  - rstudioapi
- Prefer base R for simple operations

## API Details

### CassidyAI API

- **Base URL:** `https://app.cassidyai.com/api`
- **Authentication:** Bearer token in Authorization header
- **Environment Variables:**
  - `CASSIDY_API_KEY` - API key
  - `CASSIDY_ASSISTANT_ID` - Assistant ID
- **Endpoints:**
  - `POST /assistants/thread/create` - Create thread
  - `POST /assistants/message/create` - Send message
  - `GET /assistants/thread/get` - Get thread history
  - `GET /assistants/threads/get` - List threads
- **Retry Logic:**
  - Automatic retry on 429 (rate limit) and 503/504 (server errors)
  - Max 3 retries
  - 120-second timeout (configurable)

## File Organization

### Modular Structure

The package follows a modular organization with clear separation of concerns:

**API Layer** (`api-core.R`)
- Low-level API communication
- Thread and message management
- HTTP request handling with retry logic

**Chat Interface** (7 files)
- `chat-core.R` - Main chat functions
- `chat-ui.R` - Shiny UI structure
- `chat-ui-components.R` - Reusable UI components
- `chat-conversation.R` - S7 ConversationManager class
- `chat-persistence.R` - Save/load functionality
- `chat-context-gather.R` - Context gathering logic
- `chat-helpers.R` - File/code writing utilities
- `chat-utils.R` - File tree rendering, data frame detection
- `chat-css.R` - Styling
- `chat-js.R` - Client-side JavaScript

**Chat Handlers** (5 files, split for maintainability)
- `chat-handlers-message.R` - Send message logic
- `chat-handlers-conversation.R` - New/switch/delete conversations
- `chat-handlers-context-apply.R` - Apply context when sending messages
- `chat-handlers-context-data.R` - Data frame selection handlers
- `chat-handlers-context-files.R` - File selection/refresh handlers

**Context System** (9 files)
- `context-project.R` - Project-level context
- `context-data.R` - Data frame descriptions
- `context-env.R` - Environment information
- `context-file.R` - File descriptions with tiered levels
- `context-file-parse.R` - Parse R files for function info
- `context-combine.R` - Combine multiple context sources
- `context-config.R` - Read CASSIDY.md configuration files
- `context-git.R` - Git repository status
- `context-tools.R` - Internal helper functions

**Utilities**
- `cassidy-classes.R` - S3 print methods
- `cassidyr-package.R` - Package documentation and imports
- `scripts.R` - Script conversion utilities
- `utils.R` - General utilities (%||% operator)
- `xyz.R` - Development helpers (import scanning)

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
    `conv_create_new`, `conv_switch_to`, `conv_delete`, `conv_add_message`,
    `conv_save_current`, `conv_load_and_set`

### Print Methods

- All S3 classes have print methods
- Use `cli` for formatted output (goes to stderr)
- Use `cat()` for actual content (goes to stdout)
- Always return invisibly: `invisible(x)`

### Context System

**Configuration Files**
- Supports CASSIDY.md, .cassidy/CASSIDY.md, and CASSIDY.local.md
- `use_cassidy_md()` creates configuration files with templates
- `cassidy_read_context_file()` reads project and user-level configs
- Automatic loading in `cassidy_app()`
- Modular rules supported in `.cassidy/rules/*.md`

**File Context Tiers** (automatic based on size)
- **Full tier** (≤2000 lines total): Complete file contents
- **Summary tier** (2001-5000 lines): Summaries with previews
- **Index tier** (>5000 lines): File listings only
- Request specific files with `[REQUEST_FILE:path]` syntax

**Context Management**
- Context sent **once at thread creation** (not per message)
- Incremental context updates (only send new/changed items)
- Automatic refresh when resuming saved conversations
- Support for project, session, Git, data, and file context
- Multiple description methods with automatic fallback

### Conversation Persistence

- Conversations saved to `tools::R_user_dir("cassidyr", "data")/conversations/`
- Auto-save on message and session end
- Functions: `cassidy_list_conversations()`, `cassidy_export_conversation()`,
  `cassidy_delete_conversation()`

## Common Development Tasks

### Adding a New Function

1. **Choose the right file** based on function purpose:
   - API functions → `api-core.R`
   - Context functions → `context-*.R`
   - Chat UI → `chat-ui*.R`
   - Chat handlers → `chat-handlers-*.R`
   - Utilities → `utils.R` or `context-tools.R`

2. Write function with roxygen2 documentation
   - Include `@export` for public functions
   - Use `@keywords internal` for internal helpers

3. Update imports if using new packages:
   - Add package::function calls in code
   - Run `source("R/xyz.R")` then `update_package_imports(dry_run = FALSE)`
   - Run `devtools::document()` to update NAMESPACE

4. Write tests in corresponding `tests/testthat/test-*.R`
5. Add example to manual test file if needed
6. Update README/CASSIDY.md if it's a major feature

### Testing Workflow

- Run all tests: `devtools::test()`
- Run specific test file: `devtools::test_active_file()`
- Check package: `devtools::check()`
- Manual testing: `source("tests/manual/test-context-live.R")`
- Live chat testing: `cassidy_app()` with your own API key

### Working with Modular Structure

**Chat Handlers:**
When adding new Shiny handlers, add them to the appropriate file:
- Message sending logic → `chat-handlers-message.R`
- Conversation management → `chat-handlers-conversation.R`
- Context application → `chat-handlers-context-apply.R`
- Data frame handlers → `chat-handlers-context-data.R`
- File handlers → `chat-handlers-context-files.R`

**Context System:**
When extending context capabilities:
- New context sources → Create new `context-*.R` file
- Parsing/formatting → `context-file-parse.R` or `context-tools.R`
- Context gathering logic → `chat-context-gather.R`

## Common Pitfalls to Avoid

1. **Don't use `sprintf()`** - use paste0() instead
2. **Don't test cli output directly** - test structure/behavior instead
3. **Don't use `.format_num()` inside cli strings** - format values first
4. **Don't forget `skip_on_cran()`** for system commands
5. **Don't make git tests strict** - git behavior varies by environment
6. **Always use `suppressMessages()`** around `use_cassidy_md()` in tests
7. **Don't forget to update imports** - run `update_package_imports()` after adding package:: calls
8. **Keep handlers modular** - put new Shiny handlers in appropriate chat-handlers-*.R file
9. **Test file tree rendering** - ensure file paths are preserved correctly through nested folders
10. **Watch context size** - tiered file context prevents API limits from being exceeded

## IDE Support

The package is designed to work across multiple IDEs:

- RStudio - Primary development environment
- Positron - Growing alternative, actively supported
- VS Code - With R extension
- Terminal - All features work in plain R

Functions detect IDE automatically and adapt behavior (e.g., file opening).

## Development Phases

### ✅ Phase 1: API Layer (Complete)

- `cassidy_create_thread()` - Create conversation threads
- `cassidy_send_message()` - Send messages to assistants
- `cassidy_get_thread()` - Retrieve thread history
- `cassidy_list_threads()` - List available threads

### ✅ Phase 2: Context System (Complete)

**Project & Environment Context:**
- `cassidy_context_project()` - Gather project context
- `cassidy_context_env()` - Environment information
- `cassidy_context_git()` - Git repository status and commits

**Data Context:**
- `cassidy_context_data()` - Describe data frames
- `cassidy_describe_df()` - Individual data frame descriptions

**File Context:**
- `cassidy_describe_file()` - File summaries with tiered levels
- Context parsing for R, Rmd, qmd files

**Configuration:**
- `use_cassidy_md()` - Create configuration files
- `cassidy_read_context_file()` - Read CASSIDY.md files
- Templates: default, package, analysis, survey
- Location options: root, hidden (.cassidy/), local (.gitignored)

### ✅ Phase 3: Interactive Shiny Chatbot (Complete)

**Core Features:**
- `cassidy_app()` - Launch interactive Shiny chat interface
- Conversation persistence - Auto-save/load conversation history
- Conversation sidebar - Switch between multiple conversations
- Export conversations - Save chat history as markdown
- Mobile-responsive design - Collapsible sidebar, clean UI
- **Copy code button** - One-click copy for code blocks

**Context Management:**
- Automatic project/data context integration
- **Nested file tree** - Collapsible folders with file counts
- File context with refresh - Re-send updated files
- Incremental context - Only send new/changed items
- Smart tiering - Automatic full/summary/index based on size
- Data frame selection - Choose which data to include
- Context refresh on resume - Auto-update when loading conversations
- **CASSIDY.md support** - Project configuration files

**File Handling:**
- File request detection - Detect `[REQUEST_FILE:path]` patterns
- Visual status indicators - Show sent/pending/refresh states
- Collapsible folder tree - Navigate project structure easily
- Individual file refresh - Update specific files without re-sending all

### ⏳ Phase 4: IDE Integration (Next)

**Planned Features:**

- RStudio/Positron addins for code assistance
- `cassidy_document_function()` - Generate roxygen2 docs
- `cassidy_explain_selection()` - Explain selected code
- `cassidy_refactor_selection()` - Improve code
- `cassidy_debug_error()` - Help debug errors

**Implementation Notes:**

- Use `rstudioapi` when available
- Provide fallbacks for other IDEs
- Keep addins optional (in Suggests)
- Test across different environments

### 🔮 Phase 5: Agent System (Future)

- `cassidy_agent()` - Iterative problem solving
- `cassidy_execute_code()` - Safe code execution with sandboxing
- Multi-step workflows with state management
- Tool calling and function execution

### 🔮 Phase 6: Survey Research Tools (Future)

- `cassidy_interpret_efa()` - EFA interpretation with recommendations
- `cassidy_write_methods()` - Generate methods sections in APA format
- `cassidy_survey_codebook()` - Enhanced codebook for survey data
- `cassidy_scale_analysis()` - Comprehensive scale reliability analysis

## Important Context

- This package is **self-documenting** - it can use its own context system to help build itself
- When working on cassidyr, always gather context first with `cassidy_context_project(level = "comprehensive")`
- The package uses a **modular structure** - handlers and context functions are split into focused files
- **Incremental context** - only new/changed items are sent to avoid redundancy
- **Smart tiering** - file context automatically adjusts based on total size
- **Configuration files** - CASSIDY.md files provide project-specific instructions
- **xyz.R** contains development helpers like `update_package_imports()` for managing dependencies

## Package Development Status

- The package follows **ellmer's testing pattern** for API tests
- Ready for **CRAN submission** after Phase 4 (IDE Integration)
- Built with **R 4.1+** in mind (native pipe `|>` support)
- Currently on **Phase 3 complete** - Interactive Shiny Chatbot implemented

## Communication Preferences

When providing help with cassidyr development:

1. **Follow established patterns** - consistency matters across the codebase
2. **Provide complete code blocks** - ready to copy and use
3. **Include tests** - always provide corresponding tests for new functions
4. **Update documentation** - include roxygen2 comments with all code
5. **Explain design decisions** - help me understand the "why" behind choices
6. **Consider edge cases** - think about what could go wrong and handle it
7. **Keep it simple** - prefer clear over clever code

## Code Review Checklist

Before finalizing any new code:

- [ ] Function follows naming conventions (`cassidy_*` prefix)
- [ ] All parameters documented with @param
- [ ] @return value described
- [ ] @examples provided (with `\dontrun{}` for API calls)
- [ ] Tests pass with `devtools::test()`
- [ ] No hardcoded credentials or sensitive data
- [ ] Error handling implemented with helpful messages
- [ ] Works without optional dependencies (graceful fallbacks)
- [ ] Documentation renders correctly with `devtools::document()`
- [ ] Package passes `devtools::check()` with no errors or warnings
