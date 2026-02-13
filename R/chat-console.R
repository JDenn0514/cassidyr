# ===========================================================================
# UNIFIED CONSOLE CHAT INTERFACE
# Package-level state management for seamless console chat experience
# ===========================================================================

# Package-level state environment
.cassidy_state <- new.env(parent = emptyenv())

# ===========================================================================
# STATE MANAGEMENT (INTERNAL)
# ===========================================================================

#' Get current conversation ID from package state
#' @keywords internal
.get_current_conv_id <- function() {
  .cassidy_state$current_conv_id
}

#' Set current conversation ID in package state
#' @keywords internal
.set_current_conv_id <- function(conv_id) {
  .cassidy_state$current_conv_id <- conv_id
}

#' Get current thread ID from package state
#' @keywords internal
.get_current_thread_id <- function() {
  .cassidy_state$current_thread_id
}

#' Set current thread ID in package state
#' @keywords internal
.set_current_thread_id <- function(thread_id) {
  .cassidy_state$current_thread_id <- thread_id
}

#' Clear all package state
#' @keywords internal
.clear_state <- function() {
  .cassidy_state$current_conv_id <- NULL
  .cassidy_state$current_thread_id <- NULL
}

# ===========================================================================
# CONVERSATION ID GENERATION
# ===========================================================================

#' Generate a unique conversation ID
#' @keywords internal
.generate_conv_id <- function() {
  timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
  random_suffix <- paste0(
    sample(letters, 4, replace = TRUE),
    collapse = ""
  )
  paste0("conv_", timestamp, "_", random_suffix)
}

#' Generate conversation title from first message
#' @keywords internal
.generate_title <- function(message, max_length = 50) {
  # Remove newlines and extra whitespace
  title <- gsub("\\s+", " ", message)
  title <- trimws(title)

  # Truncate if needed
  if (nchar(title) > max_length) {
    title <- paste0(substr(title, 1, max_length - 3), "...")
  }

  title
}

# ===========================================================================
# CONTEXT GATHERING FOR CONSOLE
# ===========================================================================

#' Gather context based on context level
#' @keywords internal
.gather_context_for_level <- function(
  context_level,
  include_data,
  include_files,
  data_method = "basic",
  include_skills = NULL
) {
  params <- switch(
    context_level,
    minimal = list(
      config = TRUE,
      session = FALSE,
      git = FALSE,
      data = FALSE,
      files = NULL,
      skills = include_skills
    ),
    standard = list(
      config = TRUE,
      session = TRUE,
      git = FALSE,
      data = include_data,
      data_method = data_method,
      files = include_files,
      skills = include_skills
    ),
    comprehensive = list(
      config = TRUE,
      session = TRUE,
      git = TRUE,
      data = include_data,
      data_method = "codebook",
      files = include_files,
      skills = include_skills
    )
  )

  do.call(gather_context, params)
}

# ===========================================================================
# MAIN UNIFIED CHAT FUNCTION
# ===========================================================================

