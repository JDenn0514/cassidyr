# ===========================================================================
# LAYER 3: CHAT INTERFACE (Core)
# High-level functions for conversational interactions with CassidyAI
# ===========================================================================

#' Create a stateful chat session
#'
#' Creates a persistent chat session with a CassidyAI assistant. Unlike
#' [cassidy_chat()], which can be used for one-off interactions, a session
#' object maintains conversation state and makes it easy to have back-and-forth
#' conversations.
#'
#' @param assistant_id Character. The CassidyAI assistant ID. Defaults to
#'   the `CASSIDY_ASSISTANT_ID` environment variable.
#' @param context Optional context object from `cassidy_context_project()`,
#'   `cassidy_describe_df()`, or similar. Context is sent with the first
#'   message for efficiency.
#' @param api_key Character. Your CassidyAI API key. Defaults to
#'   the `CASSIDY_API_KEY` environment variable.
#' @param compact_at Numeric. Fraction of token limit at which to trigger
#'   auto-compaction (default 0.85 = 85%).
#' @param auto_compact Logical. Whether to automatically compact conversation
#'   when approaching token limit (default TRUE).
#'
#' @return A `cassidy_session` S3 object containing:
#'   \describe{
#'     \item{thread_id}{The conversation thread identifier}
#'     \item{assistant_id}{The assistant this session is connected to}
#'     \item{messages}{List of messages in this session}
#'     \item{created_at}{When the session was created}
#'     \item{context}{Stored context (sent with first message)}
#'     \item{token_estimate}{Estimated token usage for this session}
#'     \item{token_limit}{Token limit (200,000 for CassidyAI)}
#'     \item{compact_at}{Auto-compaction threshold}
#'     \item{auto_compact}{Whether auto-compaction is enabled}
#'   }
#'
#' @family chat-functions
#' @export
#'
#' @examples
#' \dontrun{
#' # Create a session with project context
#' ctx <- cassidy_context_project()
#' session <- cassidy_session(context = ctx)
#'
#' # Use the session
#' chat(session, "What should I work on next?")
#' chat(session, "How do I implement that?")
#'
#' # View session info
#' print(session)
#' }
cassidy_session <- function(
  assistant_id = Sys.getenv("CASSIDY_ASSISTANT_ID"),
  context = NULL,
  api_key = Sys.getenv("CASSIDY_API_KEY"),
  compact_at = .CASSIDY_DEFAULT_COMPACT_AT,
  auto_compact = TRUE
) {
  # Create thread
  thread_id <- cassidy_create_thread(assistant_id, api_key)

  # Build session object
  structure(
    list(
      thread_id = thread_id,
      assistant_id = assistant_id,
      messages = list(),
      created_at = Sys.time(),
      api_key = api_key,
      context = context,
      context_sent = FALSE, # Track if context has been sent
      # Token tracking fields
      token_estimate = 0L,           # Current estimated token usage
      token_limit = .CASSIDY_TOKEN_LIMIT,
      compact_at = compact_at,       # Fraction of limit to trigger compaction
      auto_compact = auto_compact,   # Whether to auto-compact
      compaction_count = 0L,         # Number of times compacted
      last_compaction = NULL,        # Timestamp of last compaction
      # Tool overhead tracking
      tool_overhead = 0L             # Estimated tokens for tool definitions
    ),
    class = "cassidy_session"
  )
}


# NOTE: cassidy_chat() moved to R/chat-console.R for unified console interface
# The function now includes automatic state management and conversation persistence


