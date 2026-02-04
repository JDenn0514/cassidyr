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

#' Detect downloadable files in message content
#'
#' Scans a message for code blocks that represent downloadable files
#' (markdown, Quarto, R Markdown). Extracts content and metadata.
#'
#' @param content Character. Raw message content from assistant.
#' @return List of detected files, each with: content, extension, filename.
#'   Returns empty list if no downloadable files found.
#'
#' @keywords internal
.detect_downloadable_files <- function(content) {
  if (is.null(content) || !nzchar(content)) {
    return(list())
  }

  files <- list()
  lines <- strsplit(content, "\n", fixed = TRUE)[[1]]

  i <- 1
  while (i <= length(lines)) {
    line <- lines[i]

    # Check for opening fence with target language
    if (grepl("^```(md|markdown|qmd|rmd)\\s*$", line, ignore.case = TRUE)) {
      lang <- tolower(sub("^```", "", trimws(line)))

      extension <- switch(
        lang,
        "md" = ".md",
        "markdown" = ".md",
        "qmd" = ".qmd",
        "rmd" = ".Rmd",
        ".md"
      )

      # Find closing fence, accounting for nested code blocks
      start_line <- i + 1
      end_line <- NULL
      j <- start_line
      nesting <- 0

      while (j <= length(lines)) {
        current_line <- lines[j]

        # Check for nested code block opening (has language identifier)
        if (grepl("^```[a-zA-Z]", current_line)) {
          nesting <- nesting + 1
        } else if (grepl("^```\\s*$", current_line)) {
          # Bare ``` - either closes nested block or closes our main block
          if (nesting > 0) {
            nesting <- nesting - 1
          } else {
            end_line <- j - 1
            break
          }
        }
        j <- j + 1
      }

      if (!is.null(end_line) && end_line >= start_line) {
        file_content <- paste(lines[start_line:end_line], collapse = "\n")
        filename <- .extract_filename_from_content(file_content, extension)

        files <- c(
          files,
          list(list(
            content = file_content,
            extension = extension,
            filename = filename
          ))
        )

        i <- j + 1
        next
      }
    }
    i <- i + 1
  }

  files
}


#' Extract filename from file content
#'
#' Attempts to detect a filename from YAML front matter title field.
#' Falls back to "untitled" with appropriate extension.
#'
#' @param content Character. File content.
#' @param extension Character. File extension (e.g., ".md").
#' @return Character. Detected or default filename.
#'
#' @keywords internal

.extract_filename_from_content <- function(content, extension) {
  # Check for YAML front matter
  if (!grepl("^---\\s*$", strsplit(content, "\n", fixed = TRUE)[[1]][1])) {
    return(paste0("untitled", extension))
  }

  # Extract lines
  lines <- strsplit(content, "\n", fixed = TRUE)[[1]]

  # Find closing ---
  yaml_end <- NULL
  for (i in 2:length(lines)) {
    if (grepl("^---\\s*$", lines[i])) {
      yaml_end <- i
      break
    }
  }

  if (is.null(yaml_end)) {
    return(paste0("untitled", extension))
  }

  # Look for title line in YAML
  yaml_lines <- lines[2:(yaml_end - 1)]
  title_line <- grep("^title:", yaml_lines, value = TRUE)

  if (length(title_line) == 0) {
    return(paste0("untitled", extension))
  }

  # Extract title value
  title <- sub("^title:\\s*", "", title_line[1])
  # Remove surrounding quotes if present
  title <- gsub("^[\"']|[\"']$", "", title)
  title <- trimws(title)

  if (!nzchar(title)) {
    return(paste0("untitled", extension))
  }

  safe_title <- .sanitize_filename(title)
  paste0(safe_title, extension)
}


#' Sanitize a string for use as a filename
#'
#' Removes or replaces characters that are invalid in filenames.
#'
#' @param x Character. String to sanitize.
#' @return Character. Safe filename string.
#'
#' @keywords internal
.sanitize_filename <- function(x) {
  # Replace spaces with underscores
  x <- gsub("\\s+", "_", x)
  # Remove invalid characters
  x <- gsub("[<>:\"/\\\\|?*]", "", x)
  # Remove leading/trailing underscores
  x <- gsub("^_+|_+$", "", x)
  # Limit length
  if (nchar(x) > 50) {
    x <- substr(x, 1, 50)
  }
  # Ensure not empty
  if (!nzchar(x)) {
    x <- "untitled"
  }
  x
}

