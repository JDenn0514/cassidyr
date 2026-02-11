# List Available Skills

Displays all available skills from project and personal locations. Shows
skill name, description, invocation mode, location, and dependencies.

## Usage

``` r
cassidy_list_skills(location = c("all", "project", "personal"))
```

## Arguments

- location:

  Character. "all" (default), "project", or "personal"

## Value

Invisibly returns character vector of skill names

## Examples

``` r
if (FALSE) { # \dontrun{
# See all available skills
cassidy_list_skills()

# Just project skills
cassidy_list_skills(location = "project")

# Get skill names programmatically
skills <- cassidy_list_skills()
} # }
```
