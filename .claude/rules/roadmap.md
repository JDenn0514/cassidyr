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

### ✅ Phase 4: Agentic System (Complete)

**Hybrid Architecture:**
- **Assistant** - High-level reasoning and planning (CassidyAI)
- **Workflow** - Structured tool decisions with guaranteed JSON (CassidyAI)
- **R Functions** - Tool execution with error handling

**Core Features:**
- `cassidy_agentic_task()` - Main agentic function
- **Safe mode by default** - Interactive approval for risky operations
- Custom approval callbacks - Define your own approval logic
- 7 built-in tools - read_file, write_file, execute_code, list_files, search_files, get_context, describe_data
- Iteration management - Max iterations with early completion detection
- Error handling - Graceful handling of tool failures and workflow errors

**Tool System:**
- Tool registry - Extensible system for adding new tools
- Risk flagging - Automatic detection of risky operations
- Context-aware - Uses existing cassidyr functions (cassidy_describe_file, cassidy_context_project, etc.)
- Working directory support - All file operations respect working directory

**CLI Integration:**
- `cassidy_install_cli()` - Install command-line tool
- Interactive REPL mode - `cassidy agent` for interactive sessions
- Direct task mode - `cassidy agent "task"` for one-off tasks
- Context commands - `cassidy context` to view project context
- Cross-platform - Mac, Linux, and Windows support

**Direct Parsing:**
- No workflow setup required - works out of the box
- Structured `<TOOL_DECISION>` blocks parsed directly from assistant responses
- Automatic fallback to inference when structure is missing
- Simpler, more reliable than webhook-based workflows

### ✅ Phase 5: Skills System (Complete)

**Core Features:**
- Progressive disclosure - Metadata vs full content loading
- Skill composition - Skills can reference other skills as dependencies
- Context integration - Skills automatically included in project context
- Dual invocation - Agent can auto-invoke OR user can explicitly call
- Simple markdown format - No YAML complexity
- Two locations - Project (.cassidy/skills/) and personal (~/.cassidy/skills/)

**Functions:**
- `cassidy_context_skills()` - Get skill metadata for context
- `cassidy_list_skills()` - List available skills
- `cassidy_use_skill()` - Preview or execute skill
- `cassidy_create_skill()` - Create new skill from template

**Agentic Integration:**
- Skills available alongside tools in `cassidy_agentic_task()`
- Auto-invoke skills when task matches skill description
- Dependency resolution with circular dependency prevention
- Skills injected into conversation with full workflow content

**Example Skills:**
- `apa-tables.md` - APA 7th edition table formatting guidelines
- `efa-workflow.md` - Complete EFA workflow with best practices

### ⏳ Phase 6: IDE Integration (Next)

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

### 🔮 Phase 7: Survey Research Tools (Future)

- `cassidy_interpret_efa()` - EFA interpretation with recommendations
- `cassidy_write_methods()` - Generate methods sections in APA format
- `cassidy_survey_codebook()` - Enhanced codebook for survey data
- `cassidy_scale_analysis()` - Comprehensive scale reliability analysis

## Package Development Status

- The package follows **ellmer's testing pattern** for API tests
- Ready for **CRAN submission** after Phase 6 (IDE Integration)
- Built with **R 4.1+** in mind (native pipe `|>` support)
- Currently on **Phase 5 complete** - Skills System implemented

## IDE Support

The package is designed to work across multiple IDEs:

- RStudio - Primary development environment
- Positron - Growing alternative, actively supported
- VS Code - With R extension
- Terminal - All features work in plain R

Functions detect IDE automatically and adapt behavior (e.g., file opening).
