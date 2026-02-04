# Helper: Extract function information from all R files
.extract_all_functions <- function(path, r_files) {
  # Get exported functions from NAMESPACE
  exports <- .get_exports(path)

  output <- "\n### Function Details:\n"

  files_to_parse <- utils::head(r_files, 15)

  for (f in files_to_parse) {
    file_path <- fs::path(path, f)
    functions <- .parse_r_file_functions(file_path, exports)

    if (length(functions) > 0) {
      output <- paste0(output, "\n**`", f, "`**\n")
      for (fn in functions) {
        output <- paste0(output, fn, "\n")
      }
    }
  }

  if (length(r_files) > 15) {
    output <- paste0(
      output,
      "\n*... and ",
      length(r_files) - 15,
      " more R files not shown*\n"
    )
  }

  output
}

# Helper: Get exported functions from NAMESPACE
.get_exports <- function(path) {
  ns_path <- fs::path(path, "NAMESPACE")
  if (!fs::file_exists(ns_path)) {
    return(character(0))
  }

  tryCatch(
    {
      ns_lines <- readLines(ns_path, warn = FALSE)
      export_lines <- ns_lines[grepl("^export\\(", ns_lines)]
      exports <- gsub("^export\\((.+)\\)$", "\\1", export_lines)
      gsub("[\"']", "", exports)
    },
    error = function(e) character(0)
  )
}

# Helper: Parse a single R file for function definitions
.parse_r_file_functions <- function(file_path, exports) {
  tryCatch(
    {
      lines <- readLines(file_path, warn = FALSE)

      # Try to parse for accurate extraction
      parsed <- tryCatch(
        parse(file_path, keep.source = TRUE),
        error = function(e) NULL
      )

      if (!is.null(parsed)) {
        return(.extract_functions_from_parsed(parsed, lines, exports))
      }

      # Fallback to regex
      .extract_functions_from_regex(lines, exports)
    },
    error = function(e) character(0)
  )
}


# Helper: Extract functions from parsed R code
.extract_functions_from_parsed <- function(parsed, lines, exports) {
  functions <- character(0)

  for (i in seq_along(parsed)) {
    expr <- parsed[[i]]

    if (!is.call(expr)) {
      next
    }
    if (!as.character(expr[[1]]) %in% c("<-", "=", "assign")) {
      next
    }

    name <- if (is.symbol(expr[[2]])) as.character(expr[[2]]) else NULL
    if (is.null(name)) {
      next
    }

    rhs <- expr[[3]]
    if (!is.call(rhs) || !identical(rhs[[1]], as.symbol("function"))) {
      next
    }

    # Get line number from source reference
    srcref <- attr(expr, "srcref")
    line_num <- if (!is.null(srcref)) srcref[1] else NA

    # Format output
    is_exported <- name %in% exports
    export_tag <- if (is_exported) "[exported]" else "[internal]"
    title <- .get_roxygen_title(lines, line_num)

    fn_info <- paste0(
      "- `",
      name,
      "()` ",
      export_tag,
      if (!is.null(title)) paste0(": ", title) else ""
    )

    functions <- c(functions, fn_info)
  }

  functions
}


# Helper: Extract functions using regex (fallback)
.extract_functions_from_regex <- function(lines, exports) {
  functions <- character(0)

  for (i in seq_along(lines)) {
    line <- lines[i]

    if (
      !grepl("^[a-zA-Z._][a-zA-Z0-9._]*\\s*(<-|=)\\s*function\\s*\\(", line)
    ) {
      next
    }

    name <- sub("^([a-zA-Z._][a-zA-Z0-9._]*)\\s*(<-|=).*", "\\1", line)

    is_exported <- name %in% exports
    export_tag <- if (is_exported) "[exported]" else "[internal]"
    title <- .get_roxygen_title(lines, i)

    fn_info <- paste0(
      "- `",
      name,
      "()` ",
      export_tag,
      if (!is.null(title)) paste0(": ", title) else ""
    )

    functions <- c(functions, fn_info)
  }

  functions
}


# Helper: Get roxygen title from comments above a function
.get_roxygen_title <- function(lines, line_num) {
  if (is.na(line_num) || line_num <= 1) {
    return(NULL)
  }

  for (i in (line_num - 1):max(1, line_num - 50)) {
    line <- trimws(lines[i])

    # Found title line (first non-tag roxygen line)
    if (grepl("^#'\\s+", line)) {
      title <- sub("^#'\\s+", "", line)
      return(sub("\\.$", "", title))
    }

    # Hit non-roxygen, non-empty line - stop
    if (nchar(line) > 0 && !grepl("^#'", line)) {
      break
    }
  }

  NULL
}
