# Context Engineering System - Technical Implementation Plan

**Status:** Phase 4 Complete (Automatic Compaction)
**Date:** 2026-02-18
**Target:** cassidyr package context management system

---

## 🔄 HANDOFF NOTES FOR NEXT AGENT

### What's Been Completed

**Phase 1: Token Estimation (Complete)**
- Token estimation function with 3 methods (fast, conservative, optimistic)
- All constants defined (.CASSIDY_TOKEN_LIMIT, .CASSIDY_WARNING_AT, etc.)
- Comprehensive unit tests (50 tests passing)

**Phase 2: Session Tracking (Complete)**
- cassidy_session() now has token tracking fields (token_estimate, token_limit, compact_at, auto_compact, etc.)
- chat.cassidy_session() tracks tokens for each message and warns at 80% threshold
- cassidy_session_stats() provides detailed diagnostics with formatted output
- print.cassidy_session() shows token usage with percentage
- ConversationManager (S7) has token_estimate field with generics/methods
- Conversation persistence handles token_estimate with backward compatibility
- All tests passing

**Phase 3: Manual Compaction (Complete)**
- cassidy_compact() function implemented in R/context-compact.R
- .default_compaction_prompt() helper based on Anthropic guidelines
- .format_messages_for_summary() helper for message formatting
- Error handling for API failures during compaction
- Thread switching logic (creates new thread with summary)
- Preserves recent messages (default: last 2 pairs = 4 messages)
- Recalculates token estimates after compaction
- Updates compaction_count and last_compaction timestamp
- 29 unit tests passing (test-context-compact.R)
- Manual test file created (test-compaction-live.R)
- All 1225 package tests passing
- Package passes R CMD check with 0 errors, 0 warnings, 0 notes

**Phase 4: Automatic Compaction (Complete)**
- chat.cassidy_session() now checks token threshold BEFORE sending messages
- Auto-compaction triggers when projected tokens exceed compact_at threshold (default 85%)
- Calculates projected tokens: current + new message + tool overhead
- Calls cassidy_compact() automatically with preserve_recent = 2
- Provides clear user feedback during auto-compaction (warning, info, success messages)
- When auto_compact = FALSE, warns user but doesn't compact
- Recalculates projected tokens after compaction
- 4 new unit tests for auto-compaction behavior (test-chat-core.R)
- Tests verify: threshold triggering, auto_compact = FALSE behavior, tool overhead inclusion
- Updated documentation for chat() generic to explain auto-compaction
- All tests passing (59 tests in test-chat-core.R)
- Package passes R CMD check with 0 errors, 0 warnings

**Phase 9: Timeout Management (Complete)**
- Timeout detection and retry logic
- Input size validation
- Complex task detection
- Chunking guidance functions

### What to Do Next

**Implement Phase 5: Shiny UI Integration**

**Estimated Effort:** 8-10 hours

**Tasks:**
1. Add token usage display to Shiny UI in `R/chat-ui.R` and `R/chat-ui-components.R`
2. Create compact button in context panel
3. Implement compaction handler in appropriate chat-handlers-*.R file
4. Update ConversationManager to handle token tracking in reactive context
5. Update message handlers in `R/chat-handlers-message.R` to track tokens
6. Add visual warnings for high token usage (color-coded alerts)
7. Test in live Shiny app with real conversations
8. Polish UI feedback and error handling
9. Update documentation
10. Test, commit, and push changes

**Key Files to Modify:**
- `R/chat-ui-components.R` - Add token usage display to context panel
- `R/chat-ui.R` - Add server logic for token display (renderUI)
- `R/chat-handlers-message.R` - Update to track tokens in Shiny context
- `R/chat-handlers-conversation.R` or new file - Add compact button handler

**Important Design Decisions:**
- Token display should be color-coded: green (<60%), yellow (60-80%), red (>80%)
- Display format: "Estimated Tokens: X / 200,000 (XX%)"
- Compact button should show in context panel
- Compaction in Shiny requires handling ConversationManager state
- Show warnings/success messages using showNotification()

**Testing Strategy:**
- Manual testing in live Shiny app
- Test token display updates after each message
- Test compact button triggers compaction
- Verify ConversationManager state updates correctly
- Test conversation persistence after compaction

See **Section 5** (Shiny UI Integration) in implementation plan below for detailed code.

**After Phase 5 Completion:**
- Update this section with Phase 5 completion notes
- Run all tests and verify they pass
- Commit changes with message: "Implement Phase 5: Shiny UI Integration"
- Push to remote repository
- Update CURRENT STATUS SUMMARY below

---

## CURRENT STATUS SUMMARY

**Completed Phases:**
- ✅ Phase 1: Token Estimation (2026-02-17)
- ✅ Phase 2: Session Tracking (2026-02-18)
- ✅ Phase 3: Manual Compaction (2026-02-18)
- ✅ Phase 4: Automatic Compaction (2026-02-18)
- ✅ Phase 9: Timeout Management (2026-02-17)

**Next Phase:** Phase 5 - Shiny UI Integration

---

## 1. ARCHITECTURE OVERVIEW

### Current State Analysis

**Existing Infrastructure:**
- `cassidy_session` S3 object tracks thread_id, messages, context, context_sent flag
- Context sent once with first message (no re-sending)
- Character counting exists (`nchar()`) but no token estimation
- Message history tracked locally in session object
- ConversationManager (S7) for Shiny app with sent/pending tracking
- `cassidy_get_thread()` retrieves full thread history from API
- No token budgeting or proactive size management

**Key Constraints:**
- **Token limit:** 200,000 tokens total (thread history + new message + system prompt)
- **Timeout limit:** 60-100 seconds per request (Cloudflare limit, no partial results on failure)
- No API token counting endpoint available
- No server-side compaction (raw thread passed to model)
- No response streaming available
- Empirical ratio: ~3:1 characters-to-tokens for our content
- Single message limit: ~250,000 characters practical limit
- Thread (cumulative) limit: ~585,000 characters before 200K token failure

### Design Goals

1. **Transparent tracking** - Users see token usage without thinking about it
2. **Proactive warnings** - Alert before API failure occurs
3. **Automatic compaction** - Opt-out default behavior to prevent token limit failures
4. **Automatic timeout recovery** - Graceful handling of 524 errors with retry and chunking
5. **Tool compatibility** - Budget tokens for prompt-based tool definitions
6. **Incremental adoption** - Existing code continues to work without changes
7. **Persistent knowledge** - Memory system for long-running workflows and learned insights

---

## 2. TOKEN ESTIMATION MODULE

**File:** `R/context-tokens.R`

### Core Function: `cassidy_estimate_tokens()`

```r
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
#' #> [1] 18
#'
#' # With conservative estimate
#' cassidy_estimate_tokens(text, method = "conservative")
#' #> [1] 21
```

**Implementation:**

```r
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
```

### Helper: `cassidy_estimate_session_tokens()`

```r
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
```

### Constants and Limits

```r
# Define package constants in R/context-tokens.R

#' @keywords internal
.CASSIDY_TOKEN_LIMIT <- 200000L

#' @keywords internal
.CASSIDY_CHAR_LIMIT_SINGLE <- 250000L  # Conservative single message limit

#' @keywords internal
.CASSIDY_CHAR_LIMIT_THREAD <- 585000L  # Empirical thread limit

#' @keywords internal
.CASSIDY_DEFAULT_COMPACT_AT <- 0.85  # 85% of token limit

#' @keywords internal
.CASSIDY_WARNING_AT <- 0.80  # 80% of token limit
```

---

## 3. SESSION TRACKING ENHANCEMENTS

**File:** `R/chat-core.R` (modifications)

### Enhanced cassidy_session Object

Add new fields to the session object:

