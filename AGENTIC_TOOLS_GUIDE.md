# Agentic Tools System Guide

## Overview

The cassidyr agentic system can **automatically choose which tools to
use** based on the task. By default, all 7 tools are available, and the
AI assistant intelligently selects the appropriate ones.

## Quick Start

### Default: All Tools Available (Agent Decides)

``` r
# Agent automatically chooses from all 7 tools
cassidy_agentic_task("Analyze my code and suggest improvements")

# Equivalent to:
cassidy_agentic_task(
  "Analyze my code and suggest improvements",
  tools = names(.cassidy_tools)  # All tools
)
```

The agent will automatically use whatever tools it needs!

------------------------------------------------------------------------

## Available Tools (7)

| Tool              | Description                              | Safe Mode            |
|-------------------|------------------------------------------|----------------------|
| **read_file**     | Read contents of a file                  | ✓ Safe               |
| **write_file**    | Write content to a file                  | ⚠️ Requires approval |
| **execute_code**  | Execute R code in a safe environment     | ⚠️ Requires approval |
| **list_files**    | List files in a directory                | ✓ Safe               |
| **search_files**  | Search for text in files                 | ✓ Safe               |
| **get_context**   | Get project context information          | ✓ Safe               |
| **describe_data** | Describe a data frame in the environment | ✓ Safe               |

### View Tools in R

``` r
library(cassidyr)

# See all available tools
cassidy_list_tools()

# Get tool names
tools <- cassidy_list_tools()
```

**Output:**

    ── Available Agentic Tools (7) ──

    ✔ read_file: Read contents of a file
    ! write_file: Write content to a file
      Requires approval in safe mode
    ! execute_code: Execute R code in a safe environment
      Requires approval in safe mode
    ✔ list_files: List files in a directory
    ✔ search_files: Search for text in files
    ✔ get_context: Get project context information
    ✔ describe_data: Describe a data frame in the environment

    ℹ Default: All tools available unless you specify `tools` argument

------------------------------------------------------------------------

## Tool Presets

