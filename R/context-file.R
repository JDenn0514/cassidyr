#' Read File Contents as Context
#'
#' Reads a file and formats it as context for use with [cassidy_chat()].
#' The file content is wrapped in a markdown code block with appropriate
#' syntax highlighting based on file extension.
#'
#' @param path Path to the file to read. Can be absolute or relative to the
#'   working directory.
#' @param max_lines Maximum number of lines to read. Use `Inf` to read entire
#'   file. Defaults to `Inf` (read all).
#' @param lines Numeric vector specifying specific line numbers to read.
#'   If provided, only these lines are included. Use `NULL` (default) to read
#'   all lines (subject to `max_lines`).
#' @param line_range Numeric vector of length 2 specifying start and end lines
#'   (e.g., `c(10, 50)` reads lines 10-50). Ignored if `lines` is provided.
#' @param show_line_numbers Logical; if `TRUE`, prepends line numbers to each
#'   line. Useful for discussing specific line numbers. Defaults to `TRUE`.
#' @param level Character; detail level for file content. One of:
#'   - `"full"`: Complete file contents (default)
#'   - `"summary"`: Function signatures + key excerpts
#'   - `"index"`: Metadata and function listing only
#'   Used by chat system to manage context size. Most users should use default.
#'
#' @return A `cassidy_context` object containing the formatted file contents.
#'
#' @details
#' The function automatically detects the file type from the extension and
#' applies appropriate syntax highlighting in the markdown output.
#'
#' You can read files in three ways:
#' - Entire file: Just provide `path`
#' - Specific lines: Use `lines = c(1, 5, 10:20)`
#' - Line range: Use `line_range = c(10, 50)`
#'
#' The `level` parameter controls detail:
#' - `"full"`: Best for detailed code review, includes all content
#' - `"summary"`: Good for understanding structure without full content
#' - `"index"`: Minimal metadata, useful when you have many files
#'
#' @examples
#' \dontrun{
#'   # Read an entire R file
#'   ctx <- cassidy_describe_file("R/my-function.R")
#'
#'   # Read specific lines (useful for focusing on a function)
#'   ctx <- cassidy_describe_file("R/my-function.R", lines = 45:120)
#'
#'   # Read with summary level (less detail)
#'   ctx <- cassidy_describe_file("R/my-function.R", level = "summary")
#'
#'   # Ask Cassidy to review specific code
#'   cassidy_chat(
#'     "Review this function and suggest improvements",
#'     context = cassidy_describe_file("R/my-function.R", lines = 45:120)
#'   )
#' }
#'
#' @seealso [cassidy_context_combined()], [cassidy_context_project()],
#'   [cassidy_chat()]
#' @export
cassidy_describe_file <- function(
  path,
  max_lines = Inf,
  lines = NULL,
  line_range = NULL,
  show_line_numbers = TRUE,
  level = c("full", "summary", "index") # ADD THIS PARAMETER
) {
  level <- match.arg(level)

  # Validate file exists
  if (!fs::file_exists(path)) {
    cli::cli_abort(c(
      "File not found: {.file {path}}",
      "i" = "Check that the path is correct and the file exists."
    ))
  }

  # Read entire file first
  all_lines <- readLines(path, warn = FALSE)
  total_lines <- length(all_lines)
  ext <- tolower(tools::file_ext(path))

  # Calculate lang BEFORE branching
  lang <- .get_language_from_ext(ext)

  # === NEW: Handle summary/index levels ===
  if (level != "full") {
    return(.build_smart_file_context(path, all_lines, total_lines, ext, level))
  }

  # === EXISTING CODE BELOW - Keep everything exactly as is ===
  # Determine which lines to include
  if (!is.null(lines)) {
    # Specific lines provided
    lines <- unique(sort(lines))
    lines <- lines[lines > 0 & lines <= total_lines]

    if (length(lines) == 0) {
      cli::cli_abort("No valid line numbers provided")
    }

    selected_lines <- all_lines[lines]
    line_numbers <- lines
    truncated <- FALSE
    selection_type <- "specific"
  } else if (!is.null(line_range)) {
    # Line range provided
    if (length(line_range) != 2) {
      cli::cli_abort("`line_range` must be a numeric vector of length 2")
    }

    start_line <- max(1, line_range[1])
    end_line <- min(total_lines, line_range[2])

    if (start_line > end_line) {
      cli::cli_abort("Invalid line range: start must be <= end")
    }

    line_numbers <- start_line:end_line
    selected_lines <- all_lines[line_numbers]
    truncated <- FALSE
    selection_type <- "range"
  } else {
    # Read all lines (subject to max_lines)
    truncated <- FALSE

    if (is.finite(max_lines) && total_lines > max_lines) {
      selected_lines <- all_lines[seq_len(max_lines)]
      line_numbers <- seq_len(max_lines)
      truncated <- TRUE
    } else {
      selected_lines <- all_lines
      line_numbers <- seq_len(total_lines)
    }
    selection_type <- "all"
  }

  # Add line numbers if requested
  if (show_line_numbers) {
    width <- nchar(as.character(max(line_numbers)))
    display_lines <- paste0(
      formatC(line_numbers, width = width, flag = " "),
      " | ",
      selected_lines
    )
  } else {
    display_lines <- selected_lines
  }

  # Build header with selection info
  header <- paste0("## File: `", path, "`\n")

  if (selection_type == "specific") {
    header <- paste0(
      header,
      "*Lines: ",
      paste(range(line_numbers), collapse = "-"),
      " (",
      length(line_numbers),
      " lines selected)*\n"
    )
  } else if (selection_type == "range") {
    header <- paste0(
      header,
      "*Lines: ",
      line_range[1],
      "-",
      line_range[2],
      "*\n"
    )
  } else if (truncated) {
    header <- paste0(
      header,
      "*Note: Showing first ",
      max_lines,
      " of ",
      total_lines,
      " total lines*\n"
    )
  } else {
    header <- paste0(header, "*Total lines: ", total_lines, "*\n")
  }

  # Build content
  content <- paste0(
    header,
    "\n",
    "```",
    lang,
    "\n",
    paste(display_lines, collapse = "\n"),
    "\n```"
  )

  structure(
    list(
      text = content,
      file_path = path,
      total_lines = total_lines,
      selected_lines = line_numbers,
      truncated = truncated,
      detail_level = level,
      parts = "file"
    ),
    class = "cassidy_context"
  )
}