```r
cassidy_session <- function(
  assistant_id = Sys.getenv("CASSIDY_ASSISTANT_ID"),
  context = NULL,
  api_key = Sys.getenv("CASSIDY_API_KEY"),
  compact_at = .CASSIDY_DEFAULT_COMPACT_AT,  # NEW
  auto_compact = TRUE  # NEW
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
      context_sent = FALSE,
      # NEW: Token tracking fields
      token_estimate = 0L,           # Current estimated token usage
      token_limit = .CASSIDY_TOKEN_LIMIT,
      compact_at = compact_at,       # Fraction of limit to trigger compaction
      auto_compact = auto_compact,   # Whether to auto-compact
      compaction_count = 0L,         # Number of times compacted
      last_compaction = NULL,        # Timestamp of last compaction
      # NEW: Tool overhead tracking
      tool_overhead = 0L             # Estimated tokens for tool definitions
    ),
    class = "cassidy_session"
  )
}
```

### Update chat.cassidy_session Method

Modify the chat method to track tokens and handle compaction:

```r
#' @export
chat.cassidy_session <- function(x, message, ...) {
  # Estimate tokens for new message
  new_msg_tokens <- cassidy_estimate_tokens(message)

  # Check if we need to compact BEFORE sending
  if (x$auto_compact) {
    threshold_tokens <- floor(x$token_limit * x$compact_at)
    current_tokens <- x$token_estimate
    projected_tokens <- current_tokens + new_msg_tokens + x$tool_overhead

    if (projected_tokens > threshold_tokens) {
      cli::cli_alert_warning(
        "Approaching token limit ({current_tokens} + {new_msg_tokens} = {projected_tokens} tokens, threshold: {threshold_tokens})"
      )
      cli::cli_alert_info("Auto-compacting conversation history...")

      # Perform compaction (creates new thread with summary)
      x <- cassidy_compact(x, preserve_recent = 3)

      cli::cli_alert_success("Compaction complete. Continuing with your message...")
    }
  } else {
    # Warn but don't compact
    if (x$token_estimate > floor(x$token_limit * .CASSIDY_WARNING_AT)) {
      cli::cli_alert_warning(
        paste0(
          "Token usage is high: {x$token_estimate}/{x$token_limit} ",
          "({round(100 * x$token_estimate / x$token_limit)}%)"
        )
      )
      cli::cli_alert_info(
        "Consider running {.fn cassidy_compact} or the conversation may fail soon"
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
    context_tokens <- cassidy_estimate_tokens(x$context$text)
    x$token_estimate <- x$token_estimate + context_tokens
  } else {
    result <- cassidy_chat(
      message = message,
      thread_id = x$thread_id,
      api_key = x$api_key
    )
  }

  # Update session with new messages and token counts
  user_msg <- list(
    role = "user",
    content = message,
    timestamp = Sys.time(),
    tokens = new_msg_tokens  # NEW: Track per-message tokens
  )

  assistant_tokens <- cassidy_estimate_tokens(result$response$content)
  assistant_msg <- list(
    role = "assistant",
    content = result$response$content,
    timestamp = result$response$timestamp,
    tokens = assistant_tokens  # NEW: Track per-message tokens
  )

  x$messages <- c(x$messages, list(user_msg, assistant_msg))

  # Update total token estimate
  x$token_estimate <- x$token_estimate + new_msg_tokens + assistant_tokens

  # Print response
  print(result$response)

  # Return updated session invisibly
  invisible(x)
}
```

---

## 4. MANUAL COMPACTION FUNCTION

**File:** `R/context-compact.R` (new file)

### Core Function: `cassidy_compact()`

```r
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

  summary_response <- cassidy_send_message(
    thread_id = session$thread_id,
    message = summary_message,
    api_key = api_key,
    timeout = 120
  )

  summary_text <- summary_response$content

  # Create new thread
  cli::cli_alert_info("Creating new compacted thread...")
  new_thread_id <- cassidy_create_thread(
    assistant_id = session$assistant_id,
    api_key = api_key
  )

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

  acknowledge_response <- cassidy_send_message(
    thread_id = new_thread_id,
    message = continuation_message,
    api_key = api_key,
    timeout = 120
  )

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
```

### Default Compaction Prompt

```r
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
```

### Message Formatting Helper

```r
#' Format messages for summarization
#' @keywords internal
.format_messages_for_summary <- function(messages) {
  parts <- vapply(messages, function(msg) {
    role_label <- if (msg$role == "user") "User" else "Assistant"
    paste0("### ", role_label, "\n\n", msg$content)
  }, character(1))

  paste(parts, collapse = "\n\n---\n\n")
}
```

---

## 5. SHINY APP INTEGRATION

**File:** `R/chat-handlers-message.R` (modifications)

### Update ConversationManager

Add token tracking to the ConversationManager S7 object:

```r
# In R/chat-conversation.R

ConversationManager <- S7::new_class(
  "ConversationManager",
  properties = list(
    conversations = S7::class_any,
    current_id = S7::class_any,
    context_sent = S7::class_any,
    context_files = S7::class_any,
    is_loading = S7::class_any,
    context_text = S7::class_any,
    sent_context_files = S7::class_any,
    sent_data_frames = S7::class_any,
    context_skills = S7::class_any,
    sent_skills = S7::class_any,
    pending_refresh_files = S7::class_any,
    pending_refresh_data = S7::class_any,
    pending_refresh_skills = S7::class_any,
    # NEW: Token tracking
    token_estimate = S7::class_any,
    token_limit = S7::class_any
  ),
  constructor = function() {
    S7::new_object(
      S7::S7_object(),
      conversations = shiny::reactiveVal(list()),
      current_id = shiny::reactiveVal(NULL),
      context_sent = shiny::reactiveVal(FALSE),
      context_files = shiny::reactiveVal(character()),
      is_loading = shiny::reactiveVal(FALSE),
      context_text = shiny::reactiveVal(NULL),
      sent_context_files = shiny::reactiveVal(character()),
      sent_data_frames = shiny::reactiveVal(character()),
      context_skills = shiny::reactiveVal(character()),
      sent_skills = shiny::reactiveVal(character()),
      pending_refresh_files = shiny::reactiveVal(character()),
      pending_refresh_data = shiny::reactiveVal(character()),
      pending_refresh_skills = shiny::reactiveVal(character()),
      # NEW
      token_estimate = shiny::reactiveVal(0L),
      token_limit = shiny::reactiveVal(.CASSIDY_TOKEN_LIMIT)
    )
  }
)

# Add generics and methods for token tracking
conv_token_estimate <- S7::new_generic("conv_token_estimate", "x")
conv_set_token_estimate <- S7::new_generic("conv_set_token_estimate", "x")

S7::method(conv_token_estimate, ConversationManager) <- function(x) {
  x@token_estimate()
}

S7::method(conv_set_token_estimate, ConversationManager) <- function(x, value) {
  x@token_estimate(value)
  invisible(x)
}
```

### Update Message Handler

Modify `send_message_observer` to track tokens:

```r
# In R/chat-handlers-message.R

# Update token estimate after sending message
user_msg_tokens <- cassidy_estimate_tokens(user_input)
assistant_msg_tokens <- cassidy_estimate_tokens(response$content)

current_estimate <- conv_token_estimate(conv)
new_estimate <- current_estimate + user_msg_tokens + assistant_msg_tokens

# If context was included, add those tokens too
if (!conv_context_sent(conv) && context_included) {
  context_tokens <- cassidy_estimate_tokens(context_text)
  new_estimate <- new_estimate + context_tokens
}

conv_set_token_estimate(conv, new_estimate)

# Update conversation object with token estimate
conv_update_current(conv, list(token_estimate = new_estimate))

# Check if approaching limit and warn
if (new_estimate > floor(.CASSIDY_TOKEN_LIMIT * .CASSIDY_WARNING_AT)) {
  showNotification(
    paste0(
      "Token usage is high: ",
      format(new_estimate, big.mark = ","),
      " / ",
      format(.CASSIDY_TOKEN_LIMIT, big.mark = ","),
      " (",
      round(100 * new_estimate / .CASSIDY_TOKEN_LIMIT),
      "%)"
    ),
    type = "warning",
    duration = 10
  )
}
```

### UI Token Display

Add token usage display to the Shiny UI:

