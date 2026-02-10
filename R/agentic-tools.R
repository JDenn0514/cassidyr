# ══════════════════════════════════════════════════════════════════════════════
# AGENTIC TOOLS - Tool Registry and Execution
# Defines available tools for agentic workflow and handles execution
# ══════════════════════════════════════════════════════════════════════════════

#' Tool Registry
#'
#' Internal list defining all available tools for agentic workflows.
#' Each tool has a description, risk flag, and handler function.
#'
#' @keywords internal
#' @noRd
.cassidy_tools <- list(
  read_file = list(
    description = "Read contents of a file",
    risky = FALSE,
    parameters = list(
      filepath = "Path to the file to read",
      working_dir = "Working directory (optional)"
    ),
    handler = function(filepath, working_dir = getwd()) {
      full_path <- if (dirname(filepath) == ".") {
        file.path(working_dir, filepath)
      } else {
        filepath
      }

      if (!file.exists(full_path)) {
        stop(paste("File not found:", full_path))
      }

      # Use cassidy_describe_file for R files
      if (grepl("\\.R$|\\.r$", full_path, ignore.case = TRUE)) {
        tryCatch({
          result <- cassidy_describe_file(full_path, level = "standard")
          result$text
        }, error = function(e) {
          # Fallback to plain text
          paste(readLines(full_path, warn = FALSE), collapse = "\n")
        })
      } else {
        # Plain text for other files
        paste(readLines(full_path, warn = FALSE), collapse = "\n")
      }
    }
  ),

  write_file = list(
    description = "Write content to a file",
    risky = TRUE,  # Requires approval
    parameters = list(
      filepath = "Path to the file to write",
      content = "Content to write",
      working_dir = "Working directory (optional)"
    ),
    handler = function(filepath, content, working_dir = getwd()) {
      full_path <- if (dirname(filepath) == ".") {
        file.path(working_dir, filepath)
      } else {
        filepath
      }

      # Create directory if needed
      dir_path <- dirname(full_path)
      if (!dir.exists(dir_path)) {
        dir.create(dir_path, recursive = TRUE)
      }

      writeLines(content, full_path)
      paste("File written successfully:", full_path)
    }
  ),

  execute_code = list(
    description = "Execute R code in a safe environment",
    risky = TRUE,  # Requires approval
    parameters = list(
      code = "R code to execute"
    ),
    handler = function(code) {
      # Create temporary environment for execution
      temp_env <- new.env(parent = .GlobalEnv)

      result <- tryCatch({
        # Capture output and result
        output <- capture.output({
          result <- eval(parse(text = code), envir = temp_env)
        })

        list(
          result = result,
          output = output
        )
      }, error = function(e) {
        stop(paste("Code execution error:", e$message))
      })

      # Format result
      if (length(result$output) > 0) {
        paste(c(
          "Output:",
          result$output,
          "\nResult:",
          capture.output(print(result$result))
        ), collapse = "\n")
      } else {
        paste(capture.output(print(result$result)), collapse = "\n")
      }
    }
  ),

  list_files = list(
    description = "List files in a directory",
    risky = FALSE,
    parameters = list(
      directory = "Directory to list (default: current)",
      pattern = "Optional file pattern to match"
    ),
    handler = function(directory = ".", pattern = NULL) {
      if (!dir.exists(directory)) {
        stop(paste("Directory not found:", directory))
      }

      files <- list.files(
        directory,
        pattern = pattern,
        recursive = TRUE,
        full.names = FALSE
      )

      if (length(files) == 0) {
        "No files found"
      } else {
        paste(files, collapse = "\n")
      }
    }
  ),

  search_files = list(
    description = "Search for text in files",
    risky = FALSE,
    parameters = list(
      pattern = "Text pattern to search for",
      directory = "Directory to search (default: current)",
      file_pattern = "Optional file pattern to limit search"
    ),
    handler = function(pattern, directory = ".", file_pattern = NULL) {
      if (!dir.exists(directory)) {
        stop(paste("Directory not found:", directory))
      }

      # Get files to search
      files <- list.files(
        directory,
        pattern = file_pattern,
        recursive = TRUE,
        full.names = TRUE
      )

      if (length(files) == 0) {
        return("No files to search")
      }

      # Search files
      matches <- list()
      for (file in files) {
        tryCatch({
          lines <- readLines(file, warn = FALSE)
          matching_lines <- grep(pattern, lines, value = TRUE)
          if (length(matching_lines) > 0) {
            matches[[file]] <- matching_lines
          }
        }, error = function(e) {
          # Skip files that can't be read
        })
      }

      if (length(matches) == 0) {
        "No matches found"
      } else {
        # Format results
        result <- lapply(names(matches), function(file) {
          paste(c(
            paste0("File: ", file),
            paste0("  ", matches[[file]])
          ), collapse = "\n")
        })
        paste(result, collapse = "\n\n")
      }
    }
  ),

  get_context = list(
    description = "Get project context information",
    risky = FALSE,
    parameters = list(
      level = "Context level: 'minimal', 'standard', or 'comprehensive'"
    ),
    handler = function(level = "standard") {
      ctx <- cassidy_context_project(level = level)
      ctx$text
    }
  ),

  describe_data = list(
    description = "Describe a data frame in the environment",
    risky = FALSE,
    parameters = list(
      name = "Name of the data frame",
      method = "Description method: 'basic', 'skim', or 'codebook'"
    ),
    handler = function(name, method = "basic") {
      # Check if object exists
      if (!exists(name, envir = .GlobalEnv)) {
        stop(paste("Object not found:", name))
      }

      obj <- get(name, envir = .GlobalEnv)

      # Check if it's a data frame
      if (!is.data.frame(obj)) {
        stop(paste("Object is not a data frame:", name))
      }

      result <- cassidy_describe_df(obj, method = method)
      result$text
    }
  )
)

