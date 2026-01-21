# R/context-environment.R
# Functions for gathering R environment context

#' Get current environment snapshot
#'
#' Creates a snapshot of the current R environment including loaded objects,
#' packages, and working directory.
#'
#' @param detailed Include detailed object information
#'
#' @return Character string with formatted environment information
#' @export
#'
#' @examples
#' \dontrun{
#'   # Basic environment snapshot
#'   cassidy_context_env()
#'
#'   # Detailed snapshot
#'   cassidy_context_env(detailed = TRUE)
#' }
cassidy_context_env <- function(detailed = FALSE) {
  context <- ""

  # Objects in global environment
  obj_info <- cassidy_list_objects(detailed = detailed)
  if (!is.null(obj_info) && nchar(obj_info) > 0) {
    context <- paste0(context, obj_info, "\n\n")
  }

  # Loaded packages (only if detailed)
  if (detailed) {
    pkg_info <- .context_packages()
    if (!is.null(pkg_info)) {
      context <- paste0(context, pkg_info, "\n\n")
    }
  }

  # Remove trailing newlines
  trimws(context, which = "right")
}

#' List objects in global environment
#'
#' Creates a formatted list of objects currently in the global environment,
#' categorized by type (data frames, functions, etc.).
#'
#' @param envir Environment to list objects from (default: .GlobalEnv)
#' @param detailed Include object sizes and classes
#'
#' @return Character string with formatted object list
#' @export
#'
#' @examples
#' \dontrun{
#' # Basic object list
#' cassidy_list_objects()
#'
#' # Detailed list with sizes
#' cassidy_list_objects(detailed = TRUE)
#' }
cassidy_list_objects <- function(envir = .GlobalEnv, detailed = FALSE) {
  objects <- ls(envir = envir)

  if (length(objects) == 0) {
    return("## Environment Objects\nEmpty")
  }

  # Categorize objects
  data_frames <- character()
  functions <- character()
  other <- character()

  for (obj_name in objects) {
    obj <- get(obj_name, envir = envir)

    if (is.data.frame(obj)) {
      dims <- dim(obj)
      df_info <- paste0(
        "- `",
        obj_name,
        "`: ",
        dims[1],
        " obs × ",
        dims[2],
        " vars"
      )

      if (detailed) {
        size_mb <- format(utils::object.size(obj), units = "MB")
        df_info <- paste0(df_info, " (", size_mb, ")")
      }

      data_frames <- c(data_frames, df_info)
    } else if (is.function(obj)) {
      func_info <- paste0("- `", obj_name, "()`")
      functions <- c(functions, func_info)
    } else if (detailed) {
      obj_class <- class(obj)[1]
      obj_size <- format(utils::object.size(obj), units = "auto")
      other <- c(
        other,
        paste0("- `", obj_name, "` (", obj_class, ", ", obj_size, ")")
      )
    }
  }

  context <- "## Environment Objects\n\n"

  if (length(data_frames) > 0) {
    context <- paste0(
      context,
      "**Data frames:**\n",
      paste(data_frames, collapse = "\n"),
      "\n\n"
    )
  }

  if (detailed && length(functions) > 0) {
    # Limit functions to first 10 if many
    if (length(functions) > 10) {
      func_display <- c(
        utils::head(functions, 10),
        paste0("... and ", length(functions) - 10, " more")
      )
    } else {
      func_display <- functions
    }
    context <- paste0(
      context,
      "**Functions:**\n",
      paste(func_display, collapse = "\n"),
      "\n\n"
    )
  }

  if (detailed && length(other) > 0) {
    context <- paste0(
      context,
      "**Other objects:**\n",
      paste(other, collapse = "\n"),
      "\n\n"
    )
  }

  # Summary
  context <- paste0(
    context,
    "**Total:** ",
    length(objects),
    " object(s)"
  )

  context
}

#' Get session info formatted for LLM
#'
#' Returns R session information formatted in a way that's useful
#' for AI assistants to understand the current R environment.
#'
#' @param include_packages Whether to include loaded package information
#'
#' @return Character string with formatted session information
#' @export
#'
#' @examples
#' \dontrun{
#' # Basic session info
#' cassidy_session_info()
#'
#' # With package info
#' cassidy_session_info(include_packages = TRUE)
#' }
cassidy_session_info <- function(include_packages = FALSE) {
  session_text <- "## R Session Information\n\n"

  # R version
  session_text <- paste0(
    session_text,
    "**R version:** ",
    R.version$major,
    ".",
    R.version$minor,
    " (",
    R.version$version.string,
    ")\n"
  )

  # Platform
  session_text <- paste0(
    session_text,
    "**Platform:** ",
    R.version$platform,
    "\n"
  )

  # IDE
  ide <- .detect_ide()
  session_text <- paste0(session_text, "**IDE:** ", ide, "\n")

  # Locale
  session_text <- paste0(
    session_text,
    "**Locale:** ",
    Sys.getlocale("LC_CTYPE"),
    "\n"
  )

  # Working directory
  session_text <- paste0(
    session_text,
    "**Working directory:** ",
    getwd(),
    "\n"
  )

  # Loaded packages
  if (include_packages) {
    pkg_info <- .context_packages()
    if (!is.null(pkg_info)) {
      session_text <- paste0(session_text, "\n", pkg_info)
    }
  }

  session_text
}

# Helper: Get loaded packages (excluding base packages)
.context_packages <- function() {
  loaded <- loadedNamespaces()
  # Filter out base packages for brevity
  base_pkgs <- c(
    "base",
    "utils",
    "stats",
    "graphics",
    "grDevices",
    "methods",
    "datasets"
  )
  user_pkgs <- setdiff(loaded, base_pkgs)

  if (length(user_pkgs) == 0) {
    return(NULL)
  }

  paste0("**Loaded packages:** ", paste(sort(user_pkgs), collapse = ", "))
}
