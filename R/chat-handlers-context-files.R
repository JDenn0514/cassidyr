#' Setup file context display renderer
#' @keywords internal
setup_file_context_renderer <- function(output, conv_manager) {
  output$context_files_display <- shiny::renderUI({
    files <- conv_context_files(conv_manager)

    if (length(files) == 0) {
      return(shiny::tags$small(
        class = "text-muted",
        shiny::icon("info-circle"),
        " No files in context. Click 'Manage Files' to add files."
      ))
    }

    shiny::div(
      shiny::tags$small(
        shiny::icon("file-code"),
        " Files in context:"
      ),
      lapply(files, function(f) {
        file_id <- gsub("[^a-zA-Z0-9]", "_", f)
        shiny::span(
          class = "context-file-badge",
          basename(f),
          shiny::actionButton(
            paste0("refresh_", file_id),
            shiny::icon("sync"),
            class = "btn-icon-sm",
            title = "Refresh this file"
          ),
          shiny::actionButton(
            paste0("remove_", file_id),
            shiny::icon("times"),
            class = "btn-icon-sm",
            title = "Remove this file"
          )
        )
      })
    )
  })
}


#' Setup file context handlers
#' @keywords internal
setup_file_context_handlers <- function(
  input,
  session,
  conv_manager,
  assistant_id,
  api_key,
  timeout
) {
  # File management modal
  setup_file_management_handler(
    input,
    session,
    conv_manager,
    assistant_id,
    api_key,
    timeout
  )

  # Individual file removal
  setup_file_removal_handlers(input, session, conv_manager)

  # File refresh handlers
  shiny::observe({
    files <- conv_context_files(conv_manager)

    lapply(files, function(f) {
      file_id <- gsub("[^a-zA-Z0-9]", "_", f)
      button_id <- paste0("refresh_", file_id)

      shiny::observeEvent(
        input[[button_id]],
        {
          tryCatch(
            {
              file_ctx <- cassidy_describe_file(f)

              file_message <- paste0(
                "**System:** Refreshed context from `",
                basename(f),
                "`\n\n",
                "*The assistant now has the latest version of this file.*"
              )

              context_message <- paste0(
                "# Refreshed File Context\n\n",
                file_ctx$text,
                "\n\n---\n\n",
                "The user has updated this file. ",
                "Please acknowledge that you have the latest version."
              )

              conv <- conv_get_current(conv_manager)
              if (!is.null(conv) && !is.null(conv$thread_id)) {
                conv_add_message(conv_manager, "system", file_message)

                response <- cassidy_send_message(
                  thread_id = conv$thread_id,
                  message = context_message,
                  api_key = api_key,
                  timeout = timeout
                )

                conv_add_message(conv_manager, "assistant", response$content)
              }

              shiny::showNotification(
                paste("Refreshed", basename(f)),
                type = "message",
                duration = 2
              )
              cli::cli_alert_success("Refreshed file context: {f}")
            },
            error = function(e) {
              shiny::showNotification(
                paste("Error refreshing file:", e$message),
                type = "error",
                duration = 5
              )
            }
          )
        },
        ignoreInit = TRUE
      )
    })
  })
}


