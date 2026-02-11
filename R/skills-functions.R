# ══════════════════════════════════════════════════════════════════════════════
# SKILLS FUNCTIONS - User-Facing Skill Management
# List, use, and manage skills
# ══════════════════════════════════════════════════════════════════════════════

#' List Available Skills
#'
#' Displays all available skills from project and personal locations.
#' Shows skill name, description, invocation mode, location, and dependencies.
#'
#' @param location Character. "all" (default), "project", or "personal"
#'
#' @return Invisibly returns character vector of skill names
#' @export
#'
#' @examples
#' \dontrun{
#' # See all available skills
#' cassidy_list_skills()
#'
#' # Just project skills
#' cassidy_list_skills(location = "project")
#'
#' # Get skill names programmatically
#' skills <- cassidy_list_skills()
#' }
cassidy_list_skills <- function(location = c("all", "project", "personal")) {
  location <- match.arg(location)

  skills <- cassidy_context_skills(location = location, format = "list")

  if (length(skills) == 0) {
    cli::cli_alert_info("No skills found")
    if (location == "all") {
      cli::cli_text("")
      cli::cli_text("Create skills in:")
      cli::cli_ul(c(
        "Project: {.path .cassidy/skills/my-skill.md}",
        "Personal: {.path ~/.cassidy/skills/my-skill.md}"
      ))
    }
    return(invisible(character(0)))
  }

  cli::cli_h2("Available Skills ({length(skills)})")
  cli::cli_text("")

  # Group by location
  project_skills <- Filter(function(s) {
    grepl(file.path(getwd(), ".cassidy/skills"), s$file_path, fixed = TRUE)
  }, skills)

  personal_skills <- Filter(function(s) {
    grepl(path.expand("~/.cassidy/skills"), s$file_path, fixed = TRUE)
  }, skills)

  # Show project skills
  if (length(project_skills) > 0) {
    cli::cli_h3("Project Skills")
    for (name in names(project_skills)) {
      skill <- project_skills[[name]]
      .print_skill_summary(name, skill)
    }
    cli::cli_text("")
  }

  # Show personal skills
  if (length(personal_skills) > 0) {
    cli::cli_h3("Personal Skills")
    for (name in names(personal_skills)) {
      skill <- personal_skills[[name]]
      .print_skill_summary(name, skill)
    }
    cli::cli_text("")
  }

  cli::cli_text("Use {.run cassidy_use_skill('skill-name')} to preview a skill")
  cli::cli_text("Use {.run cassidy_use_skill('skill-name', task = 'your task')} to use a skill")

  invisible(names(skills))
}

#' Print Skill Summary
#' @keywords internal
#' @noRd
.print_skill_summary <- function(name, skill) {
  # Icon based on auto-invoke
  icon <- if (skill$auto_invoke) {
    cli::col_green(cli::symbol$tick)
  } else {
    cli::col_silver(cli::symbol$circle)
  }

  # Dependencies note
  deps <- if (length(skill$requires) > 0) {
    paste0(" {.emph (requires: ", paste(skill$requires, collapse = ", "), ")}")
  } else {
    ""
  }

  cli::cli_text(paste0(
    icon, " {.field ", name, "}: ", skill$description, deps
  ))
}

#' Use a Skill
#'
#' Load and optionally execute a skill. Skills are loaded with all their
#' dependencies. Can preview skill content or execute with a task.
#'
#' @param skill_name Character. Name of the skill to use
#' @param task Character. Optional task to run with skill loaded
#' @param show_dependencies Logical. Show loaded dependencies? (default: TRUE)
#' @param ... Additional arguments passed to `cassidy_agentic_task()`
#'
#' @return If `task` is NULL, returns skill content invisibly. If `task` is
#'   provided, returns result from `cassidy_agentic_task()`
#' @export
#'
#' @examples
#' \dontrun{
#' # Preview a skill
#' cassidy_use_skill("efa-workflow")
#'
#' # Use skill for a task
#' result <- cassidy_use_skill("efa-workflow",
#'   task = "Analyze the personality_items dataset"
#' )
#'
#' # Use skill with specific tools
#' result <- cassidy_use_skill("efa-workflow",
#'   task = "Run EFA on survey_data",
#'   tools = c("read_file", "execute_code", "describe_data")
#' )
#' }
cassidy_use_skill <- function(
  skill_name,
  task = NULL,
  show_dependencies = TRUE,
  ...
) {
  # Load skill with dependencies
  skill_result <- .load_skill(skill_name)

  if (!skill_result$success) {
    cli::cli_abort(skill_result$error)
  }

  # Show what was loaded
  if (show_dependencies && length(skill_result$dependencies) > 0) {
    cli::cli_alert_info(
      "Loaded {.field {skill_name}} with dependencies: {.val {skill_result$dependencies}}"
    )
  }

  # If no task, just preview
  if (is.null(task)) {
    cat(skill_result$content)
    return(invisible(skill_result))
  }

  # Execute with task
  initial_context <- paste0(
    "# Active Skills\n\n",
    "The following skills have been loaded to help complete this task:\n\n",
    skill_result$content, "\n\n",
    strrep("-", 70), "\n\n",
    "Follow the workflows above to complete the task."
  )

  cassidy_agentic_task(
    task = task,
    initial_context = initial_context,
    ...
  )
}

