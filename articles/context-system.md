# Understanding the Context System

## What is Context?

When you chat with an AI assistant like Cassidy, the AI doesn’t have
access to your computer, your files, or your R session. It only knows
what you tell it in the conversation. **Context** is the background
information you provide to help the AI understand your project and give
relevant, accurate responses.

Think of it like calling a colleague for help. If you just say “Why
isn’t my code working?”, they can’t help much. But if you say “I’m
building an R package for survey analysis, using tidyverse style, and
this function is throwing an error when I pass a tibble instead of a
data frame” — now they have context to give useful advice.

The cassidyr package provides tools to automatically gather and send
this context to Cassidy, so you don’t have to manually copy-paste your
code, describe your data, or explain your project setup every time.

## The Context Architecture

cassidyr’s context system has four main components:

Component \| Function \| What It Captures \| \|———–\|———-\|——————\|
\| **Project** \| [`cassidy_context_project()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_context_project.md) \|
CASSIDY.md config, Git status, R session info \|
\| **Data** \| [`cassidy_context_data()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_context_data.md) \|
Data frames in your environment \|
\| **Files** \| [`cassidy_describe_file()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_describe_file.md) \|
Contents of specific code files \|
\| **Environment** \| [`cassidy_context_env()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_context_env.md) \|
Objects loaded in R, packages \|

Each component can be used independently or combined together for
comprehensive context.

## Project Context

Project context provides the AI with understanding of your overall
project structure, preferences, and configuration.

### The CASSIDY.md File

The most important piece of project context is your `CASSIDY.md` file.
This is a markdown file where you document:

- What your project does
- Your coding preferences and style
- Key files and their purposes
- Common tasks you need help with

Create one with:

``` r
use_cassidy_md()
```

📋

Or use a specialized template:

``` r
use_cassidy_md(template = "package")    # R package development
use_cassidy_md(template = "analysis")   # Data analysis project
use_cassidy_md(template = "survey")     # Survey research
```

📋

The file is automatically read when you
start [`cassidy_app()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_app.md) or
gather project context.

### File Locations

You can place your configuration in several locations:

Location \| File \| Use Case \| \|———-\|——\|———-\| \| Project root
\| `CASSIDY.md` \| Shared with team via Git \| \| Hidden directory
\| `.cassidy/CASSIDY.md` \| Keeps root directory clean \| \| Local only
\| `CASSIDY.local.md` \| Personal preferences (gitignored) \| \|
User-level \| `~/.cassidy/CASSIDY.md` \| Applies to all your projects \|

cassidyr searches recursively up from your working directory (inspired
by Claude Code), reading these files in order from lowest to highest
priority. More specific (project-level) settings override broader
(user-level) defaults. This enables organization-wide standards in
parent directories to be combined with project-specific configurations.

### Gathering Project Context

``` r
# Standard context (recommended for most uses)
ctx <- cassidy_context_project()

# Minimal - just R session and config
ctx_min <- cassidy_context_project(level = "minimal")

# Comprehensive - includes Git history, full file listing
ctx_full <- cassidy_context_project(level = "comprehensive")
```

📋

The context levels control how much information is gathered:

- **minimal**: R version, IDE, CASSIDY.md only (~1-2 KB)
- **standard**: Adds file structure, Git status, environment objects
  (~3-5 KB)
- **comprehensive**: Adds commit history, function extraction, detailed
  object info (~5-15 KB)

## Data Context

When working with data analysis, the AI needs to understand your
datasets. cassidyr provides several ways to describe data frames.

### Basic Data Context

``` r
# See what data frames are in your environment
cassidy_context_data()

# Get detailed summaries
cassidy_context_data(detailed = TRUE)
```

📋

### Describing Individual Data Frames

For more control,
use [`cassidy_describe_df()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_describe_df.md):

``` r
# Using the codebook method (best for labelled survey data)
desc <- cassidy_describe_df(my_survey_data, method = "codebook")

# Using skimr for statistical summaries
desc <- cassidy_describe_df(my_data, method = "skim")

# Basic method (no extra dependencies)
desc <- cassidy_describe_df(mtcars, method = "basic")
```

📋

The three methods serve different purposes:

Method \| Best For \| Includes \| \|——–\|———-\|———-\| \| `codebook` \|
Survey data with labels \| Variable labels, value labels, factor levels
\| \| `skim` \| Exploratory analysis \| Distribution stats, histograms,
missing patterns \| \| `basic` \| Quick overview \| Types, ranges,
missing counts \|

### Detecting Data Issues

Before sending data context, you might want to check for problems:

``` r
issues <- cassidy_detect_issues(my_data)
print(issues)
# Shows: high missing data, constant columns, outliers, duplicates
```

📋

## File Context

Often you need the AI to see specific code files to help with debugging,
refactoring, or documentation.

### Reading Files

``` r
# Read an entire file
ctx <- cassidy_describe_file("R/my-function.R")

# Read specific lines (great for focusing on one function)
ctx <- cassidy_describe_file("R/analysis.R", lines = 45:120)

# Read a range
ctx <- cassidy_describe_file("R/analysis.R", line_range = c(100, 200))

# Without line numbers (cleaner for short snippets)
ctx <- cassidy_describe_file("R/utils.R", show_line_numbers = FALSE)
```