#' Chat with CassidyAI (Unified Interface)
#'
#' Send a message to a CassidyAI assistant with automatic conversation
#' management. This unified interface automatically continues conversations,
#' manages context, and persists chat history without requiring you to track
#' thread IDs or session objects.
#'
#' @param message Character. The message to send to the assistant.
#' @param conversation Character or NULL. Controls conversation behavior:
#'   - `NULL` (default): Continue current conversation, or create new if none
#'   - `"new"`: Start a fresh conversation with new context
#'   - `conv_id` (string): Switch to and continue a specific conversation
#' @param assistant_id Character. The CassidyAI assistant ID. Defaults to
#'   the `CASSIDY_ASSISTANT_ID` environment variable.
#' @param api_key Character. Your CassidyAI API key. Defaults to
#'   the `CASSIDY_API_KEY` environment variable.
#' @param context_level Character. Amount of context to include for new
#'   conversations: `"minimal"`, `"standard"` (default), or `"comprehensive"`.
#'   See Details for what each level includes.
#' @param include_data Logical. Whether to include data frame descriptions
#'   in context. Default is TRUE.
#' @param include_files Character vector. Optional file paths to include in
#'   context for new conversations.
#' @param include_skills Character vector. Optional skill names to include
#'   in context for new conversations.
#' @param timeout Numeric. Request timeout in seconds. Default is 300.
#' @param thread_id Character or NULL. **Deprecated.** For backward
#'   compatibility only. If provided, uses legacy behavior without state
#'   management.
#' @param context **Deprecated.** For backward compatibility with session-based
#'   chat only. Ignored when `thread_id` is provided.
#'
#' @return A `cassidy_chat` S3 object containing:
#'   \describe{
#'     \item{conversation_id}{Local conversation ID}
#'     \item{thread_id}{Cassidy API thread ID}
#'     \item{response}{The assistant's response (a `cassidy_response` object)}
#'     \item{message}{Your original message}
#'     \item{context_level}{Context level used (for new conversations)}
#'   }
#'
#' @details
#' ## Context Levels
#'
#' - **minimal**: Only project configuration (CASSIDY.md)
#' - **standard**: Config + session info + data descriptions (default)
#' - **comprehensive**: Config + session + git status + detailed data + files
#'
#' Context is only gathered and sent for **new conversations**, not when
#' continuing existing ones.
#'
#' ## Conversation Management
#'
#' The package automatically tracks your current conversation in memory. Each
#' call to `cassidy_chat()` either continues the current conversation or starts
#' a new one based on the `conversation` parameter.
#'
#' Conversations are automatically saved to disk after each message, so you can
#' resume them later even after restarting R.
#'
#' ## State Management Functions
#'
#' - [cassidy_conversations()] - List saved conversations
#' - [cassidy_current()] - View current conversation info
#' - [cassidy_reset()] - Clear package state and start fresh
#'
#' @family chat-functions
#' @export
#'
#' @examples
#' \dontrun{
#' # Simple usage - just chat!
#' cassidy_chat("What is the tidyverse?")
#' cassidy_chat("Tell me more")  # Automatically continues
#'
#' # Start a new conversation
#' cassidy_chat("New topic", conversation = "new")
#'
#' # Include specific files in context
#' cassidy_chat(
#'   "Review this code",
#'   conversation = "new",
#'   include_files = c("R/my-function.R")
#' )
#'
#' # Use comprehensive context
#' cassidy_chat(
#'   "Help me understand this project",
#'   conversation = "new",
#'   context_level = "comprehensive"
#' )
#'
#' # Switch to a previous conversation
#' convs <- cassidy_conversations()
#' cassidy_chat("Continue where we left off", conversation = convs$id[2])
#'
#' # Reset and start fresh
#' cassidy_reset()
#' cassidy_chat("Hello!")
#' }
cassidy_chat <- function(
  message,
  conversation = NULL,
  assistant_id = Sys.getenv("CASSIDY_ASSISTANT_ID"),
  api_key = Sys.getenv("CASSIDY_API_KEY"),
  context_level = c("standard", "minimal", "comprehensive"),
  include_data = TRUE,
  include_files = NULL,
  include_skills = NULL,
  timeout = 300,
  thread_id = NULL,
  context = NULL
) {
  # Validate message
  if (missing(message) || is.null(message) || message == "") {
    cli::cli_abort("message is required and cannot be empty")
  }

  # BACKWARD COMPATIBILITY: If thread_id provided, use legacy mode
  if (!is.null(thread_id)) {
    cli::cli_alert_info("Using thread_id directly (legacy mode)")
    return(.cassidy_chat_legacy(
      message = message,
      thread_id = thread_id,
      context = context,
      assistant_id = assistant_id,
      api_key = api_key,
      timeout = timeout
    ))
  }

  # Match context level
  context_level <- match.arg(context_level)

  # Determine conversation mode
  if (is.null(conversation)) {
    # Default: continue current or create new
    current_conv_id <- .get_current_conv_id()

    if (is.null(current_conv_id)) {
      # No current conversation - create new
      result <- .chat_new_conversation(
        message = message,
        assistant_id = assistant_id,
        api_key = api_key,
        context_level = context_level,
        include_data = include_data,
        include_files = include_files,
        include_skills = include_skills,
        timeout = timeout
      )
    } else {
      # Continue current conversation
      result <- .chat_continue_conversation(
        message = message,
        conv_id = current_conv_id,
        api_key = api_key,
        timeout = timeout
      )
    }
  } else if (conversation == "new") {
    # Explicit new conversation request
    result <- .chat_new_conversation(
      message = message,
      assistant_id = assistant_id,
      api_key = api_key,
      context_level = context_level,
      include_data = include_data,
      include_files = include_files,
      include_skills = include_skills,
      timeout = timeout
    )
  } else {
    # Switch to specific conversation
    result <- .chat_switch_conversation(
      message = message,
      conv_id = conversation,
      api_key = api_key,
      timeout = timeout
    )
  }

  result
}

# ===========================================================================
# CONVERSATION FLOW HELPERS (INTERNAL)
# ===========================================================================

