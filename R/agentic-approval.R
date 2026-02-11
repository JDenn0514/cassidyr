# ══════════════════════════════════════════════════════════════════════════════
# AGENTIC APPROVAL - User Approval for Risky Operations
# Interactive prompts for approving/denying/editing tool actions
# ══════════════════════════════════════════════════════════════════════════════

#' Request user approval for risky actions
#'
#' Displays an interactive prompt asking the user to approve, deny, edit, or
#' view details about a proposed tool action.
#'
#' @param action Character. Tool name
#' @param input List. Tool parameters
#' @param reasoning Character. Why agent wants to do this
#' @param callback Function. Optional custom approval handler
#'
#' @return List with approved (logical) and input (potentially edited)
#' @keywords internal
#' @noRd
.request_approval <- function(action, input, reasoning, callback = NULL) {

  # Use custom callback if provided
  if (!is.null(callback)) {
    return(callback(action, input, reasoning))
  }

  # Interactive approval prompt
  cli::cli_rule(left = "Agent Action Request")
  cli::cli_alert_warning("Action: {.field {action}}")
  cli::cli_text("Reasoning: {.emph {reasoning}}")
  cli::cli_h3("Parameters:")
  cli::cli_code(jsonlite::toJSON(input, pretty = TRUE, auto_unbox = TRUE))
  cli::cli_text("")

  # Get user response
  response <- readline(
    prompt = paste0(
      cli::col_cyan("\u276f Approve? [y/n/e(dit)/v(iew)]: ")
    )
  )
  response <- tolower(trimws(response))

  if (response == "n" || response == "no") {
    cli::cli_alert_danger("Action denied")
    return(list(approved = FALSE, input = input))
  }

  if (response == "v" || response == "view") {
    # Show more details
    .show_tool_details(action, input)
    cli::cli_text("")
    # Ask again after showing details
    return(.request_approval(action, input, reasoning, callback))
  }

  if (response == "e" || response == "edit") {
    # Interactive parameter editing
    edited_input <- .edit_tool_input(action, input)
    cli::cli_alert_success("Parameters updated")
    return(list(approved = TRUE, input = edited_input))
  }

  # Default: approve (y, yes, or Enter)
  cli::cli_alert_success("Action approved")
  list(approved = TRUE, input = input)
}

#' Edit tool input interactively
#'
#' Allows user to modify tool parameters by entering new JSON or
#' keeping the current values.
#'
#' @param action Character. Tool name
#' @param input List. Current tool parameters
#'
#' @return List. Modified or original parameters
#' @keywords internal
#' @noRd
.edit_tool_input <- function(action, input) {
  cli::cli_h3("Edit parameters")
  cli::cli_text("Enter new JSON or press Enter to keep current values")
  cli::cli_text("")
  cli::cli_text("Current:")
  cli::cli_code(jsonlite::toJSON(input, pretty = TRUE, auto_unbox = TRUE))
  cli::cli_text("")

  # Get edited JSON
  edited_json <- readline("New JSON: ")

  if (!nzchar(trimws(edited_json))) {
    return(input)  # Keep original
  }

  # Parse and validate
  tryCatch({
    new_input <- jsonlite::fromJSON(edited_json, simplifyVector = FALSE)
    cli::cli_alert_success("JSON parsed successfully")
    new_input
  }, error = function(e) {
    cli::cli_alert_danger("Invalid JSON: {e$message}")
    cli::cli_text("Try again or press Enter to keep current values")
    .edit_tool_input(action, input)  # Try again
  })
}

#' Show detailed tool information
#'
#' Displays comprehensive information about a tool including description,
#' risk level, and parameter details.
#'
#' @param action Character. Tool name
#' @param input List. Current tool parameters
#'
#' @keywords internal
#' @noRd
.show_tool_details <- function(action, input) {
  tool <- .cassidy_tools[[action]]

  if (is.null(tool)) {
    cli::cli_alert_warning("Tool not found: {action}")
    return(invisible(NULL))
  }

  cli::cli_h3("Tool Details: {action}")
  cli::cli_text("Description: {.emph {tool$description}}")
  cli::cli_text("Risky: {.val {tool$risky %||% FALSE}}")

  cli::cli_h3("Parameters:")
  if (!is.null(tool$parameters) && length(tool$parameters) > 0) {
    for (param_name in names(tool$parameters)) {
      param_desc <- tool$parameters[[param_name]]
      cli::cli_li("{.field {param_name}}: {param_desc}")
    }
  } else {
    cli::cli_text("  {.emph No parameters}")
  }

  cli::cli_h3("Current Input:")
  if (length(input) > 0) {
    cli::cli_code(jsonlite::toJSON(input, pretty = TRUE, auto_unbox = TRUE))
  } else {
    cli::cli_text("  {.emph No input provided}")
  }

  invisible(NULL)
}
