# Agentic Implementation Plan for cassidyr

## ✅ IMPLEMENTATION COMPLETED

**Date**: February 10, 2026
**Status**: Fully functional agentic system with direct parsing

### What Was Built

The cassidyr package now has a complete agentic system that allows the CassidyAI assistant to autonomously:
- ✅ Read and write files (with user approval by default)
- ✅ Execute R code safely in sandboxed environment
- ✅ List and search files
- ✅ Gather project context dynamically
- ✅ Describe data frames in the environment
- ✅ Chain multiple operations together
- ✅ Work iteratively toward completing complex tasks
- ✅ Support unlimited iterations (`max_iterations = Inf`)
- ✅ Provide command-line interface (`cassidy agent`)

### Architecture: Direct Parsing (Simplified from Original Plan)

**Original Plan**: Hybrid with CassidyAI Workflows for tool decisions
**Actual Implementation**: Direct parsing of assistant responses

**Why the Change?**
- CassidyAI Workflows had unreliable template variable handling for webhooks
- Direct parsing is simpler, more maintainable, and works reliably
- No external dependencies (workflow setup, webhook configuration)

**Current Architecture**:
```
User → Assistant (reasoning + structured decision) → Parse → Execute → Loop
```

The assistant responds with structured text:
```
<TOOL_DECISION>
ACTION: list_files
INPUT: {"directory": ".", "pattern": "*.R"}
REASONING: Need to find all R files
STATUS: continue
</TOOL_DECISION>
```

R code parses this directly and executes the tool.

### Key Features Implemented

1. **Tool System** (`R/agentic-tools.R`)
   - 7 built-in tools: read_file, write_file, execute_code, list_files, search_files, get_context, describe_data
   - Flexible parameter handling (accepts both `directory` and `path`)
   - Proper error handling and validation

2. **Direct Parsing** (`R/agentic-workflow.R`)
   - Robust regex-based parsing with `[\s\S]` for multiline matching
   - TASK COMPLETE detection with multiple pattern variants
   - Fallback inference when structured format not used
   - Debug mode support (`options(cassidy.debug = TRUE)`)

3. **Approval System** (`R/agentic-approval.R`)
   - Interactive prompts for risky operations (write_file, execute_code)
   - Approve/deny/edit/view options
   - Custom approval callbacks supported
   - Safe mode enabled by default

4. **Main Agentic Loop** (`R/agentic-chat.R`)
   - Orchestrates assistant → parsing → tool execution
   - Iteration management (finite or unlimited with `Inf`)
   - Context persistence across iterations
   - Graceful error handling
   - Tool validation (rejects unavailable tools)

5. **CLI Wrapper** (`R/cli-install.R`, `inst/cli/cassidy.R`)
   - Command-line interface: `cassidy agent "task"`
   - Interactive REPL mode: `cassidy agent`
   - Cross-platform support (Mac, Linux, Windows)
   - Installation helper: `cassidy_install_cli()`

### Usage Examples

```r
# Simple task
result <- cassidy_agentic_task(
  "List all R files in this directory"
)

# With unlimited iterations
result <- cassidy_agentic_task(
  "Analyze and refactor test files",
  max_iterations = Inf
)

# Read-only tools
result <- cassidy_agentic_task(
  "Review my code structure",
  tools = c("list_files", "read_file", "get_context")
)

# Disable safe mode (careful!)
result <- cassidy_agentic_task(
  "Create a helper function",
  safe_mode = FALSE
)
```

### Files Created/Modified

**New Files**:
- ✅ `R/agentic-tools.R` - Tool registry and execution
- ✅ `R/agentic-workflow.R` - Direct parsing (renamed from workflow integration)
- ✅ `R/agentic-approval.R` - User approval system
- ✅ `R/agentic-chat.R` - Main agentic loop
- ✅ `R/agentic-test.R` - Workflow testing utilities
- ✅ `R/cli-install.R` - CLI installation
- ✅ `inst/cli/cassidy.R` - CLI executable
- ✅ `tests/testthat/test-agentic-tools.R` - Tool tests
- ✅ `tests/testthat/test-agentic-workflow.R` - Parsing tests
- ✅ `tests/manual/test-agentic-live.R` - Live integration tests
- ✅ `tests/manual/test-agentic-direct-parsing.R` - Direct parsing tests
- ✅ `tests/manual/test-unlimited-iterations.R` - Unlimited iteration tests
- ✅ `tests/manual/test-parsing-debug.R` - Debug mode tests
- ✅ `DIRECT_PARSING_MIGRATION.md` - Migration guide

