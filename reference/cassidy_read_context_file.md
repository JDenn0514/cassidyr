# Read CASSIDY.md or similar context configuration files

Looks for project-specific configuration files. By default, only
searches the current working directory and user-level location
(~/.cassidy/).

## Usage

``` r
cassidy_read_context_file(path = ".", recursive = FALSE, include_user = TRUE)
```

## Arguments

- path:

  Directory to search (default: current directory)

- recursive:

  Whether to search parent directories (default: FALSE). When TRUE,
  searches up the directory tree like Claude Code does. For R packages,
  FALSE is recommended for predictability.

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
