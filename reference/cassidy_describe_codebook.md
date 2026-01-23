# Format data frame description for LLM context

Creates a compact, markdown-formatted description of a data frame
optimized for LLM consumption.

## Usage

``` r
cassidy_describe_codebook(
  data,
  name = NULL,
  max_vars = NULL,
  show_sample = TRUE
)
```

## Arguments

- data:

  A data.frame

- name:

  Optional name for the data (defaults to object name)

- max_vars:

  Maximum variables to show (NULL = all)

- show_sample:

  Include sample values? (Default: TRUE)

## Value

Character string in markdown format
