# Get Git repository status and recent commits

Get Git repository status and recent commits

## Usage

``` r
cassidy_context_git(repo = ".", include_commits = FALSE, n_commits = 5)
```

## Arguments

- repo:

  Path to Git repository (default: current directory)

- include_commits:

  Whether to include recent commit history

- n_commits:

  Number of recent commits to include (default: 5)

## Value

Character string with formatted Git information, or NULL if no Git repo

## Examples

``` r
if (FALSE) { # \dontrun{
# Basic Git status
cassidy_context_git()

# Include recent commits
cassidy_context_git(include_commits = TRUE)

# More commits
cassidy_context_git(include_commits = TRUE, n_commits = 10)
} # }
```