#' Execute a tool with error handling
#'
#' @param tool_name Character. Name of the tool to execute
#' @param input List. Parameters for the tool
#' @param working_dir Character. Working directory for file operations
#'
#' @return List with success flag, result or error message
#' @keywords internal
#' @noRd
.execute_tool <- function(tool_name, input, working_dir = getwd()) {
  # Validate tool exists
  if (!tool_name %in% names(.cassidy_tools)) {
    return(list(
      success = FALSE,
      error = paste("Unknown tool:", tool_name)
    ))
  }

  tool <- .cassidy_tools[[tool_name]]

  # Add working_dir to input if tool supports it
  if ("working_dir" %in% names(tool$parameters)) {
    input$working_dir <- working_dir
  }

  # Execute tool
  result <- tryCatch({
    # Call handler with input parameters
    do.call(tool$handler, input)
  }, error = function(e) {
    return(list(
      success = FALSE,
      error = e$message
    ))
  })

  # Handle error result
  if (is.list(result) && !is.null(result$success) && !result$success) {
    return(result)
  }

  # Success
  list(
    success = TRUE,
    result = result
  )
}

#' Check if a tool is risky
#'
#' @param tool_name Character. Name of the tool
#'
#' @return Logical. TRUE if tool is risky (requires approval)
#' @keywords internal
#' @noRd
.is_risky_tool <- function(tool_name) {
  if (!tool_name %in% names(.cassidy_tools)) {
    return(FALSE)
  }

  .cassidy_tools[[tool_name]]$risky %||% FALSE
}

#' Get tool information
#'
#' @param tool_name Character. Name of the tool
#'
#' @return List with tool information
#' @keywords internal
#' @noRd
.get_tool_info <- function(tool_name) {
  if (!tool_name %in% names(.cassidy_tools)) {
    return(NULL)
  }

  tool <- .cassidy_tools[[tool_name]]
  list(
    name = tool_name,
    description = tool$description,
    risky = tool$risky %||% FALSE,
    parameters = tool$parameters
  )
}
