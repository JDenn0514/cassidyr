# Get Skills Context

Gathers metadata about available skills (workflows) without loading full
content. Provides progressive disclosure - only skill names and
descriptions are included, full content loads on-demand.

## Usage

``` r
cassidy_context_skills(
  location = c("all", "project", "personal"),
  format = c("text", "list")
)
```

## Arguments

- location:

  Character. "all" (default), "project", or "personal"

- format:

  Character. "text" (default) or "list"

## Value

A `cassidy_context` object with skill metadata, or list if format="list"

## Examples

``` r
if (FALSE) { # \dontrun{
# Get all available skills
ctx <- cassidy_context_skills()

# Just project skills
ctx <- cassidy_context_skills(location = "project")

# Get as list for programmatic use
skills_list <- cassidy_context_skills(format = "list")
} # }
```
