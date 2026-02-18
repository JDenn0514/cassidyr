# Token Estimation and Limits
# Phase 1 of Context Engineering System

# Package Constants -------------------------------------------------------

#' Token limit for CassidyAI API
#' @keywords internal
.CASSIDY_TOKEN_LIMIT <- 200000L

#' Conservative single message character limit
#' @keywords internal
.CASSIDY_CHAR_LIMIT_SINGLE <- 250000L

#' Empirical thread character limit before token failure
#' @keywords internal
.CASSIDY_CHAR_LIMIT_THREAD <- 585000L

#' Default compaction threshold (fraction of token limit)
#' @keywords internal
.CASSIDY_DEFAULT_COMPACT_AT <- 0.85

#' Warning threshold (fraction of token limit)
#' @keywords internal
.CASSIDY_WARNING_AT <- 0.80


# Token Estimation Functions ----------------------------------------------

#' Estimate token count from text
#'
#' Uses empirically-determined character-to-token ratio with safety buffer.
#' CassidyAI uses Claude Sonnet 4.5 which has ~3:1 char-to-token ratio for
#' typical mixed content (code, prose, structured data).
#'
#' @param text Character vector. Text to estimate tokens for.
#' @param safety_factor Numeric. Multiply estimate by this factor for safety buffer.
#'   Default 1.15 (15% safety margin).
#' @param method Character. Estimation method:
#'   - "fast": Simple char count / 3 (default)
#'   - "conservative": Assumes 2.5:1 ratio (more conservative)
#'   - "optimistic": Assumes 3.5:1 ratio (for prose-heavy content)
#'
#' @return Integer. Estimated token count.
#' @export
#'
#' @examples
#' text <- "The quick brown fox jumps over the lazy dog."
#' cassidy_estimate_tokens(text)
#'
#' # With conservative estimate
#' cassidy_estimate_tokens(text, method = "conservative")
#'
#' # Multiple text elements are collapsed
#' cassidy_estimate_tokens(c("Hello", "world"))
cassidy_estimate_tokens <- function(
  text,
  safety_factor = 1.15,
  method = c("fast", "conservative", "optimistic")
) {
  method <- match.arg(method)

  if (is.null(text) || length(text) == 0) {
    return(0L)
  }

  # Collapse to single string
  text <- paste(text, collapse = "\n")
  chars <- nchar(text)

  # Base ratio (chars per token)
  base_ratio <- switch(
    method,
    fast = 3.0,
    conservative = 2.5,
    optimistic = 3.5
  )

  # Estimate tokens with safety factor
  tokens <- ceiling((chars / base_ratio) * safety_factor)

  as.integer(tokens)
}


#' Estimate total tokens in a session
#'
#' Calculates token count for all messages in session history plus
#' any context that was sent.
#'
#' @param session A cassidy_session object
#' @param method Token estimation method (passed to cassidy_estimate_tokens)
#'
#' @return Integer. Estimated total token count for session.
#' @keywords internal
cassidy_estimate_session_tokens <- function(session, method = "fast") {
  total <- 0L

  # Count context if it was sent
  if (session$context_sent && !is.null(session$context)) {
    total <- total + cassidy_estimate_tokens(session$context$text, method = method)
  }

  # Count all messages
  for (msg in session$messages) {
    total <- total + cassidy_estimate_tokens(msg$content, method = method)
  }

  total
}


# Timeout Management Constants -----------------------------------------------

#' Timeout error detection patterns
#' @keywords internal
.CASSIDY_TIMEOUT_ERROR_PATTERNS <- c("524", "timeout", "Gateway Time-out")

#' Large input threshold (100k characters)
#' @keywords internal
.CASSIDY_LARGE_INPUT_THRESHOLD <- 100000L

#' Very large input threshold (250k characters)
#' @keywords internal
.CASSIDY_VERY_LARGE_INPUT_THRESHOLD <- 250000L


# Timeout Prevention Functions ------------------------------------------------

#' Detect if message likely requires complex processing
#'
#' Checks for patterns indicating tasks that might timeout due to
#' extended reasoning requirements.
#'
#' @param message Character. User message to analyze.
#' @return Logical. TRUE if message contains complex task patterns.
#' @keywords internal
.is_complex_task <- function(message) {
  # Patterns indicating complex tasks
  patterns <- c(
    "implementation plan",
    "comprehensive analysis",
    "detailed design",
    "architecture",
    "step.by.step",
    "thoroughly analyze",
    "create.*documentation"
  )

  any(vapply(patterns, function(p) {
    grepl(p, message, ignore.case = TRUE)
  }, logical(1)))
}


