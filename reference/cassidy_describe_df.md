# Describe a data frame for AI context

Creates a formatted description of a data frame suitable for AI context.
Can use different methods to generate the description.

## Usage

``` r
cassidy_describe_df(
  data,
  name = NULL,
  method = c("codebook", "skim", "basic"),
  include_summary = TRUE,
  max_vars = NULL,
  show_sample = TRUE
)
```

## Arguments

- data:

  A data frame or tibble

- name:

  Optional character string to use as the data frame name. If NULL,
  attempts to use the name of the object passed to `data`.

- method:

  Method to use: "codebook" (default), "skim", or "basic"

- include_summary:

  Include statistical summaries (for "basic" method)

- max_vars:

  Maximum variables to show (NULL = all)

- show_sample:

  Include sample values? (Default: TRUE)

## Value

An object of class `cassidy_df_description` containing the formatted
description text

## Details

The `method` parameter controls how the data frame is described:

- `"codebook"`: Uses
  [`cassidy_describe_codebook()`](https://jdenn0514.github.io/cassidyr/reference/codebook_for_llm.md)
  which provides a compact, markdown-formatted description optimized for
  LLM consumption, including variable labels, value labels, factor
  levels, and more

- `"skim"`: Uses
  [`skimr::skim()`](https://docs.ropensci.org/skimr/reference/skim.html)
  if available, which provides summary statistics organized by variable
  type. Falls back to "basic" if not installed.

- `"basic"`: Uses base R to provide a simple description with variable
  types and basic summaries.

## Examples

``` r
if (FALSE) { # \dontrun{
  # Using codebook method (most detailed)
  desc <- cassidy_describe_df(mtcars, method = "codebook")

  # With explicit name
  desc <- cassidy_describe_df(my_data, name = "survey_responses", method = "skim")

  # Using basic method (lightweight)
  desc <- cassidy_describe_df(mtcars, method = "basic")

  # Use in chat
  cassidy_chat("What analyses would you recommend?", context = desc)
} # }
```
