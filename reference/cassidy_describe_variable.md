# Describe a single variable in detail

Provides detailed information about a specific variable in a data frame,
including summary statistics, distribution, and potential issues.

## Usage

``` r
cassidy_describe_variable(data, variable, max_unique = 10)
```

## Arguments

- data:

  A data frame

- variable:

  Variable name (character) or position (integer)

- max_unique:

  Maximum unique values to display for categorical variables

## Value

Character string with variable description

## Examples

``` r
if (FALSE) { # \dontrun{
  # Describe a numeric variable
  cassidy_describe_variable(mtcars, "mpg")

  # Describe a factor
  cassidy_describe_variable(iris, "Species")

  # By position
  cassidy_describe_variable(mtcars, 1)
} # }
```
