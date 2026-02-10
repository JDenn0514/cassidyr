# ══════════════════════════════════════════════════════════════════════════════
# AGENTIC CHAT - Main Agentic Loop
# Orchestrates Assistant ↔ Workflow ↔ Tools for autonomous task completion
# ══════════════════════════════════════════════════════════════════════════════

#' Run an Agentic Task with CassidyAI
#'
#' Execute a task where the AI assistant autonomously uses tools to accomplish
#' complex goals. Uses a hybrid architecture: Assistant for reasoning, Workflow
#' for structured tool decisions, R for execution.
#'
#' **Safe Mode** is enabled by default, requiring user approval for risky
#' operations like writing files or executing code. This protects against
#' unintended changes to your system.
#'
#' @param task Character. The task description
#' @param assistant_id Character. CassidyAI assistant ID (default: env var)
#' @param api_key Character. CassidyAI API key (default: env var)
#' @param workflow_webhook Character. Workflow webhook URL (default: env var)
#' @param tools Character vector. Tools to enable (default: all)
#' @param working_dir Character. Working directory (default: current)
#' @param max_iterations Integer. Max tool calls (default: 10)
#' @param initial_context Character/list. Optional context to provide
#' @param safe_mode Logical. Require approval for risky tools? (default: TRUE)
#' @param approval_callback Function. Custom approval handler (default: NULL)
#' @param verbose Logical. Show progress? (default: TRUE)
#'
#' @return A `cassidy_agentic_result` object containing:
#'   \describe{
#'     \item{task}{The original task description}
#'     \item{final_response}{Final response or completion message}
#'     \item{iterations}{Number of iterations completed}
#'     \item{actions_taken}{List of all actions performed}
#'     \item{thread_id}{CassidyAI thread ID}
#'     \item{success}{Whether the task completed successfully}
#'   }
#'
#' @details
#' ## How It Works
#'
#' The agentic system uses a hybrid architecture:
#'
#' 1. **Assistant** provides high-level reasoning about the task
#' 2. **Workflow** makes structured tool decisions (guaranteed JSON)
#' 3. **R functions** execute tools with proper error handling
#'
#' This architecture eliminates parsing errors and provides reliable tool calling.
#'
#' ## Safe Mode
#'
#' When `safe_mode = TRUE` (default), risky operations require approval:
#'
#' - `write_file`: Writing/modifying files
#' - `execute_code`: Executing R code
#'
#' You'll be prompted to approve, deny, edit parameters, or view details
#' before each risky action. Safe mode can be disabled by setting
#' `safe_mode = FALSE`, but use caution!
#'
#' ## Custom Approval
#'
#' Provide your own approval logic with a callback function:
#'
#' ```r
#' my_approver <- function(action, input, reasoning) {
#'   # Auto-approve read operations, deny writes
#'   list(approved = action == "read_file", input = input)
#' }
#'
#' cassidy_agentic_task("Analyze code", approval_callback = my_approver)
#' ```
#'
#' @family agentic-functions
#' @export
#'
#' @examples
#' \dontrun{
#' # Simple task with safe mode (default)
#' result <- cassidy_agentic_task(
#'   "List all R files and describe what they do"
#' )
#'
#' # Task with limited tools (read-only)
#' result <- cassidy_agentic_task(
#'   "Analyze the package structure",
#'   tools = c("list_files", "read_file", "get_context"),
#'   max_iterations = 5
#' )
#'
#' # Allow risky operations without approval (use with caution!)
#' result <- cassidy_agentic_task(
#'   "Create a helper function in R/helpers.R",
#'   safe_mode = FALSE
#' )
#'
#' # Provide initial context
#' ctx <- cassidy_context_project(level = "standard")
#' result <- cassidy_agentic_task(
#'   "Review my code and suggest improvements",
#'   initial_context = ctx$text
#' )
#' }
cassidy_agentic_task <- function(
  task,
  assistant_id = Sys.getenv("CASSIDY_ASSISTANT_ID"),
  api_key = Sys.getenv("CASSIDY_API_KEY"),
  workflow_webhook = Sys.getenv("CASSIDY_WORKFLOW_WEBHOOK"),
  tools = names(.cassidy_tools),
  working_dir = getwd(),
  max_iterations = 10,
  initial_context = NULL,
  safe_mode = TRUE,  # ← DEFAULT TRUE
  approval_callback = NULL,
  verbose = TRUE
) {

  # Validate inputs
  if (!nzchar(task)) {
    cli::cli_abort("Task cannot be empty")
  }

  if (!nzchar(assistant_id)) {
    cli::cli_abort(c(
      "Assistant ID not found",
      "i" = "Set {.envvar CASSIDY_ASSISTANT_ID} in your {.file .Renviron}",
      "i" = "Run {.run cassidy_setup()} for guided setup"
    ))
  }

  if (!nzchar(workflow_webhook)) {
    cli::cli_abort(c(
      "Workflow webhook URL not found",
      "i" = "Set {.envvar CASSIDY_WORKFLOW_WEBHOOK} in your {.file .Renviron}",
      "i" = "Run {.run cassidy_setup_workflow()} for setup instructions"
    ))
  }

  # Create thread
  if (verbose) cli::cli_alert_info("Creating conversation thread...")
  thread_id <- cassidy_create_thread(assistant_id, api_key)

  # Build system prompt for assistant
  system_prompt <- .build_agentic_prompt(working_dir, max_iterations)

  # Build initial message
  message <- paste0(
    system_prompt,
    if (!is.null(initial_context)) paste0("\n\nCONTEXT:\n", initial_context),
    "\n\nTASK: ", task
  )

  # Initialize tracking
  iteration <- 0
  actions_taken <- list()

  if (verbose) {
    cli::cli_alert_success("Thread: {.val {thread_id}}")
    cli::cli_rule(left = "Starting Agentic Task")
    cli::cli_text("Task: {.emph {task}}")
    cli::cli_text("Safe mode: {.val {safe_mode}}")
    cli::cli_text("Max iterations: {.val {max_iterations}}")
    cli::cli_text("")
  }

  # Main loop
  current_message <- message

  repeat {
    iteration <- iteration + 1

    if (iteration > max_iterations) {
      if (verbose) cli::cli_alert_warning("Max iterations reached")
      break
    }

    if (verbose) {
      cli::cli_rule(left = paste("Iteration", iteration, "/", max_iterations))
    }

    # Get assistant reasoning
    if (verbose) cli::cli_alert_info("Consulting assistant...")
    response <- cassidy_send_message(thread_id, current_message, api_key)

    if (verbose) {
      cli::cli_text("{cli::symbol$pointer} {cli::col_silver(response$content)}")
      cli::cli_text("")
    }

    # Get tool decision from workflow
    if (verbose) cli::cli_alert_info("Getting tool decision...")

    decision <- tryCatch({
      .call_tool_workflow(
        reasoning = response$content,
        available_tools = tools,
        context = list(
          iteration = iteration,
          working_dir = working_dir
        ),
        workflow_webhook = workflow_webhook
      )
    }, error = function(e) {
      if (verbose) {
        cli::cli_alert_danger("Workflow error: {e$message}")
      }
      list(
        status = "final",
        reasoning = paste("Error calling workflow:", e$message)
      )
    })

    # Check if done
    if (decision$status == "final") {
      if (verbose) {
        cli::cli_rule()
        cli::cli_alert_success("Task completed!")
        cli::cli_text(decision$reasoning)
      }

      return(structure(
        list(
          task = task,
          final_response = decision$reasoning,
          iterations = iteration,
          actions_taken = actions_taken,
          thread_id = thread_id,
          success = TRUE
        ),
        class = "cassidy_agentic_result"
      ))
    }

    # Handle tool execution
    if (verbose) {
      cli::cli_alert_info("Action: {.field {decision$action}}")
      cli::cli_text("Reasoning: {.emph {decision$reasoning}}")
      cli::cli_text("")
    }

    # Check approval for risky tools
    if (safe_mode && .is_risky_tool(decision$action)) {
      approval <- .request_approval(
        action = decision$action,
        input = decision$input,
        reasoning = decision$reasoning,
        callback = approval_callback
      )

      if (!approval$approved) {
        if (verbose) cli::cli_text("")
        # Send denial back
        current_message <- paste0(
          "DENIED: User did not approve the '", decision$action, "' action.\n",
          "Try a different approach or ask for clarification."
        )
        next
      }

      # Use potentially edited input
      decision$input <- approval$input
      if (verbose) cli::cli_text("")
    }

    # Execute tool
    if (verbose) cli::cli_alert_info("Executing {.field {decision$action}}...")

    result <- .execute_tool(
      tool_name = decision$action,
      input = decision$input,
      working_dir = working_dir
    )

    # Record action
    actions_taken <- c(actions_taken, list(list(
      iteration = iteration,
      action = decision$action,
      input = decision$input,
      result = if (result$success) result$result else result$error,
      success = result$success
    )))

    # Format for next message
    if (result$success) {
      if (verbose) {
        cli::cli_alert_success("Tool executed successfully")
        cli::cli_text("")
      }
      current_message <- paste0(
        "RESULT (", decision$action, "):\n",
        if (is.character(result$result)) {
          result$result
        } else {
          paste(capture.output(print(result$result)), collapse = "\n")
        }
      )
    } else {
      if (verbose) {
        cli::cli_alert_danger("Tool failed: {result$error}")
        cli::cli_text("")
      }
      current_message <- paste0(
        "ERROR (", decision$action, "):\n", result$error,
        "\n\nTry a different approach or adjust parameters."
      )
    }
  }

  # Max iterations reached
  if (verbose) {
    cli::cli_rule()
  }

  structure(
    list(
      task = task,
      final_response = "Task incomplete (max iterations reached)",
      iterations = iteration,
      actions_taken = actions_taken,
      thread_id = thread_id,
      success = FALSE
    ),
    class = "cassidy_agentic_result"
  )
}

