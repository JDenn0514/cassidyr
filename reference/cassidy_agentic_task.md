# Run an Agentic Task with CassidyAI

Execute a task where the AI assistant autonomously uses tools to
accomplish complex goals. Uses a hybrid architecture: Assistant for
reasoning, Workflow for structured tool decisions, R for execution.

## Usage

``` r
cassidy_agentic_task(
  task,
  assistant_id = Sys.getenv("CASSIDY_ASSISTANT_ID"),
  api_key = Sys.getenv("CASSIDY_API_KEY"),
  tools = names(.cassidy_tools),
  working_dir = getwd(),
  max_iterations = 10,
  initial_context = NULL,
  safe_mode = TRUE,
  approval_callback = NULL,
  verbose = TRUE
)
```

## Arguments

- task:

  Character. The task description

- assistant_id:

  Character. CassidyAI assistant ID (default: env var)

- api_key:

  Character. CassidyAI API key (default: env var)

- tools:

  Character vector. Tools to enable (default: all)

- working_dir:

  Character. Working directory (default: current)

- max_iterations:

  Integer. Max tool calls (default: 10). Use `Inf` for unlimited.

- initial_context:

  Character/list. Optional context to provide

- safe_mode:

  Logical. Require approval for risky tools? (default: TRUE)

- approval_callback:

  Function. Custom approval handler (default: NULL)

- verbose:

  Logical. Show progress? (default: TRUE)

## Value

A `cassidy_agentic_result` object containing:

- task:

  The original task description

- final_response:

  Final response or completion message

- iterations:

  Number of iterations completed

- actions_taken:

  List of all actions performed

- thread_id:

  CassidyAI thread ID

- success:

  Whether the task completed successfully

## Details

**Safe Mode** is enabled by default, requiring user approval for risky
operations like writing files or executing code. This protects against
unintended changes to your system.

### How It Works

The agentic system uses direct parsing:

1.  **Assistant** analyzes the task and chooses a tool in structured
    format

2.  **R parsing** extracts the tool decision from the response

3.  **R functions** execute tools with proper error handling

4.  **Results** are sent back to the assistant for next steps

The assistant responds with structured `<TOOL_DECISION>` blocks that
specify which tool to use and what parameters to provide.

### Safe Mode

When `safe_mode = TRUE` (default), risky operations require approval:

- `write_file`: Writing/modifying files

- `execute_code`: Executing R code

You'll be prompted to approve, deny, edit parameters, or view details
before each risky action. Safe mode can be disabled by setting
`safe_mode = FALSE`, but use caution!

### Custom Approval

Provide your own approval logic with a callback function:

    my_approver <- function(action, input, reasoning) {
      # Auto-approve read operations, deny writes
      list(approved = action == "read_file", input = input)
    }

    cassidy_agentic_task("Analyze code", approval_callback = my_approver)

## Examples

``` r
if (FALSE) { # \dontrun{
# Simple task with safe mode (default)
result <- cassidy_agentic_task(
  "List all R files and describe what they do"
)

# Task with limited tools (read-only)
result <- cassidy_agentic_task(
  "Analyze the package structure",
  tools = c("list_files", "read_file", "get_context"),
  max_iterations = 5
)

# Unlimited iterations for complex tasks
result <- cassidy_agentic_task(
  "Refactor all test files to use modern patterns",
  max_iterations = Inf
)

# Allow risky operations without approval (use with caution!)
result <- cassidy_agentic_task(
  "Create a helper function in R/helpers.R",
  safe_mode = FALSE
)

# Provide initial context
ctx <- cassidy_context_project(level = "standard")
result <- cassidy_agentic_task(
  "Review my code and suggest improvements",
  initial_context = ctx$text
)
} # }
```
