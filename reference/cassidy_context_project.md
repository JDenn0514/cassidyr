# Gather project context

Collects comprehensive information about the current R project including
file structure, Git status, configuration files, and more.

## Usage

``` r
cassidy_context_project(
  level = c("standard", "minimal", "comprehensive"),
  max_size = 8000,
  include_config = TRUE
)
```

## Arguments

- level:

  Context detail level: "minimal", "standard", or "comprehensive"

- max_size:

  Maximum context size in characters (approximate)

- include_config:

  Whether to include cassidy.md or similar config files

## Value

An object of class `cassidy_context` containing project information

## Examples

``` r
if (FALSE) { # \dontrun{
  # Gather standard context
  ctx <- cassidy_context_project()

  # Minimal context (fastest)
  ctx_min <- cassidy_context_project(level = "minimal")

  # Comprehensive context (most detailed)
  ctx_full <- cassidy_context_project(level = "comprehensive")

  # Use in chat
  cassidy_chat("Help me understand this project", context = ctx)
} # }
```
