
<!-- README.md is generated from README.Rmd. Please edit that file -->

# cassidyr

<!-- badges: start -->

[![Lifecycle:
experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
<!-- badges: end -->

**cassidyr** is an R client for the
[CassidyAI](https://www.cassidyai.com/) API, providing a clean and
intuitive interface to integrate AI-powered assistants into your R
workflows.

## Features

- 🤖 **Simple API Client**: Create threads, send messages, and manage
  conversations
- 💬 **Interactive Chat** (coming soon): Launch Shiny-based chat
  interfaces
- 📊 **Context-Aware** (coming soon): Automatically gather project
  context from your R environment
- 🔧 **IDE Integration** (coming soon): RStudio addins for AI-assisted
  coding
- 📋 **Survey Research Tools** (coming soon): Specialized functions for
  survey analysis workflows

## Installation

You can install the development version of cassidyr from
[GitHub](https://github.com/) with:

``` r
# install.packages("pak")
pak::pak("JDenn0514/cassidyr")
```

## Setup

Before using cassidyr, you’ll need:

1.  CassidyAI Account: Sign up at cassidyai.com
2.  API Key: Generate one from Organization Settings → API Keys
3.  Assistant ID: Find this in your assistant’s External Deployments
    settings

Store your credentials securely in your .Renviron file:

``` r
# Open your .Renviron file
usethis::edit_r_environ()

# Add these lines (with your actual credentials):
# CASSIDY_API_KEY = "your_api_key_here"
# CASSIDY_ASSISTANT_ID = "your_assistant_id_here"

# Save, close, and restart R
```

## Quick Start

``` r
library(cassidyr)

# Option 1: Manual thread management (more control)
thread_id <- cassidy_create_thread()
response <- cassidy_send_message(thread_id, "What is the tidyverse?")
print(response)

# Continue the conversation
response2 <- cassidy_send_message(thread_id, "Which package should I use for data cleaning?")

# Option 2: Simplified workflow (handles threads automatically)
result <- cassidy_chat("How do I create a bar plot in ggplot2?")
print(result$response)

# Continue with the same thread
result <- cassidy_chat(
  "Can you show me an example with the mtcars dataset?",
  thread_id = result$thread_id
)

# Retrieve conversation history
thread <- cassidy_get_thread(result$thread_id)
threads <- cassidy_list_threads()
```

## Roadmap

cassidyr is under active development. Upcoming features (subject to
change) include:

#### Phase 1.5: Interactive Chat UI

- cassidy_app() - Launch a Shiny chat interface
- Session history and export
- Context selection controls

#### Phase 2: Context System

- cassidy_context_project() - Gather project-level context
- cassidy_context_data() - Summarize data frames
- cassidy.md configuration files

#### Phase 3: IDE Integration

- cassidy_document_function() - Generate roxygen2 docs
- cassidy_explain_selection() - Explain code
- cassidy_refactor_selection() - Improve code quality

#### Phase 4: Agent System

- cassidy_agent() - Iterative problem solving
- cassidy_execute_code() - Safe code execution
- Multi-step workflows

#### Phase 5: Survey Research Tools

- cassidy_interpret_efa() - EFA interpretation
- cassidy_write_methods() - Generate methods sections
- cassidy_codebook() - Variable documentation

## Design Philosophy

cassidyr is built with three core principles:

1.  **Security First**: No credentials in code, secure by default
2.  **Tidyverse Style**: Consistent naming (`cassidy_*`), pipe-friendly
    functions
3.  **Modular Design**: Core API separate from specialized tools, easy
    to extend

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

- 📖 [Documentation](https://jdenn0514.github.io/cassidyr/) (coming
  soon)
- 🐛 [Report bugs](https://github.com/JDenn0514/cassidyr/issues)
- 💬 [Ask questions](https://github.com/JDenn0514/cassidyr/discussions)
- 📧 Email: <your.email@example.com>

## Code of Conduct

Please note that cassidyr is released with a [Contributor Code of
Conduct](https://contributor-covenant.org/version/2/1/CODE_OF_CONDUCT.html).
By contributing to this project, you agree to abide by its terms.

## License

MIT © Jacob Dennen