#' Create new conversation with context
#' @keywords internal
.chat_new_conversation <- function(
  message,
  assistant_id,
  api_key,
  context_level,
  include_data,
  include_files,
  include_skills,
  timeout
) {
  # Generate conversation ID
  conv_id <- .generate_conv_id()
  title <- .generate_title(message)

  cli::cli_alert_info("Starting new conversation: {.val {title}}")

  # Gather context
  context_text <- .gather_context_for_level(
    context_level = context_level,
    include_data = include_data,
    include_files = include_files,
    include_skills = include_skills
  )

  if (!is.null(context_text)) {
    context_size <- nchar(context_text)
    cli::cli_alert_info(
      "Including context ({context_size} characters, {.val {context_level}} level)"
    )
  }

  # Create thread
  thread_id <- cassidy_create_thread(assistant_id, api_key)

  # Prepare message with context
  original_message <- message
  if (!is.null(context_text)) {
    message <- paste0(
      "# Context\n\n",
      context_text,
      "\n\n---\n\n# Question\n\n",
      message
    )
  }

  # Send message
  response <- cassidy_send_message(
    thread_id = thread_id,
    message = message,
    api_key = api_key,
    timeout = timeout
  )

  # Create conversation object
  conversation <- list(
    id = conv_id,
    title = title,
    thread_id = thread_id,
    messages = list(
      list(
        role = "user",
        content = original_message,
        timestamp = Sys.time()
      ),
      list(
        role = "assistant",
        content = response$content,
        timestamp = response$timestamp
      )
    ),
    context_sent = !is.null(context_text),
    context_level = context_level,
    context_files = include_files %||% character(),
    sent_context_files = if (!is.null(include_files)) include_files else character(),
    sent_data_frames = character(),
    sent_skills = if (!is.null(include_skills)) include_skills else character(),
    created_at = Sys.time(),
    updated_at = Sys.time()
  )

  # Save conversation
  cassidy_save_conversation(conversation)

  # Update package state
  .set_current_conv_id(conv_id)
  .set_current_thread_id(thread_id)

  # Return result
  structure(
    list(
      conversation_id = conv_id,
      thread_id = thread_id,
      response = response,
      message = original_message,
      timestamp = Sys.time(),
      context_level = context_level,
      context_used = !is.null(context_text)
    ),
    class = "cassidy_chat"
  )
}

#' Continue existing conversation
#' @keywords internal
.chat_continue_conversation <- function(
  message,
  conv_id,
  api_key,
  timeout
) {
  # Load conversation
  conversation <- cassidy_load_conversation(conv_id)

  if (is.null(conversation)) {
    cli::cli_abort(c(
      "x" = "Conversation {.val {conv_id}} not found.",
      "i" = "Use {.fn cassidy_conversations} to see available conversations",
      "i" = "Or use {.code conversation = 'new'} to start a new conversation"
    ))
  }

  if (is.null(conversation$thread_id)) {
    cli::cli_abort(c(
      "x" = "Conversation {.val {conv_id}} has no thread_id.",
      "i" = "This conversation may be corrupted. Start a new one with {.code conversation = 'new'}"
    ))
  }

  # Send message to existing thread
  response <- cassidy_send_message(
    thread_id = conversation$thread_id,
    message = message,
    api_key = api_key,
    timeout = timeout
  )

  # Update conversation
  conversation$messages <- c(
    conversation$messages,
    list(
      list(
        role = "user",
        content = message,
        timestamp = Sys.time()
      ),
      list(
        role = "assistant",
        content = response$content,
        timestamp = response$timestamp
      )
    )
  )
  conversation$updated_at <- Sys.time()

  # Save updated conversation
  cassidy_save_conversation(conversation)

  # Return result
  structure(
    list(
      conversation_id = conv_id,
      thread_id = conversation$thread_id,
      response = response,
      message = message,
      timestamp = Sys.time(),
      context_level = conversation$context_level,
      context_used = FALSE
    ),
    class = "cassidy_chat"
  )
}

#' Switch to different conversation and continue
#' @keywords internal
.chat_switch_conversation <- function(
  message,
  conv_id,
  api_key,
  timeout
) {
  # Load conversation
  conversation <- cassidy_load_conversation(conv_id)

  if (is.null(conversation)) {
    cli::cli_abort(c(
      "x" = "Conversation {.val {conv_id}} not found.",
      "i" = "Use {.fn cassidy_conversations} to see available conversations"
    ))
  }

  cli::cli_alert_info("Switching to conversation: {.val {conversation$title}}")

  # Update package state
  .set_current_conv_id(conv_id)
  .set_current_thread_id(conversation$thread_id)

  # Continue with the conversation
  .chat_continue_conversation(
    message = message,
    conv_id = conv_id,
    api_key = api_key,
    timeout = timeout
  )
}

# ===========================================================================
# LEGACY SUPPORT
# ===========================================================================