#' Create a New Skill Template
#'
#' Creates a new skill file from a template, making it easy to add
#' custom workflows.
#'
#' @param name Character. Name of the skill (lowercase, hyphens allowed)
#' @param location Character. "project" (default) or "personal"
#' @param template Character. Template to use: "basic" (default), "analysis",
#'   or "workflow"
#'
#' @return Path to created file (invisibly)
#' @export
#'
#' @examples
#' \dontrun{
#' # Create a basic skill
#' cassidy_create_skill("my-workflow")
#'
#' # Create an analysis skill in personal location
#' cassidy_create_skill("custom-analysis",
#'   location = "personal",
#'   template = "analysis"
#' )
#' }
cassidy_create_skill <- function(
  name,
  location = c("project", "personal"),
  template = c("basic", "analysis", "workflow")
) {
  location <- match.arg(location)
  template <- match.arg(template)

  # Validate name
  if (!grepl("^[a-z0-9-]+$", name)) {
    cli::cli_abort(c(
      "Invalid skill name: {.val {name}}",
      "i" = "Skill names must be lowercase with hyphens only (e.g., 'my-skill')"
    ))
  }

  # Determine directory
  skill_dir <- if (location == "project") {
    file.path(getwd(), ".cassidy/skills")
  } else {
    path.expand("~/.cassidy/skills")
  }

  # Create directory if needed
  if (!dir.exists(skill_dir)) {
    dir.create(skill_dir, recursive = TRUE)
  }

  # Create file path
  skill_file <- file.path(skill_dir, paste0(name, ".md"))

  if (file.exists(skill_file)) {
    cli::cli_abort(c(
      "Skill already exists: {.path {skill_file}}",
      "i" = "Choose a different name or edit the existing skill"
    ))
  }

  # Get template content
  skill_content <- .get_skill_template(name, template)

  # Write file
  writeLines(skill_content, skill_file)

  cli::cli_alert_success("Created skill: {.path {skill_file}}")
  cli::cli_text("")
  cli::cli_text("Next steps:")
  cli::cli_ol(c(
    "Edit the skill file to add your workflow",
    "Test with: {.run cassidy_use_skill('{name}')}",
    "Use in tasks: {.run cassidy_use_skill('{name}', task = 'your task')}"
  ))

  invisible(skill_file)
}

#' Get Skill Template Content
#' @keywords internal
#' @noRd
.get_skill_template <- function(name, template) {
  # Convert name to title case for display
  title <- gsub("-", " ", name)
  title <- paste(toupper(substring(title, 1, 1)), substring(title, 2), sep = "")

  if (template == "basic") {
    return(c(
      paste0("# ", title),
      "",
      "**Description**: Brief description of what this skill does and when to use it",
      "**Auto-invoke**: yes",
      "",
      "---",
      "",
      "## When to Use This Skill",
      "",
      "Describe the scenarios when this skill should be used.",
      "",
      "## Workflow Steps",
      "",
      "1. **Step 1**: Description",
      "2. **Step 2**: Description",
      "3. **Step 3**: Description",
      "",
      "## Example",
      "",
      "```r",
      "# Example R code",
      "```",
      "",
      "## Output Format",
      "",
      "Describe the expected output or deliverables."
    ))
  } else if (template == "analysis") {
    return(c(
      paste0("# ", title),
      "",
      "**Description**: Custom analysis workflow",
      "**Auto-invoke**: yes",
      "**Requires**: ",
      "",
      "---",
      "",
      "## Analysis Overview",
      "",
      "Describe the analysis this skill performs.",
      "",
      "## Prerequisites",
      "",
      "- Data requirements",
      "- Required packages",
      "- Assumptions",
      "",
      "## Analysis Steps",
      "",
      "1. **Data Preparation**",
      "   - Check data quality",
      "   - Handle missing values",
      "   - Transform variables",
      "",
      "2. **Main Analysis**",
      "   - Describe analytical approach",
      "   - Key statistical tests",
      "   - Model specifications",
      "",
      "3. **Results Interpretation**",
      "   - What to look for",
      "   - How to interpret findings",
      "   - Common issues",
      "",
      "## Example",
      "",
      "```r",
      "# Load data",
      "data <- read.csv(\"data.csv\")",
      "",
      "# Run analysis",
      "# ...",
      "```",
      "",
      "## Expected Output",
      "",
      "- Summary statistics",
      "- Test results",
      "- Visualizations",
      "- Interpretation guide"
    ))
  } else {  # workflow
    return(c(
      paste0("# ", title),
      "",
      "**Description**: Multi-step workflow for complex tasks",
      "**Auto-invoke**: no",
      "**Requires**: ",
      "",
      "---",
      "",
      "## Workflow Purpose",
      "",
      "Describe what this workflow accomplishes.",
      "",
      "## Workflow Phases",
      "",
      "### Phase 1: Preparation",
      "- [ ] Task 1",
      "- [ ] Task 2",
      "- [ ] Task 3",
      "",
      "### Phase 2: Execution",
      "- [ ] Task 1",
      "- [ ] Task 2",
      "- [ ] Task 3",
      "",
      "### Phase 3: Validation",
      "- [ ] Task 1",
      "- [ ] Task 2",
      "- [ ] Task 3",
      "",
      "### Phase 4: Finalization",
      "- [ ] Task 1",
      "- [ ] Task 2",
      "- [ ] Task 3",
      "",
      "## Quality Checks",
      "",
      "- Check 1",
      "- Check 2",
      "- Check 3",
      "",
      "## Deliverables",
      "",
      "List what should be produced:",
      "- Deliverable 1",
      "- Deliverable 2",
      "- Deliverable 3"
    ))
  }
}