Use
[`cassidy_tool_preset()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_tool_preset.md)
for common patterns:

### 1. Read-Only (Safe Exploration)

Perfect for exploring code without making changes:

``` r
cassidy_agentic_task(
  "Analyze my code structure and find potential issues",
  tools = cassidy_tool_preset("read_only")
)

# Includes: read_file, list_files, search_files, get_context, describe_data
# Excludes: write_file, execute_code
```

**Use Cases:** - Code review - Documentation generation - Finding
patterns or issues - Understanding project structure

### 2. Code Analysis

For analyzing code structure:

``` r
cassidy_agentic_task(
  "Find all functions that use the pipe operator",
  tools = cassidy_tool_preset("code_analysis")
)

# Includes: read_file, list_files, search_files, get_context
# Excludes: write_file, execute_code, describe_data
```

**Use Cases:** - Finding specific code patterns - Understanding
dependencies - Analyzing function usage - Refactoring planning

### 3. Data Analysis

For working with data frames:

``` r
cassidy_agentic_task(
  "Summarize the mtcars dataset and create a correlation analysis",
  tools = cassidy_tool_preset("data_analysis")
)

# Includes: describe_data, execute_code, get_context
# Excludes: File operations
```

**Use Cases:** - Data exploration - Statistical analysis - Creating
summaries - Quick calculations

### 4. Code Generation

For creating or modifying files:

``` r
cassidy_agentic_task(
  "Create a helper function for data validation",
  tools = cassidy_tool_preset("code_generation"),
  safe_mode = TRUE  # Still get approval for writes
)

# Includes: read_file, list_files, write_file, get_context
# Excludes: execute_code, search_files, describe_data
```

**Use Cases:** - Creating new functions - Modifying existing code -
Generating boilerplate - Refactoring code

### 5. All Tools

Full power (default):

``` r
cassidy_agentic_task(
  "Create a data cleaning pipeline, test it on mtcars, and save results",
  tools = cassidy_tool_preset("all")
)

# Or simply omit the tools argument:
cassidy_agentic_task(
  "Create a data cleaning pipeline, test it on mtcars, and save results"
)
```

------------------------------------------------------------------------

## Custom Tool Combinations

### Manual Selection

``` r
# Only allow specific tools
cassidy_agentic_task(
  "Find TODO comments in my code",
  tools = c("search_files", "list_files")
)

# Read and analyze (no modifications)
cassidy_agentic_task(
  "Analyze test coverage",
  tools = c("read_file", "list_files", "get_context")
)
```

### Dynamic Selection

``` r
# Create tool sets programmatically
safe_tools <- c("read_file", "list_files", "search_files", "get_context")

cassidy_agentic_task(
  "Review my code",
  tools = safe_tools
)

# Exclude risky tools
all_tools <- cassidy_list_tools()
safe_tools <- all_tools[!grepl("write|execute", all_tools)]

cassidy_agentic_task(
  "Explore codebase",
  tools = safe_tools
)
```

------------------------------------------------------------------------

## Safe Mode

**Safe mode is ON by default** and requires approval for risky
operations:

### With Safe Mode (Default)

``` r
cassidy_agentic_task(
  "Create a test file",
  safe_mode = TRUE  # Default
)
# Will prompt: "Approve? [y/n/e(dit)/v(iew)]"
```

You’ll see:

    ── Agent Action Request ────────────────────────────────
    Action: write_file
    Reasoning: Creating test file as requested
    Parameters:
    {
      "filepath": "test.txt",
      "content": "Hello World"
    }

    ❯ Approve? [y/n/e(dit)/v(iew)]:

Options: - **y** = Approve and execute - **n** = Deny (agent will try
different approach) - **e** = Edit parameters before executing - **v** =
View detailed tool information

### Without Safe Mode (Use with Caution!)

``` r
cassidy_agentic_task(
  "Create a test file",
  safe_mode = FALSE  # No approval needed
)
# Executes automatically - use carefully!
```

------------------------------------------------------------------------

## Examples

### Example 1: Read-Only Exploration

``` r
result <- cassidy_agentic_task(
  "Find all functions in the R directory and list their purposes",
  tools = cassidy_tool_preset("read_only"),
  max_iterations = 10
)
```

Agent will: 1. Use `list_files` to find R files 2. Use `read_file` to
read each file 3. Extract function definitions 4. Summarize purposes

### Example 2: Code Generation with Approval

``` r
result <- cassidy_agentic_task(
  "Create a utility function for cleaning column names in R/utils.R",
  tools = cassidy_tool_preset("code_generation"),
  safe_mode = TRUE  # Will ask before writing
)
```

Agent will: 1. Use `list_files` to check if R/utils.R exists 2. Use
`read_file` to see existing code 3. Request approval to use `write_file`
4. Create/update the file after approval

### Example 3: Data Analysis

``` r
result <- cassidy_agentic_task(
  "Analyze the mtcars dataset: compute correlations between mpg and other variables",
  tools = cassidy_tool_preset("data_analysis")
)
```

Agent will: 1. Use `describe_data` to understand mtcars structure 2. Use
`execute_code` to compute correlations 3. Return analysis results

### Example 4: Complex Multi-Step Task

``` r
result <- cassidy_agentic_task(
  "Find all test files, identify which ones test the agentic system,
   read them, and summarize the test coverage"
)
# Uses all tools as needed (default)
```

Agent will: 1. Use `list_files` to find test files 2. Use `search_files`
to find agentic-related tests 3. Use `read_file` to read test files 4.
Use `get_context` for project structure 5. Summarize findings

------------------------------------------------------------------------

## CLI Usage

The CLI (`cassidy agent`) also supports tool control:

### Default (All Tools)

``` bash
cassidy agent "Analyze my code"
```

### With R Code

``` bash
# Use presets via R code in task string
cassidy agent "Using read_only tools, analyze my code structure"
```

### Interactive Mode

``` bash
cassidy agent
# Then enter tasks interactively
```

------------------------------------------------------------------------

## Best Practices

### 1. Start with Read-Only

When exploring or analyzing, use read-only preset:

``` r
tools = cassidy_tool_preset("read_only")
```

### 2. Use Safe Mode for Writes

Always keep safe mode ON when allowing writes:

``` r
safe_mode = TRUE  # Default, but be explicit
```

### 3. Limit Tool Scope for Specific Tasks

Don’t give the agent more tools than needed:

``` r
# Good: Specific tools for specific task
cassidy_agentic_task(
  "Find TODO comments",
  tools = c("search_files", "list_files")
)

# Overkill: All tools for simple search
cassidy_agentic_task(
  "Find TODO comments"  # Has access to write_file, execute_code, etc.
)
```

### 4. Increase Iterations for Complex Tasks

Default is 10 iterations, but complex tasks may need more:

``` r
cassidy_agentic_task(
  "Comprehensive code analysis",
  max_iterations = 20  # Or Inf for unlimited
)
```

### 5. Check Results

Always review the `actions_taken` to see what the agent did:

``` r
result <- cassidy_agentic_task("Your task")
print(result)  # Shows all actions taken
```

------------------------------------------------------------------------

## Advanced: Custom Approval

Create your own approval logic:

``` r
# Auto-approve reads, deny writes
my_approver <- function(action, input, reasoning) {
  if (action %in% c("read_file", "list_files", "search_files")) {
    return(list(approved = TRUE, input = input))
  } else {
    return(list(approved = FALSE, input = input))
  }
}

cassidy_agentic_task(
  "Analyze and modify code",
  approval_callback = my_approver
)
```

------------------------------------------------------------------------

## Summary

| What You Want        | Tools Argument              | Safe Mode |
|----------------------|-----------------------------|-----------|
| **Let agent decide** | *(omit)* or `preset("all")` | TRUE      |
| **Safe exploration** | `preset("read_only")`       | TRUE      |
| **Code analysis**    | `preset("code_analysis")`   | TRUE      |
| **Data analysis**    | `preset("data_analysis")`   | TRUE      |
| **Code generation**  | `preset("code_generation")` | TRUE      |
| **Specific tools**   | `c("tool1", "tool2")`       | TRUE      |
| **Automated writes** | *(any)*                     | FALSE ⚠️  |

**Default behavior:** All tools available, safe mode ON, max 10
iterations.

**Recommendation:** Start with defaults and restrict as needed!

------------------------------------------------------------------------

## See Also

- [`?cassidy_agentic_task`](https://jdenn0514.github.io/cassidyr/reference/cassidy_agentic_task.md) -
  Main function documentation
- [`?cassidy_list_tools`](https://jdenn0514.github.io/cassidyr/reference/cassidy_list_tools.md) -
  View available tools
- [`?cassidy_tool_preset`](https://jdenn0514.github.io/cassidyr/reference/cassidy_tool_preset.md) -
  Tool preset documentation
- `AGENTIC_SYSTEM_TEST_REPORT.md` - System test results
