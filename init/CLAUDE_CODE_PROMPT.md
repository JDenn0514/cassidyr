# Implementation Prompt for Claude Code

## Task: Implement Agentic Capabilities for cassidyr

Please implement the agentic capabilities for the cassidyr R package following the hybrid architecture approach detailed in `init/AGENTIC_IMPLEMENTATION_PLAN.md`.

### Step 1: Create Feature Branch

**IMPORTANT**: Create a new git branch for this work:
```bash
git checkout -b feature/agentic-hybrid
```

### Step 2: Explore the Package (15-20 minutes)

Before implementing, thoroughly scan the cassidyr package:

1. **Read the implementation plan**: `init/AGENTIC_IMPLEMENTATION_PLAN.md`
2. **Understand existing patterns**:
   - File structure: `.claude/rules/file-structure.md`
   - Coding conventions: `.claude/rules/testing-standards.md`
   - Development workflow: `.claude/rules/development-workflow.md`

3. **Examine key files**:
   - `R/api-core.R` - API client patterns
   - `R/context-*.R` - Context system we'll leverage
   - `R/chat-*.R` - Shiny app structure (for future v1.3)
   - `DESCRIPTION` - Current dependencies

4. **Note patterns**:
   - Naming: All exports use `cassidy_*` prefix
   - Errors: Use `cli::cli_abort()` with helpful messages
   - Docs: Roxygen2 with markdown, include examples
   - Testing: testthat 3e, no API calls in unit tests

### Step 3: Implement Core Components

#### Phase 1: Tool System (Week 1)

Create these files following the detailed specifications in the implementation plan:

1. **`R/agentic-tools.R`**
   - Tool registry (`.cassidy_tools` list)
   - Tool execution (`.execute_tool()`)
   - Risk identification (`.is_risky_tool()`)
   - **Key**: Mark `write_file` and `execute_code` as `risky = TRUE`

2. **`R/agentic-workflow.R`**
   - Workflow integration (`.call_tool_workflow()`)
   - Setup helper (`cassidy_setup_workflow()` - exported)
   - **Key**: Validates structured output schema

3. **`R/agentic-approval.R`**
   - Approval system (`.request_approval()`)
   - Interactive editing (`.edit_tool_input()`)
   - Tool details (`.show_tool_details()`)
   - **Key**: Uses `cli` for nice interactive prompts

4. **Tests**: `tests/testthat/test-agentic-tools.R`
   - Tool registry structure
   - Risky tool identification
   - Error handling

#### Phase 2: Main Loop (Week 2)

1. **`R/agentic-chat.R`**
   - Main function (`cassidy_agentic_task()`)
   - System prompt builder (`.build_agentic_prompt()`)
   - Print method (`print.cassidy_agentic_result()`)
   - **Key**: `safe_mode = TRUE` by default!

