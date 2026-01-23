# Gather context from data frames in environment

Creates a summary of data frames currently loaded in the global
environment, useful for giving Cassidy context about available data.

## Usage

``` r
cassidy_context_data(detailed = FALSE, method = c("codebook", "skim", "basic"))
```

## Arguments

- detailed:

  Whether to include detailed summaries of each data frame

- method:

  Method to use for detailed summaries: "codebook", "skim", or "basic"

## Value

Character string with formatted data frame information

## Examples

``` r
if (FALSE) { # \dontrun{
  # Load some data
  data(mtcars)
  data(iris)

  # Basic summary
  cassidy_context_data()

  # Detailed summary
  cassidy_context_data(detailed = TRUE)
} # }
```