```r
# In R/chat-ui-components.R

#' Build context panel with token usage display
#' @keywords internal
.build_context_panel <- function() {
  bslib::card(
    bslib::card_header("Context & Token Usage"),
    bslib::card_body(
      # Existing context controls...

      # NEW: Token usage display
      div(
        class = "token-usage-container",
        hr(),
        h5("Token Usage"),
        uiOutput("token_usage_display"),
        actionButton(
          "compact_conversation",
          "Compact Conversation",
          icon = icon("compress"),
          class = "btn-sm btn-outline-secondary mt-2"
        )
      )
    )
  )
}
```

Add server logic for token display:

```r
# In R/chat-ui.R

output$token_usage_display <- renderUI({
  tokens <- conv_token_estimate(conv)
  limit <- conv@token_limit()
  pct <- round(100 * tokens / limit)

  # Color based on usage
  color <- if (pct < 60) {
    "success"
  } else if (pct < 80) {
    "warning"
  } else {
    "danger"
  }

  div(
    class = paste0("alert alert-", color, " py-2"),
    strong("Estimated Tokens: "),
    format(tokens, big.mark = ","),
    " / ",
    format(limit, big.mark = ","),
    " (",
    pct,
    "%)",
    br(),
    if (pct > 80) {
      small(
        "Consider compacting the conversation to avoid failures",
        class = "text-muted"
      )
    }
  )
})

# Handler for compact button
observeEvent(input$compact_conversation, {
  # Trigger compaction for current conversation
  # Implementation depends on whether we want sync or async compaction
  # For now, show a modal with progress

  showModal(modalDialog(
    title = "Compacting Conversation",
    "Summarizing conversation history...",
    footer = NULL
  ))

  # TODO: Implement compaction in Shiny context
  # This is more complex because we need to:
  # 1. Get current conversation's thread_id
  # 2. Call compaction logic
  # 3. Update ConversationManager with new thread_id
  # 4. Refresh UI
})
```

---

## 6. TOOL-AWARE TOKEN BUDGETING

**File:** `R/agentic-tools.R` (modifications)

### Estimate Tool Overhead

Add function to estimate token overhead from tool definitions:

```r
#' Estimate token overhead for tool system
#'
#' When tools are active, they add token overhead:
#' - System prompt with tool instructions
#' - Tool schemas and examples
#' - Tool results in conversation history
#'
#' @param tools Character vector of tool names to include
#' @param include_results Logical. Whether to estimate tokens for tool results
#'   in history (requires session object)
#' @param session Optional cassidy_session object to count tool result tokens
#'
#' @return Integer. Estimated token overhead
#' @keywords internal
.estimate_tool_overhead <- function(tools, include_results = FALSE, session = NULL) {
  # Base overhead for tool system prompt
  base_overhead <- 500L  # Estimated tokens for tool instructions

  # Per-tool overhead for schemas
  tool_overhead <- length(tools) * 150L  # ~150 tokens per tool definition

  total_overhead <- base_overhead + tool_overhead

  # Optionally count tool results in history
  if (include_results && !is.null(session)) {
    tool_result_tokens <- 0L
    for (msg in session$messages) {
      if (!is.null(msg$is_tool_result) && msg$is_tool_result) {
        tool_result_tokens <- tool_result_tokens +
          (msg$tokens %||% cassidy_estimate_tokens(msg$content))
      }
    }
    total_overhead <- total_overhead + tool_result_tokens
  }

  as.integer(total_overhead)
}
```

### Update cassidy_agentic_task

Integrate tool overhead tracking:

```r
# In cassidy_agentic_task() function

# Estimate tool overhead
tool_overhead <- .estimate_tool_overhead(names(tools))

# If session tracking, update session object
if (inherits(session, "cassidy_session")) {
  session$tool_overhead <- tool_overhead
}

# Reserve headroom for tools when checking token budget
effective_limit <- session$token_limit - tool_overhead

# Use effective_limit for compaction threshold calculations
```

---

## 7. SESSION METADATA AND DIAGNOSTICS

**File:** `R/context-tokens.R` (additions)

### Session Stats Function

```r
#' Get detailed token usage statistics for a session
#'
#' @param session A cassidy_session object
#'
#' @return A list with token usage statistics
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
    cli::cli_abort("session must be a cassidy_session object")
  }

  n_messages <- length(session$messages)
  n_user_messages <- sum(vapply(
    session$messages,
    function(m) m$role == "user",
    logical(1)
  ))

  # Token breakdown
  context_tokens <- if (session$context_sent && !is.null(session$context)) {
    cassidy_estimate_tokens(session$context$text)
  } else {
    0L
  }

  message_tokens <- session$token_estimate - context_tokens

  # Usage percentages
  pct_used <- round(100 * session$token_estimate / session$token_limit, 1)
  pct_remaining <- 100 - pct_used

  # Compaction stats
  times_compacted <- session$compaction_count

  structure(
    list(
      session_id = session$thread_id,
      created_at = session$created_at,
      total_messages = n_messages,
      user_messages = n_user_messages,
      assistant_messages = n_messages - n_user_messages,
      token_estimate = session$token_estimate,
      token_limit = session$token_limit,
      token_percentage = pct_used,
      tokens_remaining = session$token_limit - session$token_estimate,
      context_tokens = context_tokens,
      message_tokens = message_tokens,
      tool_overhead = session$tool_overhead,
      compaction_count = times_compacted,
      last_compaction = session$last_compaction,
      auto_compact = session$auto_compact,
      compact_at_threshold = floor(session$token_limit * session$compact_at)
    ),
    class = "cassidy_session_stats"
  )
}
```

### Print Method for Stats

```r
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

  bar_char <- if (x$token_percentage < 60) {
    "\u2588"  # Full block
  } else if (x$token_percentage < 80) {
    "\u2588"
  } else {
    "\u2588"
  }

  bar <- paste0(
    "[",
    paste(rep(bar_char, filled), collapse = ""),
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
```

### Update print.cassidy_session

Add brief token usage to session print method:

```r
#' @export
print.cassidy_session <- function(x, ...) {
  cli::cli_h1("Cassidy Session")

  cli::cli_text("{.field Thread ID}: {.val {x$thread_id}}")
  cli::cli_text("{.field Assistant}: {.val {x$assistant_id}}")
  cli::cli_text("{.field Messages}: {.val {length(x$messages)}}")
  cli::cli_text(
    "{.field Created}: {.val {format(x$created_at, '%Y-%m-%d %H:%M:%S')}}"
  )

  # NEW: Token usage display
  if (x$token_estimate > 0) {
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
```

---

## 8. CONSOLE CHAT INTEGRATION

**File:** `R/chat-console.R` (modifications)

### Update cassidy_chat

Add optional session parameter and token tracking:

```r
cassidy_chat <- function(
  message,
  context = NULL,
  context_level = c("standard", "minimal", "comprehensive", "none"),
  thread_id = NULL,
  conversation = NULL,
  assistant_id = Sys.getenv("CASSIDY_ASSISTANT_ID"),
  api_key = Sys.getenv("CASSIDY_API_KEY"),
  timeout = 120,
  # NEW: Token management parameters
  track_tokens = TRUE,
  warn_at = .CASSIDY_WARNING_AT,
  auto_compact = FALSE  # Default FALSE for console to maintain simplicity
) {
  # ... existing logic ...

  # If tracking tokens and we have conversation state, check usage
  if (track_tokens && !is.null(conversation)) {
    conv_data <- cassidy_load_conversation(conversation)
    if (!is.null(conv_data$token_estimate)) {
      current_tokens <- conv_data$token_estimate
      new_msg_tokens <- cassidy_estimate_tokens(message)
      projected_tokens <- current_tokens + new_msg_tokens

      if (projected_tokens > floor(.CASSIDY_TOKEN_LIMIT * warn_at)) {
        pct <- round(100 * projected_tokens / .CASSIDY_TOKEN_LIMIT, 1)
        cli::cli_alert_warning(
          "Token usage is high: {format(projected_tokens, big.mark = ',')} ({pct}%)"
        )

        if (auto_compact && projected_tokens > floor(.CASSIDY_TOKEN_LIMIT * .CASSIDY_DEFAULT_COMPACT_AT)) {
          cli::cli_alert_info("Auto-compacting conversation...")
          # Compaction logic for console chat
          # This is complex because console chat doesn't maintain session object
          # May want to recommend switching to cassidy_session() for long conversations
          cli::cli_alert_info(
            "For long conversations with auto-compaction, use {.fn cassidy_session}"
          )
        }
      }
    }
  }

  # ... rest of existing logic ...
}
```

