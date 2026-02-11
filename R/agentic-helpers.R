# ══════════════════════════════════════════════════════════════════════════════
# AGENTIC HELPERS - Utility Functions for Agentic Workflows
# Helper functions to work with tools and common patterns
# ══════════════════════════════════════════════════════════════════════════════

#' List Available Agentic Tools
#'
#' Shows all available tools that can be used with `cassidy_agentic_task()`.
#' Displays tool names, descriptions, and whether they require approval in
#' safe mode.
#'
#' @return Invisibly returns a character vector of tool names
#' @export
#'
#' @examples
#' \dontrun{
#' # See all available tools
#' cassidy_list_tools()
#'
#' # Get tool names programmatically
#' tools <- cassidy_list_tools()
#'
#' # Use specific tools
#' cassidy_agentic_task(
#'   "Analyze code",
#'   tools = tools[!grepl("write|execute", tools)]  # Read-only
#' )
#' }
cassidy_list_tools <- function() {
  all_tools <- names(.cassidy_tools)

  cli::cli_h2("Available Agentic Tools ({length(all_tools)})")
  cli::cli_text("")

  for (tool in all_tools) {
    tool_info <- .cassidy_tools[[tool]]
    risky <- tool_info$risky %||% FALSE

    if (risky) {
      cli::cli_alert_warning("{.field {tool}}: {tool_info$description}")
      cli::cli_text("  {cli::col_silver('Requires approval in safe mode')}")
    } else {
      cli::cli_alert_success("{.field {tool}}: {tool_info$description}")
    }
  }

  cli::cli_text("")
  cli::cli_alert_info(paste(
    "Default: All tools available unless you specify {.arg tools} argument"
  ))
  cli::cli_text("")

  invisible(all_tools)
}

#' Get Tool Presets for Common Tasks
#'
#' Returns predefined sets of tools for common agentic task patterns.
#'
#' @param preset Character. One of:
#'   - `"read_only"` - Safe exploration (no writes or code execution)
#'   - `"code_analysis"` - Analyze code structure
#'   - `"data_analysis"` - Work with data frames
#'   - `"code_generation"` - Create/modify code files
#'   - `"all"` - All tools (default)
#'
#' @return Character vector of tool names
#' @export
#'
#' @examples
#' \dontrun{
#' # Use read-only preset
#' cassidy_agentic_task(
#'   "Analyze my code structure",
#'   tools = cassidy_tool_preset("read_only")
#' )
#'
#' # Use data analysis preset
#' cassidy_agentic_task(
#'   "Summarize the mtcars dataset",
#'   tools = cassidy_tool_preset("data_analysis")
#' )
#' }
cassidy_tool_preset <- function(preset = c("all", "read_only", "code_analysis",
                                           "data_analysis", "code_generation")) {
  preset <- match.arg(preset)

  presets <- list(
    all = names(.cassidy_tools),

    read_only = c(
      "read_file",
      "list_files",
      "search_files",
      "get_context",
      "describe_data"
    ),

    code_analysis = c(
      "read_file",
      "list_files",
      "search_files",
      "get_context"
    ),

    data_analysis = c(
      "describe_data",
      "execute_code",
      "get_context"
    ),

    code_generation = c(
      "read_file",
      "list_files",
      "write_file",
      "get_context"
    )
  )

  tools <- presets[[preset]]

  if (preset != "all") {
    cli::cli_alert_info("Using {.strong {preset}} preset with {length(tools)} tools")
  }

  tools
}