#' Build system prompt for agentic assistant
#'
#' Creates the initial instructions for the assistant explaining its role
#' in the agentic workflow.
#'
#' @param working_dir Character. Working directory path
#' @param max_iterations Integer. Maximum iterations allowed
#'
#' @return Character. System prompt
#' @keywords internal
#' @noRd
.build_agentic_prompt <- function(working_dir, max_iterations) {
  paste0(
    "You are an expert R programming assistant working in: ", working_dir, "\n\n",
    "Your role is to analyze tasks and provide clear reasoning about what needs to be done. ",
    "After you provide your reasoning, a tool decision system will choose which tool to use.\n\n",
    "Guidelines:\n",
    "- Break down complex tasks into clear, logical steps\n",
    "- Explain your reasoning thoroughly\n",
    "- Consider edge cases and potential errors\n",
    "- Follow R and tidyverse best practices\n",
    "- Be precise about file paths and parameters\n",
    "- You have ", max_iterations, " iterations to complete the task\n\n",
    "When you believe the task is complete, clearly state: 'TASK COMPLETE' ",
    "followed by a summary of what was accomplished."
  )
}

#' Print method for agentic results
#'
#' @param x A `cassidy_agentic_result` object
#' @param ... Additional arguments (unused)
#'
#' @return Invisibly returns x
#' @export
print.cassidy_agentic_result <- function(x, ...) {
  cli::cli_rule(left = "Agentic Task Result")
  cli::cli_text("Task: {.emph {x$task}}")
  cli::cli_text("Success: {.val {x$success}}")
  cli::cli_text("Iterations: {.val {x$iterations}}")
  cli::cli_text("Actions taken: {.val {length(x$actions_taken)}}")
  cli::cli_text("")

  if (x$success) {
    cli::cli_h2("Result")
    cli::cli_text(x$final_response)
  } else {
    cli::cli_alert_warning(x$final_response)
  }

  if (length(x$actions_taken) > 0) {
    cli::cli_text("")
    cli::cli_h2("Actions Taken")
    for (i in seq_along(x$actions_taken)) {
      action <- x$actions_taken[[i]]
      status_symbol <- if (action$success) {
        cli::col_green(cli::symbol$tick)
      } else {
        cli::col_red(cli::symbol$cross)
      }
      cli::cli_text(
        "{status_symbol} {i}. {.field {action$action}} (iteration {action$iteration})"
      )
    }
  }

  cli::cli_rule()

  invisible(x)
}