**Modified Files**:
- ✅ `NAMESPACE` - Exported agentic functions
- ✅ `R/cassidyr-package.R` - Updated package documentation

### Environment Variables Required

```bash
# In .Renviron
CASSIDY_ASSISTANT_ID=your-assistant-id
CASSIDY_API_KEY=your-api-key
# CASSIDY_WORKFLOW_WEBHOOK - NO LONGER NEEDED!
```

### Testing Status

- ✅ All automated tests pass
- ✅ Manual tests verified with live API
- ✅ Safe mode approval tested
- ✅ Unlimited iterations tested
- ✅ Tool execution tested (all 7 tools)
- ✅ TASK COMPLETE detection tested
- ✅ Error handling tested

### Success Metrics

1. ✅ Assistant provides structured tool decisions
2. ✅ Safe mode prompts for approval on risky operations (default behavior)
3. ✅ Users can approve/deny/edit tool parameters
4. ✅ Tools execute correctly with proper error handling
5. ✅ CLI tool works from command line
6. ✅ Real-world tasks complete end-to-end
7. ✅ Unlimited iterations supported
8. ✅ Debug mode available for troubleshooting

---

## ORIGINAL PLAN (For Reference)

The sections below contain the original implementation plan. The actual implementation differs in the following ways:
- **Direct parsing** instead of CassidyAI Workflow integration
- **Simpler architecture** with fewer moving parts
- **No workflow setup** required (removed `cassidy_setup_workflow()` complexity)
- **More robust parsing** with fallback mechanisms

---

## Background

### CassidyAI Platform Capabilities

**Assistants**:
- ✅ Conversational interface with thread history
- ✅ Complex reasoning and planning
- ✅ Context-aware responses
- ❌ No guaranteed output structure

**Workflows**:
- ✅ **Structured output fields** with schema validation
- ✅ Webhook triggers (POST request → JSON response)
- ✅ JavaScript execution via "Run Code" action
- ✅ API request capabilities
- ✅ Guaranteed JSON format

### Why Hybrid?

1. **Use Assistants for Reasoning**: Complex thought, planning, explanations
2. **Use Workflows for Tool Decisions**: Reliable JSON with `{action, input, reasoning}`
3. **Use R for Execution**: Native file/code operations with full control

## Architecture Design

### High-Level Flow

```
┌─────────────────────────────────────────────────┐
│  User Task                                      │
│  cassidy_agentic_task("Review my R code")      │
└────────────────┬────────────────────────────────┘
                 │
        ┌────────▼────────┐
        │  Agentic Loop   │  (R function)
        │  - Iterations   │
        │  - Context mgmt │
        │  - Approval     │
        └────┬───────┬────┘
             │       │
    ┌────────▼──┐ ┌─▼──────────┐
    │ ASSISTANT │ │  WORKFLOW  │
    │ (Thinking)│ │  (Actions) │
    └────────┬──┘ └─┬──────────┘
             │      │
             │  ┌───▼────────────┐
             │  │ Structured     │
             │  │ {action, input}│
             │  └───┬────────────┘
             │      │
             └──────┴──────┐
                    │
        ┌───────────▼───────────┐
        │  Tool Execution (R)   │
        │  - read_file()        │
        │  - write_file()       │ ← Requires approval
        │  - execute_code()     │ ← Requires approval
        └───────────────────────┘
```

### Detailed Flow

1. **User submits task** via CLI or R console
   ```bash
   $ cassidy agent "Review all R files in my package"
   ```

2. **R Loop** creates Assistant thread with context
   ```r
   thread_id <- cassidy_create_thread()
   message <- paste(system_prompt, context, task)
   response <- cassidy_send_message(thread_id, message)
   ```

3. **Assistant** provides reasoning
   ```
   "I should start by listing all R files to understand
    the package structure, then read each file to review the code..."
   ```

4. **R Loop** calls Tool Decision Workflow
   ```r
   decision <- .call_tool_workflow(
     reasoning = assistant_response,
     available_tools = c("read_file", "list_files", ...),
     context = current_state
   )
   ```