#' Summarize Project Files
#'
#' Provides a summary of files in the project, with varying levels of detail.
#' Useful for understanding project structure and for providing context to
#' AI assistants about your codebase.
#'
#' @param path Root directory to search (default: current directory)
#' @param level Detail level: "minimal", "standard", or "comprehensive"
#'   - `"minimal"`: File counts by type and key directories
#'   - `"standard"`: Adds file listing with sizes
#'   - `"comprehensive"`: Adds function extraction from R files with
#'     descriptions and export status
#'
#' @return Character string with formatted file information
#' @export
#'
#' @examples
#' \dontrun{
#'   # Quick overview
#'   cassidy_file_summary()
#'
#'   # Standard listing with file sizes
#'   cassidy_file_summary(level = "standard")
#'
#'   # Full analysis with function extraction
#'   cassidy_file_summary(level = "comprehensive")
#' }
#'
#' @seealso [cassidy_context_project()], [cassidy_describe_file()]
cassidy_file_summary <- function(
  path = ".",
  level = c("minimal", "standard", "comprehensive")
) {
  level <- match.arg(level)

  files <- as.character(fs::dir_ls(
    path,
    recurse = TRUE,
    all = FALSE,
    type = "file"
  ))

  if (length(files) == 0) {
    return("## Project Files\nNo files found")
  }

  # Categorize files
  r_files <- files[grepl("\\.R$", files, ignore.case = TRUE)]
  rmd_files <- files[grepl("\\.Rmd$", files, ignore.case = TRUE)]
  qmd_files <- files[grepl("\\.qmd$", files, ignore.case = TRUE)]
  data_files <- files[grepl(
    "\\.(csv|rds|rda|feather|parquet|xlsx?)$",
    files,
    ignore.case = TRUE
  )]

  # Check for common directories
  dirs <- basename(as.character(fs::dir_ls(
    path,
    recurse = FALSE,
    type = "directory"
  )))
  key_dirs <- intersect(
    dirs,
    c("R", "data", "scripts", "output", "docs", "tests", "man", "vignettes")
  )

  # Build output
  output <- "## Project Files\n"
  output <- paste0(output, "R scripts: ", length(r_files), "\n")

  if (length(rmd_files) > 0) {
    output <- paste0(output, "R Markdown files: ", length(rmd_files), "\n")
  }

  if (length(qmd_files) > 0) {
    output <- paste0(output, "Quarto files: ", length(qmd_files), "\n")
  }

  output <- paste0(output, "Data files: ", length(data_files), "\n")

  if (length(key_dirs) > 0) {
    output <- paste0(
      output,
      "Key directories: ",
      paste(key_dirs, collapse = ", "),
      "\n"
    )
  }

  # Package info if available
  if (fs::file_exists(fs::path(path, "DESCRIPTION"))) {
    desc <- tryCatch(
      read.dcf(fs::path(path, "DESCRIPTION"))[1, ],
      error = function(e) NULL
    )
    if (!is.null(desc) && "Package" %in% names(desc)) {
      output <- paste0(output, "Package name: ", desc["Package"], "\n")
      if ("Title" %in% names(desc)) {
        output <- paste0(output, "Package title: ", desc["Title"], "\n")
      }
    }
  }

  # Standard level: add file listing
  if (level %in% c("standard", "comprehensive") && length(r_files) > 0) {
    output <- paste0(output, "\n### R Files:\n")

    max_files <- if (level == "comprehensive") 20 else 10
    files_to_show <- utils::head(r_files, max_files)

    for (f in files_to_show) {
      file_path <- fs::path(path, f)
      size_kb <- round(as.numeric(fs::file_size(file_path)) / 1024, 1)

      n_lines <- tryCatch(
        length(readLines(file_path, warn = FALSE)),
        error = function(e) NA
      )
      line_info <- if (!is.na(n_lines)) paste0(", ", n_lines, " lines") else ""

      output <- paste0(
        output,
        "- `",
        f,
        "` (",
        size_kb,
        " KB",
        line_info,
        ")\n"
      )
    }

    if (length(r_files) > max_files) {
      output <- paste0(
        output,
        "... and ",
        length(r_files) - max_files,
        " more R files\n"
      )
    }
  }

  # Comprehensive level: add function extraction
  if (level == "comprehensive" && length(r_files) > 0) {
    output <- paste0(output, .extract_all_functions(path, r_files))
  }

  output
}


