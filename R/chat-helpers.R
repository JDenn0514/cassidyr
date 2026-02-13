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

        # FIXED: Check for nested code block opening
        # Matches: ```r, ```{r}, ```python, etc.
        if (grepl("^```\\{?[a-zA-Z]", current_line)) {
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

    # FIXED: Check for opening code fence with language (``` or ~~~)
    # Now matches: ```r, ```{r}, ```python, etc.
    if (grepl("^(`{3,}|~{3,})\\{?[a-zA-Z]", line)) {
      fence_char <- substr(line, 1, 1)
      fence_match <- regexpr(paste0("^", fence_char, "+"), line)
      fence_len <- attr(fence_match, "match.length")
      lang <- trimws(substr(line, fence_len + 1, nchar(line)))

      # Collect entire block using fence counting (pairs)
      block_lines <- character()
      j <- i + 1
      open_count <- 1 # We've seen one opening fence
      max_inner_fence <- 0

      while (j <= length(lines) && open_count > 0) {
        current_line <- lines[j]

        # Check for any fence of same character type
        if (grepl(paste0("^", fence_char, "{3,}"), current_line)) {
          inner_match <- regexpr(paste0("^", fence_char, "+"), current_line)
          inner_len <- attr(inner_match, "match.length")
          # FIXED: Now matches ```{r} style chunks
          has_lang <- grepl(
            paste0("^", fence_char, "+\\{?[a-zA-Z]"),
            current_line
          )

          if (has_lang) {
            # Opening fence
            open_count <- open_count + 1
            max_inner_fence <- max(max_inner_fence, inner_len)
            block_lines <- c(block_lines, current_line)
          } else {
            # Closing fence
            open_count <- open_count - 1
            if (open_count > 0) {
              # Inner closing fence - keep as-is
              block_lines <- c(block_lines, current_line)
            }
            # If open_count == 0, this is our outer closing fence (don't add)
          }
        } else {
          block_lines <- c(block_lines, current_line)
        }
        j <- j + 1
      }

      # Determine if we need longer outer fences
      if (max_inner_fence > 0) {
        new_fence_len <- max(fence_len, max_inner_fence + 1)
        new_fence <- paste(rep(fence_char, new_fence_len), collapse = "")
        result <- c(result, paste0(new_fence, lang))
        result <- c(result, block_lines)
        result <- c(result, new_fence)
      } else {
        # No inner fences - keep original
        result <- c(result, line)
        result <- c(result, block_lines)
        result <- c(result, paste(rep(fence_char, fence_len), collapse = ""))
      }
      i <- j
    } else {
      result <- c(result, line)
      i <- i + 1
    }
  }

  paste(result, collapse = "\n")
}


#' Extract file blocks and replace with placeholders
#'
#' Scans markdown for code blocks tagged as md/qmd/rmd files,
#' extracts them, and replaces with unique placeholders to prevent
#' them from being rendered as HTML.
#'
#' @param content Character. Raw markdown content
#' @return List with:
#'   - processed_content: Content with placeholders
#'   - files: List of extracted file info (content, extension, filename, placeholder_id)
#' @keywords internal
#' @noRd
.extract_and_replace_file_blocks <- function(content) {
  if (is.null(content) || !nzchar(content)) {
    return(list(
      processed_content = content,
      files = list()
    ))
  }

  files <- list()
  processed_content <- content
  lines <- strsplit(content, "\n", fixed = TRUE)[[1]]

  i <- 1
  file_count <- 0

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

        # Check for nested code block opening
        if (grepl("^```\\{?[a-zA-Z]", current_line)) {
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

        # Generate unique placeholder (use format that won't be interpreted as markdown)
        file_count <- file_count + 1
        placeholder_id <- paste0("{{CASSIDY_FILE_BLOCK_", file_count, "}}")

        # Store file info
        files <- c(
          files,
          list(list(
            content = file_content,
            extension = extension,
            filename = filename,
            placeholder_id = placeholder_id
          ))
        )

        # Replace entire code block with placeholder
        # Build the full block to replace (from opening fence to closing fence)
        block_start <- i
        block_end <- j
        block_text <- paste(lines[block_start:block_end], collapse = "\n")

        # Replace in processed content
        processed_content <- sub(
          block_text,
          placeholder_id,
          processed_content,
          fixed = TRUE
        )

        i <- j + 1
        next
      }
    }
    i <- i + 1
  }

  list(
    processed_content = processed_content,
    files = files
  )
}