5. **Workflow** returns structured JSON (guaranteed)
   ```json
   {
     "action": "list_files",
     "input": {"directory": "R", "pattern": "*.R"},
     "reasoning": "Need to see all R files first",
     "status": "continue"
   }
   ```

6. **R Loop** checks if approval needed (safe_mode = TRUE by default)
   ```r
   if (safe_mode && is_risky_tool(decision$action)) {
     approval <- request_user_approval(decision)
     if (!approval$approved) {
       # Send denial back to assistant
       continue
     }
     # Use potentially edited input
     decision$input <- approval$input
   }
   ```

7. **Execute tool** and send result back
   ```r
   result <- execute_tool(decision$action, decision$input)
   # Loop back to step 2 with result
   ```

8. **Repeat** until workflow returns `"status": "final"`

### Core Components

1. **Tool Registry** (`R/agentic-tools.R`)
   - Defines available tools and their handlers
   - Executes tools with proper error handling

2. **Workflow Integration** (`R/agentic-workflow.R`)
   - Calls CassidyAI Workflow via webhook POST
   - Receives structured JSON responses
   - Validates schema

3. **Approval System** (`R/agentic-approval.R`)
   - Interactive prompts for risky operations
   - Shows reasoning and parameters
   - Allows editing before execution

4. **Main Loop** (`R/agentic-chat.R`)
   - Orchestrates Assistant ↔ Workflow ↔ Tools
   - Manages iterations and context
   - Handles errors and edge cases

5. **CLI Wrapper** (`inst/cli/cassidy.R`)
   - Command-line interface
   - Interactive REPL mode
   - Real-time progress display

## Implementation Plan

### Phase 1: Core Infrastructure (Week 1-2)

#### 1.1 Tool System

**File**: `R/agentic-tools.R`

```r
# Tool registry (same as original plan)
.cassidy_tools <- list(
  read_file = list(
    description = "Read contents of a file",
    risky = FALSE,
    handler = function(filepath, working_dir = getwd()) {
      # Use existing cassidy_describe_file() for R files
      # Plain readLines() for others
    }
  ),

  write_file = list(
    description = "Write content to a file",
    risky = TRUE,  # ← Requires approval
    handler = function(filepath, content, working_dir = getwd()) {
      # Implementation
    }
  ),

  execute_code = list(
    description = "Execute R code",
    risky = TRUE,  # ← Requires approval
    handler = function(code) {
      # Sandboxed execution
    }
  ),

  list_files = list(
    description = "List files in directory",
    risky = FALSE,
    handler = function(directory = ".", pattern = NULL) {
      # Implementation
    }
  ),

  search_files = list(
    description = "Search for text in files",
    risky = FALSE,
    handler = function(pattern, directory = ".", file_pattern = NULL) {
      # Implementation
    }
  ),

  get_context = list(
    description = "Get project context",
    risky = FALSE,
    handler = function(level = "standard") {
      cassidy_context_project(level = level)
    }
  ),

  describe_data = list(
    description = "Describe a data frame",
    risky = FALSE,
    handler = function(name, method = "basic") {
      cassidy_describe_df(get(name, envir = .GlobalEnv), method = method)
    }
  )
)

# Execute tool with error handling
.execute_tool <- function(tool_name, input, working_dir = getwd()) {
  # Implementation
}

# Check if tool is risky
.is_risky_tool <- function(tool_name) {
  .cassidy_tools[[tool_name]]$risky %||% FALSE
}
```

#### 1.2 Workflow Integration

**File**: `R/agentic-workflow.R`