2. **Tests**: `tests/testthat/test-agentic-workflow.R`
   - Mock workflow responses (don't call real API)
   - Validate response handling

3. **Manual tests**: `tests/manual/test-agentic-live.R`
   - Real workflow integration (requires API key)
   - Safe mode testing

#### Phase 3: CLI Wrapper (Week 3)

1. **`inst/cli/cassidy.R`**
   - Executable script with shebang
   - Command routing (agent/chat/context/setup/help)
   - Interactive REPL mode

2. **`R/cli-install.R`**
   - Installation function (`cassidy_install_cli()`)
   - Cross-platform (Unix + Windows)

#### Phase 4: Documentation & Integration

1. **Update `DESCRIPTION`**
   - No new dependencies needed (all existing!)
   - Version bump if appropriate

2. **Update `NAMESPACE`**
   - Run `devtools::document()` after adding roxygen docs

3. **Update `README.md`**
   - Add "Agentic Capabilities" section
   - Quick start example
   - Link to workflow setup

4. **Update `.claude/rules/roadmap.md`**
   - Mark Phase 1 (Agentic v1.0) as "In Progress"

### Step 4: Testing Strategy

After implementing each phase:

1. **Run tests**: `devtools::test()`
2. **Check package**: `devtools::check()`
3. **Fix issues** before moving to next phase
4. **Document** what was tested and any issues found

**For manual testing** (requires API credentials):
```r
# 1. Set up environment variables
Sys.setenv(
  CASSIDY_API_KEY = "your-key",
  CASSIDY_ASSISTANT_ID = "your-assistant-id",
  CASSIDY_WORKFLOW_WEBHOOK = "your-webhook-url"
)

# 2. Test safe mode (should prompt for approval)
cassidy_agentic_task(
  "Create a function that adds two numbers in R/test.R",
  max_iterations = 5
)

# 3. Test read-only operations (no approval needed)
cassidy_agentic_task(
  "List all R files and summarize what they do",
  tools = c("list_files", "read_file"),
  max_iterations = 3
)
```

### Step 5: Commit Strategy

Make logical commits as you go:

```bash
# After Phase 1
git add R/agentic-tools.R R/agentic-workflow.R R/agentic-approval.R tests/testthat/test-agentic-tools.R
git commit -m "feat: Add tool system with workflow integration and approval

- Implement tool registry with 7 core tools
- Add workflow integration for structured JSON responses
- Add interactive approval system (safe_mode = TRUE by default)
- Mark write_file and execute_code as risky
- Add tests for tool execution and risk identification"

# After Phase 2
git add R/agentic-chat.R tests/testthat/test-agentic-workflow.R tests/manual/test-agentic-live.R
git commit -m "feat: Implement main agentic loop with hybrid architecture

- Add cassidy_agentic_task() with safe_mode default
- Integrate Assistant (reasoning) + Workflow (tool decisions)
- Add iteration management and error handling
- Add print method for results
- Add manual tests for live API integration"

# After Phase 3
git add inst/cli/cassidy.R R/cli-install.R
git commit -m "feat: Add CLI wrapper for command-line usage

- Add cassidy executable script with REPL mode
- Add installation function for cross-platform setup
- Support interactive and direct task modes
- Add help/context/setup commands"

# After Phase 4
git add DESCRIPTION NAMESPACE README.md .claude/rules/roadmap.md
git commit -m "docs: Update documentation for agentic features

- Add agentic section to README
- Update roadmap to mark v1.0 in progress
- Run devtools::document() to update NAMESPACE
- No new dependencies required"
```

## Key Implementation Notes

### Architecture: Hybrid Approach

This is NOT a simple text-parsing agent. The architecture is:

1. **Assistant (CassidyAI)**: High-level reasoning and planning
2. **Workflow (CassidyAI)**: Structured tool decisions (guaranteed JSON)
3. **R Functions**: Tool execution with approval

**Why?** Workflows with structured output fields eliminate parsing errors and guarantee reliable tool calling.

### Safe Mode: Default TRUE

**CRITICAL**: `safe_mode = TRUE` must be the default in `cassidy_agentic_task()`.

Risky operations (write_file, execute_code) should:
1. Show the action, parameters, and reasoning
2. Prompt: "Approve? [y/n/e/v]:"
3. Allow editing parameters before execution
4. Be deniable

Only set `safe_mode = FALSE` when user explicitly opts out.

### Code Quality

Follow existing cassidyr conventions:

- ✅ `cassidy_*` prefix for all exports
- ✅ `cli::cli_abort()` for errors with helpful messages
- ✅ Roxygen2 docs with `@export`, `@param`, `@return`, `@examples`
- ✅ Use `\dontrun{}` for examples requiring API keys
- ✅ Internal functions start with `.` (e.g., `.execute_tool()`)
- ✅ Leverage existing functions:
  - `cassidy_create_thread()` for threads
  - `cassidy_send_message()` for messages
  - `cassidy_describe_file()` for reading R files
  - `cassidy_context_project()` for context

### Dependencies

**Good news**: No new dependencies needed!

- `httr2` - Already imported (for workflow webhooks)
- `cli` - Already imported (for prompts)
- `jsonlite` - Already imported (for JSON)

Just use existing tools.

### Testing Philosophy

- **Unit tests**: Test logic without API calls
- **Manual tests**: Real API integration (requires credentials)
- **No mocking complex APIs**: Keep tests simple and maintainable

### Error Handling

Be defensive:

- Validate workflow response structure
- Handle missing environment variables gracefully
- Provide actionable error messages
- Never crash silently

Good:
```r
cli::cli_abort(c(
  "Workflow webhook URL not found",
  "i" = "Set {.envvar CASSIDY_WORKFLOW_WEBHOOK} in .Renviron",
  "i" = "Run {.run cassidy_setup_workflow()} for setup instructions"
))
```

Bad:
```r
stop("Webhook URL missing")
```

## Expected Deliverables

After implementation, we should have:

1. ✅ Working agentic system with hybrid architecture
2. ✅ Safe mode enabled by default
3. ✅ Interactive approval for risky operations
4. ✅ CLI tool installable with `cassidy_install_cli()`
5. ✅ Documentation and examples
6. ✅ Tests passing (`devtools::test()`)
7. ✅ Package checks clean (`devtools::check()`)
8. ✅ Feature branch ready for review

## Questions?

If you encounter issues or need clarification:

1. **Check the implementation plan**: `init/AGENTIC_IMPLEMENTATION_PLAN.md`
2. **Review existing code**: Look at how similar patterns are implemented
3. **Ask for clarification**: Document specific questions/blockers

## Success Criteria

Implementation is complete when:

- [ ] All 4 phases implemented
- [ ] Tests pass (`devtools::test()`)
- [ ] Package checks clean (`devtools::check()`)
- [ ] CLI tool works: `cassidy agent "test task"`
- [ ] Safe mode prompts for approval on risky operations
- [ ] README documents agentic features
- [ ] Manual test successfully completes a real task
- [ ] Code follows cassidyr conventions
- [ ] Feature branch committed and ready for review

## Getting Started

Start by reading the implementation plan carefully, then create the feature branch and begin with Phase 1 (Tool System). Test thoroughly after each phase before moving forward.

Good luck! 🚀
