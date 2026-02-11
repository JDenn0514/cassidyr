# Gather project context

Collects comprehensive information about the current R project including
file structure, Git status, configuration files, and more.

## Usage

``` r
cassidy_context_project(
  level = c("standard", "minimal", "comprehensive"),
  max_size = 8000,
  include_config = TRUE,
  include_skills = TRUE
)
```

## Arguments

- level:

  Context detail level: "minimal", "standard", or "comprehensive"

- max_size:

  Maximum context size in characters (approximate)

- include_config:

  Whether to include cassidy.md or similar config files. When TRUE
  (default), searches recursively up the directory tree.

- include_skills:

  Whether to include available skills metadata. Default TRUE.

## Value

An object of class `cassidy_context` containing project information

## Details

By default, searches for CASSIDY.md files recursively up the directory
tree (like Claude Code), allowing company-wide configurations in parent
directories to be combined with project-specific configurations.

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