```r
#' Call CassidyAI Tool Decision Workflow
#'
#' @param reasoning Character. The assistant's reasoning about next steps
#' @param available_tools Character vector. Tools the agent can use
#' @param context List. Current state/context
#' @param workflow_webhook Character. Webhook URL from CASSIDY_WORKFLOW_WEBHOOK env var
#'
#' @return List with action, input, reasoning, status
#' @keywords internal
.call_tool_workflow <- function(
  reasoning,
  available_tools,
  context = NULL,
  workflow_webhook = Sys.getenv("CASSIDY_WORKFLOW_WEBHOOK")
) {

  if (!nzchar(workflow_webhook)) {
    cli::cli_abort(c(
      "Workflow webhook URL not found",
      "i" = "Set {.envvar CASSIDY_WORKFLOW_WEBHOOK} in .Renviron",
      "i" = "Create workflow in CassidyAI with structured output fields"
    ))
  }

  # Build payload
  payload <- list(
    reasoning = reasoning,
    available_tools = available_tools,
    context = context
  )

  # Call workflow
  resp <- httr2::request(workflow_webhook) |>
    httr2::req_body_json(payload) |>
    httr2::req_timeout(120) |>
    httr2::req_perform()

  # Parse structured output
  result <- httr2::resp_body_json(resp)

  # Validate required fields
  required <- c("action", "input", "reasoning", "status")
  if (!all(required %in% names(result))) {
    cli::cli_abort(c(
      "Workflow returned invalid structure",
      "i" = "Expected fields: {.field {required}}",
      "i" = "Got: {.field {names(result)}}"
    ))
  }

  result
}

#' Setup Tool Decision Workflow (one-time)
#'
#' Helper to document how to create the workflow in CassidyAI platform
#'
#' @export
cassidy_setup_workflow <- function() {
  cli::cli_h1("Setup Tool Decision Workflow")
  cli::cli_text("Create a new workflow in CassidyAI with:")
  cli::cli_h2("Trigger")
  cli::cli_ul(c(
    "Type: Webhook",
    "Enable: 'Return results from webhook'"
  ))
  cli::cli_h2("Action: Generate Text with Cassidy Agent")
  cli::cli_text("Prompt:")
  cli::cli_code('
Based on the reasoning and available tools, decide what action to take next.

Available tools: {{available_tools}}
Current reasoning: {{reasoning}}
Context: {{context}}

Choose the most appropriate tool and provide the exact parameters needed.
  ')
  cli::cli_h2("Structured Output Fields")
  cli::cli_ul(c(
    "action (Dropdown): [list all tool names]",
    "input (Object): Tool parameters as key-value pairs",
    "reasoning (Text): Why this action was chosen",
    "status (Dropdown): ['continue', 'final']"
  ))
  cli::cli_h2("Save Webhook URL")
  cli::cli_code("Sys.setenv(CASSIDY_WORKFLOW_WEBHOOK = 'your-webhook-url')")
  cli::cli_text("Add to {.file .Renviron} for persistence")
}
```

#### 1.3 Approval System

**File**: `R/agentic-approval.R`

```r
#' Request user approval for risky actions
#'
#' @param action Character. Tool name
#' @param input List. Tool parameters
#' @param reasoning Character. Why agent wants to do this
#' @param callback Function. Optional custom approval handler
#'
#' @return List with approved (logical) and input (potentially edited)
#' @keywords internal
.request_approval <- function(action, input, reasoning, callback = NULL) {

  # Use custom callback if provided
  if (!is.null(callback)) {
    return(callback(action, input, reasoning))
  }

  # Interactive approval prompt
  cli::cli_h3("Agent Action Request")
  cli::cli_alert_warning("Action: {.field {action}}")
  cli::cli_text("Reasoning: {.emph {reasoning}}")
  cli::cli_h4("Parameters:")
  cli::cli_code(jsonlite::toJSON(input, pretty = TRUE, auto_unbox = TRUE))
  cli::cli_text("")

  # Get user response
  response <- readline(cli::col_cyan("❯ Approve? [y/n/e(dit)/v(iew)]: "))
  response <- tolower(trimws(response))

  if (response == "n" || response == "no") {
    cli::cli_alert_danger("Action denied")
    return(list(approved = FALSE, input = input))
  }

  if (response == "v" || response == "view") {
    # Show more details
    .show_tool_details(action, input)
    return(.request_approval(action, input, reasoning, callback))
  }

  if (response == "e" || response == "edit") {
    # Interactive parameter editing
    edited_input <- .edit_tool_input(action, input)
    cli::cli_alert_success("Parameters updated")
    return(list(approved = TRUE, input = edited_input))
  }

  # Default: approve
  cli::cli_alert_success("Action approved")
  list(approved = TRUE, input = input)
}

#' Edit tool input interactively
#' @keywords internal
.edit_tool_input <- function(action, input) {
  cli::cli_h4("Edit parameters (enter new JSON or press Enter to keep current)")
  cli::cli_text("Current:")
  cli::cli_code(jsonlite::toJSON(input, pretty = TRUE, auto_unbox = TRUE))

  # Get edited JSON
  edited_json <- readline("New JSON: ")

  if (!nzchar(trimws(edited_json))) {
    return(input)  # Keep original
  }

  # Parse and validate
  tryCatch({
    jsonlite::fromJSON(edited_json, simplifyVector = FALSE)
  }, error = function(e) {
    cli::cli_alert_danger("Invalid JSON: {e$message}")
    .edit_tool_input(action, input)  # Try again
  })
}

#' Show detailed tool information
#' @keywords internal
.show_tool_details <- function(action, input) {
  tool <- .cassidy_tools[[action]]
  cli::cli_h4("Tool: {action}")
  cli::cli_text("Description: {tool$description}")
  cli::cli_text("Risky: {tool$risky}")
  cli::cli_h5("Parameters:")
  for (param in names(tool$parameters)) {
    cli::cli_li("{param}: {tool$parameters[[param]]}")
  }
}
```

