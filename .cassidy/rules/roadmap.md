# Development Roadmap & Status

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

## Package Development Status

- The package follows **ellmer's testing pattern** for API tests
- Ready for **CRAN submission** after Phase 4 (IDE Integration)
- Built with **R 4.1+** in mind (native pipe `|>` support)
- Currently on **Phase 3 complete** - Interactive Shiny Chatbot implemented

## IDE Support

The package is designed to work across multiple IDEs:

- RStudio - Primary development environment
- Positron - Growing alternative, actively supported
- VS Code - With R extension
- Terminal - All features work in plain R

Functions detect IDE automatically and adapt behavior (e.g., file opening).
