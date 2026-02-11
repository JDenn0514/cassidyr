#' Setup skills context renderer
#' @keywords internal
setup_context_skills_renderer <- function(output, input, conv_manager) {
  # Render skill count
  output$skills_count_ui <- shiny::renderUI({
    # Only trigger on conversation change
    conv_current_id(conv_manager)

    # ISOLATE to prevent re-render on every checkbox change
    skills <- shiny::isolate(conv_context_skills(conv_manager))
    paste0("(", length(skills), " selected)")
  })

  # Render skills list
  output$context_skills_ui <- shiny::renderUI({
    # Trigger on conversation change
    conv_current_id(conv_manager)

    # Get all available skills
    all_skills <- cassidy_context_skills(location = "all", format = "list")

    if (length(all_skills) == 0) {
      return(shiny::div(
        class = "empty-state",
        shiny::icon("magic", class = "text-muted"),
        shiny::p("No skills found"),
        shiny::tags$small(
          class = "text-muted",
          "Create skills in .cassidy/skills/"
        )
      ))
    }

    # ISOLATE reactive reads
    selected_skills <- shiny::isolate(conv_context_skills(conv_manager))
    sent_skills <- shiny::isolate(conv_sent_skills(conv_manager))

    # Group skills by location
    project_skills <- Filter(function(s) {
      grepl(file.path(getwd(), ".cassidy/skills"), s$file_path, fixed = TRUE)
    }, all_skills)

    personal_skills <- Filter(function(s) {
      grepl(path.expand("~/.cassidy/skills"), s$file_path, fixed = TRUE)
    }, all_skills)

    # Build UI
    skill_items <- list()

    # Project skills section
    if (length(project_skills) > 0) {
      skill_items <- c(
        skill_items,
        list(shiny::div(
          class = "context-subsection-header",
          shiny::icon("folder-open", class = "text-primary"),
          " Project Skills"
        ))
      )

      for (skill_name in names(project_skills)) {
        skill <- project_skills[[skill_name]]
        skill_items <- c(skill_items, list(.render_skill_item(
          skill_name,
          skill,
          selected_skills,
          sent_skills
        )))
      }
    }

    # Personal skills section
    if (length(personal_skills) > 0) {
      skill_items <- c(
        skill_items,
        list(shiny::div(
          class = "context-subsection-header mt-2",
          shiny::icon("user", class = "text-info"),
          " Personal Skills"
        ))
      )

      for (skill_name in names(personal_skills)) {
        skill <- personal_skills[[skill_name]]
        skill_items <- c(skill_items, list(.render_skill_item(
          skill_name,
          skill,
          selected_skills,
          sent_skills
        )))
      }
    }

    shiny::tagList(skill_items)
  })
}


#' Render a single skill item
#' @keywords internal
.render_skill_item <- function(
  skill_name,
  skill,
  selected_skills,
  sent_skills
) {
  skill_id <- gsub("[^a-zA-Z0-9]", "_", skill_name)
  is_selected <- skill_name %in% selected_skills
  is_sent <- skill_name %in% sent_skills

  # Determine status class
  status_class <- if (is_sent) {
    "skill-sent"
  } else if (is_selected) {
    "skill-pending"
  } else {
    ""
  }

  # Auto-invoke badge
  auto_badge <- if (skill$auto_invoke) {
    shiny::tags$span(
      class = "badge bg-success ms-1",
      style = "font-size: 0.7em;",
      "auto"
    )
  } else {
    NULL
  }

  # Dependencies note
  deps_note <- if (length(skill$requires) > 0) {
    shiny::tags$small(
      class = "text-muted d-block",
      style = "font-size: 0.75em; margin-left: 24px;",
      paste0("requires: ", paste(skill$requires, collapse = ", "))
    )
  } else {
    NULL
  }

  shiny::div(
    class = paste("context-item", status_class),
    shiny::div(
      class = "context-item-main",
      shiny::checkboxInput(
        paste0("ctx_skill_", skill_id),
        shiny::tagList(
          shiny::icon("magic"),
          " ",
          skill_name,
          auto_badge
        ),
        value = is_selected
      ),
      shiny::tags$small(
        class = "text-muted d-block",
        style = "font-size: 0.8em; margin-left: 24px; margin-top: -8px;",
        skill$description
      ),
      deps_note
    ),
    if (is_sent) {
      shiny::actionButton(
        paste0("refresh_skill_", skill_id),
        shiny::icon("sync"),
        class = "btn-icon-xs",
        title = "Refresh this skill"
      )
    } else {
      NULL
    }
  )
}


#' Setup skill selection handlers
#' @keywords internal
setup_skill_selection_handlers <- function(input, session, conv_manager) {
  # ========================================
  # Handle checkbox changes for skills
  # ========================================
  shiny::observe({
    all_skills <- cassidy_context_skills(location = "all", format = "list")

    lapply(names(all_skills), function(skill_name) {
      skill_id <- gsub("[^a-zA-Z0-9]", "_", skill_name)
      input_id <- paste0("ctx_skill_", skill_id)

      shiny::observeEvent(
        input[[input_id]],
        {
          is_checked <- isTRUE(input[[input_id]])
          current_skills <- conv_context_skills(conv_manager)

          if (is_checked) {
            # Add skill if not already present
            if (!skill_name %in% current_skills) {
              new_skills <- c(current_skills, skill_name)
              conv_set_context_skills(conv_manager, new_skills)

              # Update conversation WITHOUT triggering auto-save
              conv <- conv_get_current(conv_manager)
              if (!is.null(conv)) {
                conv$context_skills <- new_skills
              }

              cli::cli_alert_info("Added skill to context: {.field {skill_name}}")
            }
          } else {
            # Remove skill
            new_skills <- setdiff(current_skills, skill_name)
            conv_set_context_skills(conv_manager, new_skills)

            # Update conversation WITHOUT triggering auto-save
            conv <- conv_get_current(conv_manager)
            if (!is.null(conv)) {
              conv$context_skills <- new_skills
            }

            cli::cli_alert_info("Removed skill from context: {.field {skill_name}}")
          }
        },
        ignoreInit = TRUE
      )
    })
  })

  # ========================================
  # Individual skill refresh handlers
  # ========================================
  shiny::observe({
    all_skills <- cassidy_context_skills(location = "all", format = "list")

    lapply(names(all_skills), function(skill_name) {
      skill_id <- gsub("[^a-zA-Z0-9]", "_", skill_name)
      refresh_id <- paste0("refresh_skill_", skill_id)

      shiny::observeEvent(
        input[[refresh_id]],
        {
          # Check if skill has been sent
          sent_skills <- conv_sent_skills(conv_manager)

          if (!(skill_name %in% sent_skills)) {
            shiny::showNotification(
              paste(
                skill_name,
                "hasn't been sent yet. Select it and click 'Apply Context'."
              ),
              type = "warning",
              duration = 3
            )
            return()
          }

          # Add to pending refresh queue
          current_pending <- conv_pending_refresh_skills(conv_manager)
          conv_set_pending_refresh_skills(
            conv_manager,
            union(current_pending, skill_name)
          )

          shiny::showNotification(
            paste(
              skill_name,
              "queued for refresh - click 'Apply Context' to send"
            ),
            type = "message",
            duration = 3
          )

          cli::cli_alert_info("Queued skill for refresh: {skill_name}")
        },
        ignoreInit = TRUE
      )
    })
  })
}
