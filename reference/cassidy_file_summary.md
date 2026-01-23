# Summarize Project Files

Provides a summary of files in the project, with varying levels of
detail. Useful for understanding project structure and for providing
context to AI assistants about your codebase.

## Usage

``` r
cassidy_file_summary(
  path = ".",
  level = c("minimal", "standard", "comprehensive")
)
```

## Arguments

- path:

  Root directory to search (default: current directory)

- level:

  Detail level: "minimal", "standard", or "comprehensive"

  - `"minimal"`: File counts by type and key directories

  - `"standard"`: Adds file listing with sizes

  - `"comprehensive"`: Adds function extraction from R files with
    descriptions and export status

## Value

Character string with formatted file information

## See also

[`cassidy_context_project()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_context_project.md),
[`cassidy_describe_file()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_describe_file.md)

## Examples

``` r
if (FALSE) { # \dontrun{
  # Quick overview
  cassidy_file_summary()

  # Standard listing with file sizes
  cassidy_file_summary(level = "standard")

  # Full analysis with function extraction
  cassidy_file_summary(level = "comprehensive")
} # }
```
