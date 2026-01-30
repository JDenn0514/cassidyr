# Managing Project Memory in cassidyr

## Introduction

This vignette explains how to manage *cassidyr*’s project memory across
sessions using different memory locations and best practices.

The *cassidyr* package can remember your preferences, project context,
and coding guidelines across chat sessions. When you launch
[`cassidy_app()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_app.md),
it automatically loads project memory files to provide relevant context
to the AI assistant.

## Memory Types and Locations

*cassidyr* offers multiple memory locations in a hierarchical structure,
each serving a different purpose:

| Memory Type            | Location                                  | Purpose                                      | Use Case Examples                                                | Shared With                         |
|------------------------|-------------------------------------------|----------------------------------------------|------------------------------------------------------------------|-------------------------------------|
| Project memory         | `./CASSIDY.md` or `./.cassidy/CASSIDY.md` | Team-shared instructions for the project     | Project architecture, coding standards, workflows, analysis plan | Team members via source control     |
| Project rules          | `./.cassidy/rules/*.md`                   | Modular, topic-specific project instructions | R guidelines, testing conventions, visualization preferences     | Team members via source control     |
| Project memory (local) | `./CASSIDY.local.md`                      | Personal project-specific preferences        | Local file paths, test data locations, API keys                  | Just you (current project, not git) |
| User memory            | `~/.cassidy/CASSIDY.md`                   | Personal preferences for all projects        | Code style, favorite packages, common patterns                   | Just you (all projects)             |

All memory files are automatically loaded when you launch
[`cassidy_app()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_app.md).
Files are loaded in order from user-level to project-level, with
project-specific settings taking precedence.

> **Note:** `CASSIDY.local.md` files are automatically added to
> `.gitignore`, making them ideal for private project-specific
> preferences that should not be checked into version control.

## How cassidyr Looks Up Memory Files

By default, cassidyr searches for memory files in two locations:

1.  **User-level memory**: `~/.cassidy/CASSIDY.md` and
    `~/.cassidy/rules/*.md`
    - Your personal preferences that apply to all R projects
    - Loaded first (lowest priority)
2.  **Project-level memory**: Files in your current working directory
    - `./CASSIDY.md` or `./.cassidy/CASSIDY.md`
    - `./CASSIDY.local.md` (gitignored, personal project notes)
    - `./.cassidy/rules/*.md` (modular rules)
    - Loaded second (highest priority, overrides user-level)

This design keeps memory files discoverable and predictable - anyone who
clones your R package will see exactly what context is being used.

#### Optional: Recursive Search

If you’re working in a large monorepo or nested project structure, you
can enable upward recursive search:

``` r
# Search parent directories (like Claude Code)
cassidy_app(recursive = TRUE)
```

## Setting Up Project Memory

### Quick Start

The easiest way to create a project memory file is with the
[`use_cassidy_md()`](https://jdenn0514.github.io/cassidyr/reference/use_cassidy_md.md)
function:

``` r
library(cassidyr)

# Create CASSIDY.md in project root
use_cassidy_md()

# Create in .cassidy/ directory (keeps root clean)
use_cassidy_md(location = "hidden")

# Create local-only file (not shared with team)
use_cassidy_md(location = "local")
```

### Choose a Template

*cassidyr* provides several templates to get you started:

``` r
# Default template - general purpose
use_cassidy_md(template = "default")

# Package development template
use_cassidy_md(template = "package")

# Data analysis template
use_cassidy_md(template = "analysis")

# Survey research template
use_cassidy_md(template = "survey")
```

### Manual Creation

You can also manually create a `CASSIDY.md` file. Here is a basic
example:

``` markdown
# Project Context for Cassidy AI

## Project Overview
This is an R package for analyzing survey data with a focus on factor analysis
and scale reliability.

## Key Files
- `R/factor_analysis.R` - Main EFA/CFA functions
- `R/reliability.R` - Cronbach's alpha and omega calculations
- `data/survey_data.rda` - Example dataset

## Coding Preferences
- Style: tidyverse with native pipe `|>`
- Prefer `dplyr` over base R for data manipulation
- Use `ggplot2` for all visualizations
- Maximum line length: 80 characters
- Always include roxygen2 documentation

## Common Tasks
- Running factor analyses and interpreting results
- Creating publication-quality tables
- Writing methods sections in APA format
- Generating codebooks

## Packages to Use
- `psych` for factor analysis
- `lavaan` for CFA
- `gt` for tables
- `ggplot2` for visualization
```

## File Structure Examples

### Basic Project

For a simple analysis project:

    my-analysis/
    ├── CASSIDY.md              # Project memory
    ├── data/
    ├── R/
    │   └── analysis.R
    └── output/

### Using the `.cassidy` Directory

For keeping the root directory clean:

    my-project/
    ├── .cassidy/
    │   ├── CASSIDY.md          # Main project instructions
    │   └── CASSIDY.local.md    # Your personal notes (gitignored)
    ├── R/
    ├── tests/
    └── vignettes/

### Large Project with Rules

For complex projects with multiple areas:

    large-project/
    ├── .cassidy/
    │   ├── CASSIDY.md          # Main project instructions
    │   └── rules/
    │       ├── coding-style.md # Team coding standards
    │       ├── testing.md      # Testing conventions
    │       ├── data/
    │       │   └── cleaning.md # Data cleaning guidelines
    │       └── analysis/
    │           ├── eda.md      # EDA preferences
    │           └── modeling.md # Modeling approaches
    ├── R/
    ├── data-raw/
    └── analysis/

## Modular Rules with `.cassidy/rules/`

For larger projects, organize instructions into multiple files using the
`.cassidy/rules/` directory. This allows teams to maintain focused,
well-organized rule files instead of one large `CASSIDY.md`.

### Basic Structure

Place markdown files in your project’s `.cassidy/rules/` directory:

    your-project/
    ├── .cassidy/
    │   ├── CASSIDY.md          # Main project instructions
    │   └── rules/
    │       ├── r-style.md      # R coding style
    │       ├── testing.md      # Testing conventions
    │       └── visualization.md # Plotting preferences

All `.md` files in `.cassidy/rules/` are automatically loaded as project
memory.

### Organizing with Subdirectories

Rules can be organized into subdirectories for better structure:

    .cassidy/rules/
    ├── r-code/
    │   ├── style.md
    │   ├── functions.md
    │   └── packages.md
    ├── analysis/
    │   ├── eda.md
    │   ├── modeling.md
    │   └── reporting.md
    ├── data/
    │   ├── cleaning.md
    │   └── validation.md
    └── general.md

All `.md` files are discovered recursively.

### Sharing Rules Across Projects

You can use symbolic links to share common rules across multiple
projects:

``` bash
# Symlink a shared rules directory (Unix/Mac)
ln -s ~/my-r-standards .cassidy/rules/shared

# Symlink individual rule files
ln -s ~/company-standards/r-style.md .cassidy/rules/r-style.md
```

On Windows, you can use junction points or directory symbolic links.

## Example Rule Files

### `.cassidy/rules/r-style.md`

``` markdown
# R Coding Style Guidelines

## Function Naming
- Use `snake_case` for all function names
- Prefix exported functions with package name (e.g., `mypackage_analyze()`)
- Use `.` prefix for internal helpers

## Documentation
- All exported functions must have complete roxygen2 documentation
- Include `@examples` with realistic use cases
- Use markdown formatting (`@md` in DESCRIPTION)

## Testing
- Use `testthat 3e` for all tests
- Test names should follow: `test_that("function does X when Y")`
- Aim for >80% code coverage
```

### `.cassidy/rules/visualization.md`

``` markdown
# Data Visualization Preferences

## ggplot2 Standards
- Always use `theme_minimal()` as base
- Use viridis color scales for continuous variables
- Include informative titles and axis labels
- Save plots at 300 DPI for publications

## Default Settings
- Figure width: 8 inches
- Figure height: 6 inches
- Font size: 12pt for body, 14pt for titles
```

## User-Level Memory

You can also create a user-level memory file that applies to all your R
projects:

``` r
# Create user-level memory directory
dir.create("~/.cassidy", showWarnings = FALSE, recursive = TRUE)

# Create your personal CASSIDY.md
cat("# My Personal R Preferences

## Code Style
- I prefer tidyverse style with native pipe |>
- Use explicit returns in functions
- Comment complex logic

## Favorite Packages
- Data manipulation: dplyr, tidyr
- Visualization: ggplot2, patchwork
- Tables: gt, kableExtra
- Modeling: tidymodels, mgcv

## Common Patterns
- Always load tidyverse first
- Use here::here() for file paths
- Save intermediate results in data/processed/
",
    file = "~/.cassidy/CASSIDY.md"
)
```

## Automatic Context Loading

When you start
[`cassidy_app()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_app.md),
all memory files are automatically loaded:

``` r
library(cassidyr)

# Start app - automatically loads all CASSIDY.md files
cassidy_app()

# Start with new context (re-gathers project context)
cassidy_app(new_chat = TRUE)

# Start with comprehensive context
cassidy_app(new_chat = TRUE, context_level = "comprehensive")
```

The app will:

- Search for and load all `CASSIDY.md` files up the directory tree.
- Load all files from `.cassidy/rules/` directories.
- Combine them with project context (Git status, file structure, etc.).
- Send everything to the AI assistant.

## Reading Memory Files Programmatically

You can also read memory files directly:

``` r
# Read all memory files recursively
config <- cassidy_read_context_file()

# Only search current directory
config <- cassidy_read_context_file(recursive = FALSE)

# Check what was found
if (!is.null(config)) {
  cat(config)
}
```

## Memory Best Practices

### Be Specific

**Good:** Use 2-space indentation for R code and always include spaces
around operators.

**Not as good:** Format code properly.

### Use Structure to Organize

Format each individual memory as a bullet point and group related
memories under descriptive markdown headings:

``` markdown
## Data Cleaning Guidelines

- Remove outliers beyond 3 SD from mean.
- Impute missing values using the mice package with m = 5 imputations.
- Always create a `data/processed/` directory for cleaned data.

## Visualization Standards

- Use `theme_minimal()` as base theme.
- Color scheme: viridis for continuous, Set2 for categorical.
- Always include confidence intervals in plots.
```

### Review Periodically

Update memory files as your project evolves to ensure Cassidy always has
the most up-to-date information and context. This is especially
important for:

- Changes in project goals or scope.
- New coding conventions adopted by the team.
- Updates to preferred packages or methods.
- New data sources or analytical approaches.

### Keep Files Focused

For large projects, prefer multiple focused rule files over one large
`CASSIDY.md`:

- One topic per file: `testing.md`, `visualization.md`,
  `data-cleaning.md`.
- Descriptive filenames: The name should clearly indicate content.
- Organize with subdirectories: Group related rules (e.g., `analysis/`,
  `reporting/`).

### Use Local Files for Personal Settings

Keep personal preferences in `CASSIDY.local.md` to avoid merge
conflicts:

``` markdown
# My Local Preferences (CASSIDY.local.md)

## File Paths
- My data: `~/Dropbox/research/project-data/`
- Scratch directory: `~/scratch/project-temp/`

## Testing
- Use small test dataset: `data/test_sample_100.rds`
- Test API endpoint: http://localhost:8000

## Notes
- Remember to use VPN when accessing remote database.
```

## Example Workflows

### R Package Development

``` r
# Set up package memory
use_cassidy_md(template = "package")

# Add specific rules
dir.create(".cassidy/rules", recursive = TRUE, showWarnings = FALSE)

# Create testing guidelines
cat("# Testing Standards

## Test Coverage
- All exported functions must have tests.
- Aim for >80% code coverage.
- Test error handling and edge cases.

## Test Structure
- Use descriptive test names.
- Group related tests with describe().
- Use withr for temporary state changes.
",
    file = ".cassidy/rules/testing.md"
)
```

### Data Analysis Project

``` r
# Set up analysis memory
use_cassidy_md(template = "analysis")

# Add your data context
cat("
## Current Dataset

- **Name**: Customer Survey 2024
- **N**: 1,247 respondents
- **Key Variables**:
  - satisfaction (1-7 Likert)
  - nps (0-10 scale)
  - demographic variables
- **Missing Data**: ~5% on satisfaction items.

## Analysis Plan

1. Descriptive statistics and data quality checks.
2. Factor analysis on satisfaction items.
3. Regression predicting NPS from satisfaction factors.
4. Visualizations for stakeholder report.
",
    file = "CASSIDY.md",
    append = TRUE
)
```

### Survey Research

``` r
# Set up survey memory
use_cassidy_md(template = "survey")

# Add scale information
cat("
## Measurement Scales

### Job Satisfaction (5 items, α = .89)
- Items: JS1-JS5.
- Response scale: 1 (Strongly Disagree) to 7 (Strongly Agree).
- Reverse coded: JS2, JS4.

### Organizational Commitment (6 items, α = .92)
- Items: OC1-OC6.
- Response scale: 1 (Strongly Disagree) to 7 (Strongly Agree).
- No reverse coding.

## Analysis Notes
- Use lavaan for CFA.
- Report ω alongside α.
- Include fit indices: CFI, TLI, RMSEA, SRMR.
",
    file = "CASSIDY.md",
    append = TRUE
)
```

## Troubleshooting

### Memory files not loading?

Check that:

- Files are named correctly (`CASSIDY.md`, not `cassidy.txt`).
- Files are in the project directory or parent directories.
- File encoding is UTF-8.

You can verify what is being loaded:

``` r
# Check what memory files are found
config <- cassidy_read_context_file()
if (!is.null(config)) {
  cat("Found memory files!\n")
  cat(config)
} else {
  cat("No memory files found in directory tree\n")
}
```

### Too much context?

If you are hitting context limits:

- Use `CASSIDY.local.md` for personal notes instead of putting
  everything in `CASSIDY.md`.
- Be more concise in your memory files.
- Focus on the most important information.
- Use `context_level = "minimal"` when starting the app.

### Files in subdirectories not loading?

Remember: *cassidyr* searches *up* the directory tree from your working
directory, not down. If you have `project/subdir/CASSIDY.md` and you are
working from `project/`, that file will not be loaded. It is only loaded
when you work from `project/subdir/` or deeper.

## Summary

- Use `CASSIDY.md` for team-shared project context.
- Use `CASSIDY.local.md` for personal project settings
  (auto-gitignored).
- Use `.cassidy/rules/` for modular, organized guidelines.
- Files are automatically loaded when you start
  [`cassidy_app()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_app.md).
- Memory files are searched recursively up the directory tree.
- Be specific, use structure, and review periodically.

For more information on context gathering and chat functionality, see:

- [`vignette("context-system")`](https://jdenn0514.github.io/cassidyr/articles/context-system.md)
  — Understanding the context system.
- [`?cassidy_app`](https://jdenn0514.github.io/cassidyr/reference/cassidy_app.md)
  — Chat application documentation.
- [`?use_cassidy_md`](https://jdenn0514.github.io/cassidyr/reference/use_cassidy_md.md)
  — Creating memory files.