#' Setup file management modal handler
#' @keywords internal
setup_file_management_handler <- function(
  input,
  session,
  conv_manager,
  assistant_id,
  api_key,
  timeout
) {
  # Show file management modal
  shiny::observeEvent(input$add_files, {
    # Get available R files
    available_files <- as.character(fs::dir_ls(
      regexp = "\\.(R|Rmd|qmd|txt|md)$",
      recurse = TRUE,
      type = "file"
    ))

    # Get currently selected files
    current_files <- conv_context_files(conv_manager)

    shiny::showModal(
      shiny::modalDialog(
        title = "Manage Context Files",
        size = "l",
        shiny::div(
          shiny::p("Select files to include in the conversation context:"),
          shiny::checkboxGroupInput(
            "selected_files",
            label = NULL,
            choices = stats::setNames(available_files, available_files),
            selected = current_files
          ),
          shiny::hr(),
          shiny::tags$small(
            class = "text-muted",
            shiny::icon("info-circle"),
            " Files will be read and sent to the assistant when you click 'Apply'."
          )
        ),
        footer = shiny::tagList(
          shiny::modalButton("Cancel"),
          shiny::actionButton(
            "apply_file_changes",
            "Apply",
            class = "btn-primary"
          )
        )
      )
    )
  })

  # Apply file changes
  shiny::observeEvent(input$apply_file_changes, {
    selected <- input$selected_files
    current <- conv_context_files(conv_manager)

    # Determine what changed
    added_files <- setdiff(selected, current)
    removed_files <- setdiff(current, selected)

    # Handle added files
    if (length(added_files) > 0) {
      # Ensure we have a conversation
      if (is.null(conv_current_id(conv_manager))) {
        conv_create_new(conv_manager, session)
      }

      tryCatch(
        {
          # Gather context from all new files
          file_contexts <- lapply(added_files, function(f) {
            if (fs::file_exists(f)) {
              cassidy_describe_file(f)
            } else {
              NULL
            }
          })

          # Remove NULL entries
          file_contexts <- Filter(Negate(is.null), file_contexts)

          if (length(file_contexts) > 0) {
            # Create combined message
            file_list <- paste(basename(added_files), collapse = ", ")

            file_message <- paste0(
              "**System:** Added context from ",
              length(added_files),
              " file(s): ",
              file_list,
              "\n\n",
              "*The assistant now has access to these files' contents.*"
            )

            # Combine all file contexts
            combined_context <- paste(
              sapply(file_contexts, function(ctx) ctx$text),
              collapse = "\n\n---\n\n"
            )

            context_message <- paste0(
              "# New File Context\n\n",
              combined_context,
              "\n\n---\n\n",
              "The user has shared ",
              length(added_files),
              " file(s). ",
              "Please acknowledge and be ready to discuss or modify this code."
            )

            conv_add_message(conv_manager, "system", file_message)

            # Get or create thread
            conv <- conv_get_current(conv_manager)
            thread_id <- conv$thread_id

            if (is.null(thread_id)) {
              thread_id <- cassidy_create_thread(
                assistant_id = assistant_id,
                api_key = api_key
              )
              conv_update_current(conv_manager, list(thread_id = thread_id))
            }

            # Send to API
            response <- cassidy_send_message(
              thread_id = thread_id,
              message = context_message,
              api_key = api_key,
              timeout = timeout
            )

            conv_add_message(conv_manager, "assistant", response$content)

            cli::cli_alert_success(
              "Added {length(added_files)} file{?s} to context"
            )
          }
        },
        error = function(e) {
          shiny::showNotification(
            paste("Error adding files:", e$message),
            type = "error",
            duration = 5
          )
        }
      )
    }

    # Handle removed files
    if (length(removed_files) > 0) {
      file_list <- paste(basename(removed_files), collapse = ", ")

      removal_message <- paste0(
        "**System:** Removed ",
        length(removed_files),
        " file(s) from context: ",
        file_list
      )

      conv_add_message(conv_manager, "system", removal_message)

      cli::cli_alert_info(
        "Removed {length(removed_files)} file{?s} from context"
      )
    }

    # Update the stored files list
    conv_set_context_files(conv_manager, selected)
    conv_update_current(conv_manager, list(context_files = selected))

    # Show notification
    if (length(added_files) > 0 || length(removed_files) > 0) {
      shiny::showNotification(
        "File context updated",
        type = "message",
        duration = 3
      )
    }

    shiny::removeModal()
  })
}

#' Setup individual file removal handlers
#' @keywords internal
setup_file_removal_handlers <- function(
  input,
  session,
  conv_manager
) {
  shiny::observe({
    files <- conv_context_files(conv_manager)

    lapply(files, function(f) {
      file_id <- gsub("[^a-zA-Z0-9]", "_", f)
      button_id <- paste0("remove_", file_id)

      shiny::observeEvent(
        input[[button_id]],
        {
          # Remove file from list
          remaining_files <- setdiff(conv_context_files(conv_manager), f)
          conv_set_context_files(conv_manager, remaining_files)
          conv_update_current(
            conv_manager,
            list(context_files = remaining_files)
          )

          # Add system message
          removal_message <- paste0(
            "**System:** Removed `",
            basename(f),
            "` from context"
          )
          conv_add_message(conv_manager, "system", removal_message)

          shiny::showNotification(
            paste("Removed", basename(f)),
            type = "message",
            duration = 2
          )
          cli::cli_alert_info("Removed file from context: {f}")
        },
        ignoreInit = TRUE
      )
    })
  })
}

