#' Gather project context
#'
#' Collects comprehensive information about the current R project including
#' file structure, Git status, configuration files, and more.
#'
#' By default, searches for CASSIDY.md files recursively up the directory tree
#' (like Claude Code), allowing company-wide configurations in parent directories
#' to be combined with project-specific configurations.
#'
#' @param level Context detail level: "minimal", "standard", or "comprehensive"
#' @param max_size Maximum context size in characters (approximate)
#' @param include_config Whether to include cassidy.md or similar config files.
#'   When TRUE (default), searches recursively up the directory tree.
#'
#' @return An object of class \code{cassidy_context} containing project information
#' @export
#'
#' @examples
#' \dontrun{
#'   # Gather standard context
#'   ctx <- cassidy_context_project()
#'
#'   # Minimal context (fastest)
#'   ctx_min <- cassidy_context_project(level = "minimal")
#'
#'   # Comprehensive context (most detailed)
#'   ctx_full <- cassidy_context_project(level = "comprehensive")
#'
#'   # Use in chat
#'   cassidy_chat("Help me understand this project", context = ctx)
#' }
cassidy_context_project <- function(
  level = c("standard", "minimal", "comprehensive"),
  max_size = 8000,
  include_config = TRUE
) {
  level <- match.arg(level)

  context_parts <- list()

  # Always include: R version and IDE
  context_parts$r_info <- cassidy_session_info()

  # Include project config files if they exist
  # Default to recursive=TRUE to match Claude Code behavior:
  # walks up directory tree to find upstream CASSIDY.md files
  if (include_config) {
    config_text <- cassidy_read_context_file(recursive = TRUE)
    if (!is.null(config_text)) {
      context_parts$config <- config_text
    }
  }

  if (level %in% c("standard", "comprehensive")) {
    # Project structure
    if (.is_r_project()) {
      file_level <- if (level == "comprehensive") {
        "comprehensive"
      } else {
        "standard"
      }
      context_parts$files <- cassidy_file_summary(level = file_level)
    }

    # Git status
    if (.has_git()) {
      git_ctx <- cassidy_context_git(
        include_commits = level == "comprehensive"
      )
      if (!is.null(git_ctx)) {
        context_parts$git <- git_ctx
      }
    }

    # Environment snapshot
    context_parts$env <- cassidy_context_env(
      detailed = level == "comprehensive"
    )
  }

  if (level == "comprehensive") {
    # Working directory
    context_parts$wd <- paste0("## Working Directory\n", getwd())
  }

  # Combine and trim if needed
  full_context <- paste(unlist(context_parts), collapse = "\n\n")

  if (nchar(full_context) > max_size) {
    full_context <- .trim_context(full_context, max_size)
    cli::cli_alert_info("Context trimmed to {max_size} characters")
  }

  structure(
    list(
      text = full_context,
      level = level,
      parts = names(context_parts)
    ),
    class = "cassidy_context"
  )
}


# Helper: Read user-level configs
.read_user_configs <- function() {
  configs <- list()

  user_cassidy_dir <- path.expand("~/.cassidy")

  if (!dir.exists(user_cassidy_dir)) {
    return(configs)
  }

  # Check for user-level CASSIDY.md
  user_file <- file.path(user_cassidy_dir, "CASSIDY.md")
  if (file.exists(user_file)) {
    content <- tryCatch(
      {
        lines <- readLines(user_file, warn = FALSE)
        paste(lines, collapse = "\n")
      },
      error = function(e) NULL
    )

    if (!is.null(content) && nchar(content) > 0) {
      configs[[length(configs) + 1]] <- list(
        file = "~/.cassidy/CASSIDY.md",
        content = content,
        path = user_file
      )
    }
  }

  # Check for user-level rules
  user_rules_dir <- file.path(user_cassidy_dir, "rules")
  if (dir.exists(user_rules_dir)) {
    rule_configs <- .read_rules_directory(
      user_rules_dir,
      prefix = "~/.cassidy/rules/"
    )
    if (length(rule_configs) > 0) {
      configs <- c(configs, rule_configs)
    }
  }

  configs
}

# Helper: Read all config files in a single directory
.read_configs_in_dir <- function(dir_path) {
  configs <- list()

  # Files to look for (in order of precedence)
  config_files <- c(
    # Project-level
    "CASSIDY.md",
    "CASSIDY.local.md",
    # Hidden .cassidy directory
    ".cassidy/CASSIDY.md",
    ".cassidy/CASSIDY.local.md",
    # Legacy names (backwards compatibility)
    "cassidy.md",
    ".cassidy.md"
  )

  # Check each file
  for (file in config_files) {
    full_path <- file.path(dir_path, file)
    if (file.exists(full_path)) {
      content <- tryCatch(
        {
          lines <- readLines(full_path, warn = FALSE)
          paste(lines, collapse = "\n")
        },
        error = function(e) NULL
      )

      if (!is.null(content) && nchar(content) > 0) {
        # Store relative path for display
        rel_path <- .make_relative_path(full_path, getwd())
        configs[[length(configs) + 1]] <- list(
          file = rel_path,
          content = content,
          path = full_path
        )
      }
    }
  }

  # Also check for .cassidy/rules/ directory
  rules_dir <- file.path(dir_path, ".cassidy", "rules")
  if (dir.exists(rules_dir)) {
    rule_configs <- .read_rules_directory(rules_dir)
    if (length(rule_configs) > 0) {
      configs <- c(configs, rule_configs)
    }
  }

  configs
}

# Helper: Read all .md files from rules directory
.read_rules_directory <- function(rules_dir, prefix = NULL) {
  configs <- list()

  # Find all .md files recursively
  md_files <- list.files(
    rules_dir,
    pattern = "\\.md$",
    full.names = TRUE,
    recursive = TRUE
  )

  for (md_file in md_files) {
    content <- tryCatch(
      {
        lines <- readLines(md_file, warn = FALSE)
        paste(lines, collapse = "\n")
      },
      error = function(e) NULL
    )

    if (!is.null(content) && nchar(content) > 0) {
      # Store relative path for display
      if (!is.null(prefix)) {
        # For user-level rules, use the prefix
        rel_name <- basename(md_file)
        if (dirname(md_file) != rules_dir) {
          # Include subdirectory structure
          rel_name <- sub(paste0("^", rules_dir, "/"), "", md_file)
        }
        rel_path <- paste0(prefix, rel_name)
      } else {
        rel_path <- .make_relative_path(md_file, getwd())
      }

      configs[[length(configs) + 1]] <- list(
        file = rel_path,
        content = content,
        path = md_file
      )
    }
  }

  configs
}