#' Add chunking guidance to complex tasks
#'
#' Prepends chunking instructions to messages that appear complex,
#' encouraging incremental delivery to prevent timeouts.
#'
#' @param message Character. User message.
#' @return Character. Message with chunking guidance if needed.
#' @keywords internal
.add_chunking_guidance <- function(message) {
  if (.is_complex_task(message)) {
    guidance <- paste0(
      "Note: This appears to be a complex task. Please approach it incrementally:\n",
      "1. First provide an outline or high-level structure\n",
      "2. Then elaborate key sections\n",
      "3. You can deliver this in parts if needed\n\n"
    )
    message <- paste0(guidance, message)
  }
  message
}


#' Validate message size and warn about timeout risk
#'
#' Checks input size and categorizes timeout risk. Optionally warns user
#' about large inputs that might cause timeouts.
#'
#' @param message Character. Message to validate.
#' @param warn Logical. Whether to print warnings. Default TRUE.
#' @return List with risk level ("low", "medium", "high") and size.
#' @keywords internal
.validate_message_size <- function(message, warn = TRUE) {
  msg_size <- nchar(message)

  if (msg_size > .CASSIDY_VERY_LARGE_INPUT_THRESHOLD) {
    if (warn) {
      cli::cli_alert_warning(
        "Very large input: {format(msg_size, big.mark = ',')} characters"
      )
      cli::cli_alert_danger(
        "High risk of timeout. Consider breaking this into smaller messages."
      )
    }
    return(list(risk = "high", size = msg_size))
  } else if (msg_size > .CASSIDY_LARGE_INPUT_THRESHOLD) {
    if (warn) {
      cli::cli_alert_warning(
        "Large input: {format(msg_size, big.mark = ',')} characters"
      )
      cli::cli_alert_info(
        "Timeout possible. Message may be retried automatically if timeout occurs."
      )
    }
    return(list(risk = "medium", size = msg_size))
  }

  list(risk = "low", size = msg_size)
}


#' Default chunking guidance for timeout prevention
#'
#' Returns prompt text encouraging Claude to deliver responses
#' incrementally for complex tasks.
#'
#' @return Character. Chunking guidance text.
#' @keywords internal
.timeout_prevention_prompt <- function() {
  paste0(
    "## Response Delivery Guidelines\n\n",
    "For complex tasks:\n",
    "1. Assess the scope before starting your response\n",
    "2. If the task is extensive, break it into logical sections\n",
    "3. Deliver work incrementally rather than all at once\n",
    "4. After completing a substantial section, you can pause\n",
    "5. The user can ask you to continue if needed\n\n",
    "Prioritize sending partial progress over attempting to complete ",
    "everything in a single response that might timeout."
  )
}


#' Create retry chunking prompt after timeout
#'
#' Returns prompt to prepend to message after a timeout occurs,
#' with strong guidance to deliver concise, focused responses.
#'
#' @return Character. Retry chunking prompt text.
#' @keywords internal
.timeout_retry_prompt <- function() {
  paste0(
    "IMPORTANT: The previous attempt at this task timed out. ",
    "Please provide a focused, concise response:\n\n",
    "1. Break the task into phases if it's complex\n",
    "2. Start with the most essential information\n",
    "3. Prioritize clarity and brevity over comprehensiveness\n",
    "4. You can elaborate in follow-up messages if needed\n\n",
    "Original task:\n\n"
  )
}


# Session Statistics Functions -----------------------------------------------