---

## 9. TESTING STRATEGY

**File:** `tests/testthat/test-context-tokens.R` (new file)

### Unit Tests

```r
test_that("cassidy_estimate_tokens works correctly", {
  # Basic estimation
  text <- "Hello world"
  tokens <- cassidy_estimate_tokens(text)
  expect_type(tokens, "integer")
  expect_gt(tokens, 0)

  # Empty text
  expect_equal(cassidy_estimate_tokens(""), 0L)
  expect_equal(cassidy_estimate_tokens(NULL), 0L)

  # Different methods
  text <- paste(rep("test", 100), collapse = " ")
  fast <- cassidy_estimate_tokens(text, method = "fast")
  conservative <- cassidy_estimate_tokens(text, method = "conservative")
  optimistic <- cassidy_estimate_tokens(text, method = "optimistic")

  expect_gt(conservative, fast)
  expect_lt(optimistic, fast)
})

test_that("token limits are defined correctly", {
  expect_equal(.CASSIDY_TOKEN_LIMIT, 200000L)
  expect_equal(.CASSIDY_DEFAULT_COMPACT_AT, 0.85)
  expect_equal(.CASSIDY_WARNING_AT, 0.80)
})

test_that("cassidy_estimate_session_tokens counts correctly", {
  # Create mock session
  session <- structure(
    list(
      context = list(text = paste(rep("word", 100), collapse = " ")),
      context_sent = TRUE,
      messages = list(
        list(role = "user", content = "Hello"),
        list(role = "assistant", content = "Hi there!")
      )
    ),
    class = "cassidy_session"
  )

  tokens <- cassidy_estimate_session_tokens(session)
  expect_type(tokens, "integer")
  expect_gt(tokens, 0)
})
```

### Integration Tests

```r
# File: tests/manual/test-compaction-live.R

# Manual test for compaction (requires API key)
test_compaction_live <- function() {
  library(cassidyr)

  # Create session
  session <- cassidy_session(auto_compact = FALSE)

  # Send several messages to build up history
  for (i in 1:10) {
    chat(session, paste("Message", i, ": Tell me something interesting"))
    Sys.sleep(2)  # Rate limiting
  }

  # Check token estimate
  stats <- cassidy_session_stats(session)
  print(stats)

  # Manual compact
  session <- cassidy_compact(session)

  # Continue conversation
  chat(session, "What did we discuss?")

  # Check stats again
  stats_after <- cassidy_session_stats(session)
  print(stats_after)

  invisible(session)
}
```

---

## 10. IMPLEMENTATION PHASES

### Phase 1: Token Estimation (Highest Impact, Lowest Effort)
**Estimated Effort:** 4-6 hours
**Files:** `R/context-tokens.R` (new)

- Implement `cassidy_estimate_tokens()`
- Define package constants
- Add basic tests
- Document functions

**Outcome:** Can estimate tokens from text, foundation for all other features

---

### Phase 2: Session Tracking (Medium Effort)
**Estimated Effort:** 6-8 hours
**Files:** `R/chat-core.R` (modify), `R/chat-conversation.R` (modify)

- Add token tracking fields to `cassidy_session`
- Update `chat.cassidy_session()` to track tokens
- Add token fields to ConversationManager
- Update conversation persistence to save token estimates
- Add `cassidy_session_stats()` function
- Update print methods to show token usage

**Outcome:** Sessions track token usage, users can see estimates

---

### Phase 3: Manual Compaction (Complex)
**Estimated Effort:** 10-12 hours
**Files:** `R/context-compact.R` (new)

- Implement `cassidy_compact()` core function
- Build default summarization prompt
- Handle thread switching logic
- Test with real API calls (manual tests)
- Document compaction process

**Outcome:** Users can manually compact conversations when needed

---

### Phase 4: Automatic Compaction (Build on Phase 3)
**Estimated Effort:** 4-6 hours
**Files:** `R/chat-core.R` (modify)

- Add auto-compaction logic to `chat.cassidy_session()`
- Add warnings before compaction
- Test auto-compaction threshold
- Document auto-compaction behavior

**Outcome:** Conversations auto-compact before hitting limits

---

### Phase 5: Shiny UI Integration (Medium Effort)
**Estimated Effort:** 8-10 hours
**Files:** `R/chat-ui.R`, `R/chat-ui-components.R`, `R/chat-handlers-message.R` (modify)

- Add token usage display to Shiny UI
- Add compact button to context panel
- Implement compaction handler for Shiny
- Update message handlers to track tokens
- Add visual warnings for high token usage
- Test in live Shiny app

**Outcome:** Shiny app shows token usage and supports compaction

---

### Phase 6: Tool-Aware Budgeting (Low Priority)
**Estimated Effort:** 4-6 hours
**Files:** `R/agentic-tools.R` (modify), `R/agentic-chat.R` (modify)

- Implement `.estimate_tool_overhead()`
- Update agentic task to track tool overhead
- Reserve headroom for tool definitions
- Test with tool-heavy conversations

**Outcome:** Agentic tasks properly budget tokens for tools

---

### Phase 7: Console Chat Integration (Polish)
**Estimated Effort:** 4-6 hours
**Files:** `R/chat-console.R` (modify)

- Add token tracking to console chat
- Implement warnings for high usage
- Add optional auto-compaction (opt-in)
- Document console chat token management

**Outcome:** Console chat has basic token awareness

---

### Phase 8: Memory Tool (Advanced Feature)
**Estimated Effort:** 8-10 hours
**Files:** `R/context-memory.R` (new), `R/agentic-tools.R` (modify)

**Purpose:** Persistent knowledge store for workflow state and learned insights

**Key Design Principles:**
- **NOT for project conventions** (use ~/.cassidy/rules/ instead)
- **FOR workflow state and learned knowledge** (dynamic, not static)
- **Progressive disclosure** - directory listing in context, files read on demand
- Avoid duplicating rules system
- Avoid context bloat

**Implementation:**

1. **Memory Storage:**
   - Create `~/.cassidy/memory/` directory structure
   - Local file-based storage (user controls data)
   - Support subdirectories for organization

2. **Memory Tool (Prompt-Based):**
   - Add to agentic tool registry
   - Commands: `view`, `create`, `str_replace`, `insert`, `delete`, `rename`
   - Restrict all operations to `/memories/` directory (security)
   - Similar interface to Anthropic's memory tool but prompt-based

3. **Context Integration (Lightweight):**
   ```r
   # In cassidy_context_project()
   if (include_memory) {
     # ONLY include directory listing (NOT full file contents)
     memory_listing <- cassidy_list_memory_files()
     context_parts$memory <- format_memory_listing(memory_listing)
     # Output: ~50-100 tokens for file list with sizes/timestamps
   }
   ```

4. **On-Demand File Reading:**
   - Claude sees available files in context
   - Explicitly requests specific files via memory tool
   - Only loads content when needed for current task

5. **Use Cases:**
   - Long-running workflow state: "Currently on Phase 3 of implementation..."
   - Discovered debugging insights: "Memory leak traced to reactive values..."
   - User preferences: "User prefers verbose statistical explanations..."
   - Cross-session progress: "Completed api-core.R refactoring, next: chat-handlers-*.R"

6. **Clear Separation from Rules:**
   - **Rules** (~/.cassidy/rules/): Static project instructions (always loaded)
   - **Memory** (~/.cassidy/memory/): Dynamic state and learned knowledge (on-demand)
   - **Skills** (~/.cassidy/skills/): Methodology templates (metadata + on-demand)
   - **Context**: Current session working memory

7. **Integration with Compaction:**
   - Before compaction, Claude can save important info to memory
   - Memory persists across compaction boundaries
   - Enables truly unlimited conversation workflows

8. **Testing:**
   - Unit tests for file operations (create, read, update, delete)
   - Security tests (path traversal protection)
   - Integration test: workflow state across sessions
   - Test with compaction: verify memory persists

**Functions to Implement:**

