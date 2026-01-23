# List objects in global environment

Creates a formatted list of objects currently in the global environment,
categorized by type (data frames, functions, etc.).

## Usage

``` r
cassidy_list_objects(envir = .GlobalEnv, detailed = FALSE)
```

## Arguments

- envir:

  Environment to list objects from (default: .GlobalEnv)

- detailed:

  Include object sizes and classes

## Value

Character string with formatted object list

## Examples

``` r
if (FALSE) { # \dontrun{
# Basic object list
cassidy_list_objects()

# Detailed list with sizes
cassidy_list_objects(detailed = TRUE)
} # }
```
