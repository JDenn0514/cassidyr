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
      # Use new file-aware rendering that preserves file blocks as raw code
      rendered_content <- .render_message_with_file_blocks(msg$content)

      shiny::div(
        class = paste0("message message-", msg$role),
        shiny::div(class = "message-role", msg$role),
        shiny::div(shiny::HTML(rendered_content))
      )
    })

    # Return just the messages (remove the loading indicator code from here)
    message_elements
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

        # === NEW: TRACK TOKENS ===
        # Estimate tokens for both messages
        user_msg_tokens <- cassidy_estimate_tokens(user_message)
        assistant_msg_tokens <- cassidy_estimate_tokens(response$content)

        # Update token estimate
        current_estimate <- conv_token_estimate(conv_manager)
        new_estimate <- current_estimate + user_msg_tokens + assistant_msg_tokens

        # If context was sent with this message, add those tokens too
        if (!conv_context_sent(conv_manager) && !is.null(context_text)) {
          context_tokens <- cassidy_estimate_tokens(context_text)
          new_estimate <- new_estimate + context_tokens
        }

        # Update conversation manager
        conv_set_token_estimate(conv_manager, new_estimate)

        # Update conversation object with token estimate
        conv_update_current(conv_manager, list(token_estimate = new_estimate))

        # Check if approaching limit and warn
        limit <- conv_manager@token_limit()
        pct <- round(100 * new_estimate / limit)
        if (pct > 80) {
          shiny::showNotification(
            paste0(
              "Token usage is high: ",
              format(new_estimate, big.mark = ","),
              " / ",
              format(limit, big.mark = ","),
              " (",
              pct,
              "%)"
            ),
            type = "warning",
            duration = 10
          )
        }

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
              if (fs::file_exists(f)) {
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

              # === NEW: TRACK TOKENS FOR FILE FETCH ===
              file_msg_tokens <- cassidy_estimate_tokens(file_message)
              response2_tokens <- cassidy_estimate_tokens(response2$content)
              current_estimate <- conv_token_estimate(conv_manager)
              new_estimate <- current_estimate + file_msg_tokens + response2_tokens
              conv_set_token_estimate(conv_manager, new_estimate)
              conv_update_current(conv_manager, list(token_estimate = new_estimate))

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