#' Continue an existing conversation
#'
#' Convenience function to continue a conversation from a previous
#' [cassidy_chat()] result. Automatically uses the thread_id from the
#' previous interaction.
#'
#' @param previous A `cassidy_chat` or `cassidy_session` object from a
#'   previous interaction.
#' @param message Character. The message to send.
#' @param api_key Character. Your CassidyAI API key. Defaults to
#'   the `CASSIDY_API_KEY` environment variable.
#' @param timeout Numeric. Request timeout in seconds. Default is 120.
#'
#' @return A `cassidy_chat` object (same as [cassidy_chat()]).
#'
#' @family chat-functions
#' @export
#'
#' @examples
#' \dontrun{
#' # Start conversation
#' result <- cassidy_chat("What is R?")
#'
#' # Continue it
#' result2 <- cassidy_continue(result, "Tell me more")
#' result3 <- cassidy_continue(result2, "Show an example")
#'
#' # Also works with sessions
#' session <- cassidy_session()
#' result <- chat(session, "Hello")
#' result2 <- cassidy_continue(session, "How are you?")
#' }
cassidy_continue <- function(
  previous,
  message,
  api_key = Sys.getenv("CASSIDY_API_KEY"),
  timeout = 120
) {
  # Extract thread_id from previous result
  if (inherits(previous, "cassidy_chat")) {
    thread_id <- previous$thread_id
  } else if (inherits(previous, "cassidy_session")) {
    thread_id <- previous$thread_id
  } else {
    cli::cli_abort(c(
      "previous must be a cassidy_chat or cassidy_session object",
      "x" = "Got {.cls {class(previous)}}"
    ))
  }

  # Send message using existing thread
  cassidy_chat(
    message = message,
    thread_id = thread_id,
    api_key = api_key,
    timeout = 120
  )
}

#' Send a message within a session
#'
#' Generic function for sending messages. Works with both `cassidy_session`
#' objects and directly with thread IDs.
#'
#' @param x A `cassidy_session` object or character thread_id.
#' @param message Character. The message to send.
#' @param ... Additional arguments passed to methods.
#'
#' @return A `cassidy_chat` object.
#'
#' @family chat-functions
#' @export
#'
#' @examples
#' \dontrun{
#' # With a session
#' session <- cassidy_session()
#' result <- chat(session, "Hello!")
#' result2 <- chat(session, "How are you?")
#'
#' # With a thread_id directly
#' result <- chat("thread_abc123", "Hello!")
#' }
chat <- function(x, message, ...) {
  UseMethod("chat")
}

#' @export
#' @export
chat.cassidy_session <- function(x, message, ...) {
  # Estimate tokens for new message
  new_msg_tokens <- cassidy_estimate_tokens(message)

  # Check if we need to warn about token usage
  if (!is.null(x$token_estimate) && !is.null(x$token_limit)) {
    threshold_tokens <- floor(x$token_limit * .CASSIDY_WARNING_AT)
    current_tokens <- x$token_estimate
    projected_tokens <- current_tokens + new_msg_tokens + (x$tool_overhead %||% 0L)

    if (projected_tokens > threshold_tokens) {
      pct <- round(100 * projected_tokens / x$token_limit, 1)
      cli::cli_alert_warning(
        "Token usage is high: {format(projected_tokens, big.mark = ',')} / {format(x$token_limit, big.mark = ',')} ({pct}%)"
      )
      cli::cli_alert_info(
        "Consider using {.fn cassidy_compact} to reduce conversation length"
      )
    }
  }

  # If this is the first message and we have context, include it
  if (!x$context_sent && !is.null(x$context)) {
    result <- cassidy_chat(
      message = message,
      thread_id = x$thread_id,
      context = x$context,
      api_key = x$api_key
    )
    x$context_sent <- TRUE

    # Add context tokens to estimate
    if (!is.null(x$context$text)) {
      context_tokens <- cassidy_estimate_tokens(x$context$text)
      x$token_estimate <- x$token_estimate + context_tokens
    }
  } else {
    result <- cassidy_chat(
      message = message,
      thread_id = x$thread_id,
      api_key = x$api_key
    )
  }

  # Estimate assistant response tokens
  assistant_tokens <- cassidy_estimate_tokens(result$response$content)

  # Update session with new messages (now with token tracking)
  user_msg <- list(
    role = "user",
    content = message,
    timestamp = Sys.time(),
    tokens = new_msg_tokens
  )

  assistant_msg <- list(
    role = "assistant",
    content = result$response$content,
    timestamp = result$response$timestamp,
    tokens = assistant_tokens
  )

  x$messages <- c(x$messages, list(user_msg, assistant_msg))

  # Update total token estimate
  x$token_estimate <- x$token_estimate + new_msg_tokens + assistant_tokens

  # Print response
  print(result$response)

  # Return updated session invisibly
  invisible(x)
}