```r
# R/context-memory.R

cassidy_list_memory_files()        # Get directory listing
cassidy_format_memory_listing()    # Format for context (~100 tokens)
cassidy_read_memory_file()         # Read specific file
cassidy_write_memory_file()        # Write/update file
cassidy_delete_memory_file()       # Delete file
cassidy_rename_memory_file()       # Rename/move file

# Tool handler (added to .cassidy_tools registry)
.tool_memory()                     # Execute memory commands
```

**Security Considerations:**

```r
# Validate all paths to prevent directory traversal
.validate_memory_path <- function(path) {
  # Ensure path starts with /memories
  # Resolve to canonical form
  # Reject ../ sequences and URL-encoded traversal
  # Use fs::path_abs() and verify within memory dir
}
```

**Context Output Example:**

```
## Memory Directory

Available memory files (5):
- context_implementation.md (2.3K, updated 2h ago)
- user_preferences.md (0.8K, updated 3 days ago)
- debugging_insights.md (1.5K, updated yesterday)
- efa_workflow_state.md (1.1K, updated last week)

Use the memory tool to read specific files when needed.
```

**Outcome:**
- Persistent knowledge across sessions
- Long-running workflows without context bloat
- Learned insights preserved
- Complements compaction for unlimited conversation length

---

## 11. INTERACTION WITH TOOL SYSTEM

### Tool System Token Considerations

The parallel tool system work affects context management in several ways:

1. **System Prompt Overhead:**
   - Tool definitions injected into each message
   - Estimated ~500 tokens base + ~150 tokens per tool
   - Need to reserve this from available budget

2. **Tool Results in History:**
   - Each tool execution adds user message (tool call) + assistant message (result)
   - Large tool results (file contents, data summaries) consume significant tokens
   - Consider lightweight compaction: clear old tool results after N turns

3. **Compaction Implications:**
   - Tool results can often be discarded if final output is preserved
   - Default compaction prompt should handle tool-heavy conversations
   - Consider custom compaction prompts for agentic tasks

4. **Estimation Challenges:**
   - Tool call JSON is more token-dense than prose
   - May need different estimation method for tool content
   - Consider separate tracking for "tool tokens" vs "conversation tokens"

### Recommended Integration Points

```r
# When starting agentic task with tools
cassidy_agentic_task <- function(..., tools = NULL) {
  # Estimate tool overhead
  tool_overhead <- .estimate_tool_overhead(names(tools))

  # Reserve from budget
  effective_limit <- .CASSIDY_TOKEN_LIMIT - tool_overhead

  # Pass to session or tracking
  session$tool_overhead <- tool_overhead
  session$effective_limit <- effective_limit
}

# When compacting a tool-heavy conversation
cassidy_compact <- function(session, ...) {
  # Detect tool usage
  has_tools <- any(vapply(session$messages, function(m) {
    !is.null(m$is_tool_result) && m$is_tool_result
  }, logical(1)))

  if (has_tools) {
    # Use tool-aware summarization prompt
    summary_prompt <- .tool_aware_compaction_prompt()
  }
}

# Lightweight compaction: clear old tool results
cassidy_clear_tool_results <- function(session, keep_recent = 5) {
  # Keep only last N tool results, clear older ones
  # This is cheaper than full compaction
}
```

---

## 12. R-SPECIFIC CONSIDERATIONS

### S3 vs S7 Consistency

- `cassidy_session` is S3 - keep token tracking as list fields (simple, R-like)
- `ConversationManager` is S7 - add reactive properties for token tracking
- Both patterns work well for their contexts

### Environment Mutation

Current session objects are **immutable** - `chat()` returns updated session.

This is good R practice but requires:
- Users must capture return value: `session <- chat(session, "hi")`
- Or we could make session **mutable** (using environments)

**Recommendation:** Keep immutable pattern, document clearly:

```r
# CORRECT
session <- chat(session, "message")

# WRONG (session not updated)
chat(session, "message")
```

### Backward Compatibility

All new features must be **opt-in or non-breaking**:

- Existing `cassidy_session()` calls work without changes
- Token tracking happens automatically but doesn't change behavior
- Auto-compaction is opt-out (enabled by default) with clear parameter
- Console chat (`cassidy_chat()`) gets warnings but not auto-compaction by default

### Package Dependencies

New dependencies needed:
- **None!** All token estimation uses base R string functions

---

## 13. DOCUMENTATION REQUIREMENTS

### User-Facing Documentation

1. **Vignette:** "Managing Long Conversations"
   - Explain token limits and why they matter
   - Show how to track token usage
   - Demonstrate manual compaction
   - Explain auto-compaction
   - Troubleshooting tips

2. **Function Documentation:**
   - `cassidy_estimate_tokens()` - with examples
   - `cassidy_compact()` - detailed with workflow explanation
   - `cassidy_session_stats()` - interpretation guide
   - Updated `cassidy_session()` docs with new parameters

3. **README Updates:**
   - Add "Long Conversations" section
   - Show token tracking example
   - Link to vignette

### Developer Documentation

1. **Context Engineering Guide:**
   - Document the compaction strategy
   - Explain token estimation methodology
   - Provide guidance for custom summary prompts

2. **Architecture Docs:**
   - Update `.claude/rules/file-structure.md`
   - Document new files and their purposes

---

## 14. ERROR HANDLING

### Compaction Failures

What happens if compaction fails?

```r
cassidy_compact <- function(session, ...) {
  result <- tryCatch(
    {
      # Compaction logic
      new_session
    },
    error = function(e) {
      cli::cli_alert_danger("Compaction failed: {e$message}")
      cli::cli_alert_info("Conversation will continue with existing thread")
      cli::cli_alert_info(
        "You may need to manually start a new conversation soon"
      )

      # Return original session unchanged
      session
    }
  )

  invisible(result)
}
```

### API Failures During Compaction

If the summarization request fails:
- Catch error
- Warn user
- Return original session
- Suggest manual intervention

If thread creation fails after summary:
- We have summary text but no new thread
- Log the summary somewhere?
- Return original session with warning

### Token Estimation Errors

If estimation seems way off (user reports):
- Provide `method = "conservative"` option
- Allow custom `safety_factor`
- Document that these are estimates, not guarantees

---

## 15. TIMEOUT MANAGEMENT

**File:** `R/api-core.R` (modifications)

### The Problem

**Cloudflare 524 Timeout Errors:**
- CassidyAI API requests can timeout if Claude requires extended thinking time
- Cloudflare timeout: 60-100 seconds (depending on plan)
- **No partial results returned** - the entire request fails
- User receives Error 524 with no response content

**Timeout vs Token Limits (Different Constraints):**

| Constraint | Cause | Limit | Solution |
|------------|-------|-------|----------|
| **Token Limit** | Cumulative conversation length | 200,000 tokens | Compaction (Sections 4-5) |
| **Timeout** | Single-request processing time | 60-100 seconds | Chunking (this section) |

Both can occur, and they interact: long context + complex reasoning = higher timeout risk.

### Timeout Scenarios

**High-risk scenarios:**
1. Complex planning tasks ("create implementation plan", "comprehensive analysis")
2. Very long inputs (>100k characters requiring extensive processing)
3. Deep reasoning tasks (multi-step problem solving, architecture design)
4. Large context + complex query (combined effect)

**Examples from testing:**
- Building tool implementation plan → timeout
- 493k character input (repeated "a") with Opus 4.5 → timeout
- Same input with Sonnet 4.5 → possibly no timeout (model-dependent)

### Strategy 1: Prompt-Based Chunking (Prevention)

Encourage Claude to deliver incremental responses that complete before timeout.

#### System-Level Instructions

Add to assistant instructions or project context:

```r
#' Default chunking guidance for timeout prevention
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
```

This can be included in:
- `cassidy_context_project()` output (always present)
- CASSIDY.md assistant instructions
- Prepended to high-risk messages

#### Task-Specific Chunking Prompts

Detect high-risk patterns and add guidance:

```r
#' Detect if message likely requires complex processing
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
```

### Strategy 2: Auto-Retry with Chunking Guidance (Recovery)

When timeout occurs, retry with explicit chunking instructions.

