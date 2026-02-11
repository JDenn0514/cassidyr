# Get Tool Presets for Common Tasks

Returns predefined sets of tools for common agentic task patterns.

## Usage

``` r
cassidy_tool_preset(
  preset = c("all", "read_only", "code_analysis", "data_analysis", "code_generation")
)
```

## Arguments

- preset:

  Character. One of:

  - `"read_only"` - Safe exploration (no writes or code execution)

  - `"code_analysis"` - Analyze code structure

  - `"data_analysis"` - Work with data frames

  - `"code_generation"` - Create/modify code files

  - `"all"` - All tools (default)

## Value

Character vector of tool names

## Examples

``` r
if (FALSE) { # \dontrun{
# Use read-only preset
cassidy_agentic_task(
  "Analyze my code structure",
  tools = cassidy_tool_preset("read_only")
)

# Use data analysis preset
cassidy_agentic_task(
  "Summarize the mtcars dataset",
  tools = cassidy_tool_preset("data_analysis")
)
} # }
```
