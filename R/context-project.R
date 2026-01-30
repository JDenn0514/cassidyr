# R/context-project.R
# Functions for gathering project-level context

# ------------------------------------------------------------------------
# Gather project context -------------------------------------------------
# ------------------------------------------------------------------------

#' Gather project context
#'
#' Collects comprehensive information about the current R project including
#' file structure, Git status, configuration files, and more.
#'
#' @param level Context detail level: "minimal", "standard", or "comprehensive"
#' @param max_size Maximum context size in characters (approximate)
#' @param include_config Whether to include cassidy.md or similar config files
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
  if (include_config) {
    config_text <- cassidy_read_context_file()
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

# ------------------------------------------------------------------------
# Get git context and helpers --------------------------------------------
# ------------------------------------------------------------------------

#' Get Git repository status and recent commits
#'
#' @param repo Path to Git repository (default: current directory)
#' @param include_commits Whether to include recent commit history
#' @param n_commits Number of recent commits to include (default: 5)
#'
#' @return Character string with formatted Git information, or NULL if no Git repo
#' @export
#'
#' @examples
#' \dontrun{
#' # Basic Git status
#' cassidy_context_git()
#'
#' # Include recent commits
#' cassidy_context_git(include_commits = TRUE)
#'
#' # More commits
#' cassidy_context_git(include_commits = TRUE, n_commits = 10)
#' }
cassidy_context_git <- function(
  repo = ".",
  include_commits = FALSE,
  n_commits = 5
) {
  if (!.has_git()) {
    return(NULL)
  }

  # Try using gert package if available
  if (requireNamespace("gert", quietly = TRUE)) {
    return(.git_status_gert(repo, include_commits, n_commits))
  }

  # Fall back to system git commands
  .git_status_system(repo, include_commits, n_commits)
}

# Helper: Get Git status using gert package
.git_status_gert <- function(repo, include_commits, n_commits) {
  tryCatch(
    {
      # Get basic info
      info <- gert::git_info(repo = repo)
      status <- gert::git_status(repo = repo)

      git_text <- "## Git Status\n"
      git_text <- paste0(git_text, "Branch: ", info$shorthand, "\n")

      # Check for uncommitted changes
      n_changed <- nrow(status)
      if (n_changed > 0) {
        git_text <- paste0(
          git_text,
          "Status: ",
          n_changed,
          " uncommitted changes\n"
        )

        # Show what's changed
        staged <- status[status$staged, ]
        unstaged <- status[!status$staged, ]

        if (nrow(staged) > 0) {
          git_text <- paste0(git_text, "Staged files: ", nrow(staged), "\n")
        }
        if (nrow(unstaged) > 0) {
          git_text <- paste0(git_text, "Unstaged files: ", nrow(unstaged), "\n")
        }
      } else {
        git_text <- paste0(git_text, "Status: clean\n")
      }

      # Add commit history if requested
      if (include_commits) {
        commits <- gert::git_log(max = n_commits, repo = repo)

        if (nrow(commits) > 0) {
          git_text <- paste0(git_text, "\n### Recent Commits:\n")
          for (i in 1:nrow(commits)) {
            commit_date <- format(commits$time[i], "%Y-%m-%d")
            git_text <- paste0(
              git_text,
              "- ",
              commit_date,
              ": ",
              commits$message[i],
              " (",
              commits$author[i],
              ")\n"
            )
          }
        }
      }

      git_text
    },
    error = function(e) {
      cli::cli_alert_warning("Error reading Git status with gert")
      .git_status_system(repo, include_commits, n_commits)
    }
  )
}

# Helper: Get Git status using system commands
.git_status_system <- function(repo, include_commits, n_commits) {
  tryCatch(
    {
      if (Sys.which("git") == "") {
        return(NULL)
      }

      old_wd <- getwd()
      on.exit(setwd(old_wd))
      setwd(repo)

      branch <- system(
        "git branch --show-current",
        intern = TRUE,
        ignore.stderr = TRUE
      )
      status <- system(
        "git status --porcelain",
        intern = TRUE,
        ignore.stderr = TRUE
      )
      clean <- length(status) == 0

      git_text <- "## Git Status\n"
      git_text <- paste0(git_text, "Branch: ", branch, "\n")
      git_text <- paste0(
        git_text,
        "Status: ",
        if (clean) "clean" else paste(length(status), "uncommitted changes"),
        "\n"
      )

      # Add commit history if requested
      if (include_commits) {
        # Use simpler format that works cross-platform
        log_cmd <- paste0(
          'git log -n ',
          n_commits,
          ' --pretty=format:"%h|%an|%ad|%s" --date=short'
        )
        commits <- suppressWarnings(
          system(log_cmd, intern = TRUE, ignore.stderr = TRUE)
        )

        if (length(commits) > 0 && !any(grepl("^fatal:", commits))) {
          git_text <- paste0(git_text, "\n### Recent Commits:\n")
          for (commit in commits) {
            # Split by | but handle cases where message might contain |
            parts <- strsplit(commit, "\\|", fixed = FALSE)[[1]]
            if (length(parts) >= 4) {
              # Rejoin message parts if split
              msg <- paste(parts[4:length(parts)], collapse = "|")
              git_text <- paste0(
                git_text,
                "- ",
                parts[3],
                ": ",
                msg,
                " (",
                parts[2],
                ")\n"
              )
            }
          }
        }
      }

      git_text
    },
    error = function(e) {
      NULL
    }
  )
}

# ------------------------------------------------------------------------
# Cassidy.md reader and helpers ------------------------------------------
# ------------------------------------------------------------------------

#' Read CASSIDY.md or similar context configuration files
#'
#' Looks for project-specific configuration files. By default, only searches
#' the current working directory and user-level location (~/.cassidy/).
#'
#' @param path Directory to search (default: current directory)
#' @param recursive Whether to search parent directories (default: FALSE).
#'   When TRUE, searches up the directory tree like Claude Code does.
#'   For R packages, FALSE is recommended for predictability.
#' @param include_user Whether to include user-level memory from ~/.cassidy/
#'   (default: TRUE)
#'
#' @return Character string with config file contents, or NULL if none found
#' @export
#'
#' @examples
#' \dontrun{
#' # Read project and user-level config (default, recommended)
#' config <- cassidy_read_context_file()
#'
#' # Only search current directory (no user-level)
#' config <- cassidy_read_context_file(include_user = FALSE)
#'
#' # Search parent directories (Claude Code style)
#' config <- cassidy_read_context_file(recursive = TRUE)
#' }
cassidy_read_context_file <- function(
  path = ".",
  recursive = FALSE,
  include_user = TRUE
) {
  all_configs <- list()

  # Normalize path
  path <- normalizePath(path, mustWork = FALSE)

  # 1. User-level memory first (lowest priority)
  if (include_user) {
    user_configs <- .read_user_configs()
    if (length(user_configs) > 0) {
      all_configs <- c(all_configs, user_configs)
    }
  }

  # 2. Project-level memory
  if (recursive) {
    # Search up the directory tree (Claude Code behavior)
    current_path <- path
    root_path <- .get_root_path()

    while (current_path != root_path) {
      configs <- .read_configs_in_dir(current_path)
      if (length(configs) > 0) {
        all_configs <- c(all_configs, configs)
      }

      # Move up one directory
      parent_path <- dirname(current_path)
      if (parent_path == current_path) {
        break
      } # Reached root
      current_path <- parent_path
    }
  } else {
    # Only search current directory (default, recommended for R packages)
    configs <- .read_configs_in_dir(path)
    if (length(configs) > 0) {
      all_configs <- configs
    }
  }

  if (length(all_configs) == 0) {
    return(NULL)
  }

  # Format all found configs
  config_text <- "## Project Memory\n\n"

  for (cfg in all_configs) {
    config_text <- paste0(
      config_text,
      "### From ",
      cfg$file,
      ":\n\n",
      cfg$content,
      "\n\n"
    )
  }

  config_text
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

# Helper: Get root path (OS-specific)
.get_root_path <- function() {
  if (.Platform$OS.type == "windows") {
    # On Windows, get the root of current drive
    drive <- substr(getwd(), 1, 2)
    paste0(drive, "/")
  } else {
    # On Unix-like systems
    "/"
  }
}

# Helper: Make a path relative to a base directory
.make_relative_path <- function(path, base) {
  # Normalize both paths
  path <- normalizePath(path, mustWork = FALSE)
  base <- normalizePath(base, mustWork = FALSE)

  # Try to make relative
  if (startsWith(path, base)) {
    rel <- substring(path, nchar(base) + 2) # +2 to skip trailing /
    if (nchar(rel) > 0) return(rel)
  }

  # Fall back to basename if can't make relative
  basename(path)
}


#' Create a CASSIDY.md configuration file
#'
#' Creates a project-specific configuration file that provides automatic context
#' when you start \code{cassidy_app()}. Follows similar conventions to Claude Code's
#' CLAUDE.md files, but uses CASSIDY.md naming.
#'
#' @param path Directory where to create the file (default: current directory)
#' @param location Where to create the file: "root" (CASSIDY.md),
#'   "hidden" (.cassidy/CASSIDY.md), or "local" (CASSIDY.local.md for .gitignore)
#' @param template Template to use: "default", "package", "analysis", or "survey"
#' @param open Whether to open the file for editing (default: TRUE in interactive sessions)
#'
#' @details
#' You can create project memory files in several locations:
#' \itemize{
#'   \item \code{CASSIDY.md} - Project-level, checked into git (location = "root")
#'   \item \code{.cassidy/CASSIDY.md} - Project-level in hidden directory (location = "hidden")
#'   \item \code{CASSIDY.local.md} - Local-only, auto-gitignored (location = "local")
#' }
#'
#' These files are automatically loaded when you start \code{cassidy_app()}.
#' You can also create modular rules in \code{.cassidy/rules/*.md} files.
#'
#' @return Invisibly returns TRUE if file was created, FALSE if cancelled
#'
#' @export
#' @examples
#' \dontrun{
#' # Create CASSIDY.md in project root
#' use_cassidy_md()
#'
#' # Create in .cassidy/ directory (keeps root clean)
#' use_cassidy_md(location = "hidden")
#'
#' # Create local-only file (not shared with team)
#' use_cassidy_md(location = "local")
#'
#' # Create a package development template
#' use_cassidy_md(template = "package")
#' }
use_cassidy_md <- function(
  path = ".",
  location = c("root", "hidden", "local"),
  template = c("default", "package", "analysis", "survey"),
  open = interactive()
) {
  location <- match.arg(location)
  template <- match.arg(template)

  # Determine file path based on location
  file_name <- switch(
    location,
    root = "CASSIDY.md",
    hidden = ".cassidy/CASSIDY.md",
    local = "CASSIDY.local.md"
  )

  file_path <- file.path(path, file_name)

  # Create .cassidy directory if needed
  if (location == "hidden") {
    cassidy_dir <- file.path(path, ".cassidy")
    if (!dir.exists(cassidy_dir)) {
      dir.create(cassidy_dir, recursive = TRUE)
      cli::cli_alert_success("Created {.path .cassidy/} directory")
    }
  }

  if (file.exists(file_path)) {
    cli::cli_alert_warning(
      "{.file {file_name}} already exists at {.path {dirname(file_path)}}"
    )
    if (!interactive() || !.ask_overwrite()) {
      cli::cli_alert_info("Cancelled. No changes made.")
      return(invisible(FALSE))
    }
  }

  content <- switch(
    template,
    default = .cassidy_md_default(),
    package = .cassidy_md_package(),
    analysis = .cassidy_md_analysis(),
    survey = .cassidy_md_survey()
  )

  writeLines(content, file_path)
  cli::cli_alert_success("Created {.path {file_name}}")
  cli::cli_alert_info(
    "Edit this file to customize AI assistance for your project"
  )
  cli::cli_alert_info(
    "This file will be automatically loaded when you start {.fn cassidy_app}"
  )

  # Add CASSIDY.local.md to .gitignore if creating local file
  if (location == "local") {
    .add_to_gitignore(path, "CASSIDY.local.md")
  }

  # Try to open in editor (IDE-agnostic)
  if (open) {
    .open_file(file_path)
  }

  invisible(TRUE)
}

# Helper: Add entry to .gitignore
.add_to_gitignore <- function(path, entry) {
  gitignore_path <- file.path(path, ".gitignore")

  # Read existing .gitignore
  if (file.exists(gitignore_path)) {
    lines <- readLines(gitignore_path, warn = FALSE)
    # Check if entry already exists
    if (any(grepl(paste0("^", entry, "$"), lines))) {
      return(invisible(NULL)) # Already in .gitignore
    }
    # Append to existing
    lines <- c(lines, "", entry)
  } else {
    # Create new .gitignore
    lines <- entry
  }

  writeLines(lines, gitignore_path)
  cli::cli_alert_success("Added {.file {entry}} to {.path .gitignore}")
}

# Template functions (keeping your originals)
.cassidy_md_default <- function() {
  c(
    "# Project Context for Cassidy AI",
    "",
    "## Project Overview",
    "<!-- Brief description of what this project does -->",
    "",
    "## Key Files",
    "<!-- List important files and their purposes -->",
    "- `R/main.R` - Main analysis script",
    "- `data/` - Data directory",
    "",
    "## Coding Preferences",
    "<!-- Specify your preferred coding style and practices -->",
    "- Style: tidyverse",
    "- Prefer dplyr over base R",
    "- Use native pipe operator |>",
    "- Maximum line length: 80 characters",
    "",
    "## Common Tasks",
    "<!-- List common tasks you ask AI to help with -->",
    "- Data cleaning and transformation",
    "- Creating visualizations",
    "- Writing documentation",
    "",
    "## Notes",
    "<!-- Any other context that would be helpful -->"
  )
}


.cassidy_md_package <- function() {
  c(
    "# R Package Development Context",
    "",
    "## Package Information",
    "- **Name:** [your-package-name]",
    "- **Purpose:** [brief description]",
    "- **Target audience:** [who will use this]",
    "",
    "## Development Preferences",
    "- **Documentation:** roxygen2 with markdown (@md)",
    "- **Testing:** testthat 3e",
    "- **Style:** tidyverse style guide",
    "- **Dependencies:** Minimize when possible, prefer base R for simple operations",
    "- **Pipe:** Use native pipe |> for R >= 4.1",
    "",
    "## Documentation Standards",
    "- All exported functions must have examples",
    "- Include @return descriptions",
    "- Use markdown formatting in roxygen2",
    "- Link related functions with @seealso",
    "- Document all parameters completely",
    "",
    "## Testing Standards",
    "- Unit tests for all exported functions",
    "- Use descriptive test names following: 'test_that(\"function does X when Y\")'",
    "- Test error handling and edge cases",
    "- Aim for >80% code coverage",
    "",
    "## Code Review Checklist",
    "- [ ] Functions follow naming conventions",
    "- [ ] All parameters documented",
    "- [ ] Examples run without errors",
    "- [ ] Tests pass",
    "- [ ] No unnecessary dependencies added"
  )
}

.cassidy_md_analysis <- function() {
  c(
    "# Data Analysis Project Context",
    "",
    "## Project Goal",
    "<!-- Describe the research question or analysis goal -->",
    "",
    "## Data Sources",
    "<!-- List and describe your data sources -->",
    "- **Source 1:** Description, location, format",
    "- **Source 2:** Description, location, format",
    "",
    "## Analysis Approach",
    "- **Methods:** [e.g., regression, clustering, time series]",
    "- **Key variables:** [list important variables]",
    "- **Software preferences:** [tidyverse, data.table, etc.]",
    "",
    "## Workflow",
    "<!-- Describe your typical analysis workflow -->",
    "1. Data import and cleaning",
    "2. Exploratory analysis",
    "3. Statistical modeling",
    "4. Visualization and reporting",
    "",
    "## Reporting",
    "- **Audience:** [who will read this]",
    "- **Format:** [R Markdown, Quarto, etc.]",
    "- **Emphasis:** [visualization, statistics, interpretation]",
    "- **Style preferences:** [APA, Chicago, custom]",
    "",
    "## Visualization Preferences",
    "- **Package:** [ggplot2, base R, etc.]",
    "- **Theme:** [minimal, classic, custom]",
    "- **Color palette:** [viridis, RColorBrewer, custom]"
  )
}

.cassidy_md_survey <- function() {
  c(
    "# Survey Research Project Context",
    "",
    "## Study Overview",
    "<!-- Brief description of the survey study -->",
    "- **Population:** [target population]",
    "- **Sample size:** [N = ?]",
    "- **Data collection:** [method and timeframe]",
    "",
    "## Survey Details",
    "- **Key constructs:** [list main constructs measured]",
    "- **Scale types:** [Likert, semantic differential, etc.]",
    "- **Missing data:** [how handled]",
    "",
    "## Analysis Preferences",
    "- **Factor analysis:** [EFA, CFA, preferences]",
    "- **Scale reliability:** [Cronbach's alpha, omega]",
    "- **Statistical tests:** [preferred methods]",
    "- **Packages:** [survey, psych, lavaan, semTools, adlgraphs, etc.]",
    "",
    "## Reporting Standards",
    "- **Effect sizes:** Always report",
    "- **Tables:** APA format",
    "- **Figures:** Publication quality",
    "- **Decimals:** 2-3 places for most statistics",
    "",
    "## Data Management",
    "- **Variable naming:** [conventions used]",
    "- **Value labels:** [how coded]",
    "- **Codebook:** [location and format]",
    "- **Weights:** [if applicable]",
    "",
    "## Common Tasks",
    "- Creating/interpreting factor analyses",
    "- Generating codebooks",
    "- Writing methods sections",
    "- Creating correlation matrices",
    "- Recoding and transforming variables"
  )
}

# ------------------------------------------------------------------------
# printing method for cassidy_context objects ----------------------------
# ------------------------------------------------------------------------

#' @export
print.cassidy_context <- function(x, ...) {
  cli::cli_h1("Cassidy Context")
  cli::cli_alert_info("Level: {x$level}")
  cli::cli_alert_info("Parts: {paste(x$parts, collapse = ', ')}")
  cli::cli_alert_info("Size: {nchar(x$text)} characters")
  cat("\n")
  cat(x$text)
  invisible(x)
}