#' Setup file request confirmation handler
#' @keywords internal
setup_file_request_handler <- function(
  input,
  session,
  conv_manager,
  assistant_id,
  api_key,
  timeout
) {
  shiny::observeEvent(input$send_requested_files, {
    # Remove notification
    shiny::removeNotification("file_request_notification")

    # Parse requested files
    requested_files <- strsplit(input$send_requested_files, ",")[[1]]

    cli::cli_alert_info(
      "Sending {length(requested_files)} requested file(s)..."
    )

    # Gather full content
    file_contexts <- lapply(requested_files, function(f) {
      if (fs::file_exists(f)) {
        cassidy_describe_file(f) # Full content
      } else {
        NULL
      }
    })

    file_contexts <- Filter(Negate(is.null), file_contexts)

    if (length(file_contexts) > 0) {
      # Combine file contents
      combined_context <- paste(
        sapply(file_contexts, function(ctx) ctx$text),
        collapse = "\n\n---\n\n"
      )

      # Create message
      file_message <- paste0(
        "# Requested Files\n\n",
        combined_context,
        "\n\n---\n\n",
        "Here are the complete file contents you requested. ",
        "Please provide your detailed analysis."
      )

      # Add system message to UI
      conv_add_message(
        conv_manager,
        "system",
        sprintf(
          "**System:** Sent full content of %d file(s) to assistant",
          length(file_contexts)
        )
      )

      # Send to Cassidy
      conv_set_loading(conv_manager, TRUE)
      session$sendCustomMessage("setLoading", TRUE)

      tryCatch(
        {
          conv <- conv_get_current(conv_manager)

          response <- cassidy_send_message(
            thread_id = conv$thread_id,
            message = file_message,
            api_key = api_key,
            timeout = timeout
          )

          # Add response
          conv_add_message(conv_manager, "assistant", response$content)

          conv_set_loading(conv_manager, FALSE)
          session$sendCustomMessage("setLoading", FALSE)
          session$sendCustomMessage("scrollToBottom", list())

          cli::cli_alert_success("Cassidy reviewed requested files")
        },
        error = function(e) {
          conv_set_loading(conv_manager, FALSE)
          session$sendCustomMessage("setLoading", FALSE)

          shiny::showNotification(
            paste("Error sending files:", e$message),
            type = "error",
            duration = 5
          )
        }
      )
    }
  })
}