### Phase 2: Main Agentic Function (Week 2-3)

**File**: `R/agentic-chat.R`

```r
#' Run an Agentic Task with CassidyAI
#'
#' Execute a task where the AI assistant autonomously uses tools to accomplish
#' complex goals. Uses a hybrid architecture: Assistant for reasoning, Workflow
#' for structured tool decisions, R for execution.
#'
#' @param task Character. The task description
#' @param assistant_id Character. CassidyAI assistant ID (default: env var)
#' @param api_key Character. CassidyAI API key (default: env var)
#' @param workflow_webhook Character. Workflow webhook URL (default: env var)
#' @param tools Character vector. Tools to enable (default: all)
#' @param working_dir Character. Working directory (default: current)
#' @param max_iterations Integer. Max tool calls (default: 10)
#' @param initial_context Character/list. Optional context
#' @param safe_mode Logical. Require approval for risky tools? (default: TRUE)
#' @param approval_callback Function. Custom approval handler (default: NULL)
#' @param verbose Logical. Show progress? (default: TRUE)
#'
#' @return cassidy_agentic_result object
#'
#' @export
#'
#' @examples
#' \dontrun{
#' # Simple task with safe mode (default)
#' result <- cassidy_agentic_task(
#'   "Review the code in R/utils.R"
#' )
#'
#' # Allow risky operations without approval (use with caution!)
#' result <- cassidy_agentic_task(
#'   "Create a helper function in R/helpers.R",
#'   safe_mode = FALSE
#' )
#'
#' # Custom approval function
#' my_approver <- function(action, input, reasoning) {
#'   # Auto-approve read operations, deny writes
#'   list(approved = action == "read_file", input = input)
#' }
#'
#' result <- cassidy_agentic_task(
#'   "Analyze my package",
#'   approval_callback = my_approver
#' )
#' }
cassidy_agentic_task <- function(
  task,
  assistant_id = Sys.getenv("CASSIDY_ASSISTANT_ID"),
  api_key = Sys.getenv("CASSIDY_API_KEY"),
  workflow_webhook = Sys.getenv("CASSIDY_WORKFLOW_WEBHOOK"),
  tools = names(.cassidy_tools),
  working_dir = getwd(),
  max_iterations = 10,
  initial_context = NULL,
  safe_mode = TRUE,  # ← DEFAULT TRUE
  approval_callback = NULL,
  verbose = TRUE
) {

  # Validate inputs
  if (!nzchar(task)) {
    cli::cli_abort("Task cannot be empty")
  }

  # Create thread
  if (verbose) cli::cli_alert_info("Creating conversation thread...")
  thread_id <- cassidy_create_thread(assistant_id, api_key)

  # Build system prompt for assistant
  system_prompt <- .build_agentic_prompt(working_dir, max_iterations)

  # Build initial message
  message <- paste0(
    system_prompt,
    if (!is.null(initial_context)) paste0("\n\nCONTEXT:\n", initial_context),
    "\n\nTASK: ", task
  )

  # Initialize tracking
  iteration <- 0
  actions_taken <- list()

  if (verbose) {
    cli::cli_alert_success("Thread: {.val {thread_id}}")
    cli::cli_h2("Starting Agentic Task")
    cli::cli_text("Task: {.emph {task}}")
    cli::cli_text("Safe mode: {.val {safe_mode}}")
    cli::cli_text("")
  }

  # Main loop
  current_message <- message

  repeat {
    iteration <- iteration + 1

    if (iteration > max_iterations) {
      if (verbose) cli::cli_alert_warning("Max iterations reached")
      break
    }

    if (verbose) cli::cli_h3("Iteration {iteration}/{max_iterations}")

    # Get assistant reasoning
    if (verbose) cli::cli_alert_info("Consulting assistant...")
    response <- cassidy_send_message(thread_id, current_message, api_key)

    if (verbose) {
      cli::cli_text("{cli::col_silver('💭')} {response$content}")
    }

    # Get tool decision from workflow
    if (verbose) cli::cli_alert_info("Getting tool decision...")

    decision <- tryCatch({
      .call_tool_workflow(
        reasoning = response$content,
        available_tools = tools,
        context = list(
          iteration = iteration,
          working_dir = working_dir
        ),
        workflow_webhook = workflow_webhook
      )
    }, error = function(e) {
      list(
        status = "final",
        reasoning = paste("Workflow error:", e$message)
      )
    })

    # Check if done
    if (decision$status == "final") {
      if (verbose) {
        cli::cli_alert_success("Task completed!")
        cli::cli_text(decision$reasoning)
      }

      return(structure(
        list(
          task = task,
          final_response = decision$reasoning,
          iterations = iteration,
          actions_taken = actions_taken,
          thread_id = thread_id,
          success = TRUE
        ),
        class = "cassidy_agentic_result"
      ))
    }

    # Handle tool execution
    if (verbose) {
      cli::cli_alert_info("Action: {.field {decision$action}}")
      cli::cli_text("Reasoning: {.emph {decision$reasoning}}")
    }

    # Check approval for risky tools
    if (safe_mode && .is_risky_tool(decision$action)) {
      approval <- .request_approval(
        action = decision$action,
        input = decision$input,
        reasoning = decision$reasoning,
        callback = approval_callback
      )

      if (!approval$approved) {
        # Send denial back
        current_message <- paste0(
          "DENIED: User did not approve the '", decision$action, "' action.\n",
          "Try a different approach."
        )
        next
      }

      # Use potentially edited input
      decision$input <- approval$input
    }

    # Execute tool
    if (verbose) cli::cli_alert_info("Executing...")

    result <- .execute_tool(
      tool_name = decision$action,
      input = decision$input,
      working_dir = working_dir
    )

    # Record action
    actions_taken <- c(actions_taken, list(list(
      iteration = iteration,
      action = decision$action,
      input = decision$input,
      result = result
    )))

    # Format for next message
    if (result$success) {
      if (verbose) cli::cli_alert_success("Tool executed")
      current_message <- paste0(
        "RESULT (", decision$action, "):\n",
        if (is.character(result$result)) result$result
        else paste(capture.output(print(result$result)), collapse = "\n")
      )
    } else {
      if (verbose) cli::cli_alert_danger("Tool failed: {result$error}")
      current_message <- paste0(
        "ERROR (", decision$action, "):\n", result$error,
        "\nTry a different approach."
      )
    }
  }

  # Max iterations reached
  structure(
    list(
      task = task,
      final_response = "Task incomplete (max iterations)",
      iterations = iteration,
      actions_taken = actions_taken,
      thread_id = thread_id,
      success = FALSE
    ),
    class = "cassidy_agentic_result"
  )
}

#' Build system prompt for assistant
#' @keywords internal
.build_agentic_prompt <- function(working_dir, max_iterations) {
  paste0(
    "You are an expert R programming assistant working in: ", working_dir, "\n\n",
    "Your role is to analyze tasks and provide clear reasoning about what needs to be done.\n",
    "After you provide your reasoning, a tool decision system will choose which tool to use.\n\n",
    "Guidelines:\n",
    "- Break down complex tasks into steps\n",
    "- Explain your reasoning clearly\n",
    "- Consider edge cases and errors\n",
    "- Follow R and tidyverse best practices\n",
    "- You have ", max_iterations, " iterations to complete the task\n\n",
    "When the task is complete, clearly state: TASK COMPLETE: [summary]"
  )
}

#' @export
print.cassidy_agentic_result <- function(x, ...) {
  cli::cli_h1("Agentic Task Result")
  cli::cli_text("Task: {.emph {x$task}}")
  cli::cli_text("Success: {.val {x$success}}")
  cli::cli_text("Iterations: {.val {x$iterations}}")
  cli::cli_text("Actions: {.val {length(x$actions_taken)}}")

  if (x$success) {
    cli::cli_h2("Result")
    cli::cli_text(x$final_response)
  }

  if (length(x$actions_taken) > 0) {
    cli::cli_h2("Actions Taken")
    for (i in seq_along(x$actions_taken)) {
      a <- x$actions_taken[[i]]
      cli::cli_text("{i}. {.field {a$action}} (iteration {a$iteration})")
    }
  }

  invisible(x)
}
```

