# ══════════════════════════════════════════════════════════════════════════════
# AGENTIC TEST - Test Workflow Setup
# Helper functions to test CassidyAI Workflow configuration
# ══════════════════════════════════════════════════════════════════════════════

#' Test CassidyAI Workflow Setup
#'
#' Tests your CassidyAI Workflow configuration to verify it returns the correct
#' structured output format. This is useful for debugging workflow setup issues.
#'
#' @param workflow_webhook Character. Workflow webhook URL (default: env var)
#' @param verbose Logical. Print detailed output? (default: TRUE)
#'
#' @return Invisibly returns the workflow response if successful
#' @export
#'
#' @examples
#' \dontrun{
#' # Test your workflow setup
#' cassidy_test_workflow()
#'
#' # Test with custom webhook
#' cassidy_test_workflow(
#'   workflow_webhook = "https://webhook.cassidyai.com/your-id"
#' )
#' }
cassidy_test_workflow <- function(
  workflow_webhook = Sys.getenv("CASSIDY_WORKFLOW_WEBHOOK"),
  verbose = TRUE
) {

  if (verbose) {
    cli::cli_h1("Testing CassidyAI Workflow")
  }

  # Check webhook URL
  if (!nzchar(workflow_webhook)) {
    cli::cli_abort(c(
      "Workflow webhook URL not found",
      "i" = "Set {.envvar CASSIDY_WORKFLOW_WEBHOOK} in .Renviron",
      "i" = "Run {.run cassidy_setup_workflow()} for setup instructions"
    ))
  }

  if (verbose) {
    cli::cli_alert_info("Webhook URL: {.url {substr(workflow_webhook, 1, 50)}}...")
  }

  # Test payload
  test_payload <- list(
    reasoning = "I need to list all R files in the current directory to understand the project structure.",
    available_tools = c(
      "read_file", "write_file", "execute_code",
      "list_files", "search_files", "get_context", "describe_data"
    ),
    context = list(
      iteration = 1,
      working_dir = getwd()
    )
  )

  if (verbose) {
    cli::cli_alert_info("Sending test request...")
  }

  # Call workflow
  result <- tryCatch({
    resp <- httr2::request(workflow_webhook) |>
      httr2::req_body_json(test_payload) |>
      httr2::req_timeout(30) |>
      httr2::req_error(body = function(resp) {
        body <- httr2::resp_body_json(resp)
        body$message %||% body$error %||% "Unknown workflow error"
      }) |>
      httr2::req_perform()

    httr2::resp_body_json(resp)
  }, error = function(e) {
    if (verbose) {
      cli::cli_alert_danger("Workflow request failed")
      cli::cli_text("Error: {.emph {e$message}}")
    }
    return(NULL)
  })

  if (is.null(result)) {
    cli::cli_alert_danger("Test failed: No response from workflow")
    return(invisible(NULL))
  }

  # Check if response is wrapped in CassidyAI workflow execution metadata
  if ("workflowRun" %in% names(result) && "actionResults" %in% names(result$workflowRun)) {
    if (verbose) {
      cli::cli_alert_info("Detected CassidyAI workflow wrapper, extracting output...")
    }

    # Extract the actual output from the first action
    action_results <- result$workflowRun$actionResults

    if (length(action_results) == 0) {
      cli::cli_abort(c(
        "Workflow returned no action results",
        "i" = "Check that workflow has a Generate Text action"
      ))
    }

    # Get output from first action
    output <- action_results[[1]]$output

    if (is.null(output)) {
      cli::cli_abort(c(
        "Action output is null",
        "i" = "Check that Generate Text action has structured output fields"
      ))
    }

    # Parse the JSON string output
    if (is.character(output)) {
      result <- jsonlite::fromJSON(output, simplifyVector = FALSE)
    } else {
      result <- output
    }
  }

  # Validate response structure
  if (verbose) {
    cli::cli_alert_success("Response received")
    cli::cli_h2("Validating Response")
  }

  required_fields <- c("action", "input", "reasoning", "status")
  missing_fields <- setdiff(required_fields, names(result))

  if (length(missing_fields) > 0) {
    if (verbose) {
      cli::cli_alert_danger("Missing required fields: {.field {missing_fields}}")
      cli::cli_text("Received fields: {.field {names(result)}}")
      cli::cli_text("")
      cli::cli_alert_info("Response:")
      cli::cli_code(jsonlite::toJSON(result, pretty = TRUE, auto_unbox = TRUE))
    }

    cli::cli_abort(c(
      "Workflow returned invalid structure",
      "x" = "Missing fields: {.field {missing_fields}}",
      "i" = "Check structured output configuration in CassidyAI",
      "i" = "Run {.run cassidy_setup_workflow()} for setup instructions"
    ))
  }

  if (verbose) {
    cli::cli_alert_success("All required fields present")
  }

  # Validate field types
  checks <- list(
    list(
      name = "action",
      test = is.character(result$action) && nzchar(result$action),
      message = "action must be a non-empty string"
    ),
    list(
      name = "input",
      test = is.list(result$input),
      message = "input must be an object/list"
    ),
    list(
      name = "reasoning",
      test = is.character(result$reasoning) && nzchar(result$reasoning),
      message = "reasoning must be a non-empty string"
    ),
    list(
      name = "status",
      test = result$status %in% c("continue", "final"),
      message = "status must be 'continue' or 'final'"
    )
  )

  all_valid <- TRUE
  for (check in checks) {
    if (check$test) {
      if (verbose) {
        cli::cli_alert_success("{.field {check$name}}: Valid")
      }
    } else {
      if (verbose) {
        cli::cli_alert_danger("{.field {check$name}}: Invalid")
        cli::cli_text("  {check$message}")
      }
      all_valid <- FALSE
    }
  }

  if (!all_valid) {
    if (verbose) {
      cli::cli_text("")
      cli::cli_alert_info("Full response:")
      cli::cli_code(jsonlite::toJSON(result, pretty = TRUE, auto_unbox = TRUE))
    }

    cli::cli_abort(c(
      "Workflow response validation failed",
      "i" = "Check structured output field types in CassidyAI",
      "i" = "Ensure all fields are configured as specified"
    ))
  }

  # Success!
  if (verbose) {
    cli::cli_text("")
    cli::cli_rule(left = "Test Results")
    cli::cli_alert_success("Workflow is correctly configured!")
    cli::cli_text("")
    cli::cli_h3("Response Details")
    cli::cli_text("Action: {.field {result$action}}")
    cli::cli_text("Status: {.val {result$status}}")
    cli::cli_text("Reasoning: {.emph {result$reasoning}}")
    cli::cli_text("")
    cli::cli_h3("Input Parameters")
    cli::cli_code(jsonlite::toJSON(result$input, pretty = TRUE, auto_unbox = TRUE))
    cli::cli_text("")
    cli::cli_alert_success("You can now use {.run cassidy_agentic_task()}")
  }

  invisible(result)
}
