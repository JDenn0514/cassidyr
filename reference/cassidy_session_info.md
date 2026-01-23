# Get session info formatted for LLM

Returns R session information formatted in a way that's useful for AI
assistants to understand the current R environment.

## Usage

``` r
cassidy_session_info(include_packages = FALSE)
```

## Arguments

- include_packages:

  Whether to include loaded package information

## Value

Character string with formatted session information

## Examples

``` r
if (FALSE) { # \dontrun{
# Basic session info
cassidy_session_info()

# With package info
cassidy_session_info(include_packages = TRUE)
} # }
```