### Phase 3: CLI Wrapper (Week 3-4)

**File**: `inst/cli/cassidy.R`

```r
#!/usr/bin/env Rscript

# Parse args
args <- commandArgs(trailingOnly = TRUE)

# Load package
suppressPackageStartupMessages(library(cassidyr))

# CLI router
if (length(args) == 0 || args[1] == "agent") {
  # Agentic mode
  if (length(args) > 1) {
    # Direct task
    task <- paste(args[-1], collapse = " ")
    result <- cassidy_agentic_task(task)
  } else {
    # Interactive REPL
    cli::cli_h1("Cassidy Agent")
    cli::cli_text("Type your task or 'exit' to quit\n")

    repeat {
      task <- readline(cli::col_cyan("❯ "))
      task <- trimws(task)

      if (task == "" || tolower(task) %in% c("exit", "quit", "q")) {
        cli::cli_alert_info("Goodbye!")
        break
      }

      result <- cassidy_agentic_task(task)
      cat("\n")
    }
  }

} else if (args[1] == "chat") {
  # Launch Shiny app
  cassidy_app()

} else if (args[1] == "context") {
  # Show context
  ctx <- cassidy_context_project()
  cat(ctx$text)

} else if (args[1] == "setup") {
  # Setup wizard
  cassidy_setup_workflow()

} else {
  # Help
  cat("
Cassidy CLI - AI-powered R assistant

Usage:
  cassidy agent [task]     Start agentic session
  cassidy chat             Launch Shiny chat app
  cassidy context          Show project context
  cassidy setup            Setup workflow configuration
  cassidy help             Show this help

Examples:
  cassidy agent \"Review my code\"
  cassidy agent            # Interactive mode
  ")
}
```

