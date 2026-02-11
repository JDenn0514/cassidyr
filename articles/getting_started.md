# Getting Started with cassidyr

## Introduction

**cassidyr** provides an R client for the CassidyAI API, enabling
seamless integration of AI-powered assistants into your R workflows.
Whether you’re developing packages, analyzing data, or conducting survey
research, cassidyr helps you get context-aware AI assistance directly in
R.

## Installation

``` r
# Install from GitHub
# install.packages("pak")
pak::pak("your-username/cassidyr")
```

## Setup

Before using cassidyr, you need to configure your API credentials. The
package uses environment variables for security—your credentials are
never stored in code.

### Get API Credentials

Get your API credentials from CassidyAI.

### Configure Environment Variables

Add your credentials to your `.Renviron` file:

``` r
# Open your .Renviron file
usethis::edit_r_environ()
```

Add these lines:

    CASSIDY_API_KEY=your_api_key_here
    CASSIDY_ASSISTANT_ID=your_assistant_id_here

Then restart R for the changes to take effect.

## Interactive Chat

The easiest way to use cassidyr is through the interactive chat
application:

``` r
library(cassidyr)

# Launch the chat interface
cassidy_app()
```

This opens a Shiny-based chat interface where you can:

- Chat with your Cassidy AI assistant
- Automatically share project context
- Add files to the conversation
- Switch between multiple conversations
- Export chat history as Markdown

### Managing Conversations

Cassidyr automatically saves your conversations:

``` r
# Resume your most recent conversation (default)
cassidy_app()

# Start fresh with new context
cassidy_app(new_chat = TRUE)

# List saved conversations
cassidy_list_conversations()

# Export a conversation to Markdown
cassidy_export_conversation("conv_20240115_123456")

# Delete old conversations
cassidy_delete_conversation("conv_20240101_000000")
```

### Working with Files

In the chat interface, dynamically add files to give the AI more
context:

1.  Click the Context panel toggle (left sidebar)
2.  Expand the Files section
3.  Browse and select files from your project
4.  Click Apply Context to send the updated context

The AI will then have access to your selected files’ contents.

## Project Context

One of cassidyr’s most powerful features is automatic context gathering.
When you start a chat, cassidyr can share information about your project
with the AI assistant.

cassidyr’s memory system is inspired by [Claude
Code](https://code.claude.com/docs/en/memory), using a hierarchical
structure that searches recursively up your directory tree. This enables
organization-wide standards in parent directories to be combined with
project-specific settings.

### Create a CASSIDY.md File

For the best experience, create a `CASSIDY.md` file in your project.
This file tells the AI about your project’s conventions, goals, and
preferences:

``` r
# Create a configuration file
use_cassidy_md()

# For R package development
use_cassidy_md(template = "package")

# For data analysis projects
use_cassidy_md(template = "analysis")

# For survey research
use_cassidy_md(template = "survey")
```

You can place your configuration in several locations:

- **`CASSIDY.md`** - Project root, shared with team via Git
- **`.cassidy/CASSIDY.md`** - Hidden directory, keeps root clean
- **`CASSIDY.local.md`** - Local-only (auto-gitignored), for personal
  project preferences
- **`~/.cassidy/CASSIDY.md`** - User-level, applies to all your R
  projects

When you start
[`cassidy_app()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_app.md),
it searches up from your working directory to find all memory files,
with more specific (project-level) settings taking precedence over
broader (user-level) ones. For complex projects, you can also organize
instructions into modular files in `.cassidy/rules/*.md`.

The AI will automatically read these files and tailor its responses to
your project. See
[`vignette("project-memory")`](https://jdenn0514.github.io/cassidyr/articles/project-memory.md)
for complete details.

### Example CASSIDY.md

``` markdown
## Coding Preferences
- Use tidyverse style
- Prefer purrr::map() over lapply()
- Always include roxygen2 documentation
- Maximum line length: 80 characters

## Common Tasks
- Writing unit tests with testthat
- Creating ggplot2 visualizations
- Documenting functions
```

### Context Levels

When starting a new chat, you can control how much context is shared:

``` r
# Minimal: Just R session info
cassidy_app(new_chat = TRUE, context_level = "minimal")

# Standard: Session + project config + file structure (default)
cassidy_app(new_chat = TRUE, context_level = "standard")

# Comprehensive: Everything including git status
cassidy_app(new_chat = TRUE, context_level = "comprehensive")
```

## Programmatic API

For scripting and automation, you can use the API functions directly:

### Basic Usage

``` r
# Create a new conversation thread
thread_id <- cassidy_create_thread()

# Send a message
response <- cassidy_send_message(
  thread_id = thread_id,
  message = "Help me write a function to calculate means by group"
)

# View the response
cat(response$content)
```

### Include Context

``` r
# Gather project context
ctx <- cassidy_context_project(level = "standard")

# Describe a specific file
file_ctx <- cassidy_describe_file("R/analysis.R")

# Describe a data frame
data_ctx <- cassidy_describe_df(my_data, name = "survey_results")

# Combine multiple contexts
combined <- cassidy_context_combined(ctx, file_ctx, data_ctx)

# Use in a chat
response <- cassidy_chat(
  "Review this code and suggest improvements",
  context = combined
)
```

## Tips for Effective Use

### Be Specific in Your Configuration

The more specific your `CASSIDY.md` file, the better the AI can help.
Include your coding style, preferred packages, common tasks, and
project-specific conventions.

### Use Context Strategically

- **New topic?** Start a new chat with `cassidy_app(new_chat = TRUE)`
- **Continuing work?** Just use
  [`cassidy_app()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_app.md)
  to resume
- **Reviewing specific code?** Add just those files to context

### Leverage Data Descriptions

When working with data, let cassidyr describe your data frames:

``` r
# In the chat sidebar, select data frames to include
# Or programmatically:
cassidy_describe_df(
  my_survey_data,
  name = "survey",
  method = "codebook"
)
```

## Next Steps

- **Explore templates**: Try different templates with
  [`use_cassidy_md()`](https://jdenn0514.github.io/cassidyr/reference/use_cassidy_md.md)
- **Customize context**: Edit your `CASSIDY.md` to match your workflow
- **Read the documentation**: See
  [`?cassidy_app`](https://jdenn0514.github.io/cassidyr/reference/cassidy_app.md),
  [`?cassidy_chat`](https://jdenn0514.github.io/cassidyr/reference/cassidy_chat.md),
  and related functions
- **Learn more about memory**: Check out
  [`vignette("project-memory")`](https://jdenn0514.github.io/cassidyr/articles/project-memory.md)

## Troubleshooting

If you encounter issues:

1.  Check that your API credentials are set correctly in `.Renviron`
2.  Ensure you have an active internet connection
3.  Try `cassidy_app(new_chat = TRUE)` to start fresh
4.  File issues at the package GitHub repository
