# List Available Agentic Tools

Shows all available tools that can be used with
[`cassidy_agentic_task()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_agentic_task.md).
Displays tool names, descriptions, and whether they require approval in
safe mode.

## Usage

``` r
cassidy_list_tools()
```

## Value

Invisibly returns a character vector of tool names

## Examples

``` r
if (FALSE) { # \dontrun{
# See all available tools
cassidy_list_tools()

# Get tool names programmatically
tools <- cassidy_list_tools()

# Use specific tools
cassidy_agentic_task(
  "Analyze code",
  tools = tools[!grepl("write|execute", tools)]  # Read-only
)
} # }
```
