# ══════════════════════════════════════════════════════════════════════════════
# SKILLS DISCOVERY - Find and Parse Skill Files
# Discovers skills from .cassidy/skills/ directories
# ══════════════════════════════════════════════════════════════════════════════

#' Discover Available Skills
#'
#' Scans project and personal skills directories for .md files and parses
#' their metadata (name, description, auto-invoke, requires).
#'
#' @return Named list of skill metadata
#' @keywords internal
#' @noRd
.discover_skills <- function() {
  skill_dirs <- c(
    file.path(getwd(), ".cassidy/skills"),      # Project
    path.expand("~/.cassidy/skills")             # Personal
  )

  skill_files <- unlist(lapply(skill_dirs, function(dir) {
    if (dir.exists(dir)) {
      list.files(dir, pattern = "\\.md$", full.names = TRUE)
    }
  }))

  if (length(skill_files) == 0) {
    return(list())
  }

  # Parse metadata from each file
  skills <- lapply(skill_files, .parse_skill_metadata)
  names(skills) <- tools::file_path_sans_ext(basename(skill_files))

  # Remove any NULL entries (failed parsing)
  Filter(Negate(is.null), skills)
}

#' Parse Skill Metadata from File
#'
#' Reads the header portion of a skill file and extracts metadata fields.
#' Only reads first ~30 lines to avoid loading full content.
#'
#' @param file_path Character. Path to skill .md file
#'
#' @return List with name, description, auto_invoke, requires, file_path
#' @keywords internal
#' @noRd
.parse_skill_metadata <- function(file_path) {
  tryCatch({
    # Read just the header (first 30 lines should contain all metadata)
    lines <- readLines(file_path, n = 30, warn = FALSE)

    # Extract name (first # heading)
    name_line <- grep("^#\\s+", lines)[1]
    name <- if (!is.na(name_line)) {
      gsub("^#\\s+", "", lines[name_line])
    } else {
      tools::file_path_sans_ext(basename(file_path))
    }

    # Extract description
    desc_line <- grep("^\\*\\*Description\\*\\*:", lines, ignore.case = TRUE)
    description <- if (length(desc_line) > 0) {
      gsub("^\\*\\*Description\\*\\*:\\s*", "", lines[desc_line[1]], ignore.case = TRUE)
    } else {
      "No description provided"
    }

    # Extract auto-invoke setting
    auto_line <- grep("^\\*\\*Auto-invoke\\*\\*:", lines, ignore.case = TRUE)
    auto_invoke <- if (length(auto_line) > 0) {
      grepl("yes|true", lines[auto_line[1]], ignore.case = TRUE)
    } else {
      TRUE  # Default to auto-invoke
    }

    # Extract dependencies
    requires_line <- grep("^\\*\\*Requires\\*\\*:", lines, ignore.case = TRUE)
    requires <- if (length(requires_line) > 0) {
      deps_text <- gsub("^\\*\\*Requires\\*\\*:\\s*", "",
                        lines[requires_line[1]], ignore.case = TRUE)
      trimws(strsplit(deps_text, ",")[[1]])
    } else {
      character(0)
    }

    list(
      name = name,
      description = description,
      auto_invoke = auto_invoke,
      requires = requires,
      file_path = file_path
    )
  }, error = function(e) {
    cli::cli_warn("Failed to parse skill file: {file_path}")
    NULL
  })
}

#' Load Full Skill Content
#'
#' Reads the complete content of a skill file and resolves dependencies.
#' This is only called when a skill is actually used (progressive disclosure).
#'
#' @param skill_name Character. Name of the skill to load
#' @param loaded_skills Character vector. Already loaded skills (prevents cycles)
#'
#' @return List with success, content, dependencies
#' @keywords internal
#' @noRd
.load_skill <- function(skill_name, loaded_skills = character()) {
  skills <- .discover_skills()

  # Check skill exists
  if (!skill_name %in% names(skills)) {
    return(list(
      success = FALSE,
      error = paste("Unknown skill:", skill_name),
      content = NULL,
      dependencies = character(0)
    ))
  }

  # Prevent circular dependencies
  if (skill_name %in% loaded_skills) {
    return(list(
      success = TRUE,
      content = paste0("[Skill '", skill_name, "' already loaded - skipped to prevent circular dependency]"),
      dependencies = character(0),
      circular = TRUE
    ))
  }

  skill <- skills[[skill_name]]

  # Load full skill content
  skill_content <- tryCatch({
    paste(readLines(skill$file_path, warn = FALSE), collapse = "\n")
  }, error = function(e) {
    return(list(
      success = FALSE,
      error = paste("Failed to read skill file:", e$message),
      content = NULL,
      dependencies = character(0)
    ))
  })

  # Load dependencies first (recursively)
  dependency_content <- list()
  if (length(skill$requires) > 0) {
    for (dep in skill$requires) {
      dep_result <- .load_skill(dep, c(loaded_skills, skill_name))
      if (dep_result$success && !isTRUE(dep_result$circular)) {
        dependency_content[[dep]] <- dep_result$content
      } else if (!dep_result$success) {
        cli::cli_warn(c(
          "Failed to load dependency {.field {dep}} for skill {.field {skill_name}}",
          "x" = dep_result$error
        ))
      }
    }
  }

  # Combine: dependencies first, then main skill
  full_content <- if (length(dependency_content) > 0) {
    dep_text <- sapply(names(dependency_content), function(dep_name) {
      paste0(
        "\n", strrep("=", 70), "\n",
        "DEPENDENCY: ", dep_name, "\n",
        strrep("=", 70), "\n\n",
        dependency_content[[dep_name]]
      )
    })

    paste0(
      "## Referenced Skills\n\n",
      "The following skills are dependencies for '", skill_name, "':\n\n",
      paste(dep_text, collapse = "\n\n"),
      "\n\n",
      strrep("=", 70), "\n",
      "MAIN SKILL: ", skill_name, "\n",
      strrep("=", 70), "\n\n",
      skill_content
    )
  } else {
    skill_content
  }

  list(
    success = TRUE,
    content = full_content,
    dependencies = skill$requires,
    circular = FALSE
  )
}