**File**: `R/cli-install.R`

```r
#' Install Cassidy CLI Tool
#'
#' Installs the cassidy command-line tool to your system PATH.
#' After installation, you can run 'cassidy agent' from any directory.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' cassidy_install_cli()
#' }
cassidy_install_cli <- function() {
  cli_script <- system.file("cli", "cassidy.R", package = "cassidyr")

  if (!file.exists(cli_script)) {
    cli::cli_abort("CLI script not found in package")
  }

  if (.Platform$OS.type == "unix") {
    # Mac/Linux
    dest <- path.expand("~/.local/bin/cassidy")
    dir.create(dirname(dest), showWarnings = FALSE, recursive = TRUE)

    file.copy(cli_script, dest, overwrite = TRUE)
    Sys.chmod(dest, mode = "0755")

    cli::cli_alert_success("Installed to {.file {dest}}")
    cli::cli_alert_info("Add {.file ~/.local/bin} to PATH if needed")

  } else {
    # Windows
    dest <- file.path(Sys.getenv("APPDATA"), "cassidy", "cassidy.bat")
    dir.create(dirname(dest), showWarnings = FALSE, recursive = TRUE)

    writeLines(
      c("@echo off", paste0("Rscript \"", cli_script, "\" %*")),
      dest
    )

    cli::cli_alert_success("Installed to {.file {dest}}")
    cli::cli_alert_info("Add {.file {dirname(dest)}} to PATH")
  }
}
```

### Phase 4: Testing (Week 4-5)

**File**: `tests/testthat/test-agentic-tools.R`

```r
test_that("Tool registry is properly defined", {
  expect_true(is.list(.cassidy_tools))
  expect_true("read_file" %in% names(.cassidy_tools))
  expect_true("write_file" %in% names(.cassidy_tools))
})

test_that("Risky tools are identified correctly", {
  expect_true(.is_risky_tool("write_file"))
  expect_true(.is_risky_tool("execute_code"))
  expect_false(.is_risky_tool("read_file"))
  expect_false(.is_risky_tool("list_files"))
})

test_that("Tool execution handles errors", {
  result <- .execute_tool("read_file", list(filepath = "nonexistent.R"))
  expect_false(result$success)
  expect_true("error" %in% names(result))
})
```

