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
