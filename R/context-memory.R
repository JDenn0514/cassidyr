#' Memory File Operations
#'
#' Functions for managing persistent memory files that store workflow state,
#' learned insights, and cross-session knowledge. Memory files are stored in
#' `~/.cassidy/memory/` and provide on-demand access to persistent information
#' that complements the context system.
#'
#' @name memory
#' @keywords internal
NULL

#' Get memory directory path
#'
#' Returns the path to the user's memory directory. Creates the directory
#' if it doesn't exist.
#'
#' @return Character. Path to `~/.cassidy/memory/` directory
#' @keywords internal
.get_memory_dir <- function() {
  memory_dir <- fs::path(tools::R_user_dir("cassidyr", "data"), "memory")

  if (!fs::dir_exists(memory_dir)) {
    fs::dir_create(memory_dir, recurse = TRUE)
  }

  memory_dir
}

#' Validate memory file path
#'
#' Ensures the path is within the memory directory and doesn't contain
#' directory traversal sequences. This prevents security issues like
#' accessing files outside the memory directory.
#'
#' @param path Character. File path to validate (relative or absolute)
#' @param memory_dir Character. Base memory directory path
#'
#' @return Character. Validated absolute path within memory directory
#' @keywords internal
.validate_memory_path <- function(path, memory_dir = .get_memory_dir()) {
  # Handle empty or NULL paths
  if (is.null(path) || length(path) == 0 || nchar(path) == 0) {
    cli::cli_abort(c(
      "x" = "Path cannot be empty",
      "i" = "Provide a valid file path"
    ))
  }

  # Remove leading slash if present (for consistency)
  path <- sub("^/+", "", path)

  # Check for obvious directory traversal attempts
  if (grepl("\\.\\.", path)) {
    cli::cli_abort(c(
      "x" = "Path contains directory traversal sequence: {.file {path}}",
      "i" = "Use relative paths within the memory directory"
    ))
  }

  # Check for URL-encoded traversal attempts
  if (grepl("%2e%2e|%2E%2E", path, ignore.case = TRUE)) {
    cli::cli_abort(c(
      "x" = "Path contains URL-encoded traversal sequence: {.file {path}}",
      "i" = "Use simple relative paths"
    ))
  }

  # Construct full path
  full_path <- fs::path(memory_dir, path)

  # Resolve to canonical form (handles symlinks, .., etc.)
  # If path doesn't exist yet, check parent directory instead
  if (fs::file_exists(full_path) || fs::dir_exists(full_path)) {
    canonical_path <- fs::path_real(full_path)
  } else {
    # For new files, validate the parent directory
    parent_dir <- fs::path_dir(full_path)
    if (!fs::dir_exists(parent_dir)) {
      # Create parent directories as needed
      fs::dir_create(parent_dir, recurse = TRUE)
    }
    canonical_path <- fs::path(fs::path_real(parent_dir), fs::path_file(full_path))
  }

  # Ensure the canonical path is within memory_dir
  canonical_memory_dir <- fs::path_real(memory_dir)

  if (!startsWith(as.character(canonical_path), as.character(canonical_memory_dir))) {
    cli::cli_abort(c(
      "x" = "Path is outside memory directory: {.file {path}}",
      "i" = "Memory files must be within {.path {memory_dir}}"
    ))
  }

  canonical_path
}

#' List memory files
#'
#' Returns a data frame of memory files with metadata (size, modified time).
#' Used to generate lightweight directory listings for context.
#'
#' @return Data frame with columns: path, size, modified, size_human
#' @export
#'
#' @examples
#' \dontrun{
#' # List all memory files
#' cassidy_list_memory_files()
#' }
cassidy_list_memory_files <- function() {
  memory_dir <- .get_memory_dir()

  # Find all files recursively
  files <- fs::dir_ls(memory_dir, recurse = TRUE, type = "file")

  if (length(files) == 0) {
    return(data.frame(
      path = character(0),
      size = numeric(0),
      modified = character(0),
      size_human = character(0),
      stringsAsFactors = FALSE
    ))
  }

  # Get file info
  info <- fs::file_info(files)

  # Make paths relative to memory_dir
  relative_paths <- fs::path_rel(files, memory_dir)

  # Build data frame
  data.frame(
    path = as.character(relative_paths),
    size = as.numeric(info$size),
    modified = format(info$modification_time, "%Y-%m-%d %H:%M:%S"),
    size_human = vapply(info$size, function(s) {
      if (s < 1024) {
        paste0(s, "B")
      } else if (s < 1024^2) {
        paste0(round(s / 1024, 1), "K")
      } else {
        paste0(round(s / 1024^2, 1), "M")
      }
    }, character(1)),
    stringsAsFactors = FALSE
  )
}

