

<!-- README.md is generated from README.Rmd. Please edit that file -->

# cassidyr

<!-- badges: start -->

[![Lifecycle:
experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
[![R-CMD-check](https://github.com/JDenn0514/cassidyr/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/JDenn0514/cassidyr/actions/workflows/R-CMD-check.yaml)
<!-- badges: end -->

**cassidyr** is an R client for the
[CassidyAI](https://www.cassidyai.com/) API, providing a clean and
intuitive interface to integrate AI-powered assistants into your R
workflows.

## Features

- 🤖 **Simple API Client**: Create threads, send messages, and manage
  conversations
- 📊 **Context-Aware**: Automatically gather project and data context
  for better AI responses
- 💬 **Interactive Chat**: Launch a Shiny-based chat interface with
  `cassidy_app()`
- 💾 **Conversation Persistence**: Auto-save and restore chat history
- 📋 **Copy Code Button**: One-click copy for code blocks in chat
  responses
- 🔧 **IDE Integration** (coming soon): RStudio/Positron addins for
  AI-assisted coding

## Installation

You can install the development version of cassidyr from
[GitHub](https://github.com/) with:

``` r
# install.packages("pak")
pak::pak("JDenn0514/cassidyr")
```

## Setup

Before using cassidyr, you’ll need: 1. **CassidyAI Account**: Sign up at
[cassidyai.com](https://www.cassidyai.com/) 2. **API Key**: Generate one
from Organization Settings → API Keys 3. **Assistant ID**: Find this in
your assistant’s External Deployments settings

Store your credentials securely in your `.Renviron` file:

``` r
# Open your .Renviron file
usethis::edit_r_environ()

# Add these lines (with your actual credentials):
# CASSIDY_API_KEY = "your_api_key_here"
# CASSIDY_ASSISTANT_ID = "your_assistant_id_here"

# Save, close, and restart R
```

## Quick Start

### Interactive Chat App

The easiest way to use cassidyr is through the interactive Shiny chat
interface:

``` r
library(cassidyr)

# Launch the chat app
cassidy_app()
```

Features include: - Context sidebar for managing project/data/file
context - Conversation history with save/load - One-click code copying -
Mobile-responsive design

### Programmatic Chat

For scripting and automation:

``` r
library(cassidyr)

# Simple one-off chat
result <- cassidy_chat("How do I create a bar plot in ggplot2?")
print(result$response)

# Continue the conversation
result <- cassidy_chat(
  "Can you show me an example with the mtcars dataset?",
  thread_id = result$thread_id
)

# Or use session-based chat for interactive use
session <- cassidy_session()
chat(session, "What is the tidyverse?")
chat(session, "Which package should I use for data cleaning?")
```

### Low-Level API Access

For more control over thread management:

``` r
# Create a thread
thread_id <- cassidy_create_thread()

# Send messages
response <- cassidy_send_message(thread_id, "What is the tidyverse?")
print(response)

# Retrieve conversation history
thread <- cassidy_get_thread(thread_id)

# List all threads
threads <- cassidy_list_threads()
```

### Context Gathering

Provide rich context to improve AI responses. cassidyr’s memory system
(inspired by [Claude Code](https://code.claude.com/docs/en/memory))
searches recursively up your directory tree, combining user-level
preferences with project-specific settings:

``` r
# Create a CASSIDY.md file for your project
use_cassidy_md()  # Creates CASSIDY.md with project instructions

# Gather comprehensive project context (includes CASSIDY.md files)
ctx <- cassidy_context_project(level = "standard")

# Describe a data frame for the AI
cassidy_describe_df(mtcars)

# Files are automatically loaded when you start cassidy_app()
```

Memory files can be placed at multiple levels: - **User-level**:
`~/.cassidy/CASSIDY.md` (applies to all projects) - **Project-level**:
`CASSIDY.md` or `.cassidy/CASSIDY.md` (shared with team) - **Local**:
`CASSIDY.local.md` (personal, auto-gitignored) - **Modular**:
`.cassidy/rules/*.md` (organized by topic)

## Roadmap

cassidyr is under active development. Current status and upcoming
features:

### ✅ Complete

- **Phase 1: API Layer** - Thread creation, messaging, history retrieval
- **Phase 2: Context System** - Project, data, and file context
  gathering
- **Phase 3: Interactive Chat** - Shiny app with persistence, copy code
  button

### ⏳ In Progress

- **Phase 4: IDE Integration**
  - `cassidy_document_function()` - Generate roxygen2 docs
  - `cassidy_explain_selection()` - Explain selected code
  - `cassidy_refactor_selection()` - Improve code quality
  - `cassidy_debug_error()` - Help debug errors

### 🔮 Future

- **Phase 5: Agent System** - Iterative problem solving, safe code
  execution
- **Phase 6: Survey Research Tools** - EFA interpretation, methods
  sections, codebooks

## Design Philosophy

cassidyr is built with four core principles:

1.  **Security First**: No credentials in code, secure environment
    variables
2.  **Tidyverse Style**: Consistent naming (`cassidy_*`), pipe-friendly
    functions
3.  **Modular Design**: Core API separate from specialized tools, easy
    to extend
4.  **Hierarchical Memory**: Inspired by Claude Code’s memory system,
    enabling organization-wide standards to combine with
    project-specific configurations

## Related Packages

- [**ellmer**](https://ellmer.tidyverse.org/): Multi-provider LLM client
  (OpenAI, Claude, etc.)
- [**btw**](https://posit-dev.github.io/btw/): Toolkit for connecting R
  and LLMs
- [**shinychat**](https://posit-dev.github.io/shinychat/): Chat UI
  components for Shiny

cassidyr is specifically designed for CassidyAI’s unique features like
persistent assistants, knowledge bases, and organizational context.

## Getting Help

- 📖 [Documentation](https://jdenn0514.github.io/cassidyr/)
- 🐛 [Report bugs](https://github.com/JDenn0514/cassidyr/issues)
- 💬 [Ask questions](https://github.com/JDenn0514/cassidyr/discussions)

## Code of Conduct

Please note that cassidyr is released with a [Contributor Code of
Conduct](https://contributor-covenant.org/version/2/1/CODE_OF_CONDUCT.html).
By contributing to this project, you agree to abide by its terms.

## License

MIT © Jacob Dennen