#' Create styled HTML block for file content
#'
#' Renders file as:
#' - Header bar with filename + download button
#' - Raw code block (NOT rendered markdown)
#' - Copy button for code
#'
#' @param content Character. File content
#' @param filename Character. Filename for display
#' @param extension Character. File extension (.md, .qmd, .Rmd)
#' @return Character. HTML string
#' @keywords internal
#' @noRd
.create_file_display_block <- function(content, filename, extension) {
  # Use base64enc if available for download link
  has_base64 <- rlang::is_installed("base64enc")

  # Escape content for HTML display
  escaped_content <- htmltools::htmlEscape(content)

  # Create download button HTML
  download_btn <- ""
  if (has_base64 && rlang::is_installed("htmltools")) {
    encoded <- base64enc::base64encode(charToRaw(content))

    mime_type <- switch(
      tolower(tools::file_ext(filename)),
      "md" = "text/markdown",
      "qmd" = "text/plain",
      "rmd" = "text/plain",
      "text/plain"
    )

    data_uri <- paste0("data:", mime_type, ";base64,", encoded)

    download_btn <- paste0(
      '<a href="',
      data_uri,
      '" download="',
      htmltools::htmlEscape(filename),
      '" class="download-file-btn btn btn-sm btn-outline-primary">',
      as.character(shiny::icon("download")),
      ' Download</a>'
    )
  }

  # Determine file icon based on extension
  file_icon <- switch(
    extension,
    ".md" = "\U0001F4C4",      # Document emoji (raw encoding)
    ".qmd" = "\U0001F4CA",     # Bar chart emoji (for data doc)
    ".Rmd" = "\U0001F4C8",     # Chart emoji
    "\U0001F4C4"               # Default document
  )

  # Build HTML structure
  paste0(
    '<div class="cassidy-file-block">',
    '<div class="file-header">',
    '<span class="file-icon">', file_icon, '</span>',
    '<span class="file-name">', htmltools::htmlEscape(filename), '</span>',
    '<div class="file-actions">',
    '<button class="copy-file-btn btn btn-sm btn-outline-secondary" ',
    'onclick="copyFileContent(this)">',
    as.character(shiny::icon("copy")),
    ' Copy</button>',
    download_btn,
    '</div>',
    '</div>',
    '<pre class="file-content"><code>',
    escaped_content,
    '</code></pre>',
    '</div>'
  )
}


#' Render message preserving file blocks as raw code
#'
#' Two-pass rendering:
#' 1. Extract file blocks -> placeholders
#' 2. Render markdown (placeholders preserved)
#' 3. Replace placeholders with styled code blocks + download buttons
#'
#' @param content Character. Raw markdown message
#' @return Character. HTML with proper file rendering
#' @keywords internal
#' @noRd
.render_message_with_file_blocks <- function(content) {
  # Pass 1: Extract files
  extracted <- .extract_and_replace_file_blocks(content)

  # Pass 2: Render markdown (without files)
  rendered_html <- commonmark::markdown_html(
    .preprocess_nested_code_blocks(extracted$processed_content)
  )

  # Pass 3: Replace placeholders with styled file blocks
  for (file_info in extracted$files) {
    file_html <- .create_file_display_block(
      content = file_info$content,
      filename = file_info$filename,
      extension = file_info$extension
    )

    # Try various forms that markdown might have wrapped it in
    patterns <- c(
      paste0("<p>", file_info$placeholder_id, "</p>"),  # Normal paragraph
      paste0("<p>", htmltools::htmlEscape(file_info$placeholder_id), "</p>"),  # Escaped
      file_info$placeholder_id,  # Raw placeholder
      htmltools::htmlEscape(file_info$placeholder_id)  # Escaped placeholder
    )

    for (pattern in patterns) {
      if (grepl(pattern, rendered_html, fixed = TRUE)) {
        rendered_html <- gsub(
          pattern,
          file_html,
          rendered_html,
          fixed = TRUE
        )
        break  # Stop after first successful replacement
      }
    }
  }

  rendered_html
}
