# Read cassidy.md or similar context configuration files

Looks for project-specific configuration files that provide context
about the project, coding preferences, and common tasks.

## Usage

``` r
cassidy_read_context_file(path = ".", file_name = NULL)
```

## Arguments

- path:

  Directory to search for config files (default: current directory)

- file_name:

  The specific config file name (e.g., "cassidy.md"). If NULL, the
  default, will search for "cassidy.md", ".cassidy.md", "CASSIDY.md",
  ".cassidyrc", "ai-context.md", ".ai-context.md".

## Value

Character string with config file contents, or NULL if none found

## Examples

``` r
if (FALSE) { # \dontrun{
# Read config file
config <- cassidy_read_context_file()

# Check if config exists
if (!is.null(cassidy_read_context_file())) {
  message("Config file found")
}
} # }
```