Since **no partial results** are returned on 524 error, we can't "continue" - instead we retry the SAME task but with stronger chunking guidance.

#### Implementation in API Layer

```r
# In cassidy_send_message() or cassidy_chat()

cassidy_send_message <- function(
  thread_id,
  message,
  api_key = Sys.getenv("CASSIDY_API_KEY"),
  timeout = 120,
  retry_on_timeout = TRUE  # NEW parameter
) {
  # Track retry attempts
  max_timeout_retries <- 1  # Only retry once with chunking guidance
  timeout_retry_count <- 0

  # Store original message
  original_message <- message

  repeat {
    result <- tryCatch(
      {
        # Make API request
        resp <- httr2::request(base_url) |>
          httr2::req_headers(
            `x-api-key` = api_key,
            `Content-Type` = "application/json"
          ) |>
          httr2::req_body_json(list(
            thread_id = thread_id,
            message = message
          )) |>
          httr2::req_timeout(timeout) |>
          httr2::req_retry(
            max_tries = 3,
            is_transient = function(resp) {
              # Retry on rate limits and server errors (but NOT timeout)
              httr2::resp_status(resp) %in% c(429, 503, 504)
            }
          ) |>
          httr2::req_error(body = function(resp) {
            body <- httr2::resp_body_json(resp)
            body$message %||% "Unknown API error"
          }) |>
          httr2::req_perform()

        # Success - return result
        return(httr2::resp_body_json(resp))
      },
      error = function(e) {
        # Check if this is a timeout error
        is_timeout <- grepl("524", e$message, fixed = TRUE) ||
                      grepl("timeout", e$message, ignore.case = TRUE) ||
                      grepl("Gateway Time-out", e$message, ignore.case = TRUE)

        if (is_timeout && retry_on_timeout && timeout_retry_count < max_timeout_retries) {
          timeout_retry_count <<- timeout_retry_count + 1

          cli::cli_alert_warning("Request timed out (Error 524)")
          cli::cli_alert_info("Retrying with chunking guidance to prevent timeout...")

          # Retry with chunking prompt prepended
          chunking_prompt <- paste0(
            "IMPORTANT: The previous attempt at this task timed out. ",
            "Please provide a focused, concise response:\n\n",
            "1. Break the task into phases if it's complex\n",
            "2. Start with the most essential information\n",
            "3. Prioritize clarity and brevity over comprehensiveness\n",
            "4. You can elaborate in follow-up messages if needed\n\n",
            "Original task:\n\n"
          )

          message <<- paste0(chunking_prompt, original_message)

          # Continue the loop to retry
          return(NULL)
        }

        # Not a timeout, or retry limit reached - propagate error
        stop(e)
      }
    )

    # If we got a result, break the loop
    if (!is.null(result)) {
      break
    }
  }

  result
}
```

### Strategy 3: Input Validation (Prevention)

Warn users about inputs likely to cause timeouts:

```r
#' Validate message size and warn about timeout risk
#' @keywords internal
.validate_message_size <- function(message, warn = TRUE) {
  msg_size <- nchar(message)

  # Thresholds
  large_input <- 100000   # 100k characters
  very_large_input <- 250000  # 250k characters

  if (msg_size > very_large_input) {
    if (warn) {
      cli::cli_alert_warning(
        "Very large input: {format(msg_size, big.mark = ',')} characters"
      )
      cli::cli_alert_danger(
        "High risk of timeout. Consider breaking this into smaller messages."
      )
    }
    return(list(risk = "high", size = msg_size))
  } else if (msg_size > large_input) {
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

  return(list(risk = "low", size = msg_size))
}
```

Integrate into chat functions:

```r
# In cassidy_chat() or chat.cassidy_session()

# Validate input size
size_check <- .validate_message_size(message, warn = TRUE)

# For very high risk, optionally prompt user
if (size_check$risk == "high") {
  # Could add interactive prompt here:
  # proceed <- readline("Continue anyway? (y/n): ")
  # if (tolower(proceed) != "y") return(invisible(NULL))
}
```

### Strategy 4: Model-Aware Timeout Handling

Different models have different timeout characteristics:

```r
#' Model-specific timeout recommendations
#' @keywords internal
.model_timeout_guidance <- list(
  opus = list(
    name = "Opus",
    timeout_risk = "high",
    max_recommended_chars = 100000,
    guidance = "Use for complex reasoning on moderate inputs"
  ),
  sonnet = list(
    name = "Sonnet",
    timeout_risk = "medium",
    max_recommended_chars = 200000,
    guidance = "Better for long inputs and fast responses"
  ),
  haiku = list(
    name = "Haiku",
    timeout_risk = "low",
    max_recommended_chars = 300000,
    guidance = "Fastest, least likely to timeout"
  )
)
```

This metadata can inform user guidance but doesn't require API changes (model is selected via assistant_id).

### Integration with Session Tracking

Add timeout tracking to session object:

```r
# In cassidy_session structure (Section 3)

cassidy_session <- function(...) {
  structure(
    list(
      # ... existing fields ...

      # NEW: Timeout tracking
      timeout_count = 0L,              # Number of timeouts encountered
      last_timeout = NULL,             # Timestamp of last timeout
      timeout_retries = 0L,            # Number of successful retries
      chunking_guidance_applied = FALSE  # Whether chunking guidance is active
    ),
    class = "cassidy_session"
  )
}
```

Update after timeout handling:

```r
# After successful retry
session$timeout_count <- session$timeout_count + 1L
session$last_timeout <- Sys.time()
session$timeout_retries <- session$timeout_retries + 1L
session$chunking_guidance_applied <- TRUE
```

### User Notifications

Provide clear feedback when timeouts occur:

```r
# On timeout (before retry)
cli::cli_alert_warning("Request timed out after {timeout} seconds")
cli::cli_alert_info("This can happen with complex tasks or very long inputs")
cli::cli_alert_info("Retrying with guidance to deliver response incrementally...")

# After successful retry
cli::cli_alert_success("Retry successful with chunked response")
cli::cli_alert_info(
  "For large tasks, consider breaking your requests into smaller parts"
)

# If retry also times out
cli::cli_alert_danger("Request timed out again after retry")
cli::cli_alert_info(c(
  "Suggestions:",
  "i" = "Break your task into smaller, more focused questions",
  "i" = "Reduce input size if sending large context",
  "i" = "Try a faster model (Sonnet or Haiku) for lengthy inputs",
  "i" = "For planning tasks, ask for an outline first, then elaborate sections"
))
```

### Testing Strategy

#### Unit Tests

```r
# tests/testthat/test-timeout-handling.R

test_that("complex task detection works", {
  expect_true(.is_complex_task("Create a detailed implementation plan"))
  expect_true(.is_complex_task("Comprehensive analysis of the system"))
  expect_false(.is_complex_task("What is 2+2?"))
})

test_that("input size validation categorizes correctly", {
  small <- paste(rep("a", 1000), collapse = "")
  medium <- paste(rep("a", 150000), collapse = "")
  large <- paste(rep("a", 300000), collapse = "")

  expect_equal(.validate_message_size(small, warn = FALSE)$risk, "low")
  expect_equal(.validate_message_size(medium, warn = FALSE)$risk, "medium")
  expect_equal(.validate_message_size(large, warn = FALSE)$risk, "high")
})

test_that("chunking guidance is added to complex tasks", {
  simple <- "Hello"
  complex <- "Create a comprehensive implementation plan"

  expect_equal(.add_chunking_guidance(simple), simple)
  expect_match(.add_chunking_guidance(complex), "incrementally")
})
```

#### Manual Integration Tests

```r
# tests/manual/test-timeout-recovery.R

test_timeout_recovery <- function() {
  library(cassidyr)

  # Test 1: Complex task that might timeout
  session <- cassidy_session()

  cli::cli_h1("Test 1: Complex Planning Task")
  tryCatch({
    chat(session, "Create a detailed implementation plan for a new authentication system with OAuth, JWT, session management, and security considerations.")
  }, error = function(e) {
    cli::cli_alert_info("Error: {e$message}")
  })

  # Test 2: Very long input
  cli::cli_h1("Test 2: Large Input")
  long_text <- paste(rep("Analyze this: ", 10000), collapse = " ")
  tryCatch({
    chat(session, long_text)
  }, error = function(e) {
    cli::cli_alert_info("Error: {e$message}")
  })

  # Check session timeout stats
  cli::cli_h1("Session Timeout Statistics")
  cli::cli_text("Timeout count: {session$timeout_count}")
  cli::cli_text("Successful retries: {session$timeout_retries}")

  invisible(session)
}
```

