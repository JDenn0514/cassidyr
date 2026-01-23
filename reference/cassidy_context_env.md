# Get current environment snapshot

Creates a snapshot of the current R environment including loaded
objects, packages, and working directory.

## Usage

``` r
cassidy_context_env(detailed = FALSE)
```

## Arguments

- detailed:

  Include detailed object information

## Value

Character string with formatted environment information

## Examples

``` r
if (FALSE) { # \dontrun{
  # Basic environment snapshot
  cassidy_context_env()

  # Detailed snapshot
  cassidy_context_env(detailed = TRUE)
} # }
```
