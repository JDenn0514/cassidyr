# R/context-tools.R
# Internal helper functions for context gathering

# Detect IDE (for informational purposes)
.detect_ide <- function() {
  if (Sys.getenv("RSTUDIO") == "1") {
    return("RStudio")
  } else if (
    Sys.getenv("POSITRON") == "1" || Sys.getenv("POSITRON_VERSION") != ""
  ) {
    return("Positron")
  } else if (Sys.getenv("TERM_PROGRAM") == "vscode") {
    return("VS Code")
  } else if (.Platform$GUI == "RStudio") {
    return("RStudio")
  } else {
    return("Unknown/Terminal")
  }
}

# Detect if in an R project (IDE-agnostic)
.is_r_project <- function() {
  # Check for RStudio project
  has_rproj <- length(list.files(pattern = "\\.Rproj$")) > 0

  # Check for Positron/VS Code workspace
  has_code_workspace <- file.exists(".code-workspace") ||
    file.exists(".vscode/settings.json")

  # Check for renv (common in modern R projects)
  has_renv <- file.exists("renv.lock")

  # Check for common R project structure
  has_r_structure <- dir.exists("R") ||
    file.exists("DESCRIPTION") ||
    any(file.exists(c("analysis.R", "main.R", "run.R")))

  has_rproj || has_code_workspace || has_renv || has_r_structure
}

# Check for Git repository
.has_git <- function() {
  dir.exists(".git")
}

# Trim context to max size
.trim_context <- function(context, max_size) {
  if (nchar(context) <= max_size) {
    return(context)
  }

  substr(context, 1, max_size - 50) |>
    paste0("\n\n[Context truncated...]")
}

# Open file in available editor
.open_file <- function(file_path) {
  # Try RStudio API
  if (
    requireNamespace("rstudioapi", quietly = TRUE) &&
      rstudioapi::isAvailable()
  ) {
    rstudioapi::navigateToFile(file_path)
    return(invisible(TRUE))
  }

  # Try file.edit (works in most IDEs including Positron)
  tryCatch(
    {
      utils::file.edit(file_path)
      invisible(TRUE)
    },
    error = function(e) {
      cli::cli_alert_info(
        "Open {.path {file_path}} in your editor to customize"
      )
      invisible(FALSE)
    }
  )
}

# Ask user for confirmation
.ask_overwrite <- function() {
  response <- readline("Overwrite existing file? (y/n): ")
  tolower(trimws(response)) == "y"
}

# Format number with specific digits
.format_num <- function(x, digits = 2) {
  format(x, digits = digits, nsmall = digits)
}