#' Format memory directory listing for context
#'
#' Creates a lightweight text summary of available memory files suitable
#' for inclusion in project context. Designed to be compact (~50-100 tokens).
#'
#' @return Character. Formatted listing of memory files
#' @export
#'
#' @examples
#' \dontrun{
#' # Get formatted listing
#' listing <- cassidy_format_memory_listing()
#' cat(listing)
#' }
cassidy_format_memory_listing <- function() {
  files <- cassidy_list_memory_files()

  if (nrow(files) == 0) {
    return("## Memory Directory\n\nNo memory files yet.")
  }

  # Calculate time since modified
  time_ago <- vapply(files$modified, function(m) {
    modified_time <- as.POSIXct(m)
    diff_hours <- as.numeric(difftime(Sys.time(), modified_time, units = "hours"))

    if (diff_hours < 1) {
      "just now"
    } else if (diff_hours < 24) {
      paste0(round(diff_hours), "h ago")
    } else if (diff_hours < 168) {  # 7 days
      paste0(round(diff_hours / 24), "d ago")
    } else if (diff_hours < 720) {  # 30 days
      paste0(round(diff_hours / 168), "w ago")
    } else {
      paste0(round(diff_hours / 720), "mo ago")
    }
  }, character(1))

  # Format each file
  file_lines <- vapply(seq_len(nrow(files)), function(i) {
    paste0("- ", files$path[i], " (", files$size_human[i], ", ", time_ago[i], ")")
  }, character(1))

  paste0(
    "## Memory Directory\n\n",
    "Available memory files (", nrow(files), "):\n",
    paste(file_lines, collapse = "\n"),
    "\n\n",
    "Use the memory tool to read specific files when needed."
  )
}

#' Read memory file
#'
#' Reads the contents of a memory file. The file path is validated to ensure
#' it's within the memory directory.
#'
#' @param path Character. Relative path to file within memory directory
#'
#' @return Character. File contents as a single string
#' @export
#'
#' @examples
#' \dontrun{
#' # Read a memory file
#' content <- cassidy_read_memory_file("workflow_state.md")
#' cat(content)
#' }
cassidy_read_memory_file <- function(path) {
  memory_dir <- .get_memory_dir()
  validated_path <- .validate_memory_path(path, memory_dir)

  if (!fs::file_exists(validated_path)) {
    cli::cli_abort(c(
      "x" = "Memory file not found: {.file {path}}",
      "i" = "Use {.fn cassidy_list_memory_files} to see available files"
    ))
  }

  # Read file contents
  lines <- readLines(validated_path, warn = FALSE)
  paste(lines, collapse = "\n")
}

#' Write memory file
#'
#' Writes content to a memory file. Creates the file if it doesn't exist,
#' or overwrites if it does. Subdirectories are created automatically.
#'
#' @param path Character. Relative path to file within memory directory
#' @param content Character. Content to write to file
#'
#' @return Character. Path to written file (invisibly)
#' @export
#'
#' @examples
#' \dontrun{
#' # Write a memory file
#' cassidy_write_memory_file(
#'   "workflow_state.md",
#'   "# Workflow State\n\nCurrently on Phase 3..."
#' )
#' }
cassidy_write_memory_file <- function(path, content) {
  memory_dir <- .get_memory_dir()
  validated_path <- .validate_memory_path(path, memory_dir)

  # Ensure parent directory exists
  parent_dir <- fs::path_dir(validated_path)
  if (!fs::dir_exists(parent_dir)) {
    fs::dir_create(parent_dir, recurse = TRUE)
  }

  # Write content
  writeLines(content, validated_path)

  invisible(as.character(validated_path))
}

#' Delete memory file
#'
#' Deletes a memory file. The file path is validated to ensure it's within
#' the memory directory.
#'
#' @param path Character. Relative path to file within memory directory
#'
#' @return Logical. TRUE if file was deleted, invisibly
#' @export
#'
#' @examples
#' \dontrun{
#' # Delete a memory file
#' cassidy_delete_memory_file("old_workflow.md")
#' }
cassidy_delete_memory_file <- function(path) {
  memory_dir <- .get_memory_dir()
  validated_path <- .validate_memory_path(path, memory_dir)

  if (!fs::file_exists(validated_path)) {
    cli::cli_abort(c(
      "x" = "Memory file not found: {.file {path}}",
      "i" = "Use {.fn cassidy_list_memory_files} to see available files"
    ))
  }

  # Delete file
  fs::file_delete(validated_path)

  invisible(TRUE)
}

#' Rename or move memory file
#'
#' Renames or moves a memory file within the memory directory. Both paths
#' are validated to ensure they're within the memory directory.
#'
#' @param old_path Character. Current relative path to file
#' @param new_path Character. New relative path for file
#'
#' @return Character. New path (invisibly)
#' @export
#'
#' @examples
#' \dontrun{
#' # Rename a file
#' cassidy_rename_memory_file("old_name.md", "new_name.md")
#'
#' # Move to subdirectory
#' cassidy_rename_memory_file("file.md", "archive/file.md")
#' }
cassidy_rename_memory_file <- function(old_path, new_path) {
  memory_dir <- .get_memory_dir()
  validated_old <- .validate_memory_path(old_path, memory_dir)
  validated_new <- .validate_memory_path(new_path, memory_dir)

  if (!fs::file_exists(validated_old)) {
    cli::cli_abort(c(
      "x" = "Memory file not found: {.file {old_path}}",
      "i" = "Use {.fn cassidy_list_memory_files} to see available files"
    ))
  }

  if (fs::file_exists(validated_new)) {
    cli::cli_abort(c(
      "x" = "Destination file already exists: {.file {new_path}}",
      "i" = "Choose a different name or delete the existing file first"
    ))
  }

  # Ensure parent directory exists for new path
  parent_dir <- fs::path_dir(validated_new)
  if (!fs::dir_exists(parent_dir)) {
    fs::dir_create(parent_dir, recurse = TRUE)
  }

  # Move file
  fs::file_move(validated_old, validated_new)

  invisible(as.character(validated_new))
}
