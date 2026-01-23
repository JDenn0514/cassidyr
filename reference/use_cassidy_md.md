# Create a cassidy.md configuration file

Creates a project-specific configuration file that Cassidy can read for
additional context about your project. This file will be automatically
included when using
[`cassidy_context_project()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_context_project.md).

## Usage

``` r
use_cassidy_md(
  path = ".",
  template = c("default", "package", "analysis", "survey"),
  open = interactive()
)
```

## Arguments

- path:

  Directory where to create the file (default: current directory)

- template:

  Template to use: "default", "package", "analysis", or "survey"

- open:

  Whether to open the file for editing (default: TRUE in interactive
  sessions)

## Value

Invisibly returns TRUE if file was created, FALSE if cancelled

## Details

The cassidy.md file is a markdown file that provides context about your
project to AI assistants. It can include information about:

- Project goals and objectives

- Coding preferences and style guidelines

- Key files and their purposes

- Common tasks and workflows

- Domain-specific terminology

The file will be automatically read by
[`cassidy_context_project()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_context_project.md)
and included in the context sent to Cassidy.

## Examples

``` r
if (FALSE) { # \dontrun{
# Create a default cassidy.md file
use_cassidy_md()

# Create a package development template
use_cassidy_md(template = "package")

# Create an analysis project template
use_cassidy_md(template = "analysis")

# Create for survey research
use_cassidy_md(template = "survey")
} # }
```