**File**: `tests/testthat/test-agentic-workflow.R`

```r
test_that("Workflow integration validates response structure", {
  skip_if_not(nzchar(Sys.getenv("CASSIDY_WORKFLOW_WEBHOOK")))

  result <- .call_tool_workflow(
    reasoning = "Need to list files",
    available_tools = c("list_files", "read_file"),
    context = NULL
  )

  expect_true(all(c("action", "input", "reasoning", "status") %in% names(result)))
})
```

**File**: `tests/manual/test-agentic-live.R`

```r
# Manual test: requires API credentials

# Test 1: Simple task with safe mode
result <- cassidy_agentic_task(
  "List all R files in the R/ directory",
  max_iterations = 3
)
print(result)

# Test 2: Task requiring approval
result <- cassidy_agentic_task(
  "Create a simple hello_world function in R/test.R",
  safe_mode = TRUE,  # Will prompt for approval
  max_iterations = 5
)

# Clean up
if (file.exists("R/test.R")) file.remove("R/test.R")
```

## Workflow Setup in CassidyAI

### Creating the Tool Decision Workflow

1. **Create New Workflow** in CassidyAI platform

2. **Add Webhook Trigger**
   - Enable "Return results from webhook"
   - Optionally require API key

3. **Add Action: "Generate Text with Cassidy Agent"**

   **Prompt**:
   ```
   You are a tool selection expert for an R programming assistant.

   Based on the reasoning provided, choose the most appropriate tool and parameters.

   ## Available Tools
   {{available_tools}}

   ## Current Reasoning
   {{reasoning}}

   ## Context
   {{context}}

   Choose ONE tool and provide exact parameters. If the task is complete, set status to "final".
   ```

4. **Configure Structured Output Fields**:
   - **action** (Dropdown): `read_file, write_file, execute_code, list_files, search_files, get_context, describe_data`
   - **input** (Object): Tool parameters as key-value pairs
   - **reasoning** (Text, Required): Why this action was chosen
   - **status** (Dropdown): `continue, final`

5. **Copy Webhook URL** and save to environment:
   ```r
   # In .Renviron
   CASSIDY_WORKFLOW_WEBHOOK=https://webhook.cassidyai.com/your-webhook-id
   ```

## Success Criteria

Implementation is successful when:

1. ✅ Tool Decision Workflow returns valid structured JSON
2. ✅ Safe mode prompts for approval on risky operations (default behavior)
3. ✅ Users can approve/deny/edit tool parameters
4. ✅ Assistant provides clear reasoning
5. ✅ Tools execute correctly with proper error handling
6. ✅ CLI tool works from command line
7. ✅ Package passes `devtools::check()`
8. ✅ Real-world task completes end-to-end

## File Checklist

**New Files**:
- [ ] `R/agentic-tools.R` - Tool registry and execution
- [ ] `R/agentic-workflow.R` - Workflow integration
- [ ] `R/agentic-approval.R` - User approval system
- [ ] `R/agentic-chat.R` - Main loop
- [ ] `R/cli-install.R` - CLI installation
- [ ] `inst/cli/cassidy.R` - CLI executable
- [ ] `tests/testthat/test-agentic-tools.R`
- [ ] `tests/testthat/test-agentic-workflow.R`
- [ ] `tests/manual/test-agentic-live.R`

**Modified Files**:
- [ ] `DESCRIPTION` - Add dependencies (none new needed!)
- [ ] `NAMESPACE` - Add exports
- [ ] `README.md` - Document agentic features

## Dependencies

No new dependencies required! Uses existing:
- `httr2` - For workflow webhook calls
- `cli` - For interactive prompts
- `jsonlite` - For JSON handling

## Timeline

- **Week 1-2**: Core infrastructure (tools, workflow, approval)
- **Week 3-4**: Main loop and CLI wrapper
- **Week 4-5**: Testing and documentation
- **Week 5+**: Iteration based on real usage

## Future Enhancements

After v1.0 is stable:

- **v1.1**: Skills system (pre-configured agent personas)
- **v1.2**: Enhanced capabilities (memory, custom tools)
- **v1.3**: Shiny app integration (visual agentic mode)
- **v2.0**: Multi-agent orchestration (parallel execution)

See original plan for detailed roadmap.