📋

### Detail Levels for Files

When working with many files, you can control how much content is sent:

``` r
# Full content (default)
ctx <- cassidy_describe_file("R/big-file.R", level = "full")

# Summary - first/last 10 lines with line numbers
ctx <- cassidy_describe_file("R/big-file.R", level = "summary")

# Index - just metadata and function names
ctx <- cassidy_describe_file("R/big-file.R", level = "index")
```

📋

The summary and index levels include a `[REQUEST_FILE:path]` marker that
tells the AI it can request the full file if needed.

### Project File Summary

For a bird’s-eye view of your project’s files:

``` r
# Quick overview
cassidy_file_summary()

# With file sizes and line counts
cassidy_file_summary(level = "standard")

# With function extraction from R files
cassidy_file_summary(level = "comprehensive")
```

📋

## Environment Context

The AI sometimes needs to know what objects you have loaded and what
packages are available.

``` r
# Basic environment snapshot
cassidy_context_env()

# Detailed (includes object sizes, more functions listed)
cassidy_context_env(detailed = TRUE)

# Just list objects
cassidy_list_objects()

# Session information
cassidy_session_info(include_packages = TRUE)
```

📋

## Combining Context

For complex questions, you often need multiple types of context.
Use [`cassidy_context_combined()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_context_combined.md):

``` r
# Combine project context with specific files
combined <- cassidy_context_combined(
  cassidy_context_project(),
  cassidy_describe_file("R/problematic-function.R"),
  cassidy_describe_df(my_data)
)

# Use in a chat
cassidy_chat("Why is this function failing with my data?", context = combined)
```

📋

You can combine any number of context objects, character strings, or
objects with a `$text` element.

## Context in the Chat App

When
using [`cassidy_app()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_app.md),
context is managed through the sidebar interface.

### Project Context Panel

- **cassidy.md**: Toggle inclusion of your config file
- **R session info**: R version, platform, working directory
- **Git status**: Current branch and uncommitted changes

### Data Panel

- Shows all data frames in your global environment
- Select which ones to include in context
- Choose description method (basic/codebook/skim)
- Refresh individual data frames after changes

### Files Panel

- Browse your project’s file tree
- Select files to include in context
- Visual indicators show file status:
  - 🟢 **Green (pending)**: Selected but not yet sent
  - 🔵 **Blue (sent)**: Already sent to Cassidy
- Refresh buttons to re-send updated files

### Apply Context Button

Context is only sent when you click “Apply Context”. This lets you:

1.  Select exactly what information to share
2.  Review your selections before sending
3.  Avoid sending the same context repeatedly

## Best Practices

### Start with CASSIDY.md

Create a `CASSIDY.md` file for any project you’ll use with Cassidy. Even
a brief one helps:

``` markdown
# My Analysis Project

## Overview
Analyzing customer survey data for Q4 report.

## Preferences
- Use tidyverse style
- Prefer ggplot2 for visualizations
- Tables should be APA format
```

📋

### Be Selective with Files

Don’t send your entire codebase. Select only the files relevant to your
question:

``` r
# Good: specific and relevant
ctx <- cassidy_context_combined(
  cassidy_describe_file("R/the-broken-function.R"),
  cassidy_describe_file("tests/test-broken-function.R")
)
```

📋

Sending too many files creates noise and can overwhelm both the AI and
the context limits.

### Use Appropriate Detail Levels

Match the context level to your question:

Question Type \| Recommended Context \| \|————–\|———————\| \| “What does
this project do?” \| `cassidy_context_project(level = "minimal")` \| \|
“Help me refactor this function”
\| [`cassidy_describe_file()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_describe_file.md) with
specific lines \| \| “Review my package structure”
\| `cassidy_context_project(level = "comprehensive")` \| \| “Debug this
data pipeline” \| Data context + relevant file(s) \|

### Refresh After Changes

When you modify files or data during a session:

1.  Use the refresh buttons in the sidebar
2.  Or re-run the context gathering functions
3.  Click “Apply Context” to send updates

The chat app tracks what’s been sent, so refreshing only re-sends
changed content.

### Mind the Context Size

AI models have limits on how much text they can process (called the
“context window”). cassidyr helps manage this:

- [`cassidy_context_project()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_context_project.md) has
  a `max_size` parameter (default: 8000 characters)
- File context has `level` options to reduce size
- The app shows character counts when context is applied

If you’re hitting limits, use more selective context or lower detail
levels.

## Summary

The cassidyr context system helps you communicate effectively with AI
by:

1.  **Automating** the gathering of project, data, file, and environment
    information
2.  **Organizing** context through CASSIDY.md configuration files
3.  **Controlling** detail levels to balance completeness with
    efficiency
4.  **Tracking** what’s been sent to avoid redundant context
5.  **Combining** multiple context sources for complex questions

Start
with [`use_cassidy_md()`](https://jdenn0514.github.io/cassidyr/reference/use_cassidy_md.md) to
create your project config, then use the
interactive [`cassidy_app()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_app.md) to
manage context through the visual interface, or build custom context
programmatically with the context functions.