### Documentation Requirements

#### User-Facing Documentation

Add to "Managing Long Conversations" vignette:

```markdown
## Handling Timeouts

### What are timeouts?

Timeouts occur when a request takes too long to process (typically >60-100 seconds).
Unlike token limit errors, timeouts happen during a single request and are caused by:

- Complex reasoning tasks requiring extended thinking time
- Very large inputs requiring extensive processing
- The combination of long context and complex queries

### Automatic timeout recovery

cassidyr automatically handles timeouts by:

1. Detecting timeout errors (Error 524)
2. Retrying the request with chunking guidance
3. Encouraging Claude to deliver responses incrementally

You don't need to do anything - this happens automatically.

### Preventing timeouts

For best results with complex or large requests:

- **Break tasks into phases**: Ask for an outline first, then elaborate sections
- **Limit input size**: Keep messages under 100,000 characters when possible
- **Be specific**: Focused questions are less likely to timeout than broad ones

### When timeouts persist

If a task repeatedly times out:

- Break it into smaller, more focused sub-tasks
- Reduce the amount of context you're sending
- Consider using a faster model (Sonnet instead of Opus)
- For planning tasks, request incremental delivery explicitly
```

### Integration with Compaction

Timeouts and token limits can interact:

```r
# In cassidy_compact() - Section 4

# Compaction itself could timeout if conversation is very long
cassidy_compact <- function(session, ...) {
  # Add chunking guidance to summarization prompt
  summary_message <- paste0(
    "Note: Please provide a concise summary. Focus on key points.\n\n",
    .default_compaction_prompt(),
    "\n\n# Conversation to Summarize\n\n",
    history_text
  )

  # Use timeout-aware send with retries
  summary_response <- cassidy_send_message(
    thread_id = session$thread_id,
    message = summary_message,
    api_key = api_key,
    timeout = 120,
    retry_on_timeout = TRUE  # Enable retry for compaction
  )

  # ... rest of compaction logic
}
```

### Success Metrics

Timeout management is successful if:

1. **Users see clear communication** about what's happening during timeouts
2. **Most timeouts recover automatically** via retry with chunking
3. **Users understand how to prevent timeouts** through documentation
4. **Timeout tracking** provides visibility into patterns
5. **No silent failures** - all timeout scenarios handled gracefully

### Constants and Configuration

```r
# Add to R/context-tokens.R constants section

#' @keywords internal
.CASSIDY_MAX_TIMEOUT_RETRIES <- 1L  # Retry once with chunking

#' @keywords internal
.CASSIDY_LARGE_INPUT_THRESHOLD <- 100000L  # 100k chars

#' @keywords internal
.CASSIDY_VERY_LARGE_INPUT_THRESHOLD <- 250000L  # 250k chars

#' @keywords internal
.CASSIDY_TIMEOUT_ERROR_PATTERNS <- c("524", "timeout", "Gateway Time-out")
```

### Implementation Checklist

- [ ] Add `.is_complex_task()` detection function
- [ ] Implement `.add_chunking_guidance()` helper
- [ ] Add `.validate_message_size()` validation
- [ ] Modify `cassidy_send_message()` with timeout retry logic
- [ ] Add timeout tracking fields to `cassidy_session`
- [ ] Update `cassidy_session_stats()` to include timeout info
- [ ] Add `.timeout_prevention_prompt()` to context
- [ ] Write unit tests for detection and validation
- [ ] Create manual integration tests for recovery
- [ ] Document timeout handling in vignette
- [ ] Add user-facing guidance for prevention
- [ ] Update print methods to show timeout stats
- [ ] Test with real timeout scenarios
- [ ] Verify chunking guidance actually prevents timeouts

---

## 16. FUTURE ENHANCEMENTS (Out of Scope)

These are nice-to-haves but not in the initial 8-phase implementation:

1. **Selective Message Deletion:**
   - Allow users to manually remove specific messages
   - More granular than full compaction

2. **Smart Tool Result Pruning:**
   - Automatically clear old tool results after N turns
   - Keep only summary of tool outputs
   - Lightweight compaction between full compactions

3. **Context Importance Scoring:**
   - Analyze messages for importance
   - Preserve high-value messages during compaction
   - Requires more sophisticated NLP or LLM analysis

4. **Token Counting Service:**
   - If Anthropic/Cassidy adds token counting endpoint
   - Replace estimation with accurate counts
   - More accurate than character-based estimation

5. **Conversation Branching:**
   - Allow forking conversations at any point
   - Useful when compaction is too aggressive
   - Create alternative conversation paths

6. **Export/Import Compacted History:**
   - Save full uncompacted history alongside compacted version
   - Allow users to "rewind" if needed
   - Archive complete conversation history

7. **Memory Tool Enhancements:**
   - Search across memory files (full-text search)
   - Memory expiration/archiving (auto-delete old files)
   - Memory size limits and quotas
   - Encrypted memory storage
   - Shared team memory (beyond personal memory)

---

## 17. SUCCESS CRITERIA

The context management system is successful if:

1. **Users don't hit token limits unexpectedly**
   - Auto-compaction prevents API failures
   - Clear warnings before limits

2. **Token tracking is transparent**
   - Easy to check usage with `print(session)` or `cassidy_session_stats()`
   - UI shows usage in Shiny app

3. **Compaction preserves conversation quality**
   - Users can continue productively after compaction
   - Key context and decisions are retained

4. **Minimal user friction**
   - Works automatically for most users
   - Can be customized when needed
   - Doesn't break existing code

5. **Well documented**
   - Users understand how to manage long conversations
   - Developers can extend/modify system

---

## 18. RISKS AND MITIGATION

### Risk 1: Token Estimation Inaccuracy

**Risk:** Estimates could be significantly off, leading to over-compaction or under-estimation

**Mitigation:**
- Use 15% safety buffer by default
- Provide multiple estimation methods
- Document limitations clearly
- Allow users to customize safety factor
- Empirically test and refine ratios

### Risk 2: Compaction Quality

**Risk:** Summarization might lose critical context, making conversation unusable

**Mitigation:**
- Preserve recent messages verbatim
- Use carefully crafted prompts based on Anthropic guidance
- Allow custom summary prompts
- Provide "undo" via keeping old thread_id
- Test with real conversations before release

### Risk 3: Performance Impact

**Risk:** Token estimation on every message could slow down chat

**Mitigation:**
- Estimation is O(n) character counting - very fast
- Only compute when needed (not speculatively)
- Cache estimates per message

### Risk 4: State Management Complexity

**Risk:** Tracking tokens across sessions, conversations, and persistence adds complexity

**Mitigation:**
- Keep token tracking as simple integers
- Persist in conversation objects (already have persistence layer)
- Clear separation of concerns (token logic in dedicated file)

### Risk 5: Compaction Threading Issues

**Risk:** Creating new thread during compaction could confuse users or break flow

**Mitigation:**
- Clear messaging about what's happening
- Thread ID change is transparent (session object updated)
- Document behavior clearly
- Provide old thread_id in case user needs it

---

## 19. IMPLEMENTATION CHECKLIST

### Phase 1: Token Estimation ✅ COMPLETE
- [x] Create `R/context-tokens.R`
- [x] Implement `cassidy_estimate_tokens()`
- [x] Define package constants
- [x] Write unit tests
- [x] Document functions with roxygen2
- [x] Update `.claude/rules/file-structure.md`

### Phase 2: Session Tracking ✅ COMPLETE
- [x] Update `cassidy_session()` structure
- [x] Modify `chat.cassidy_session()` method
- [x] Implement `cassidy_estimate_session_tokens()`
- [x] Add `cassidy_session_stats()` function
- [x] Update print methods
- [x] Update `ConversationManager` S7 class
- [x] Test token tracking locally
- [x] Document updates

