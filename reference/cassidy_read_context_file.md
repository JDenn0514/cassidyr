# Read CASSIDY.md or similar context configuration files

Looks for project-specific configuration files in the current directory,
parent directories (when recursive=TRUE), and user-level location.

## Usage

``` r
cassidy_read_context_file(path = ".", recursive = FALSE, include_user = TRUE)
```

## Arguments

- path:

  Directory to search (default: current directory)

- recursive:

  Whether to search parent directories (default: FALSE). When TRUE,
  searches up the directory tree like Claude Code does, enabling
  company-wide configurations in parent directories. This is the default
  behavior when called from
  [`cassidy_context_project()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_context_project.md).

- include_user:

  Whether to include user-level memory from ~/.cassidy/ (default: TRUE)

## Value

Character string with config file contents, or NULL if none found

## Examples

``` r
if (FALSE) { # \dontrun{
# Read project and user-level config (default, recommended)
config <- cassidy_read_context_file()

# Only search current directory (no user-level)
config <- cassidy_read_context_file(include_user = FALSE)

# Search parent directories (Claude Code style)
config <- cassidy_read_context_file(recursive = TRUE)
} # }
```
