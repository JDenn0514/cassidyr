#' Compact conversation history using summarization
#'
#' When a conversation approaches the token limit, this function summarizes
#' the thread history into a concise summary and starts a new thread with
#' that summary as the first message. This allows the conversation to continue
#' without hitting API limits.
#'
#' Since CassidyAI does not provide direct summarization, this function sends
#' a summarization prompt to the assistant, then creates a new thread with
#' the summary.
#'
#' @param session A cassidy_session object to compact
#' @param summary_prompt Character. Custom prompt for summarization. If NULL,
#'   uses default prompt based on Anthropic context engineering guidelines.
#' @param preserve_recent Integer. Number of most recent message pairs to
#'   preserve verbatim (not summarized). Default 2.
#' @param api_key Character. API key for requests.
#'
#' @return Updated cassidy_session object with new thread and compacted history
#' @export
#'
#' @examples
#' \dontrun{
#' session <- cassidy_session()
#' # ... many messages ...
#'
#' # Manual compaction
#' session <- cassidy_compact(session)
#'
#' # Continue chatting
#' chat(session, "What were the key decisions we made?")
#' }
cassidy_compact <- function(
  session,
  summary_prompt = NULL,
  preserve_recent = 2,
  api_key = NULL
) {
  # Validate input
  if (!inherits(session, "cassidy_session")) {
    cli::cli_abort("session must be a cassidy_session object")
  }

  if (length(session$messages) == 0) {
    cli::cli_alert_info("No messages to compact")
    return(invisible(session))
  }

  api_key <- api_key %||% session$api_key

  # Determine which messages to summarize vs preserve
  n_messages <- length(session$messages)
  n_preserve <- min(preserve_recent * 2, n_messages)  # *2 because user+assistant pairs

  if (n_messages <= n_preserve) {
    cli::cli_alert_info("Too few messages to compact effectively")
    return(invisible(session))
  }

  messages_to_summarize <- session$messages[1:(n_messages - n_preserve)]
  messages_to_preserve <- if (n_preserve > 0) {
    session$messages[(n_messages - n_preserve + 1):n_messages]
  } else {
    list()
  }

  # Build summarization prompt
  if (is.null(summary_prompt)) {
    summary_prompt <- .default_compaction_prompt()
  }

  # Format conversation history for summarization
  history_text <- .format_messages_for_summary(messages_to_summarize)

  # Send summarization request to current thread
  cli::cli_alert_info("Requesting conversation summary from assistant...")

  summary_message <- paste0(
    summary_prompt,
    "\n\n# Conversation to Summarize\n\n",
    history_text
  )

  summary_response <- tryCatch(
    {
      cassidy_send_message(
        thread_id = session$thread_id,
        message = summary_message,
        api_key = api_key,
        timeout = 120
      )
    },
    error = function(e) {
      cli::cli_alert_danger("Compaction failed: {e$message}")
      cli::cli_alert_info("Conversation will continue with existing thread")
      cli::cli_alert_info(
        "You may need to manually start a new conversation soon"
      )
      return(NULL)
    }
  )

  if (is.null(summary_response)) {
    return(invisible(session))
  }

  summary_text <- summary_response$content

  # Create new thread
  cli::cli_alert_info("Creating new compacted thread...")

  new_thread_id <- tryCatch(
    {
      cassidy_create_thread(
        assistant_id = session$assistant_id,
        api_key = api_key
      )
    },
    error = function(e) {
      cli::cli_alert_danger("Failed to create new thread: {e$message}")
      cli::cli_alert_info("Conversation will continue with existing thread")
      return(NULL)
    }
  )

  if (is.null(new_thread_id)) {
    return(invisible(session))
  }

  # Send summary as first message in new thread
  # Use a framing message so the assistant understands this is a continuation
  continuation_message <- paste0(
    "This is a continuation of our previous conversation. Here is a summary ",
    "of what we discussed:\n\n",
    summary_text,
    "\n\n---\n\n",
    "We will continue our conversation from here. Please acknowledge that you ",
    "understand the context and are ready to continue."
  )

  acknowledge_response <- tryCatch(
    {
      cassidy_send_message(
        thread_id = new_thread_id,
        message = continuation_message,
        api_key = api_key,
        timeout = 120
      )
    },
    error = function(e) {
      cli::cli_alert_danger("Failed to send summary to new thread: {e$message}")
      cli::cli_alert_info("Conversation will continue with existing thread")
      return(NULL)
    }
  )

  if (is.null(acknowledge_response)) {
    return(invisible(session))
  }

  # Build new message history: summary + preserved messages
  new_messages <- list(
    list(
      role = "user",
      content = continuation_message,
      timestamp = Sys.time(),
      tokens = cassidy_estimate_tokens(continuation_message),
      is_compaction_summary = TRUE
    ),
    list(
      role = "assistant",
      content = acknowledge_response$content,
      timestamp = acknowledge_response$timestamp,
      tokens = cassidy_estimate_tokens(acknowledge_response$content),
      is_compaction_acknowledgment = TRUE
    )
  )

  # Add preserved recent messages
  new_messages <- c(new_messages, messages_to_preserve)

  # Recalculate token estimate
  new_token_estimate <- sum(vapply(new_messages, function(m) {
    if (!is.null(m$tokens)) m$tokens else cassidy_estimate_tokens(m$content)
  }, integer(1)))

  # If context was sent in original thread, count it
  if (session$context_sent && !is.null(session$context)) {
    new_token_estimate <- new_token_estimate + cassidy_estimate_tokens(session$context$text)
  }

  # Update session object
  old_thread_id <- session$thread_id
  session$thread_id <- new_thread_id
  session$messages <- new_messages
  session$token_estimate <- new_token_estimate
  session$compaction_count <- session$compaction_count + 1L
  session$last_compaction <- Sys.time()

  cli::cli_alert_success(
    paste0(
      "Compaction complete: {n_messages} messages reduced to ",
      "{length(new_messages)} messages"
    )
  )
  cli::cli_alert_info(
    "Token estimate: {session$token_estimate} ({round(100 * session$token_estimate / session$token_limit)}%)"
  )
  cli::cli_alert_info("Old thread: {old_thread_id}")
  cli::cli_alert_info("New thread: {new_thread_id}")

  invisible(session)
}


#' Default prompt for conversation summarization
#'
#' Based on Anthropic context engineering guidelines:
#' preserve decisions, unresolved issues, key outputs, next steps;
#' discard redundant tool results and intermediate steps.
#'
#' @keywords internal
.default_compaction_prompt <- function() {
  paste0(
    "Please create a concise summary of our conversation so far. ",
    "Focus on preserving:\n\n",
    "1. **Key decisions** we made and the reasoning behind them\n",
    "2. **Unresolved issues** or questions that are still open\n",
    "3. **Important outputs** (code, data insights, recommendations)\n",
    "4. **Next steps** or action items we identified\n",
    "5. **Critical context** needed to continue productively\n\n",
    "You can omit:\n",
    "- Redundant or superseded information\n",
    "- Intermediate work that led to a final solution\n",
    "- Detailed tool outputs that are no longer relevant\n",
    "- Conversational pleasantries\n\n",
    "Structure your summary with clear headings and be as concise as possible ",
    "while retaining all essential information."
  )
}


#' Format messages for summarization
#' @keywords internal
.format_messages_for_summary <- function(messages) {
  parts <- vapply(messages, function(msg) {
    role_label <- if (msg$role == "user") "User" else "Assistant"
    paste0("### ", role_label, "\n\n", msg$content)
  }, character(1))

  paste(parts, collapse = "\n\n---\n\n")
}
