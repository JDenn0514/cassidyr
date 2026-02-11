# ══════════════════════════════════════════════════════════════════════════════
# AGENTIC PARSING - Direct Tool Decision Parsing
# Parses assistant responses to extract tool decisions (no workflow needed)
# ══════════════════════════════════════════════════════════════════════════════

#' Parse Tool Decision from Assistant Response
#'
#' Parses structured text from the assistant to extract tool decisions.
#' Expected format:
#'   <TOOL_DECISION>
#'   ACTION: tool_name
#'   INPUT: {"param": "value"}
#'   REASONING: explanation
#'   STATUS: continue|final
#'   </TOOL_DECISION>
#'
#' @param response Character. The assistant's full response
#' @param available_tools Character vector. Tools the agent can use
#'
#' @return List with action, input, reasoning, status
#' @keywords internal
#' @noRd
.parse_tool_decision <- function(response, available_tools) {

  # Debug output
  if (getOption("cassidy.debug", FALSE)) {
    cli::cli_h3("Parsing Response")
    cli::cli_text("Length: {nchar(response)} chars")
    cli::cli_text("Preview: {substr(response, 1, 200)}...")
  }

  # Check if response indicates completion (simplified pattern)
  if (grepl("TASK\\s+COMPLETE|TASK_COMPLETE|TASK COMPLETE", response, ignore.case = TRUE)) {
    if (getOption("cassidy.debug", FALSE)) {
      cli::cli_alert_info("Detected TASK COMPLETE")
    }
    # Extract completion message (everything after TASK COMPLETE:)
    completion_msg <- sub("^.*?TASK[\\s_]+COMPLETE[:\\s]*", "", response, ignore.case = TRUE, perl = TRUE)

    # Clean up the message
    completion_msg <- trimws(completion_msg)
    if (!nzchar(completion_msg)) {
      completion_msg <- "Task completed successfully"
    }

    return(list(
      action = NULL,
      input = list(),
      reasoning = completion_msg,
      status = "final"
    ))
  }

  # Try to extract structured tool decision (use [\s\S] to match newlines)
  tool_decision_pattern <- "<TOOL_DECISION>([\\s\\S]+?)</TOOL_DECISION>"
  tool_match <- regmatches(response, regexpr(tool_decision_pattern, response, perl = TRUE))

  if (length(tool_match) == 0) {
    if (getOption("cassidy.debug", FALSE)) {
      cli::cli_alert_warning("No <TOOL_DECISION> tags found, using fallback parser")
    }
    # No structured decision found - try to infer from response
    return(.infer_tool_decision(response, available_tools))
  }

  if (getOption("cassidy.debug", FALSE)) {
    cli::cli_alert_success("Found <TOOL_DECISION> block")
  }

  # Extract the content between tags
  content <- gsub("</?TOOL_DECISION>", "", tool_match)

  # Parse fields
  action <- .extract_field(content, "ACTION")
  input_json <- .extract_field(content, "INPUT")
  reasoning <- .extract_field(content, "REASONING")
  status <- .extract_field(content, "STATUS")

  # Parse INPUT JSON
  input <- tryCatch({
    if (nzchar(input_json)) {
      jsonlite::fromJSON(input_json, simplifyVector = FALSE)
    } else {
      list()
    }
  }, error = function(e) {
    cli::cli_warn("Failed to parse INPUT JSON, using empty list")
    list()
  })

  # Validate status
  if (!status %in% c("continue", "final")) {
    status <- "continue"
  }

  list(
    action = action,
    input = input,
    reasoning = reasoning,
    status = status
  )
}

#' Extract field from structured text
#'
#' @param text Character. Text to search
#' @param field Character. Field name
#'
#' @return Character. Field value
#' @keywords internal
#' @noRd
.extract_field <- function(text, field) {
  pattern <- paste0(field, ":\\s*(.+?)(?=\n[A-Z]+:|$)")
  match <- regmatches(text, regexpr(pattern, text, perl = TRUE))

  if (length(match) == 0) {
    return("")
  }

  # Remove field name and clean up
  value <- gsub(paste0("^", field, ":\\s*"), "", match)
  trimws(value)
}

#' Infer tool decision from unstructured response
#'
#' Fallback parser for when assistant doesn't use structured format.
#'
#' @param response Character. Assistant response
#' @param available_tools Character vector. Available tools
#'
#' @return List with action, input, reasoning, status
#' @keywords internal
#' @noRd
.infer_tool_decision <- function(response, available_tools) {

  # Look for tool names mentioned in response
  mentioned_tools <- available_tools[sapply(available_tools, function(tool) {
    grepl(tool, response, fixed = TRUE)
  })]

  if (length(mentioned_tools) == 0) {
    # No tool mentioned - ask for clarification
    return(list(
      action = NULL,
      input = list(),
      reasoning = "No tool decision found in response. Please use <TOOL_DECISION> format.",
      status = "continue"
    ))
  }

  # Use first mentioned tool
  tool <- mentioned_tools[1]

  # Try to extract parameters (very basic)
  input <- list()

  # Common parameter patterns
  if (grepl("filepath|file|path", response, ignore.case = TRUE)) {
    path_match <- regmatches(
      response,
      regexpr("['\"]([^'\"]+\\.[a-zA-Z]+)['\"]", response, perl = TRUE)
    )
    if (length(path_match) > 0) {
      input$filepath <- gsub("['\"]", "", path_match)
    }
  }

  list(
    action = tool,
    input = input,
    reasoning = paste("Inferred tool from response:", tool),
    status = "continue"
  )
}

