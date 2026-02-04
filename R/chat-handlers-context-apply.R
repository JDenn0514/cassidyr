#' Setup apply context handler
#' @keywords internal
setup_apply_context_handler <- function(
  input,
  session,
  conv_manager,
  assistant_id,
  api_key,
  timeout
) {
  shiny::observeEvent(input$apply_context, {
    cli::cli_alert_info("Applying context...")

    # Gather context based on selections (incremental by default)
    context_text <- gather_selected_context(
      input,
      conv_manager,
      incremental = TRUE
    )

    # Get what was actually gathered (from attributes)
    files_to_send <- attr(context_text, "files_to_send") %||% character()
    data_to_send <- attr(context_text, "data_to_send") %||% character()

    # Check if project items changed (config, session, git)
    # These are always re-sent if selected, so check if any are selected
    project_items_selected <- isTRUE(input$ctx_config) ||
      isTRUE(input$ctx_session) ||
      isTRUE(input$ctx_git)

    # Check if there's anything new to send
    if (
      length(files_to_send) == 0 &&
        length(data_to_send) == 0 &&
        (is.null(context_text) || !nzchar(context_text))
    ) {
      shiny::showNotification(
        "No new context to send - everything selected has already been sent",
        type = "message",
        duration = 3
      )
      cli::cli_alert_info("No new context to send")
      return()
    }

    if (is.null(context_text) || !nzchar(context_text)) {
      shiny::showNotification(
        "No context items selected",
        type = "warning",
        duration = 3
      )
      return()
    }

    # Show size
    context_size <- nchar(context_text)
    cli::cli_alert_success(
      "Context gathered: {format(context_size, big.mark = ',')} characters"
    )

    # Store in conversation manager
    conv_set_context(conv_manager, context_text)

    # === SEND CONTEXT ===

    # Ensure we have a conversation
    if (is.null(conv_current_id(conv_manager))) {
      conv_create_new(conv_manager, session)
    }

    # Show loading state
    conv_set_loading(conv_manager, TRUE)
    session$sendCustomMessage("setLoading", TRUE)

    shiny::showNotification(
      "Sending context to Cassidy...",
      id = "context_sending",
      type = "message",
      duration = NULL
    )

    # Send context to Cassidy
    tryCatch(
      {
        conv <- conv_get_current(conv_manager)
        thread_id <- conv$thread_id

        # Create thread if needed
        if (is.null(thread_id)) {
          thread_id <- cassidy_create_thread(
            assistant_id = assistant_id,
            api_key = api_key
          )
          conv_update_current(conv_manager, list(thread_id = thread_id))
          cli::cli_alert_success("Created new conversation thread")
        }

        # Send context to API
        context_message <- paste0(
          "# Project Context\n\n",
          context_text,
          "\n\n---\n\n",
          "I've shared my project context with you. Please acknowledge that you've received it ",
          "and let me know you're ready to help with this project.",

          if (grepl("INDEX mode", context_text, fixed = TRUE)) {
            paste0(
              "Note: Files are in INDEX mode. To see full file contents, ",
              "respond with [REQUEST_FILE:path/to/file.R] and I'll automatically send them. ",
              "Please acknowledge and let me know you're ready."
            )
          } else {
            "Please acknowledge that you've received it and let me know you're ready to help."
          }
        )

        response <- cassidy_send_message(
          thread_id = thread_id,
          message = context_message,
          api_key = api_key,
          timeout = timeout
        )

        # Add system message to UI
        conv_add_message(
          conv_manager,
          "system",
          sprintf(
            "**System:** Applied context (%s characters)",
            format(context_size, big.mark = ",")
          )
        )

        # Add Cassidy's acknowledgment
        conv_add_message(conv_manager, "assistant", response$content)

        # Mark context as sent
        conv_set_context_sent(conv_manager, TRUE)
        conv_update_current(conv_manager, list(context_sent = TRUE))

        # === NEW: Update sent tracking ===
        current_sent_files <- conv_sent_context_files(conv_manager)
        current_sent_data <- conv_sent_data_frames(conv_manager)

        # Add newly sent items to tracking
        conv_set_sent_context_files(
          conv_manager,
          union(current_sent_files, files_to_send)
        )
        conv_set_sent_data_frames(
          conv_manager,
          union(current_sent_data, data_to_send)
        )

        # Clear pending refresh queues
        conv_set_pending_refresh_files(conv_manager, character())
        conv_set_pending_refresh_data(conv_manager, character())

        # Update conversation record for persistence
        conv_update_current(
          conv_manager,
          list(
            sent_context_files = conv_sent_context_files(conv_manager),
            sent_data_frames = conv_sent_data_frames(conv_manager)
          )
        )

        # === ADD THIS: Sync file checkboxes to show sent state ===
        session$sendCustomMessage(
          "syncFileCheckboxes",
          list(
            sent = conv_sent_context_files(conv_manager),
            selected = conv_context_files(conv_manager)
          )
        )

        # Also sync data checkboxes
        session$sendCustomMessage(
          "syncDataCheckboxes",
          list(
            sent = conv_sent_data_frames(conv_manager),
            selected = data_to_send
          )
        )

        # Clear loading state
        conv_set_loading(conv_manager, FALSE)
        session$sendCustomMessage("setLoading", FALSE)
        session$sendCustomMessage("scrollToBottom", list())

        # Remove sending notification
        shiny::removeNotification("context_sending")

        # Success notification with details
        new_files_count <- length(files_to_send)
        new_data_count <- length(data_to_send)

        detail_msg <- c()
        if (new_files_count > 0) {
          detail_msg <- c(detail_msg, paste0(new_files_count, " file(s)"))
        }
        if (new_data_count > 0) {
          detail_msg <- c(detail_msg, paste0(new_data_count, " data frame(s)"))
        }

        shiny::showNotification(
          shiny::tagList(
            shiny::icon("check"),
            " Context sent successfully!",
            if (length(detail_msg) > 0) {
              paste0(" (", paste(detail_msg, collapse = ", "), ")")
            }
          ),
          type = "message",
          duration = 5
        )

        cli::cli_alert_success(
          "Context sent and acknowledged ({format(context_size, big.mark = ',')} chars)"
        )
      },
      error = function(e) {
        # Clear loading state
        conv_set_loading(conv_manager, FALSE)
        session$sendCustomMessage("setLoading", FALSE)

        # Remove sending notification
        shiny::removeNotification("context_sending")

        # Error notification
        shiny::showNotification(
          shiny::tagList(
            shiny::icon("exclamation-triangle"),
            sprintf(" Error sending context: %s", e$message)
          ),
          type = "error",
          duration = 8
        )

        cli::cli_warn("Failed to send context: {e$message}")
      }
    )
  })
}


