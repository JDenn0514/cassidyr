# Use a Skill

Load and optionally execute a skill. Skills are loaded with all their
dependencies. Can preview skill content or execute with a task.

## Usage

``` r
cassidy_use_skill(skill_name, task = NULL, show_dependencies = TRUE, ...)
```

## Arguments

- skill_name:

  Character. Name of the skill to use

- task:

  Character. Optional task to run with skill loaded

- show_dependencies:

  Logical. Show loaded dependencies? (default: TRUE)

- ...:

  Additional arguments passed to
  [`cassidy_agentic_task()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_agentic_task.md)

## Value

If `task` is NULL, returns skill content invisibly. If `task` is
provided, returns result from
[`cassidy_agentic_task()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_agentic_task.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# Preview a skill
cassidy_use_skill("efa-workflow")

# Use skill for a task
result <- cassidy_use_skill("efa-workflow",
  task = "Analyze the personality_items dataset"
)

# Use skill with specific tools
result <- cassidy_use_skill("efa-workflow",
  task = "Run EFA on survey_data",
  tools = c("read_file", "execute_code", "describe_data")
)
} # }
```