#' Get detailed token usage statistics for a session
#'
#' Provides comprehensive diagnostics about token usage, message counts,
#' and compaction history for a cassidy_session.
#'
#' @param session A cassidy_session object
#'
#' @return A list with class "cassidy_session_stats" containing:
#'   \describe{
#'     \item{session_id}{Thread ID}
#'     \item{created_at}{Session creation timestamp}
#'     \item{total_messages}{Total message count}
#'     \item{user_messages}{User message count}
#'     \item{assistant_messages}{Assistant message count}
#'     \item{token_estimate}{Current token estimate}
#'     \item{token_limit}{Token limit (200,000)}
#'     \item{token_percentage}{Token usage as percentage}
#'     \item{tokens_remaining}{Tokens remaining before limit}
#'     \item{context_tokens}{Tokens from initial context}
#'     \item{message_tokens}{Tokens from messages}
#'     \item{tool_overhead}{Tokens reserved for tools}
#'     \item{compaction_count}{Number of times compacted}
#'     \item{last_compaction}{Last compaction timestamp}
#'     \item{auto_compact}{Whether auto-compact is enabled}
#'     \item{compact_at_threshold}{Token count triggering auto-compact}
#'   }
#'
#' @family chat-functions
#' @export
#'
#' @examples
#' \dontrun{
#' session <- cassidy_session()
#' chat(session, "Hello!")
#'
#' stats <- cassidy_session_stats(session)
#' print(stats)
#' }
cassidy_session_stats <- function(session) {
  if (!inherits(session, "cassidy_session")) {
    cli::cli_abort(c(
      "x" = "session must be a cassidy_session object",
      "i" = "Got {.cls {class(session)}}"
    ))
  }

  n_messages <- length(session$messages)
  n_user_messages <- sum(vapply(
    session$messages,
    function(m) m$role == "user",
    logical(1)
  ))

  # Token breakdown
  context_tokens <- if (session$context_sent && !is.null(session$context)) {
    if (!is.null(session$context$text)) {
      cassidy_estimate_tokens(session$context$text)
    } else {
      0L
    }
  } else {
    0L
  }

  message_tokens <- (session$token_estimate %||% 0L) - context_tokens

  # Usage percentages
  token_limit <- session$token_limit %||% .CASSIDY_TOKEN_LIMIT
  token_estimate <- session$token_estimate %||% 0L
  pct_used <- round(100 * token_estimate / token_limit, 1)

  # Compaction stats
  times_compacted <- session$compaction_count %||% 0L

  structure(
    list(
      session_id = session$thread_id,
      created_at = session$created_at,
      total_messages = n_messages,
      user_messages = n_user_messages,
      assistant_messages = n_messages - n_user_messages,
      token_estimate = token_estimate,
      token_limit = token_limit,
      token_percentage = pct_used,
      tokens_remaining = token_limit - token_estimate,
      context_tokens = context_tokens,
      message_tokens = message_tokens,
      tool_overhead = session$tool_overhead %||% 0L,
      compaction_count = times_compacted,
      last_compaction = session$last_compaction,
      auto_compact = session$auto_compact %||% TRUE,
      compact_at_threshold = floor(token_limit * (session$compact_at %||% .CASSIDY_DEFAULT_COMPACT_AT))
    ),
    class = "cassidy_session_stats"
  )
}


#' @export
print.cassidy_session_stats <- function(x, ...) {
  cli::cli_h1("Session Statistics")

  cli::cli_text("{.field Session ID}: {.val {x$session_id}}")
  cli::cli_text("{.field Created}: {.val {format(x$created_at, '%Y-%m-%d %H:%M:%S')}}")
  cli::cli_text("{.field Messages}: {x$total_messages} ({x$user_messages} user, {x$assistant_messages} assistant)")

  cli::cli_h2("Token Usage")

  # Progress bar for token usage
  bar_width <- 50
  filled <- floor(bar_width * x$token_percentage / 100)
  empty <- bar_width - filled

  bar <- paste0(
    "[",
    paste(rep("\u2588", filled), collapse = ""),
    paste(rep(" ", empty), collapse = ""),
    "]"
  )

  cli::cli_text(bar)
  cli::cli_text(
    "{.strong {format(x$token_estimate, big.mark = ',')} / {format(x$token_limit, big.mark = ',')}} tokens ({x$token_percentage}%)"
  )
  cli::cli_text("{.field Remaining}: {format(x$tokens_remaining, big.mark = ',')} tokens")

  cli::cli_h3("Breakdown")
  cli::cli_text("{.field Context}: {format(x$context_tokens, big.mark = ',')} tokens")
  cli::cli_text("{.field Messages}: {format(x$message_tokens, big.mark = ',')} tokens")
  if (x$tool_overhead > 0) {
    cli::cli_text("{.field Tool Overhead}: {format(x$tool_overhead, big.mark = ',')} tokens")
  }

  if (x$compaction_count > 0) {
    cli::cli_h2("Compaction")
    cli::cli_text("{.field Times Compacted}: {x$compaction_count}")
    cli::cli_text("{.field Last Compaction}: {format(x$last_compaction, '%Y-%m-%d %H:%M:%S')}")
  }

  cli::cli_h2("Settings")
  cli::cli_text("{.field Auto-Compact}: {if (x$auto_compact) 'Enabled' else 'Disabled'}")
  if (x$auto_compact) {
    cli::cli_text(
      "{.field Compact Threshold}: {format(x$compact_at_threshold, big.mark = ',')} tokens"
    )
  }

  invisible(x)
}