#' Setup file selection handlers
#' @keywords internal
setup_file_selection_handlers <- function(input, session, conv_manager) {
  # ========================================
  # Handle checkbox changes (NO SAVE)
  # ========================================
  shiny::observeEvent(
    input$file_checkbox_changed,
    {
      change_data <- input$file_checkbox_changed

      if (is.null(change_data) || is.null(change_data$filePath)) {
        return()
      }

      file_path <- change_data$filePath
      is_checked <- isTRUE(change_data$checked)

      # Get current context files
      current_files <- conv_context_files(conv_manager)

      # Update the list
      if (is_checked) {
        # Add file if not already present
        if (!file_path %in% current_files) {
          new_files <- c(current_files, file_path)
          conv_set_context_files(conv_manager, new_files)

          # Update conversation WITHOUT triggering auto-save
          conv <- conv_get_current(conv_manager)
          if (!is.null(conv)) {
            conv$context_files <- new_files
          }

          cli::cli_alert_info("Added file to context: {.file {file_path}}")
        }
      } else {
        # Remove file
        new_files <- setdiff(current_files, file_path)
        conv_set_context_files(conv_manager, new_files)

        # Update conversation WITHOUT triggering auto-save
        conv <- conv_get_current(conv_manager)
        if (!is.null(conv)) {
          conv$context_files <- new_files
        }

        cli::cli_alert_info("Removed file from context: {.file {file_path}}")
      }
    },
    ignoreInit = TRUE
  )

  # ========================================
  # Refresh all files button
  # ========================================
  shiny::observeEvent(input$refresh_all_files, {
    # Queue all sent files for refresh
    sent_files <- conv_sent_context_files(conv_manager)
    conv_set_pending_refresh_files(conv_manager, sent_files)

    # Update visual state for all sent files - mark them as pending
    for (file in sent_files) {
      file_id <- gsub("[^a-zA-Z0-9]", "_", file)
      session$sendCustomMessage(
        "markFileAsPending",
        list(fileId = file_id)
      )
    }

    shiny::showNotification(
      paste0(
        "Queued ",
        length(sent_files),
        " file(s) for refresh - click 'Apply Context'"
      ),
      type = "message",
      duration = 3
    )
    cli::cli_alert_info("All sent files queued for refresh")
  })

  # ======================================================
  # Individual file refresh handlers - use isolate to prevent cascading reactivity
  # ======================================================
  shiny::observe({
    files <- shiny::isolate(.get_project_files())

    lapply(files, function(file) {
      file_id <- gsub("[^a-zA-Z0-9]", "_", file)
      refresh_id <- paste0("refresh_file_", file_id)

      shiny::observeEvent(
        input[[refresh_id]],
        {
          # Check if file has been sent
          sent_files <- conv_sent_context_files(conv_manager)

          if (!(file %in% sent_files)) {
            shiny::showNotification(
              paste(
                basename(file),
                "hasn't been sent yet. Select it and click 'Apply Context'."
              ),
              type = "warning",
              duration = 3
            )
            return()
          }

          # Add to pending refresh queue
          current_pending <- conv_pending_refresh_files(conv_manager)
          conv_set_pending_refresh_files(
            conv_manager,
            union(current_pending, file)
          )

          # Update visual state without re-rendering
          session$sendCustomMessage(
            "markFileAsPending",
            list(fileId = file_id)
          )

          shiny::showNotification(
            paste(
              basename(file),
              "queued for refresh - click 'Apply Context' to send"
            ),
            type = "message",
            duration = 3
          )

          cli::cli_alert_info("Queued file for refresh: {file}")
        },
        ignoreInit = TRUE
      )
    })
  })
}


#' Setup file tree renderer
#' @keywords internal
setup_file_tree_renderer <- function(output, input, conv_manager) {
  # Render file count
  output$files_count_ui <- shiny::renderUI({
    # Only trigger on conversation change
    conv_current_id(conv_manager)

    # ISOLATE to prevent re-render on every checkbox change
    files <- shiny::isolate(conv_context_files(conv_manager))
    paste0("(", length(files), " selected)")
  })

  output$context_files_tree_ui <- shiny::renderUI({
    # ONLY depend on force refresh and conversation changes
    # NOT on file selection changes
    input$force_file_tree_refresh
    conv_current_id(conv_manager)

    # Get ALL files (not reactive)
    available_files <- .get_project_files()

    # ISOLATE all the reactive reads - we'll handle styling via JS
    selected_files <- shiny::isolate(conv_context_files(conv_manager))
    sent_files <- shiny::isolate(conv_sent_context_files(conv_manager))
    pending_files <- shiny::isolate(conv_pending_refresh_files(conv_manager))

    if (length(available_files) == 0) {
      return(shiny::div(
        class = "file-tree-empty",
        shiny::div(class = "empty-icon", shiny::icon("folder-open")),
        "No files found in project"
      ))
    }

    # Build nested tree structure
    file_tree <- .build_file_tree_nested(available_files)

    # Render the tree
    tree_ui <- .render_file_tree_nested(
      file_tree,
      selected_files,
      sent_files = sent_files,
      pending_files = pending_files,
      path = "",
      level = 0
    )

    # Add controls at the top
    shiny::div(
      shiny::div(
        class = "file-tree-controls",
        shiny::actionButton(
          "expand_all_folders",
          shiny::icon("folder-open"),
          "Expand All",
          class = "btn btn-sm btn-outline-secondary"
        ),
        shiny::actionButton(
          "collapse_all_folders",
          shiny::icon("folder"),
          "Collapse All",
          class = "btn btn-sm btn-outline-secondary"
        )
      ),
      shiny::div(
        class = "file-tree-container",
        shiny::tagList(tree_ui)
      )
    )
  })
}
