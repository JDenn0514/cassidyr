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

#' Setup Tool Decision Workflow (DEPRECATED)
#'
#' This function is deprecated. The agentic system now uses direct parsing
#' instead of workflows, so no workflow setup is needed.
#'
#' @details
#' **NOTE:** As of the latest version, `cassidy_agentic_task()` uses direct
#' parsing of assistant responses instead of requiring a separate workflow.
#' This function is kept for backward compatibility but is no longer needed.
#'
#' The new approach:
#' - Simpler setup (no workflow configuration needed)
#' - More reliable (no webhook dependencies)
#' - Easier to debug (everything happens in R)
#'
#' Simply use `cassidy_agentic_task()` directly - it will work out of the box!
#'
#' @export
#'
#' @examples
#' \dontrun{
#' # No setup needed! Just use:
#' cassidy_agentic_task("List all R files")
#' }
cassidy_setup_workflow <- function() {
  cli::cli_h1("Workflow Setup (DEPRECATED)")

  cli::cli_alert_warning("This function is deprecated and no longer needed!")
  cli::cli_text("")
  cli::cli_text(
    "The agentic system now uses {.strong direct parsing} instead of workflows."
  )
  cli::cli_text("")

  cli::cli_h2("Good News!")
  cli::cli_ul(c(
    "No workflow setup required",
    "No webhook configuration needed",
    "Works out of the box with just {.envvar CASSIDY_ASSISTANT_ID} and {.envvar CASSIDY_API_KEY}",
    "More reliable and easier to debug"
  ))
  cli::cli_text("")

  cli::cli_h2("Just Use It!")
  cli::cli_code('
# That\'s it! No workflow setup needed.
result <- cassidy_agentic_task("List all R files in this directory")
  ')
  cli::cli_text("")

  return(invisible(NULL))

  # Old instructions below (kept for reference)
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
You are a tool selection expert for an R programming assistant in an agentic workflow.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⚠️  CRITICAL: ONLY USE ALLOWED TOOLS ⚠️

You MUST choose EXACTLY ONE tool from this list (exact spelling):

{{available_tools}}

Any other tool name is INVALID and will fail.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## Assistant Reasoning
{{reasoning}}

## Context
{{context}}

INSTRUCTIONS:
1. Read the assistant reasoning above to understand what they want to do
2. Choose EXACTLY ONE tool from the ALLOWED TOOLS list (spelling must match exactly)
3. In the "action" field, enter ONLY the tool name (e.g., "list_files")
4. In the "input" field, provide the exact parameters needed as an object
5. In the "reasoning" field, explain why you chose this tool
6. Set "status":
   - "continue" = A tool needs to be executed (default - use this most of the time)
   - "final" = The assistant has explicitly confirmed the task is complete with "TASK COMPLETE" after receiving results

IMPORTANT RULES:
- The "action" field must contain ONLY the tool name from the allowed list
- Only set status to "final" if the assistant says "TASK COMPLETE" AND has already received and confirmed results
- If the assistant is planning to do something or requesting a tool, set status to "continue"
  ')
  cli::cli_text("")

  # Structured output
  cli::cli_h2("3. Structured Output Fields")
  cli::cli_text("Configure these output fields (exact names required):")
  cli::cli_text("")

  cli::cli_dl(c(
    "action" = "Text (Required): Tool name from available tools (e.g., 'list_files')",
    "input" = "Object: Tool parameters as key-value pairs",
    "reasoning" = "Text (Required): Why this action was chosen",
    "status" = "Dropdown: continue, final"
  ))
  cli::cli_text("")

  cli::cli_alert_warning(paste(
    "Note: Use {.strong Text} for action field, not Dropdown.",
    "This allows dynamic tool filtering based on available_tools."
  ))

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
