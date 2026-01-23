# Read File Contents as Context

Reads a file and formats it as context for use with
[`cassidy_chat()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_chat.md).
The file content is wrapped in a markdown code block with appropriate
syntax highlighting based on file extension.

## Usage

``` r
cassidy_describe_file(
  path,
  max_lines = Inf,
  lines = NULL,
  line_range = NULL,
  show_line_numbers = TRUE,
  level = c("full", "summary", "index")
)
```

## Arguments

- path:

  Path to the file to read. Can be absolute or relative to the working
  directory.

- max_lines:

  Maximum number of lines to read. Use `Inf` to read entire file.
  Defaults to `Inf` (read all).

- lines:

  Numeric vector specifying specific line numbers to read. If provided,
  only these lines are included. Use `NULL` (default) to read all lines
  (subject to `max_lines`).

- line_range:

  Numeric vector of length 2 specifying start and end lines (e.g.,
  `c(10, 50)` reads lines 10-50). Ignored if `lines` is provided.

- show_line_numbers:

  Logical; if `TRUE`, prepends line numbers to each line. Useful for
  discussing specific line numbers. Defaults to `TRUE`.

- level:

  Character; detail level for file content. One of:

  - `"full"`: Complete file contents (default)

  - `"summary"`: Function signatures + key excerpts

  - `"index"`: Metadata and function listing only Used by chat system to
    manage context size. Most users should use default.

## Value

A `cassidy_context` object containing the formatted file contents.

## Details

The function automatically detects the file type from the extension and
applies appropriate syntax highlighting in the markdown output.

You can read files in three ways:

- Entire file: Just provide `path`

- Specific lines: Use `lines = c(1, 5, 10:20)`

- Line range: Use `line_range = c(10, 50)`

The `level` parameter controls detail:

- `"full"`: Best for detailed code review, includes all content

- `"summary"`: Good for understanding structure without full content

- `"index"`: Minimal metadata, useful when you have many files

## See also

[`cassidy_context_combined()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_context_combined.md),
[`cassidy_context_project()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_context_project.md),
[`cassidy_chat()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_chat.md)

## Examples

``` r
if (FALSE) { # \dontrun{
  # Read an entire R file
  ctx <- cassidy_describe_file("R/my-function.R")

  # Read specific lines (useful for focusing on a function)
  ctx <- cassidy_describe_file("R/my-function.R", lines = 45:120)

  # Read with summary level (less detail)
  ctx <- cassidy_describe_file("R/my-function.R", level = "summary")

  # Ask Cassidy to review specific code
  cassidy_chat(
    "Review this function and suggest improvements",
    context = cassidy_describe_file("R/my-function.R", lines = 45:120)
  )
} # }
```
