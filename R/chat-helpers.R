#' Write Cassidy code to file and show explanation in console
#'
#' Extracts code blocks from a Cassidy response and writes them to a file,
#' while displaying the explanatory text (non-code parts) in the console.
#' This allows you to see what was done while the actual code is saved to disk.
#'
#' @param x A `cassidy_chat` or `cassidy_response` object.
#' @param path Character. File path where to save the code.
#' @param open Logical. Open file after writing (default: TRUE in interactive).
#' @param append Logical. Append to existing file (default: FALSE).
#' @param show_explanation Logical. Show explanatory text in console (default: TRUE).
#'
#' @return Invisibly returns the file path.
#'
#' @family chat-functions
#' @export
#'
#' @examples
#' \dontrun{
#' # Ask Cassidy to write code
#' result <- cassidy_chat(
#'   "Write the cassidy_app() function with UI and server logic",
#'   context = ctx
#' )
#'
#' # Code goes to file, explanation to console
#' cassidy_write_code(result, "R/chat-ui.R")
#'
#' # Quiet mode - no explanation shown
#' cassidy_write_code(result, "R/chat-ui.R", show_explanation = FALSE)
#' }
cassidy_write_code <- function(
  x,
  path,
  open = interactive(),
  append = FALSE,
  show_explanation = TRUE
) {
  # Extract full content
  full_content <- if (inherits(x, "cassidy_chat")) {
    x$response$content
  } else if (inherits(x, "cassidy_response")) {
    x$content
  } else if (is.character(x)) {
    x
  } else {
    cli::cli_abort(c(
      "x must be a cassidy_chat, cassidy_response, or character",
      "x" = "Got {.cls {class(x)}}"
    ))
  }

  # Separate code and explanation
  separated <- .separate_code_and_text(full_content)

  # Create directory if needed
  dir_path <- dirname(path)
  if (!dir.exists(dir_path) && dir_path != ".") {
    dir.create(dir_path, recursive = TRUE, showWarnings = FALSE)
    cli::cli_alert_info("Created directory {.path {dir_path}}")
  }

  # Check if file exists and warn
  if (file.exists(path) && !append) {
    cli::cli_alert_warning("Overwriting existing file {.path {path}}")
  }

  # Write code to file
  if (length(separated$code) == 0) {
    cli::cli_alert_warning("No code blocks found in response")
    # Fall back to writing full content
    writeLines(full_content, path)
  } else {
    code_content <- paste(separated$code, collapse = "\n\n")

    if (append) {
      cat("\n\n", file = path, append = TRUE)
      cat(code_content, file = path, append = TRUE)
      cli::cli_alert_success("Appended code to {.path {path}}")
    } else {
      writeLines(code_content, path)
      cli::cli_alert_success("Wrote code to {.path {path}}")
    }
  }

  # Show explanation in console
  if (show_explanation && length(separated$explanation) > 0) {
    cli::cli_rule(left = "Explanation")
    cat(paste(separated$explanation, collapse = "\n\n"))
    cat("\n")
    cli::cli_rule()
  }

  # Open file in editor if requested
  if (open) {
    .open_file(path)
  }

  invisible(path)
}


#' Write Cassidy response to a file
#'
#' Saves the full response from a Cassidy chat to a file without any
#' processing. Use `cassidy_write_code()` to separate code from explanations.
#'
#' @param x A `cassidy_chat` or `cassidy_response` object.
#' @param path Character. File path where to save the response.
#' @param open Logical. Whether to open the file after writing (default: TRUE
#'   in interactive sessions).
#' @param append Logical. Whether to append to existing file (default: FALSE).
#'
#' @return Invisibly returns the file path.
#'
#' @family chat-functions
#' @export
#'
#' @examples
#' \dontrun{
#' result <- cassidy_chat("Write documentation for this function", context = ctx)
#'
#' # Save full response (no separation)
#' cassidy_write_file(result, "notes/function-docs.md")
#' }
cassidy_write_file <- function(x, path, open = interactive(), append = FALSE) {
  # Extract content
  content <- if (inherits(x, "cassidy_chat")) {
    x$response$content
  } else if (inherits(x, "cassidy_response")) {
    x$content
  } else if (is.character(x)) {
    x
  } else {
    cli::cli_abort(c(
      "x must be a cassidy_chat, cassidy_response, or character",
      "x" = "Got {.cls {class(x)}}"
    ))
  }

  # Create directory if needed
  dir_path <- dirname(path)
  if (!dir.exists(dir_path) && dir_path != ".") {
    dir.create(dir_path, recursive = TRUE, showWarnings = FALSE)
    cli::cli_alert_info("Created directory {.path {dir_path}}")
  }

  # Check if file exists and warn
  if (file.exists(path) && !append) {
    cli::cli_alert_warning("Overwriting existing file {.path {path}}")
  }

  # Write to file
  if (append) {
    cat("\n\n", file = path, append = TRUE)
    cat(content, file = path, append = TRUE)
    cli::cli_alert_success("Appended to {.path {path}}")
  } else {
    writeLines(content, path)
    cli::cli_alert_success("Wrote to {.path {path}}")
  }

  # Open file in editor if requested
  if (open) {
    .open_file(path)
  }

  invisible(path)
}

#' Separate code blocks from explanatory text
#'
#' Internal helper to parse a response and separate code blocks from
#' explanatory text.
#'
#' @param content Character. Full response content.
#' @return List with 'code' and 'explanation' elements.
#' @keywords internal
#' @noRd
.separate_code_and_text <- function(content) {
  lines <- strsplit(content, "\n")[[1]]

  code_blocks <- character()
  explanation_blocks <- character()

  in_code_block <- FALSE
  current_code <- character()
  current_text <- character()

  for (line in lines) {
    # Start or end of code block
    if (grepl("^```", line)) {
      if (!in_code_block) {
        # Starting code block - save any accumulated text
        in_code_block <- TRUE
        if (length(current_text) > 0) {
          explanation_blocks <- c(
            explanation_blocks,
            paste(trimws(current_text), collapse = "\n")
          )
          current_text <- character()
        }
        current_code <- character()
      } else {
        # Ending code block - save the code
        in_code_block <- FALSE
        if (length(current_code) > 0) {
          code_blocks <- c(code_blocks, paste(current_code, collapse = "\n"))
        }
        current_code <- character()
      }
    } else if (in_code_block) {
      # Inside code block
      current_code <- c(current_code, line)
    } else {
      # Outside code block (explanation text)
      current_text <- c(current_text, line)
    }
  }

  # Save any remaining text
  if (length(current_text) > 0) {
    explanation_blocks <- c(
      explanation_blocks,
      paste(trimws(current_text), collapse = "\n")
    )
  }

  # Clean up explanation blocks (remove empty ones)
  explanation_blocks <- explanation_blocks[
    nchar(trimws(explanation_blocks)) > 0
  ]

  list(
    code = code_blocks,
    explanation = explanation_blocks
  )
}