#' Create HTML for file download link
#'
#' Generates an HTML download button/link for a file. Uses data URI
#' encoding to embed content directly in the href.
#'
#' @param content Character. File content to download.
#' @param filename Character. Suggested filename for download.
#' @param index Integer. Unique index for multiple downloads in same message.
#' @return Character. HTML string for download link.
#'
#' @keywords internal
.create_download_link_html <- function(content, filename, index = 1) {
  # Base64 encode the content for data URI
  encoded <- base64enc::base64encode(charToRaw(content))

  # Determine MIME type from extension
  ext <- tolower(tools::file_ext(filename))
  mime_type <- switch(
    ext,
    "md" = "text/markdown",
    "qmd" = "text/plain",
    "rmd" = "text/plain",
    "text/plain"
  )

  # Create data URI
  data_uri <- paste0("data:", mime_type, ";base64,", encoded)

  # Use shiny::icon() for proper rendering
  icon_html <- as.character(shiny::icon("download"))

  paste0(
    '<div class="file-download-container">',
    '<a href="',
    data_uri,
    '" ',
    'download="',
    htmltools::htmlEscape(filename),
    '" ',
    'class="btn btn-sm btn-outline-primary file-download-btn">',
    icon_html,
    ' Download ',
    htmltools::htmlEscape(filename),
    '</a>',
    '</div>'
  )
}


#' Pre-process markdown to handle nested code blocks
#'
#' Increases fence length for outer blocks containing inner fences,
#' so commonmark renders them correctly.
#'
#' @param content Character. Raw markdown content.
#' @return Character. Pre-processed content safe for commonmark.
#' @keywords internal
#' @noRd
.preprocess_nested_code_blocks <- function(content) {
  if (is.null(content) || !nzchar(content)) {
    return(content)
  }

  lines <- strsplit(content, "\n", fixed = TRUE)[[1]]
  result <- character()
  i <- 1

  while (i <= length(lines)) {
    line <- lines[i]

    # Check for opening code fence (``` or ~~~)
    if (grepl("^(`{3,}|~{3,})\\s*[a-zA-Z]*\\s*$", line)) {
      # Extract fence character and length
      fence_char <- substr(line, 1, 1)
      fence_match <- regexpr(paste0("^", fence_char, "+"), line)
      fence_len <- attr(fence_match, "match.length")
      fence <- substr(line, 1, fence_len)
      lang <- trimws(substr(line, fence_len + 1, nchar(line)))

      # Collect block content and find closing fence
      block_lines <- character()
      j <- i + 1
      has_nested <- FALSE
      closing_pattern <- paste0("^", fence_char, "{", fence_len, "}\\s*$")

      while (j <= length(lines)) {
        if (grepl(closing_pattern, lines[j])) {
          break
        }
        # Check for nested fence of same type
        if (grepl(paste0("^", fence_char, "{3,}"), lines[j])) {
          has_nested <- TRUE
        }
        block_lines <- c(block_lines, lines[j])
        j <- j + 1
      }

      if (has_nested) {
        # Find max nested fence length
        max_nested <- fence_len
        for (bl in block_lines) {
          if (grepl(paste0("^", fence_char, "{3,}"), bl)) {
            nested_match <- regexpr(paste0("^", fence_char, "+"), bl)
            nested_len <- attr(nested_match, "match.length")
            max_nested <- max(max_nested, nested_len)
          }
        }
        # Use longer fence (at least one more than max nested)
        new_fence <- paste(rep(fence_char, max_nested + 1), collapse = "")
        result <- c(result, paste0(new_fence, lang))
        result <- c(result, block_lines)
        result <- c(result, new_fence)
      } else {
        # No nesting - keep original
        result <- c(result, line)
        result <- c(result, block_lines)
        if (j <= length(lines)) {
          result <- c(result, lines[j])
        }
      }
      i <- j + 1
    } else {
      result <- c(result, line)
      i <- i + 1
    }
  }

  paste(result, collapse = "\n")
}
