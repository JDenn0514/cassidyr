# ══════════════════════════════════════════════════════════════════════════════
# AGENTIC WORKFLOW - Integration with CassidyAI Workflows
# Handles structured tool decision via workflow webhooks
# ══════════════════════════════════════════════════════════════════════════════

#' Call CassidyAI Tool Decision Workflow
#'
#' Makes a webhook request to a CassidyAI Workflow configured with structured
#' output fields for reliable tool decision-making.
#'
#' @param reasoning Character. The assistant's reasoning about next steps
#' @param available_tools Character vector. Tools the agent can use
#' @param context List. Current state/context
#' @param workflow_webhook Character. Webhook URL from CASSIDY_WORKFLOW_WEBHOOK env var
#'
#' @return List with action, input, reasoning, status
#' @keywords internal
#' @noRd
.call_tool_workflow <- function(
  reasoning,
  available_tools,
  context = NULL,
  workflow_webhook = Sys.getenv("CASSIDY_WORKFLOW_WEBHOOK")
) {

  if (!nzchar(workflow_webhook)) {
    cli::cli_abort(c(
      "Workflow webhook URL not found",
      "i" = "Set {.envvar CASSIDY_WORKFLOW_WEBHOOK} in .Renviron",
      "i" = "Create workflow in CassidyAI with structured output fields",
      "i" = "Run {.run cassidy_setup_workflow()} for setup instructions"
    ))
  }

  # Build payload
  payload <- list(
    reasoning = reasoning,
    available_tools = available_tools
  )

  # Add context if provided
  if (!is.null(context)) {
    payload$context <- context
  }

  # Call workflow
  resp <- tryCatch({
    httr2::request(workflow_webhook) |>
      httr2::req_body_json(payload) |>
      httr2::req_timeout(120) |>
      httr2::req_retry(
        max_tries = 3,
        is_transient = function(resp) {
          httr2::resp_status(resp) %in% c(429, 503, 504)
        }
      ) |>
      httr2::req_error(body = function(resp) {
        body <- httr2::resp_body_json(resp)
        body$message %||% body$error %||% "Unknown workflow error"
      }) |>
      httr2::req_perform()
  }, error = function(e) {
    cli::cli_abort(c(
      "Failed to call workflow",
      "x" = e$message,
      "i" = "Check that {.envvar CASSIDY_WORKFLOW_WEBHOOK} is correct",
      "i" = "Verify workflow is active in CassidyAI platform"
    ))
  })

  # Parse structured output
  result <- httr2::resp_body_json(resp)

  # Validate required fields
  required <- c("action", "input", "reasoning", "status")
  missing <- setdiff(required, names(result))

  if (length(missing) > 0) {
    cli::cli_abort(c(
      "Workflow returned invalid structure",
      "x" = "Missing fields: {.field {missing}}",
      "i" = "Expected fields: {.field {required}}",
      "i" = "Got fields: {.field {names(result)}}",
      "i" = "Check workflow structured output configuration"
    ))
  }

  # Validate status
  if (!result$status %in% c("continue", "final")) {
    cli::cli_warn(c(
      "Unexpected status value: {.val {result$status}}",
      "i" = "Expected 'continue' or 'final'",
      "i" = "Defaulting to 'continue'"
    ))
    result$status <- "continue"
  }

  result
}

#' Setup Tool Decision Workflow
#'
#' Displays instructions for creating a CassidyAI Workflow with structured
#' output fields for reliable tool decision-making in agentic mode.
#'
#' @details
#' This function displays step-by-step instructions for creating a workflow
#' in the CassidyAI platform that will be used by [cassidy_agentic_task()]
#' to make tool decisions with guaranteed JSON structure.
#'
#' The workflow uses **structured output fields** to eliminate parsing errors
#' and ensure reliable tool calling.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' # Display workflow setup instructions
#' cassidy_setup_workflow()
#' }
cassidy_setup_workflow <- function() {
  cli::cli_h1("Setup Tool Decision Workflow")

  cli::cli_text(
    "Create a new workflow in the CassidyAI platform with the following configuration:"
  )
  cli::cli_text("")

  # Trigger setup
  cli::cli_h2("1. Trigger Configuration")
  cli::cli_ul(c(
    "Type: {.strong Webhook}",
    "Enable: {.strong Return results from webhook}",
    "Optional: Add API key authentication for security"
  ))
  cli::cli_text("")

  # Action setup
  cli::cli_h2("2. Action: Generate Text with Cassidy Agent")
  cli::cli_text("Add this prompt to the action:")
  cli::cli_text("")
  cli::cli_code('
You are a tool selection expert for an R programming assistant.

Based on the reasoning provided, choose the most appropriate tool and parameters.

## Available Tools
{{available_tools}}

## Current Reasoning
{{reasoning}}

## Context
{{context}}

Choose ONE tool and provide exact parameters needed. If the task is complete,
set status to "final". Otherwise set status to "continue".

Be precise with parameters - use exact file paths and clear instructions.
  ')
  cli::cli_text("")

  # Structured output
  cli::cli_h2("3. Structured Output Fields")
  cli::cli_text("Configure these output fields (exact names required):")
  cli::cli_text("")

  cli::cli_dl(c(
    "action" = "Dropdown: read_file, write_file, execute_code, list_files, search_files, get_context, describe_data",
    "input" = "Object: Tool parameters as key-value pairs",
    "reasoning" = "Text (Required): Why this action was chosen",
    "status" = "Dropdown: continue, final"
  ))
  cli::cli_text("")

  # Save webhook
  cli::cli_h2("4. Save Webhook URL")
  cli::cli_text("After creating the workflow, copy the webhook URL and save it:")
  cli::cli_text("")
  cli::cli_code('
# In R console
Sys.setenv(CASSIDY_WORKFLOW_WEBHOOK = "your-webhook-url-here")

# Or add to .Renviron for persistence
usethis::edit_r_environ()
  ')
  cli::cli_text("")

  # Testing
  cli::cli_h2("5. Test the Setup")
  cli::cli_text("Test your agentic setup with a simple task:")
  cli::cli_text("")
  cli::cli_code('
# Simple test task
cassidy_agentic_task(
  "List all R files in the current directory",
  max_iterations = 3
)
  ')
  cli::cli_text("")

  # Tips
  cli::cli_h2("Tips")
  cli::cli_ul(c(
    "The workflow ensures reliable JSON responses (no parsing errors)",
    "Safe mode is enabled by default - risky operations require approval",
    "Start with read-only tools to verify setup before allowing writes",
    "Check workflow logs in CassidyAI if you encounter errors"
  ))

  invisible(NULL)
}
