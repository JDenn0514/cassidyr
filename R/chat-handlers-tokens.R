#' Setup token usage display renderer
#' @keywords internal
setup_token_usage_renderer <- function(output, conv_manager) {
  output$token_usage_display <- shiny::renderUI({
    tokens <- conv_token_estimate(conv_manager)
    limit <- conv_manager@token_limit()
    pct <- if (limit > 0) round(100 * tokens / limit) else 0

    # Color based on usage
    color <- if (pct < 60) {
      "success"
    } else if (pct < 80) {
      "warning"
    } else {
      "danger"
    }

    shiny::div(
      class = paste0("alert alert-", color, " py-2 mb-2"),
      shiny::div(
        shiny::strong("Estimated Tokens: "),
        format(tokens, big.mark = ","),
        " / ",
        format(limit, big.mark = ","),
        shiny::tags$br(),
        shiny::tags$small(
          paste0(pct, "% used"),
          class = "text-muted"
        )
      ),
      if (pct > 80) {
        shiny::div(
          class = "mt-1",
          shiny::tags$small(
            shiny::icon("exclamation-triangle"),
            " Consider compacting the conversation to avoid failures",
            class = "text-muted"
          )
        )
      }
    )
  })
}


#' Setup compact conversation handler
#' @keywords internal
setup_compact_handler <- function(
  input,
  session,
  conv_manager,
  assistant_id,
  api_key,
  timeout
) {
  shiny::observeEvent(input$compact_conversation, {
    conv <- conv_get_current(conv_manager)

    if (is.null(conv)) {
      shiny::showNotification(
        "No active conversation to compact",
        type = "warning"
      )
      return()
    }

    if (length(conv$messages) < 4) {
      shiny::showNotification(
        "Conversation too short to compact (need at least 4 messages)",
        type = "warning"
      )
      return()
    }

    # Show progress modal
    shiny::showModal(shiny::modalDialog(
      title = "Compacting Conversation",
      shiny::div(
        shiny::icon("spinner", class = "fa-spin fa-2x text-primary"),
        shiny::tags$p(
          class = "mt-3",
          "Summarizing conversation history..."
        ),
        shiny::tags$p(
          class = "text-muted",
          shiny::tags$small(
            "This may take a moment. The conversation will be summarized ",
            "and a new thread will be created with the summary."
          )
        )
      ),
      footer = NULL
    ))

    # Perform compaction in background
    tryCatch(
      {
        # Build a cassidy_session object from conversation data
        # This is needed because cassidy_compact() expects a session object
        session_obj <- structure(
          list(
            thread_id = conv$thread_id,
            assistant_id = assistant_id,
            messages = lapply(conv$messages, function(m) {
              list(
                role = m$role,
                content = m$content,
                timestamp = Sys.time(),
                tokens = cassidy_estimate_tokens(m$content)
              )
            }),
            created_at = conv$created_at %||% Sys.time(),
            api_key = api_key,
            context = NULL,
            context_sent = conv$context_sent,
            token_estimate = conv$token_estimate %||% 0L,
            token_limit = .CASSIDY_TOKEN_LIMIT,
            compact_at = .CASSIDY_DEFAULT_COMPACT_AT,
            auto_compact = FALSE,
            compaction_count = conv$compaction_count %||% 0L,
            last_compaction = conv$last_compaction,
            tool_overhead = 0L
          ),
          class = "cassidy_session"
        )

        # Call compaction function
        compacted_session <- cassidy_compact(
          session_obj,
          preserve_recent = 2,
          api_key = api_key
        )

        # Update conversation with compacted data
        conv_update_current(conv_manager, list(
          thread_id = compacted_session$thread_id,
          messages = lapply(compacted_session$messages, function(m) {
            list(role = m$role, content = m$content)
          }),
          token_estimate = compacted_session$token_estimate,
          compaction_count = compacted_session$compaction_count,
          last_compaction = compacted_session$last_compaction
        ))

        # Update reactive token estimate
        conv_set_token_estimate(conv_manager, compacted_session$token_estimate)

        # Close modal and show success
        shiny::removeModal()
        shiny::showNotification(
          paste0(
            "Conversation compacted successfully! ",
            "Token usage reduced to ",
            format(compacted_session$token_estimate, big.mark = ","),
            " tokens (",
            round(100 * compacted_session$token_estimate / .CASSIDY_TOKEN_LIMIT),
            "%)"
          ),
          type = "message",
          duration = 10
        )

        cli::cli_alert_success("Conversation compacted in Shiny app")
      },
      error = function(e) {
        shiny::removeModal()
        shiny::showNotification(
          paste0("Compaction failed: ", e$message),
          type = "error",
          duration = 10
        )
        cli::cli_alert_danger("Compaction failed: {e$message}")
      }
    )
  })
}