#' Get language from file extension
#' @keywords internal
.get_language_from_ext <- function(ext) {
  switch(
    ext,
    "r" = "r",
    "rmd" = "r",
    "qmd" = "r",
    "py" = "python",
    "js" = "javascript",
    "ts" = "typescript",
    "json" = "json",
    "yaml" = "yaml",
    "yml" = "yaml",
    "md" = "markdown",
    "sql" = "sql",
    "sh" = "bash",
    "bash" = "bash",
    "css" = "css",
    "html" = "html",
    "xml" = "xml",
    "cpp" = "cpp",
    "c" = "c",
    "h" = "c",
    ""
  )
}


#' Build smart file context (summary or index)
#' @keywords internal
.build_smart_file_context <- function(
  path,
  all_lines,
  total_lines,
  ext,
  level
) {
  lang <- .get_language_from_ext(ext)
  size_kb <- round(as.numeric(fs::file_size(path)) / 1024, 1)

  if (level == "summary") {
    # Show first 10 + last 10 lines with line numbers
    preview <- 10

    if (total_lines <= preview * 2) {
      # File is small enough, show all
      width <- nchar(as.character(total_lines))
      display_lines <- paste0(
        formatC(seq_len(total_lines), width = width, flag = " "),
        " | ",
        all_lines
      )

      content <- paste0(
        "## File: `",
        path,
        "` (SUMMARY - Complete)\n",
        "*",
        total_lines,
        " lines | ",
        size_kb,
        " KB*\n\n",
        "```",
        ext,
        "\n",
        paste(display_lines, collapse = "\n"),
        "\n```"
      )
    } else {
      # Show preview with line numbers
      width <- nchar(as.character(total_lines))

      first_lines <- paste0(
        formatC(1:preview, width = width, flag = " "),
        " | ",
        all_lines[1:preview]
      )

      last_line_nums <- (total_lines - preview + 1):total_lines
      last_lines <- paste0(
        formatC(last_line_nums, width = width, flag = " "),
        " | ",
        all_lines[last_line_nums]
      )

      content <- paste0(
        "## File: `",
        path,
        "` (SUMMARY)\n",
        "*",
        total_lines,
        " lines | ",
        size_kb,
        " KB*\n\n",
        "**First ",
        preview,
        " lines:**\n",
        "```",
        ext,
        "\n",
        paste(first_lines, collapse = "\n"),
        "\n```\n\n",
        "*... (",
        total_lines - (preview * 2),
        " lines omitted) ...*\n\n",
        "**Last ",
        preview,
        " lines:**\n",
        "```",
        ext,
        "\n",
        paste(last_lines, collapse = "\n"),
        "\n```\n\n",
        "*Request full file: `[REQUEST_FILE:",
        path,
        "]`*"
      )
    }
  } else {
    # level == "index"
    # Just metadata and function list for R files
    content_parts <- paste0(
      "## File: `",
      path,
      "` (INDEX)\n",
      "*",
      total_lines,
      " lines | ",
      size_kb,
      " KB*\n\n"
    )

    # For R files, extract function names
    if (ext == "r") {
      functions <- .parse_r_file_functions(path, character())

      if (length(functions) > 0) {
        # Extract just function names
        fn_names <- gsub("^- `([^`]+)`.*$", "\\1", functions)
        content_parts <- paste0(
          content_parts,
          "**Contains ",
          length(fn_names),
          " function(s):** ",
          paste(fn_names, collapse = ", "),
          "\n\n"
        )
      }
    }

    content <- paste0(
      content_parts,
      "*Full file available: `[REQUEST_FILE:",
      path,
      "]`*"
    )
  }

  structure(
    list(
      text = content,
      file_path = path,
      total_lines = total_lines,
      detail_level = level,
      parts = "file"
    ),
    class = "cassidy_context"
  )
}