#' Legacy cassidy_chat behavior (for backward compatibility)
#' @keywords internal
.cassidy_chat_legacy <- function(
  message,
  thread_id,
  context = NULL,
  assistant_id = Sys.getenv("CASSIDY_ASSISTANT_ID"),
  api_key = Sys.getenv("CASSIDY_API_KEY"),
  timeout = 120
) {
  # Warn if context provided with existing thread (old behavior)
  if (!is.null(context)) {
    cli::cli_alert_warning(
      "Context ignored - thread already exists. Context is only used at thread creation."
    )
  }

  # Send message directly without state management
  response <- cassidy_send_message(
    thread_id = thread_id,
    message = message,
    api_key = api_key,
    timeout = timeout
  )

  # Return simple result (no conversation tracking)
  structure(
    list(
      thread_id = thread_id,
      response = response,
      message = message,
      timestamp = Sys.time(),
      context_used = FALSE
    ),
    class = "cassidy_chat"
  )
}

# ===========================================================================
# USER-FACING HELPER FUNCTIONS
# ===========================================================================

#' List saved conversations (enhanced)
#'
#' Lists your saved conversations with enhanced formatting for console use.
#' This wraps [cassidy_list_conversations()] with a custom print method.
#'
#' @param n Integer. Maximum number of conversations to return. Default is 10.
#'
#' @return A data frame with class `cassidy_conversations` containing:
#'   \describe{
#'     \item{id}{Conversation ID}
#'     \item{thread_id}{Cassidy API thread ID}
#'     \item{title}{Conversation title}
#'     \item{created_at}{Creation timestamp}
#'     \item{updated_at}{Last update timestamp}
#'     \item{message_count}{Number of messages}
#'   }
#'
#' @family chat-functions
#' @export
#'
#' @examples
#' \dontrun{
#' # List recent conversations
#' cassidy_conversations()
#'
#' # List more conversations
#' cassidy_conversations(n = 20)
#'
#' # Switch to a conversation
#' convs <- cassidy_conversations()
#' cassidy_chat("Let's continue", conversation = convs$id[1])
#' }
cassidy_conversations <- function(n = 10) {
  convs <- cassidy_list_conversations(n = n)

  # Add class for custom print method
  class(convs) <- c("cassidy_conversations", class(convs))

  convs
}

#' Show current conversation info
#'
#' Displays information about the currently active conversation tracked by
#' the package state.
#'
#' @return List with conversation metadata, or NULL if no active conversation.
#'   Returned invisibly.
#'
#' @family chat-functions
#' @export
#'
#' @examples
#' \dontrun{
#' # Start a conversation
#' cassidy_chat("Hello!")
#'
#' # Check current conversation
#' cassidy_current()
#'
#' # Reset state
#' cassidy_reset()
#' cassidy_current()  # Returns NULL
#' }
cassidy_current <- function() {
  conv_id <- .get_current_conv_id()

  if (is.null(conv_id)) {
    cli::cli_alert_info("No active conversation")
    cli::cli_text("Use {.fn cassidy_chat} to start a conversation")
    return(invisible(NULL))
  }

  # Load conversation
  conversation <- cassidy_load_conversation(conv_id)

  if (is.null(conversation)) {
    cli::cli_alert_warning("Current conversation {.val {conv_id}} not found on disk")
    cli::cli_text("State may be stale. Use {.fn cassidy_reset} to clear.")
    return(invisible(NULL))
  }

  # Display info
  cli::cli_h1("Current Conversation")
  cli::cli_text("{.field ID}: {.val {conversation$id}}")
  cli::cli_text("{.field Title}: {.val {conversation$title}}")
  cli::cli_text("{.field Thread ID}: {.val {conversation$thread_id}}")
  cli::cli_text(
    "{.field Created}: {.val {format(conversation$created_at, '%Y-%m-%d %H:%M:%S')}}"
  )
  cli::cli_text(
    "{.field Updated}: {.val {format(conversation$updated_at, '%Y-%m-%d %H:%M:%S')}}"
  )
  cli::cli_text("{.field Messages}: {.val {length(conversation$messages)}}")

  if (conversation$context_sent) {
    cli::cli_text(
      "{.field Context}: {.val {conversation$context_level}} level"
    )
  }

  invisible(conversation)
}

#' Reset console chat state
#'
#' Clears the package-level conversation state. This does not delete any
#' saved conversations - it only resets the "current conversation" tracking.
#' Your next call to [cassidy_chat()] will start a new conversation.
#'
#' @return NULL (invisibly)
#'
#' @family chat-functions
#' @export
#'
#' @examples
#' \dontrun{
#' # Chat for a while
#' cassidy_chat("Hello")
#' cassidy_chat("How are you?")
#'
#' # Reset and start fresh
#' cassidy_reset()
#' cassidy_chat("New conversation!")
#' }
cassidy_reset <- function() {
  .clear_state()
  cli::cli_alert_success("Console chat state cleared")
  cli::cli_text("Your next {.fn cassidy_chat} call will start a new conversation")
  invisible(NULL)
}
