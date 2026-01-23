# Combine Multiple Contexts

Combines multiple context objects into a single context for use with
[`cassidy_chat()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_chat.md).
Contexts are joined with separators to maintain clarity.

## Usage

``` r
cassidy_context_combined(..., sep = "\n\n---\n\n")
```

## Arguments

- ...:

  Context objects to combine. Can be `cassidy_context` objects,
  `cassidy_df_description` objects, character strings, or lists.

- sep:

  Character string used to separate contexts. Defaults to a horizontal
  rule for readability.

## Value

A `cassidy_context` object containing all combined contexts.

## See also

[`cassidy_context_project()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_context_project.md),
[`cassidy_describe_file()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_describe_file.md),
[`cassidy_context_data()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_context_data.md),
[`cassidy_chat()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_chat.md)

## Examples

``` r
if (FALSE) { # \dontrun{
  # Combine project context with a file
  combined <- cassidy_context_combined(
    cassidy_context_project(),
    cassidy_describe_file("R/my-function.R")
  )

  # Use directly in chat
  cassidy_chat("Review this code", context = combined)

  # Combine multiple files
  cassidy_chat("Compare these implementations", context =
    cassidy_context_combined(
      cassidy_describe_file("R/old-approach.R"),
      cassidy_describe_file("R/new-approach.R")
    )
  )
} # }
```