**Implementation Notes:**
- Added token tracking fields to cassidy_session: token_estimate, token_limit, compact_at, auto_compact, compaction_count, last_compaction, tool_overhead
- Modified chat.cassidy_session() to estimate and track tokens for each message
- Added warning when token usage exceeds 80% threshold
- Created cassidy_session_stats() with print method for detailed diagnostics
- Updated print.cassidy_session() to show token usage with percentage
- Added token_estimate field to ConversationManager S7 class with generics/methods
- Updated conversation persistence to include token_estimate with backward compatibility
- All 50 tests passing

### Phase 3: Manual Compaction ✅ COMPLETE
- [x] Create `R/context-compact.R`
- [x] Implement `cassidy_compact()` core
- [x] Build `.default_compaction_prompt()`
- [x] Implement `.format_messages_for_summary()`
- [x] Test with live API (manual tests)
- [x] Handle error cases
- [x] Document thoroughly
- [x] Add examples

**Implementation Notes:**
- Created R/context-compact.R with three functions: cassidy_compact(), .default_compaction_prompt(), .format_messages_for_summary()
- cassidy_compact() handles full compaction workflow: summarize old messages, create new thread, preserve recent messages
- Error handling with tryCatch blocks for API failures (returns original session on error)
- Default preserves last 2 message pairs (4 messages) - configurable via preserve_recent parameter
- Creates new thread with summary + acknowledgment, then appends preserved messages
- Recalculates token estimates after compaction
- Tracks compaction_count and last_compaction timestamp
- Comprehensive unit tests (29 tests) in test-context-compact.R
- Manual test file test-compaction-live.R for real API testing
- Updated test-chat-core.R to include Phase 2 token tracking fields
- All 1225 package tests passing
- Package passes R CMD check (0 errors, 0 warnings, 0 notes)

### Phase 4: Automatic Compaction ✅ COMPLETE
- [x] Add auto-compaction to `chat.cassidy_session()`
- [x] Implement threshold checking
- [x] Add user notifications
- [x] Test auto-compaction behavior
- [x] Document auto-compaction
- [x] Add disable option

**Implementation Notes:**
- Modified chat.cassidy_session() in R/chat-core.R to check token threshold BEFORE sending messages
- Auto-compaction triggers when projected tokens exceed compact_at threshold (default 85%)
- Calculates projected tokens: current + new message + tool overhead
- When auto_compact = TRUE: automatically calls cassidy_compact() with preserve_recent = 2
- When auto_compact = FALSE: warns user but doesn't compact (uses 80% warning threshold)
- Provides clear user feedback: warning (approaching limit), info (compacting), success (complete)
- Recalculates projected tokens after compaction to ensure message can be sent
- Added 4 new unit tests in test-chat-core.R:
  - Test auto-compaction triggers when threshold exceeded
  - Test auto-compaction disabled when auto_compact = FALSE
  - Test no compaction below threshold
  - Test tool overhead included in threshold calculation
- Updated documentation for chat() generic with auto-compaction examples
- All 59 tests passing in test-chat-core.R
- Package passes R CMD check (0 errors, 0 warnings, 1 note about time verification)

### Phase 5: Shiny UI
- [ ] Add token display to UI
- [ ] Create compact button
- [ ] Implement Shiny handlers
- [ ] Update ConversationManager
- [ ] Test in live Shiny app
- [ ] Polish UI feedback

### Phase 6: Tool Integration
- [ ] Implement `.estimate_tool_overhead()`
- [ ] Update agentic functions
- [ ] Test with tool-heavy tasks
- [ ] Document tool implications

### Phase 7: Console Chat
- [ ] Add token tracking to `cassidy_chat()`
- [ ] Implement warnings
- [ ] Document console usage
- [ ] Test console workflows

### Phase 8: Memory Tool
- [ ] Create `R/context-memory.R`
- [ ] Implement memory file operations (create, read, update, delete, rename)
- [ ] Add path validation and security checks
- [ ] Create `cassidy_list_memory_files()` function
- [ ] Implement lightweight directory listing for context
- [ ] Add memory tool to agentic tool registry
- [ ] Test file operations (unit tests)
- [ ] Test path traversal protection (security)
- [ ] Test cross-session workflow state
- [ ] Test integration with compaction
- [ ] Document memory vs rules vs skills distinction
- [ ] Create example memory workflows
- [ ] Update `.claude/rules/file-structure.md`

### Phase 9: Timeout Management
- [ ] Add `.is_complex_task()` detection function
- [ ] Implement `.add_chunking_guidance()` helper
- [ ] Add `.validate_message_size()` validation
- [ ] Modify `cassidy_send_message()` with timeout retry logic
- [ ] Add timeout tracking fields to `cassidy_session`
- [ ] Update `cassidy_session_stats()` to include timeout info
- [ ] Add `.timeout_prevention_prompt()` to context
- [ ] Write unit tests for detection and validation
- [ ] Create manual integration tests for recovery
- [ ] Document timeout handling in vignette
- [ ] Add user-facing guidance for prevention
- [ ] Update print methods to show timeout stats
- [ ] Test with real timeout scenarios
- [ ] Verify chunking guidance prevents timeouts

### Documentation
- [ ] Write "Managing Long Conversations" vignette
- [ ] Update README
- [ ] Update `.claude/rules/context-system.md`
- [ ] Update all function documentation
- [ ] Add NEWS.md entries

### Testing
- [ ] Unit tests for estimation
- [ ] Integration tests for compaction
- [ ] Manual testing with real API
- [ ] Test auto-compaction thresholds
- [ ] Test Shiny integration
- [ ] Test edge cases (empty sessions, single message, etc.)

---

## 20. ESTIMATED TOTAL EFFORT

**Total Implementation Time:** 54-74 hours (includes Memory Tool and Timeout Management)

**Phase Breakdown:**
- ✅ Phase 1 (Estimation): 4-6 hours - COMPLETE
- ✅ Phase 2 (Tracking): 6-8 hours - COMPLETE
- ⏳ Phase 3 (Manual Compaction): 10-12 hours - NEXT
- Phase 4 (Auto Compaction): 4-6 hours
- Phase 5 (Shiny UI): 8-10 hours
- Phase 6 (Tool Integration): 4-6 hours
- Phase 7 (Console): 4-6 hours
- Phase 8 (Memory Tool): 8-10 hours
- ✅ Phase 9 (Timeout Management): 6-8 hours - COMPLETE

**Additional Effort:**
- Testing: 12-14 hours (includes memory security tests and timeout recovery tests)
- Documentation: 8-10 hours (includes memory and timeout guides)
- Code review and refinement: 4-6 hours

**Completed So Far:** ~16-22 hours (Phases 1, 2, 9)
**Remaining:** ~38-52 hours (Phases 3-8 + additional work)

**Recommended Timeline:**
- ✅ Week 1: Phases 1-2, 9 (Foundation + Timeout) - COMPLETE
- Week 2: Phase 3 (Manual Compaction) - IN PROGRESS
- Week 3: Phases 4-5 (Auto + Shiny)
- Week 4: Phases 6-7 (Tool Integration + Console)
- Week 5: Phase 8 (Memory Tool) + Testing + Final Documentation

**Priority Notes:**
- **Phase 9 (Timeout Management)** ✅ Implemented alongside Phases 1-2 to address immediate user pain points (524 errors)
- **Phase 3 (Manual Compaction)** is the natural next step - provides core functionality for long conversations
- **Phase 8 (Memory Tool)** can be implemented independently after Phases 1-7 are complete and stable. It's an advanced feature that complements the core context management system.

**Phased Rollout Strategy:**
1. ✅ **Critical Path (Week 1):** Phases 1-2, 9 - Token estimation, tracking, and timeout recovery - COMPLETE
2. ⏳ **Core Functionality (Week 2):** Phase 3 - Manual compaction - NEXT
3. **Enhancement (Weeks 3-4):** Phases 4-7 - Automation and polish
4. **Advanced Features (Week 5):** Phase 8 - Memory tool for power users

---

END OF TECHNICAL IMPLEMENTATION PLAN