#' @export
chat.character <- function(x, message, ...) {
  # x is a thread_id
  cassidy_chat(message = message, thread_id = x, ...)
}

#' @export
chat.default <- function(x, message, ...) {
  cli::cli_abort(c(
    "chat() requires a cassidy_session object or thread_id",
    "x" = "Got {.cls {class(x)}}"
  ))
}


# ===========================================================================
# S3 PRINT METHODS
# ===========================================================================

#' @export
print.cassidy_session <- function(x, ...) {
  cli::cli_h1("Cassidy Session")

  cli::cli_text("{.field Thread ID}: {.val {x$thread_id}}")
  cli::cli_text("{.field Assistant}: {.val {x$assistant_id}}")
  cli::cli_text("{.field Messages}: {.val {length(x$messages)}}")
  cli::cli_text(
    "{.field Created}: {.val {format(x$created_at, '%Y-%m-%d %H:%M:%S')}}"
  )

  # Token usage display
  if (!is.null(x$token_estimate) && x$token_estimate > 0) {
    pct <- round(100 * x$token_estimate / x$token_limit, 1)

    cli::cli_text(
      "{.field Tokens}: {format(x$token_estimate, big.mark = ',')} / {format(x$token_limit, big.mark = ',')} ({pct}%)"
    )

    if (pct > 80) {
      cli::cli_alert_warning("Token usage is high - consider compacting")
    }
  }

  # Show recent messages if any
  if (length(x$messages) > 0) {
    cli::cli_text("")
    cli::cli_h2("Recent Messages")

    # Show last 3 messages
    recent <- utils::tail(x$messages, 3)
    for (msg in recent) {
      role_icon <- if (msg$role == "user") "-->" else "<--"

      # Truncate long messages
      content <- msg$content
      if (nchar(content) > 100) {
        content <- paste0(substr(content, 1, 97), "...")
      }

      # Show tokens if available
      token_info <- if (!is.null(msg$tokens)) {
        paste0(" (", msg$tokens, " tokens)")
      } else {
        ""
      }

      cli::cli_alert_info(
        "{.emph {role_icon} {msg$role}}: {content}{token_info}"
      )
    }

    if (length(x$messages) > 3) {
      cli::cli_text("{.emph ... and {length(x$messages) - 3} more messages}")
    }
  }

  cli::cli_text("")
  cli::cli_text("Use {.fn cassidy_session_stats} for detailed diagnostics")

  invisible(x)
}

#' @export
print.cassidy_chat <- function(x, ...) {
  # Show conversation info if available (from unified interface)
  if (!is.null(x$conversation_id)) {
    cli::cli_text("{.field Conversation}: {.val {x$conversation_id}}")
  }
  cli::cli_text("{.field Thread}: {.val {x$thread_id}}")

  # Show context info if available
  if (!is.null(x$context_level) && !is.null(x$context_used) && x$context_used) {
    cli::cli_text("{.field Context}: {.val {x$context_level}} level")
  }

  cli::cli_text("")

  # Show the response
  print(x$response)

  invisible(x)
}

# ===========================================================================
# HELPER: Extract text from response
# ===========================================================================

#' Extract text content from a chat result
#'
#' Convenience function to extract just the text content from a chat result,
#' useful for programmatic use or piping.
#'
#' @param x A `cassidy_chat` or `cassidy_response` object.
#'
#' @return Character. The text content of the response.
#'
#' @family chat-functions
#' @export
#'
#' @examples
#' \dontrun{
#' result <- cassidy_chat("What is 2+2?")
#' text <- chat_text(result)
#' cat(text)
#' }
chat_text <- function(x) {
  if (inherits(x, "cassidy_chat")) {
    x$response$content
  } else if (inherits(x, "cassidy_response")) {
    x$content
  } else {
    cli::cli_abort(c(
      "x must be a cassidy_chat or cassidy_response object",
      "x" = "Got {.cls {class(x)}}"
    ))
  }
}
