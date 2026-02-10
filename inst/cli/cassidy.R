#!/usr/bin/env Rscript

# ══════════════════════════════════════════════════════════════════════════════
# CASSIDY CLI - Command-line interface for cassidyr
# Provides interactive and direct task modes for agentic workflows
# ══════════════════════════════════════════════════════════════════════════════

# Parse command line arguments
args <- commandArgs(trailingOnly = TRUE)

# Load package
suppressPackageStartupMessages({
  if (requireNamespace("cassidyr", quietly = TRUE)) {
    library(cassidyr)
  } else {
    cat("Error: cassidyr package not installed\n", file = stderr())
    cat("Install with: install.packages('cassidyr')\n", file = stderr())
    quit(status = 1)
  }
})

# ══════════════════════════════════════════════════════════════════════════════
# COMMAND ROUTER
# ══════════════════════════════════════════════════════════════════════════════

if (length(args) == 0 || args[1] == "agent") {
  # ────────────────────────────────────────────────────────────────────────────
  # AGENTIC MODE
  # ────────────────────────────────────────────────────────────────────────────

  if (length(args) > 1) {
    # Direct task from command line
    task <- paste(args[-1], collapse = " ")

    result <- cassidy_agentic_task(
      task = task,
      verbose = TRUE
    )

    # Print result
    print(result)

    # Exit with appropriate status
    quit(status = if (result$success) 0 else 1)

  } else {
    # Interactive REPL mode
    cli::cli_rule(left = "Cassidy Agent", right = "Interactive Mode")
    cli::cli_text("Type your task or 'exit' to quit")
    cli::cli_text("Commands: help, exit, context, clear")
    cli::cli_text("")

    repeat {
      task <- readline(prompt = paste0(cli::col_cyan("\u276f ")))
      task <- trimws(task)

      # Check for exit
      if (task == "" || tolower(task) %in% c("exit", "quit", "q")) {
        cli::cli_alert_info("Goodbye!")
        break
      }

      # Check for help
      if (tolower(task) == "help") {
        cat("
Cassidy Agent - Interactive Mode

Commands:
  help      Show this help message
  exit      Exit the agent (or press Ctrl+C)
  context   Show current project context
  clear     Clear screen

Otherwise, type any task and the agent will work to complete it.

Examples:
  List all R files in this directory
  Create a function to calculate mean
  Search for TODO comments in the code
")
        cat("\n")
        next
      }

      # Check for context command
      if (tolower(task) == "context") {
        ctx <- cassidy_context_project(level = "minimal")
        cat(ctx$text)
        cat("\n")
        next
      }

      # Check for clear command
      if (tolower(task) == "clear") {
        system("clear")
        next
      }

      # Execute task
      result <- cassidy_agentic_task(
        task = task,
        verbose = TRUE
      )

      cat("\n")
    }
  }

} else if (args[1] == "chat") {
  # ────────────────────────────────────────────────────────────────────────────
  # CHAT MODE - Launch Shiny app
  # ────────────────────────────────────────────────────────────────────────────

  cli::cli_alert_info("Launching Cassidy chat interface...")
  cassidy_app()

} else if (args[1] == "context") {
  # ────────────────────────────────────────────────────────────────────────────
  # CONTEXT MODE - Show project context
  # ────────────────────────────────────────────────────────────────────────────

  level <- if (length(args) > 1) args[2] else "standard"

  if (!level %in% c("minimal", "standard", "comprehensive")) {
    cli::cli_alert_danger("Invalid context level: {level}")
    cli::cli_text("Use: minimal, standard, or comprehensive")
    quit(status = 1)
  }

  ctx <- cassidy_context_project(level = level)
  cat(ctx$text)
  cat("\n")

} else if (args[1] == "setup") {
  # ────────────────────────────────────────────────────────────────────────────
  # SETUP MODE - Show workflow setup instructions
  # ────────────────────────────────────────────────────────────────────────────

  cassidy_setup_workflow()

} else if (args[1] == "help" || args[1] == "--help" || args[1] == "-h") {
  # ────────────────────────────────────────────────────────────────────────────
  # HELP MODE
  # ────────────────────────────────────────────────────────────────────────────

  cat("
Cassidy CLI - AI-powered R assistant

Usage:
  cassidy agent [task]       Start agentic session
  cassidy chat               Launch Shiny chat interface
  cassidy context [level]    Show project context
  cassidy setup              Show workflow setup instructions
  cassidy help               Show this help message

Agent Mode:
  cassidy agent              Interactive REPL mode
  cassidy agent \"task\"       Execute specific task

  When running tasks, the agent will use tools to complete your request.
  Safe mode is enabled by default - you'll be asked to approve risky
  operations like writing files or executing code.

Context Levels:
  minimal        Quick context (R version, project type)
  standard       Standard context (+ files, git status)
  comprehensive  Full context (+ detailed environment)

Examples:
  cassidy agent \"List all R files\"
  cassidy agent \"Create a helper function\"
  cassidy agent                    # Interactive mode
  cassidy context standard         # Show project context
  cassidy setup                    # Setup workflow integration

Environment Variables:
  CASSIDY_API_KEY              Your CassidyAI API key
  CASSIDY_ASSISTANT_ID         Assistant ID for chat
  CASSIDY_WORKFLOW_WEBHOOK     Workflow webhook for agentic mode

For more information, visit: https://github.com/JDenn0514/cassidyr
")

} else {
  # ────────────────────────────────────────────────────────────────────────────
  # UNKNOWN COMMAND
  # ────────────────────────────────────────────────────────────────────────────

  cli::cli_alert_danger("Unknown command: {args[1]}")
  cli::cli_text("Run {.run cassidy help} for usage information")
  quit(status = 1)
}
