# Create a New Skill Template

Creates a new skill file from a template, making it easy to add custom
workflows.

## Usage

``` r
cassidy_create_skill(
  name,
  location = c("project", "personal"),
  template = c("basic", "analysis", "workflow")
)
```

## Arguments

- name:

  Character. Name of the skill (lowercase, hyphens allowed)

- location:

  Character. "project" (default) or "personal"

- template:

  Character. Template to use: "basic" (default), "analysis", or
  "workflow"

## Value

Path to created file (invisibly)

## Examples

``` r
if (FALSE) { # \dontrun{
# Create a basic skill
cassidy_create_skill("my-workflow")

# Create an analysis skill in personal location
cassidy_create_skill("custom-analysis",
  location = "personal",
  template = "analysis"
)
} # }
```
