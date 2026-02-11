#' Setup context data renderer
#' @keywords internal
setup_context_data_renderer <- function(output, input, conv_manager) {
  # Render data count
  output$data_count_ui <- shiny::renderUI({
    # Trigger refresh when button clicked
    input$refresh_all_context
    input$refresh_data

    dfs <- .get_env_dataframes()
    paste0("(", length(dfs), ")")
  })

  # Render data frame list
  output$context_data_ui <- shiny::renderUI({
    # Trigger refresh
    input$refresh_all_context
    input$refresh_data

    dfs <- .get_env_dataframes()

    if (length(dfs) == 0) {
      return(shiny::div(
        class = "no-data-message",
        shiny::icon("database"),
        shiny::br(),
        "No data frames in environment"
      ))
    }

    lapply(names(dfs), function(df_name) {
      df_info <- dfs[[df_name]]
      input_id <- paste0("ctx_data_", gsub("[^a-zA-Z0-9]", "_", df_name))
      refresh_id <- paste0("refresh_data_", gsub("[^a-zA-Z0-9]", "_", df_name))

      shiny::div(
        class = "context-data-item",
        id = paste0("data_item_", gsub("[^a-zA-Z0-9]", "_", df_name)),
        shiny::checkboxInput(
          input_id,
          shiny::tagList(
            shiny::div(
              class = "data-info",
              shiny::span(class = "data-name", df_name),
              shiny::span(
                class = "data-dims",
                paste0(df_info$rows, " x ", df_info$cols)
              )
            )
          ),
          value = FALSE
        ),
        shiny::actionButton(
          refresh_id,
          shiny::icon("sync"),
          class = "btn-icon-xs",
          title = paste("Refresh", df_name)
        )
      )
    })
  })
}

#' Setup context summary renderer
#' @keywords internal
setup_context_summary_renderer <- function(output, input, conv_manager) {
  output$context_summary <- shiny::renderUI({
    # Count selected project items
    config_selected <- isTRUE(input$ctx_config)
    session_selected <- isTRUE(input$ctx_session)
    git_selected <- isTRUE(input$ctx_git)

    project_items <- c()
    if (config_selected) {
      project_items <- c(project_items, "cassidy.md")
    }
    if (session_selected) {
      project_items <- c(project_items, "R session")
    }
    if (git_selected) {
      project_items <- c(project_items, "Git")
    }

    # Count selected data frames
    dfs <- .get_env_dataframes()
    data_items <- c()
    for (df_name in names(dfs)) {
      input_id <- paste0("ctx_data_", gsub("[^a-zA-Z0-9]", "_", df_name))
      if (isTRUE(input[[input_id]])) {
        data_items <- c(data_items, df_name)
      }
    }

    # Get files without triggering reactivity
    file_items <- shiny::isolate(conv_context_files(conv_manager))

    # Get skills without triggering reactivity
    skill_items <- shiny::isolate(conv_context_skills(conv_manager))

    # Check if context has been applied
    context_applied <- !is.null(conv_context_text(conv_manager))

    shiny::div(
      shiny::div(
        class = "summary-title",
        shiny::icon("layer-group"),
        "Selected Context",
        if (context_applied) {
          shiny::span(
            class = "context-applied-badge",
            shiny::icon("check"),
            "Applied"
          )
        }
      ),
      shiny::div(
        class = "summary-items",
        shiny::div(
          class = paste(
            "summary-item",
            if (length(project_items) > 0) "has-items" else "no-items"
          ),
          shiny::icon(
            if (length(project_items) > 0) "check-circle" else "circle"
          ),
          paste0(
            "Project: ",
            if (length(project_items) > 0) {
              paste(project_items, collapse = ", ")
            } else {
              "none"
            }
          )
        ),
        shiny::div(
          class = paste(
            "summary-item",
            if (length(data_items) > 0) "has-items" else "no-items"
          ),
          shiny::icon(
            if (length(data_items) > 0) "check-circle" else "circle"
          ),
          paste0(
            "Data: ",
            if (length(data_items) > 0) {
              paste(data_items, collapse = ", ")
            } else {
              "none"
            }
          )
        ),
        shiny::div(
          class = paste(
            "summary-item",
            if (length(file_items) > 0) "has-items" else "no-items"
          ),
          shiny::icon(
            if (length(file_items) > 0) "check-circle" else "circle"
          ),
          paste0(
            "Files: ",
            if (length(file_items) > 0) {
              paste(basename(file_items), collapse = ", ")
            } else {
              "none"
            }
          )
        ),
        shiny::div(
          class = paste(
            "summary-item",
            if (length(skill_items) > 0) "has-items" else "no-items"
          ),
          shiny::icon(
            if (length(skill_items) > 0) "check-circle" else "circle"
          ),
          paste0(
            "Skills: ",
            if (length(skill_items) > 0) {
              paste(skill_items, collapse = ", ")
            } else {
              "none"
            }
          )
        )
      )
    )
  })
}
