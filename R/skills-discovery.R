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
#' Reads YAML frontmatter from a skill file and extracts metadata fields.
#' Skills must have YAML frontmatter at the beginning of the file.
#'
#' @param file_path Character. Path to skill .md file
#'
#' @return List with name, description, auto_invoke, requires, file_path
#' @keywords internal
#' @noRd
.parse_skill_metadata <- function(file_path) {
  tryCatch({
    # Read file content
    content <- readLines(file_path, warn = FALSE)

    # Expect YAML frontmatter (starts with ---)
    if (length(content) == 0 || content[1] != "---") {
      cli::cli_abort(c(
        "x" = "Invalid skill file format: {.file {basename(file_path)}}",
        "i" = "Skills must start with YAML frontmatter",
        "i" = "Expected first line: {.code ---}"
      ))
    }

    # Find closing ---
    yaml_end <- which(content == "---")[2]

    if (is.na(yaml_end) || yaml_end < 2) {
      cli::cli_abort(c(
        "x" = "Malformed YAML frontmatter in: {.file {basename(file_path)}}",
        "i" = "YAML block must be closed with {.code ---} on its own line"
      ))
    }

    # Extract and parse YAML block
    yaml_lines <- content[2:(yaml_end - 1)]
    yaml_text <- paste(yaml_lines, collapse = "\n")
    metadata <- yaml::yaml.load(yaml_text)

    # Validate required fields
    if (is.null(metadata$description)) {
      cli::cli_abort(c(
        "x" = "Missing required field in: {.file {basename(file_path)}}",
        "i" = "YAML frontmatter must include {.field description}"
      ))
    }

    # Extract fields with defaults
    list(
      name = metadata$name %||% tools::file_path_sans_ext(basename(file_path)),
      description = metadata$description,
      auto_invoke = metadata$auto_invoke %||% TRUE,
      requires = metadata$requires %||% character(0),
      file_path = file_path
    )

  }, error = function(e) {
    # If already a cli error, re-throw it
    if (inherits(e, "rlang_error")) {
      stop(e)
    }
    # Otherwise, wrap in a more helpful error
    cli::cli_abort(c(
      "x" = "Failed to parse skill file: {.file {basename(file_path)}}",
      "i" = "Error: {e$message}"
    ))
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

  # Load full skill content (strip YAML frontmatter)
  skill_content <- tryCatch({
    lines <- readLines(skill$file_path, warn = FALSE)

    # Strip YAML frontmatter if present
    if (length(lines) > 0 && lines[1] == "---") {
      yaml_end <- which(lines == "---")[2]
      if (!is.na(yaml_end)) {
        lines <- lines[(yaml_end + 1):length(lines)]
      }
    }

    paste(lines, collapse = "\n")
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
