#' Setup message rendering handlers
#' @keywords internal
#' Setup message rendering handlers
#' @keywords internal
setup_message_renderer <- function(output, conv_manager) {
  output$messages <- shiny::renderUI({
    conv <- conv_get_current(conv_manager)
    msg_list <- if (!is.null(conv)) conv$messages else list()
    context_text <- conv_context_text(conv_manager)

    # Welcome message when empty
    if (length(msg_list) == 0) {
      return(shiny::div(
        class = "text-center",
        style = "margin-top: 3rem;",
        shiny::icon("comments", class = "fa-3x text-muted mb-3"),
        shiny::h5("Welcome to Cassidy Chat!", class = "text-muted"),
        shiny::p(
          class = "text-muted",
          "Type a message below to start chatting."
        ),
        if (!is.null(context_text)) {
          shiny::p(
            class = "text-muted",
            shiny::tags$small(
              shiny::icon("check-circle", class = "text-success"),
              " Project context loaded and ready"
            )
          )
        }
      ))
    }

    # Render messages
    message_elements <- lapply(msg_list, function(msg) {
      shiny::div(
        class = paste0("message message-", msg$role),
        shiny::div(class = "message-role", msg$role),
        shiny::div(shiny::HTML(markdown::renderMarkdown(text = msg$content)))
      )
    })

    # Add loading indicator if needed
    if (conv_is_loading(conv_manager)) {
      message_elements[[length(message_elements) + 1]] <- shiny::div(
        class = "message message-assistant message-loading",
        shiny::div(class = "message-role", "assistant"),
        shiny::div(
          class = "loading-indicator",
          shiny::div(
            class = "loading-dots",
            shiny::span(class = "dot"),
            shiny::span(class = "dot"),
            shiny::span(class = "dot")
          ),
          shiny::div(
            class = "loading-text",
            "Cassidy is thinking..."
          )
        )
      )
    }

    message_elements
  })
}


#' Setup conversation list renderer
#' @keywords internal
setup_conversation_list_renderer <- function(output, conv_manager) {
  output$conversation_list <- shiny::renderUI({
    # Trigger re-render when conversations change
    convs <- conv_get_all(conv_manager)
    current_id <- conv_current_id(conv_manager)

    # Also get saved conversations from disk
    saved_convs <- cassidy_list_conversations(n = 8)

    # Combine in-memory and saved conversations
    all_conv_ids <- unique(c(
      vapply(convs, function(c) c$id, character(1)),
      saved_convs$id
    ))

    if (length(all_conv_ids) == 0) {
      return(shiny::div(
        class = "no-conversations",
        shiny::icon("comments", class = "fa-2x mb-2"),
        shiny::br(),
        "No conversations yet.",
        shiny::br(),
        shiny::tags$small("Start chatting to create one!")
      ))
    }

    # Create UI for each conversation
    lapply(all_conv_ids, function(conv_id) {
      # Try to get from memory first
      conv <- NULL
      for (c in convs) {
        if (c$id == conv_id) {
          conv <- c
          break
        }
      }

      # If not in memory, get from saved list
      if (is.null(conv)) {
        saved_idx <- which(saved_convs$id == conv_id)
        if (length(saved_idx) > 0) {
          conv <- list(
            id = saved_convs$id[saved_idx],
            title = saved_convs$title[saved_idx],
            created_at = saved_convs$created_at[saved_idx],
            updated_at = saved_convs$updated_at[saved_idx],
            messages = list()
          )
          conv$messages <- vector("list", saved_convs$message_count[saved_idx])
        }
      }

      if (is.null(conv)) {
        return(NULL)
      }

      is_active <- !is.null(current_id) && conv$id == current_id

      preview <- if (
        length(conv$messages) > 0 &&
          !is.null(conv$messages[[length(conv$messages)]]$content)
      ) {
        last_msg <- conv$messages[[length(conv$messages)]]
        substr(last_msg$content, 1, 60)
      } else {
        "No messages yet"
      }

      time_str <- format(
        conv$updated_at %||% conv$created_at,
        "%b %d, %H:%M"
      )

      shiny::div(
        class = paste("conversation-item", if (is_active) "active" else ""),
        onclick = sprintf(
          "Shiny.setInputValue('load_conversation', '%s', {priority: 'event'})",
          conv$id
        ),
        shiny::div(class = "conversation-title", conv$title),
        shiny::div(class = "conversation-preview", preview),
        shiny::div(class = "conversation-time", time_str),
        shiny::div(
          class = "conversation-actions",
          shiny::actionButton(
            paste0("export_conv_", gsub("[^a-zA-Z0-9]", "_", conv$id)),
            shiny::icon("download"),
            class = "btn btn-sm export-btn",
            title = "Export",
            onclick = sprintf(
              "event.stopPropagation(); Shiny.setInputValue('export_conversation', '%s', {priority: 'event'})",
              conv$id
            )
          ),
          shiny::actionButton(
            paste0("delete_conv_", gsub("[^a-zA-Z0-9]", "_", conv$id)),
            shiny::icon("trash"),
            class = "btn btn-sm delete-btn",
            title = "Delete",
            onclick = sprintf(
              "event.stopPropagation(); Shiny.setInputValue('delete_conversation', '%s', {priority: 'event'})",
              conv$id
            )
          )
        )
      )
    })
  })
}


