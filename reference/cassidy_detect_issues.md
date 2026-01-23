# Detect potential data quality issues

Scans a data frame for common issues like missing data, outliers,
constant columns, high cardinality, etc.

## Usage

``` r
cassidy_detect_issues(
  data,
  missing_threshold = 20,
  outlier_method = c("iqr", "zscore"),
  outlier_threshold = 3
)
```

## Arguments

- data:

  A data frame

- missing_threshold:

  Percent missing to flag (default: 20)

- outlier_method:

  Method for outlier detection: "iqr" or "zscore"

- outlier_threshold:

  Threshold for outlier detection (default: 3 for IQR, 3 for z-score)

## Value

A list with detected issues

## Examples

``` r
if (FALSE) { # \dontrun{
  # Check for issues
  issues <- cassidy_detect_issues(mtcars)

  # More sensitive missing data detection
  issues <- cassidy_detect_issues(mtcars, missing_threshold = 10)
} # }
```