#' Setup refresh context handlers
#' @keywords internal
setup_refresh_context_handler <- function(
  input,
  session,
  conv_manager,
  assistant_id,
  api_key,
  timeout
) {
  # Refresh all - queue ALL sent items for refresh
  shiny::observeEvent(input$refresh_all_context, {
    # Queue all sent files for refresh
    sent_files <- conv_sent_context_files(conv_manager)
    conv_set_pending_refresh_files(conv_manager, sent_files)

    # Queue all sent data for refresh
    sent_data <- conv_sent_data_frames(conv_manager)
    conv_set_pending_refresh_data(conv_manager, sent_data)

    shiny::showNotification(
      paste0(
        "Queued ",
        length(sent_files),
        " file(s) and ",
        length(sent_data),
        " data frame(s) for refresh - click 'Apply Context'"
      ),
      type = "message",
      duration = 3
    )

    cli::cli_alert_success("All sent context queued for refresh")
  })

  # Individual refresh handlers
  shiny::observeEvent(input$refresh_config, {
    # Config is always re-sent if selected, just notify
    shiny::showNotification(
      "cassidy.md will be refreshed with next 'Apply Context'",
      type = "message",
      duration = 2
    )
  })

  # Data frame refresh handlers - queue for refresh

  shiny::observe({
    dfs <- .get_env_dataframes()

    lapply(names(dfs), function(df_name) {
      refresh_id <- paste0("refresh_data_", gsub("[^a-zA-Z0-9]", "_", df_name))

      shiny::observeEvent(
        input[[refresh_id]],
        {
          # Add to pending refresh queue
          current_pending <- conv_pending_refresh_data(conv_manager)
          conv_set_pending_refresh_data(
            conv_manager,
            union(current_pending, df_name)
          )

          shiny::showNotification(
            paste(
              df_name,
              "queued for refresh - click 'Apply Context' to send"
            ),
            type = "message",
            duration = 3
          )

          cli::cli_alert_info("Queued data frame for refresh: {df_name}")
        },
        ignoreInit = TRUE
      )
    })
  })
}