#' Setup conversation loading from sidebar
#' @keywords internal
setup_conversation_load_handler <- function(input, session, conv_manager) {
  shiny::observeEvent(input$load_conversation, {
    conv_id <- input$load_conversation
    conv_load_and_set(conv_manager, conv_id, session)
  })
}

#' Setup conversation export handler
#' @keywords internal
setup_conversation_export_handler <- function(input, session, conv_manager) {
  shiny::observeEvent(input$export_conversation, {
    conv_id <- input$export_conversation

    tryCatch(
      {
        path <- cassidy_export_conversation(conv_id)
        shiny::showNotification(
          paste("Exported to", basename(path)),
          type = "message",
          duration = 5
        )
      },
      error = function(e) {
        shiny::showNotification(
          paste("Export failed:", e$message),
          type = "error",
          duration = 5
        )
      }
    )
  })
}


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


#' Setup conversation switching handler
#' @keywords internal
setup_conversation_switch_handler <- function(input, session, conv_manager) {
  shiny::observeEvent(input$switch_conversation, {
    conv_switch_to(conv_manager, input$switch_conversation, session)
  })
}

#' Setup conversation deletion handlers
#' @keywords internal
setup_conversation_delete_handlers <- function(input, session, conv_manager) {
  shiny::observeEvent(input$delete_conversation, {
    conv_id <- input$delete_conversation
    shiny::showModal(
      shiny::modalDialog(
        title = "Delete Conversation?",
        "This will permanently delete this conversation. Are you sure?",
        footer = shiny::tagList(
          shiny::modalButton("Cancel"),
          shiny::actionButton(
            "confirm_delete",
            "Delete",
            class = "btn-danger",
            onclick = sprintf(
              "Shiny.setInputValue('confirmed_delete_id', '%s', {priority: 'event'})",
              conv_id
            )
          )
        )
      )
    )
  })

  shiny::observeEvent(input$confirmed_delete_id, {
    conv_delete(conv_manager, input$confirmed_delete_id)
    shiny::removeModal()
  })
}

#' Setup new chat handler with context options modal
#' @keywords internal
setup_new_chat_handler <- function(input, session, conv_manager) {
  # Show modal when "New Chat" is clicked

  shiny::observeEvent(input$new_chat, {
    shiny::showModal(
      shiny::modalDialog(
        title = "Start New Conversation",
        easyClose = TRUE,
        footer = shiny::tagList(
          shiny::modalButton("Cancel"),
          shiny::actionButton(
            "confirm_new_chat",
            "Start Chat",
            class = "btn-primary"
          )
        ),

        shiny::selectInput(
          "new_chat_context_level",
          "Context Level",
          choices = c(
            "Standard" = "standard",
            "Minimal" = "minimal",
            "Comprehensive" = "comprehensive"
          ),
          selected = "standard"
        ),

        shiny::checkboxInput(
          "new_chat_include_data",
          "Include environment data (data frames in memory)",
          value = TRUE
        ),

        shiny::textAreaInput(
          "new_chat_include_files",
          "Additional files to include (one path per line)",
          value = "",
          rows = 3,
          placeholder = "R/analysis.R\ndata/codebook.md"
        ),

        shiny::helpText(
          shiny::tags$small(
            shiny::tags$strong("Context levels:"),
            shiny::tags$ul(
              shiny::tags$li(
                shiny::tags$strong("Minimal:"),
                " R session info only"
              ),
              shiny::tags$li(
                shiny::tags$strong("Standard:"),
                " + project config (cassidy.md), file structure"
              ),
              shiny::tags$li(
                shiny::tags$strong("Comprehensive:"),
                " + git status, full environment details"
              )
            )
          )
        )
      )
    )
  })
}

#' Setup handler for confirming new chat with context
#' @keywords internal
setup_new_chat_confirm_handler <- function(
  input,
  session,
  conv_manager,
  assistant_id,
  api_key,
  timeout
) {
  shiny::observeEvent(input$confirm_new_chat, {
    # Close modal
    shiny::removeModal()

    # Parse file paths
    file_paths <- NULL
    if (nzchar(trimws(input$new_chat_include_files))) {
      file_paths <- trimws(
        strsplit(input$new_chat_include_files, "\n")[[1]]
      )
      file_paths <- file_paths[nzchar(file_paths)]
    }

    # Gather context with user's settings
    cli::cli_alert_info(
      "Gathering context ({input$new_chat_context_level})..."
    )

    context_text <- gather_chat_context(
      context_level = input$new_chat_context_level,
      include_data = input$new_chat_include_data,
      include_files = file_paths
    )

    # Create new conversation
    conv_create_new(conv_manager, session)

    # Store context for this conversation
    conv_set_context(conv_manager, context_text)
    conv_set_context_sent(conv_manager, FALSE)

    cli::cli_alert_success("New conversation created with fresh context")
  })
}


