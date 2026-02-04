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

    # Store context
    conv_set_context(conv_manager, context_text)
    conv_set_context_sent(conv_manager, FALSE)

    # === AUTO-SEND CONTEXT ===
    if (!is.null(context_text) && nzchar(context_text)) {
      # Show loading
      conv_set_loading(conv_manager, TRUE)
      session$sendCustomMessage("setLoading", TRUE)

      shiny::showNotification(
        "Sending context to Cassidy...",
        id = "context_sending",
        type = "message",
        duration = NULL
      )

      tryCatch(
        {
          # Create thread
          thread_id <- cassidy_create_thread(
            assistant_id = assistant_id,
            api_key = api_key
          )
          conv_update_current(conv_manager, list(thread_id = thread_id))
          cli::cli_alert_success("Created new conversation thread")

          # Send context
          context_message <- paste0(
            "# Project Context\n\n",
            context_text,
            "\n\n---\n\n",
            "I've shared my project context with you. Please acknowledge that you've received it ",
            "and let me know you're ready to help with this project."
          )

          response <- cassidy_send_message(
            thread_id = thread_id,
            message = context_message,
            api_key = api_key,
            timeout = timeout
          )

          # Add messages to UI
          conv_add_message(
            conv_manager,
            "system",
            sprintf(
              "**System:** Applied context (%s characters)",
              format(nchar(context_text), big.mark = ",")
            )
          )

          conv_add_message(conv_manager, "assistant", response$content)

          # Mark as sent
          conv_set_context_sent(conv_manager, TRUE)
          conv_update_current(conv_manager, list(context_sent = TRUE))

          # Clear loading
          conv_set_loading(conv_manager, FALSE)
          session$sendCustomMessage("setLoading", FALSE)
          session$sendCustomMessage("scrollToBottom", list())

          # Remove sending notification
          shiny::removeNotification("context_sending")

          # Success notification
          shiny::showNotification(
            "Context sent successfully! Cassidy is ready.",
            type = "message",
            duration = 5
          )

          cli::cli_alert_success("New conversation created with fresh context")
        },
        error = function(e) {
          # Clear loading
          conv_set_loading(conv_manager, FALSE)
          session$sendCustomMessage("setLoading", FALSE)

          # Remove sending notification
          shiny::removeNotification("context_sending")

          # Error notification
          shiny::showNotification(
            paste("Error sending context:", e$message),
            type = "error",
            duration = 8
          )

          cli::cli_warn("Failed to send context: {e$message}")
          cli::cli_alert_info(
            "Context saved - use 'Apply Context' button to retry"
          )
        }
      )
    }
  })
}
