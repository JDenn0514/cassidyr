# ══════════════════════════════════════════════════════════════════════════════
# SKILLS CONTEXT - Integration with Context System
# Provides skill metadata for project context
# ══════════════════════════════════════════════════════════════════════════════

#' Get Skills Context
#'
#' Gathers metadata about available skills (workflows) without loading
#' full content. Provides progressive disclosure - only skill names and
#' descriptions are included, full content loads on-demand.
#'
#' @param location Character. "all" (default), "project", or "personal"
#' @param format Character. "text" (default) or "list"
#'
#' @return A `cassidy_context` object with skill metadata, or list if format="list"
#' @export
#'
#' @examples
#' \dontrun{
#' # Get all available skills
#' ctx <- cassidy_context_skills()
#'
#' # Just project skills
#' ctx <- cassidy_context_skills(location = "project")
#'
#' # Get as list for programmatic use
#' skills_list <- cassidy_context_skills(format = "list")
#' }
cassidy_context_skills <- function(
  location = c("all", "project", "personal"),
  format = c("text", "list")
) {
  location <- match.arg(location)
  format <- match.arg(format)

  skills <- .discover_skills()

  # Filter by location if requested
  if (location != "all") {
    base_path <- if (location == "project") {
      file.path(getwd(), ".cassidy/skills")
    } else {
      path.expand("~/.cassidy/skills")
    }

    skills <- Filter(function(s) {
      startsWith(s$file_path, base_path)
    }, skills)
  }

  if (format == "list") {
    return(skills)
  }

  # Format as text
  if (length(skills) == 0) {
    text <- ""
  } else {
    skill_lines <- sapply(names(skills), function(name) {
      skill <- skills[[name]]

      # Determine location
      loc <- if (grepl(path.expand("~/.cassidy"), skill$file_path)) {
        "[personal]"
      } else {
        "[project]"
      }

      # Auto-invoke indicator
      auto <- if (skill$auto_invoke) "[auto]" else "[manual]"

      # Dependencies
      deps <- if (length(skill$requires) > 0) {
        paste0(" (requires: ", paste(skill$requires, collapse = ", "), ")")
      } else {
        ""
      }

      paste0("- **", name, "** ", auto, " ", loc, ": ", skill$description, deps)
    })

    text <- paste0(
      "## Available Skills\n\n",
      paste(skill_lines, collapse = "\n")
    )
  }

  structure(
    list(
      text = text,
      skills = skills,
      location = location
    ),
    class = "cassidy_context"
  )
}