#' Setup send message handler
#' @keywords internal
setup_send_message_handler <- function(
  input,
  session,
  conv_manager,
  assistant_id,
  api_key,
  timeout
) {
  send_message <- function() {
    user_message <- trimws(input$user_input)

    if (!nzchar(user_message)) {
      return()
    }
    if (conv_is_loading(conv_manager)) {
      return()
    }

    # Ensure we have a conversation
    if (is.null(conv_current_id(conv_manager))) {
      conv_create_new(conv_manager, session)
    }

    conv <- conv_get_current(conv_manager)
    if (is.null(conv)) {
      return()
    }

    # Add user message IMMEDIATELY
    conv_add_message(conv_manager, "user", user_message)

    # Update title if first message
    if (conv$title == "New Conversation") {
      new_title <- conv_generate_title(conv_manager, user_message)
      conv_update_current(conv_manager, list(title = new_title))
    }

    # Clear input, disable UI, and scroll IMMEDIATELY
    session$sendCustomMessage("clearInput", list())
    session$sendCustomMessage("setLoading", TRUE)
    session$sendCustomMessage("scrollToBottom", list())

    # Set loading state AFTER UI updates
    conv_set_loading(conv_manager, TRUE)

    # Get context - either from manager or gather from selections
    context_text <- conv_context_text(conv_manager)
    if (is.null(context_text)) {
      context_text <- gather_selected_context(input, conv_manager)
      if (!is.null(context_text)) {
        conv_set_context(conv_manager, context_text)
      }
    }

    # Context is already sent via "Apply Context" button, so just send user message
    message_to_send <- user_message

    # Send to Cassidy
    tryCatch(
      {
        conv <- conv_get_current(conv_manager)
        thread_id <- conv$thread_id

        if (is.null(thread_id)) {
          thread_id <- cassidy_create_thread(
            assistant_id = assistant_id,
            api_key = api_key
          )
          conv_update_current(conv_manager, list(thread_id = thread_id))
          cli::cli_alert_success("Created new conversation thread")
        }

        response <- cassidy_send_message(
          thread_id = thread_id,
          message = message_to_send,
          api_key = api_key,
          timeout = timeout
        )

        # Add assistant message
        conv_add_message(conv_manager, "assistant", response$content)

        # === NEW: CHECK FOR FILE REQUESTS AND AUTO-FETCH ===
        file_request <- .detect_file_requests(response$content)

        if (file_request$has_requests) {
          cli::cli_alert_info(
            "Cassidy requested {length(file_request$files)} file(s)"
          )

          # Get currently available files
          available_files <- conv_context_files(conv_manager)

          # Filter to files we actually have in context
          requested_and_available <- intersect(
            file_request$files,
            available_files
          )

          if (length(requested_and_available) > 0) {
            # Auto-send the requested files
            cli::cli_alert_info(
              "Auto-fetching {length(requested_and_available)} file(s)..."
            )

            # Build full file contexts
            file_contexts <- lapply(requested_and_available, function(f) {
              if (file.exists(f)) {
                cassidy_describe_file(f, level = "full") # Force FULL level
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

              # Create message with requested files
              file_message <- paste0(
                "# Requested Files\n\n",
                combined_context,
                "\n\n---\n\n",
                "Here are the complete file contents you requested. ",
                "Please provide your analysis."
              )

              # Add system message to UI
              conv_add_message(
                conv_manager,
                "system",
                sprintf(
                  "**System:** Auto-sent full content of %d file(s): %s",
                  length(file_contexts),
                  paste(basename(requested_and_available), collapse = ", ")
                )
              )

              # Send to Cassidy (recursive call)
              response2 <- cassidy_send_message(
                thread_id = thread_id,
                message = file_message,
                api_key = api_key,
                timeout = timeout
              )

              # Add Cassidy's response after reviewing files
              conv_add_message(conv_manager, "assistant", response2$content)

              cli::cli_alert_success("Cassidy reviewed requested files")
            }
          } else {
            # Requested files not in context
            cli::cli_alert_warning(
              "Cassidy requested files not in context: {paste(file_request$files, collapse = ', ')}"
            )
          }
        }

        conv_set_loading(conv_manager, FALSE)
        session$sendCustomMessage("setLoading", FALSE)
        session$sendCustomMessage("scrollToBottom", list())
      },
      error = function(e) {
        conv_add_message(
          conv_manager,
          "assistant",
          paste0(
            "**Error:** Could not get response from Cassidy.\n\n",
            "*",
            conditionMessage(e),
            "*\n\n",
            "Please try again or start a new chat."
          )
        )
        cli::cli_warn("API error: {e$message}")
        conv_set_loading(conv_manager, FALSE)
        session$sendCustomMessage("setLoading", FALSE)
      }
    )
  }

  shiny::observeEvent(input$send, {
    send_message()
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
    available_files <- list.files(
      pattern = "\\.(R|Rmd|qmd|txt|md)$",
      recursive = TRUE
    )

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
            if (file.exists(f)) {
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
      if (file.exists(f)) {
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
