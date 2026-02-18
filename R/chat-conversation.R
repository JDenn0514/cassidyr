#' Conversation Manager R6 Class
#'
#' Manages conversation state for the chat application
#' @keywords internal
#' Conversation Manager using S7
#' @keywords internal
ConversationManager <- S7::new_class(
  "ConversationManager",
  properties = list(
    conversations = S7::class_any,
    current_id = S7::class_any,
    context_sent = S7::class_any,
    context_files = S7::class_any,
    is_loading = S7::class_any,
    context_text = S7::class_any,
    # NEW: Track what's actually been sent to Cassidy
    sent_context_files = S7::class_any,
    sent_data_frames = S7::class_any,
    # NEW: Track skills
    context_skills = S7::class_any,
    sent_skills = S7::class_any,
    # NEW: Track items queued for refresh (re-send)
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
      # NEW: Initialize tracking
      sent_context_files = shiny::reactiveVal(character()),
      sent_data_frames = shiny::reactiveVal(character()),
      context_skills = shiny::reactiveVal(character()),
      sent_skills = shiny::reactiveVal(character()),
      pending_refresh_files = shiny::reactiveVal(character()),
      pending_refresh_data = shiny::reactiveVal(character()),
      pending_refresh_skills = shiny::reactiveVal(character()),
      # NEW: Token tracking
      token_estimate = shiny::reactiveVal(0L),
      token_limit = shiny::reactiveVal(.CASSIDY_TOKEN_LIMIT)
    )
  }
)

# ---- Generics ----

#' Get all conversations
#' @keywords internal
conv_get_all <- S7::new_generic("conv_get_all", "x")

#' Get current conversation
#' @keywords internal
conv_get_current <- S7::new_generic("conv_get_current", "x")

#' Update current conversation
#' @keywords internal
conv_update_current <- S7::new_generic("conv_update_current", "x")

#' Create a new conversation
#' @keywords internal
conv_create_new <- S7::new_generic("conv_create_new", "x")

#' Switch to a conversation
#' @keywords internal
conv_switch_to <- S7::new_generic("conv_switch_to", "x")

#' Delete a conversation
#' @keywords internal
conv_delete <- S7::new_generic("conv_delete", "x")

#' Add a message to current conversation
#' @keywords internal
conv_add_message <- S7::new_generic("conv_add_message", "x")

#' Generate title from message
#' @keywords internal
conv_generate_title <- S7::new_generic("conv_generate_title", "x")

#' Get current conversation ID
#' @keywords internal
conv_current_id <- S7::new_generic("conv_current_id", "x")

#' Get context sent status
#' @keywords internal
conv_context_sent <- S7::new_generic("conv_context_sent", "x")

#' Set context sent status
#' @keywords internal
conv_set_context_sent <- S7::new_generic("conv_set_context_sent", "x")

#' Get context files
#' @keywords internal
conv_context_files <- S7::new_generic("conv_context_files", "x")

#' Set context files
#' @keywords internal
conv_set_context_files <- S7::new_generic("conv_set_context_files", "x")

#' Get loading status
#' @keywords internal
conv_is_loading <- S7::new_generic("conv_is_loading", "x")

#' Set loading status
#' @keywords internal
conv_set_loading <- S7::new_generic("conv_set_loading", "x")

#' Get context text
#' @keywords internal
conv_context_text <- S7::new_generic("conv_context_text", "x")

#' Set context text
#' @keywords internal
conv_set_context <- S7::new_generic("conv_set_context", "x")

# NEW: Generics for sent tracking
#' Get sent context files
#' @keywords internal
conv_sent_context_files <- S7::new_generic("conv_sent_context_files", "x")

#' Set sent context files
#' @keywords internal
conv_set_sent_context_files <- S7::new_generic(
  "conv_set_sent_context_files",
  "x"
)

#' Get sent data frames
#' @keywords internal
conv_sent_data_frames <- S7::new_generic("conv_sent_data_frames", "x")

#' Set sent data frames
#' @keywords internal
conv_set_sent_data_frames <- S7::new_generic("conv_set_sent_data_frames", "x")

#' Get pending refresh files
#' @keywords internal
conv_pending_refresh_files <- S7::new_generic("conv_pending_refresh_files", "x")

#' Set pending refresh files
#' @keywords internal
conv_set_pending_refresh_files <- S7::new_generic(
  "conv_set_pending_refresh_files",
  "x"
)

#' Get pending refresh data frames
#' @keywords internal
conv_pending_refresh_data <- S7::new_generic("conv_pending_refresh_data", "x")

#' Set pending refresh data frames
#' @keywords internal
conv_set_pending_refresh_data <- S7::new_generic(
  "conv_set_pending_refresh_data",
  "x"
)

#' Get context skills
#' @keywords internal
conv_context_skills <- S7::new_generic("conv_context_skills", "x")

#' Set context skills
#' @keywords internal
conv_set_context_skills <- S7::new_generic("conv_set_context_skills", "x")

#' Get sent skills
#' @keywords internal
conv_sent_skills <- S7::new_generic("conv_sent_skills", "x")

#' Set sent skills
#' @keywords internal
conv_set_sent_skills <- S7::new_generic("conv_set_sent_skills", "x")

#' Get pending refresh skills
#' @keywords internal
conv_pending_refresh_skills <- S7::new_generic("conv_pending_refresh_skills", "x")

#' Set pending refresh skills
#' @keywords internal
conv_set_pending_refresh_skills <- S7::new_generic(
  "conv_set_pending_refresh_skills",
  "x"
)

#' Get token estimate
#' @keywords internal
conv_token_estimate <- S7::new_generic("conv_token_estimate", "x")

#' Set token estimate
#' @keywords internal
conv_set_token_estimate <- S7::new_generic("conv_set_token_estimate", "x")

# ---- Methods ----

S7::method(conv_get_all, ConversationManager) <- function(x) {
  x@conversations()
}

S7::method(conv_current_id, ConversationManager) <- function(x) {
  x@current_id()
}

S7::method(conv_context_sent, ConversationManager) <- function(x) {
  x@context_sent()
}

S7::method(conv_set_context_sent, ConversationManager) <- function(x, value) {
  x@context_sent(value)
  invisible(x)
}

S7::method(conv_context_files, ConversationManager) <- function(x) {
  x@context_files()
}

S7::method(conv_set_context_files, ConversationManager) <- function(x, value) {
  x@context_files(value)
  invisible(x)
}

S7::method(conv_is_loading, ConversationManager) <- function(x) {
  x@is_loading()
}

S7::method(conv_set_loading, ConversationManager) <- function(x, value) {
  x@is_loading(value)
  invisible(x)
}

S7::method(conv_context_text, ConversationManager) <- function(x) {
  x@context_text()
}

S7::method(conv_set_context, ConversationManager) <- function(x, value) {
  x@context_text(value)
  invisible(x)
}

# NEW: Methods for sent tracking
S7::method(conv_sent_context_files, ConversationManager) <- function(x) {
  x@sent_context_files()
}

S7::method(conv_set_sent_context_files, ConversationManager) <- function(
  x,
  value
) {
  x@sent_context_files(value)
  invisible(x)
}

S7::method(conv_sent_data_frames, ConversationManager) <- function(x) {
  x@sent_data_frames()
}

S7::method(conv_set_sent_data_frames, ConversationManager) <- function(
  x,
  value
) {
  x@sent_data_frames(value)
  invisible(x)
}

S7::method(conv_pending_refresh_files, ConversationManager) <- function(x) {
  x@pending_refresh_files()
}

S7::method(conv_set_pending_refresh_files, ConversationManager) <- function(
  x,
  value
) {
  x@pending_refresh_files(value)
  invisible(x)
}

S7::method(conv_pending_refresh_data, ConversationManager) <- function(x) {
  x@pending_refresh_data()
}

S7::method(conv_set_pending_refresh_data, ConversationManager) <- function(
  x,
  value
) {
  x@pending_refresh_data(value)
  invisible(x)
}

S7::method(conv_context_skills, ConversationManager) <- function(x) {
  x@context_skills()
}

S7::method(conv_set_context_skills, ConversationManager) <- function(x, value) {
  x@context_skills(value)
  invisible(x)
}

S7::method(conv_sent_skills, ConversationManager) <- function(x) {
  x@sent_skills()
}

S7::method(conv_set_sent_skills, ConversationManager) <- function(x, value) {
  x@sent_skills(value)
  invisible(x)
}

S7::method(conv_pending_refresh_skills, ConversationManager) <- function(x) {
  x@pending_refresh_skills()
}

S7::method(conv_set_pending_refresh_skills, ConversationManager) <- function(
  x,
  value
) {
  x@pending_refresh_skills(value)
  invisible(x)
}

S7::method(conv_token_estimate, ConversationManager) <- function(x) {
  x@token_estimate()
}

S7::method(conv_set_token_estimate, ConversationManager) <- function(x, value) {
  x@token_estimate(value)
  invisible(x)
}

S7::method(conv_get_current, ConversationManager) <- function(x) {
  convs <- x@conversations()
  current_id <- x@current_id()

  if (is.null(current_id) || length(convs) == 0) {
    return(NULL)
  }

  idx <- which(vapply(convs, function(c) c$id, character(1)) == current_id)

  if (length(idx) == 0) {
    return(NULL)
  }

  convs[[idx]]
}

S7::method(conv_update_current, ConversationManager) <- function(x, updates) {
  convs <- x@conversations()
  current_id <- x@current_id()

  if (is.null(current_id)) {
    return(invisible(x))
  }

  idx <- which(vapply(convs, function(c) c$id, character(1)) == current_id)

  if (length(idx) == 0) {
    return(invisible(x))
  }

  for (name in names(updates)) {
    convs[[idx]][[name]] <- updates[[name]]
  }

  x@conversations(convs)

  # AUTO-SAVE after update
  conv_save_current(x)

  invisible(x)
}

S7::method(conv_create_new, ConversationManager) <- function(
  x,
  session = NULL
) {
  new_id <- paste0(
    "conv_",
    format(Sys.time(), "%Y%m%d%H%M%S"),
    "_",
    sample(1000:9999, 1)
  )

  new_conv <- list(
    id = new_id,
    title = "New Conversation",
    messages = list(),
    thread_id = NULL,
    context_sent = FALSE,
    context_files = character(),
    # NEW: Initialize sent tracking in conversation record
    sent_context_files = character(),
    sent_data_frames = character(),
    context_skills = character(),
    sent_skills = character(),
    # NEW: Initialize token tracking
    token_estimate = 0L,
    created_at = Sys.time()
  )

  convs <- x@conversations()
  convs <- c(list(new_conv), convs)

  x@conversations(convs)
  x@current_id(new_id)
  x@context_sent(FALSE)
  x@context_files(character())
  x@is_loading(FALSE)
  # NEW: Clear all tracking for new conversation
  x@sent_context_files(character())
  x@sent_data_frames(character())
  x@context_skills(character())
  x@sent_skills(character())
  x@pending_refresh_files(character())
  x@pending_refresh_data(character())
  x@pending_refresh_skills(character())
  # NEW: Reset token tracking
  x@token_estimate(0L)

  if (!is.null(session)) {
    session$sendCustomMessage("clearInput", list())
    # Clear UI checkboxes for new conversation - use character() not list()
    session$sendCustomMessage(
      "syncFileCheckboxes",
      list(sent = character(), selected = character())
    )
    session$sendCustomMessage(
      "syncDataCheckboxes",
      list(sent = character(), selected = character())
    )
  }

  cli::cli_alert_success("Created new conversation")
  invisible(new_id)
}


S7::method(conv_switch_to, ConversationManager) <- function(
  x,
  conv_id,
  session = NULL
) {
  current <- x@current_id()

  if (!is.null(current) && current == conv_id) {
    return(invisible(x))
  }

  convs <- x@conversations()
  idx <- which(vapply(convs, function(c) c$id, character(1)) == conv_id)

  if (length(idx) > 0) {
    conv <- convs[[idx]]
    x@current_id(conv_id)
    x@context_sent(conv$context_sent)
    x@context_files(conv$context_files %||% character())
    x@is_loading(FALSE)
    # Restore sent tracking from conversation
    x@sent_context_files(conv$sent_context_files %||% character())
    x@sent_data_frames(conv$sent_data_frames %||% character())
    x@context_skills(conv$context_skills %||% character())
    x@sent_skills(conv$sent_skills %||% character())
    # Clear pending on switch (start fresh)
    x@pending_refresh_files(character())
    x@pending_refresh_data(character())
    x@pending_refresh_skills(character())
    # NEW: Restore token estimate
    x@token_estimate(conv$token_estimate %||% 0L)

    if (!is.null(session)) {
      session$sendCustomMessage("clearInput", list())

      # Sync checkboxes: combine sent + selected (context_files)
      # Sent files should be checked AND show as sent (blue)
      # Selected-but-not-sent should be checked AND show as pending (green)
      all_selected <- union(
        conv$sent_context_files %||% character(),
        conv$context_files %||% character()
      )

      # IMPORTANT: Don't use list() for empty vectors - use character()
      session$sendCustomMessage(
        "syncFileCheckboxes",
        list(
          sent = if (length(conv$sent_context_files) > 0) {
            conv$sent_context_files
          } else {
            character()
          },
          selected = if (length(all_selected) > 0) {
            all_selected
          } else {
            character()
          }
        )
      )
      session$sendCustomMessage(
        "syncDataCheckboxes",
        list(
          sent = if (length(conv$sent_data_frames) > 0) {
            conv$sent_data_frames
          } else {
            character()
          },
          selected = if (length(conv$sent_data_frames) > 0) {
            conv$sent_data_frames
          } else {
            character()
          }
        )
      )
    }

    cli::cli_alert_info("Switched to conversation: {conv$title}")
  }

  invisible(x)
}

S7::method(conv_delete, ConversationManager) <- function(x, conv_id) {
  convs <- x@conversations()
  convs <- convs[vapply(convs, function(c) c$id, character(1)) != conv_id]
  x@conversations(convs)

  current <- x@current_id()

  if (!is.null(current) && current == conv_id) {
    if (length(convs) > 0) {
      x@current_id(convs[[1]]$id)
      x@context_sent(convs[[1]]$context_sent)
      x@context_files(convs[[1]]$context_files)
      # NEW: Restore sent tracking from new current conversation
      x@sent_context_files(convs[[1]]$sent_context_files %||% character())
      x@sent_data_frames(convs[[1]]$sent_data_frames %||% character())
      x@context_skills(convs[[1]]$context_skills %||% character())
      x@sent_skills(convs[[1]]$sent_skills %||% character())
      # NEW: Restore token estimate
      x@token_estimate(convs[[1]]$token_estimate %||% 0L)
    } else {
      x@current_id(NULL)
      x@context_sent(FALSE)
      x@context_files(character())
      # NEW: Clear sent tracking
      x@sent_context_files(character())
      x@sent_data_frames(character())
      x@context_skills(character())
      x@sent_skills(character())
      # NEW: Clear token estimate
      x@token_estimate(0L)
    }
    # NEW: Clear pending on delete
    x@pending_refresh_files(character())
    x@pending_refresh_data(character())
    x@pending_refresh_skills(character())
  }

  cli::cli_alert_success("Deleted conversation")
  invisible(x)
}

S7::method(conv_add_message, ConversationManager) <- function(
  x,
  role,
  content
) {
  conv <- conv_get_current(x)

  if (is.null(conv)) {
    return(invisible(x))
  }

  new_messages <- conv$messages
  new_messages[[length(new_messages) + 1]] <- list(
    role = role,
    content = content
  )

  conv_update_current(x, list(messages = new_messages))

  # AUTO-SAVE happens in conv_update_current

  invisible(x)
}

S7::method(conv_generate_title, ConversationManager) <- function(x, message) {
  title <- substr(message, 1, 50)
  if (nchar(message) > 50) {
    title <- paste0(title, "...")
  }
  title
}

# Add this method to your existing ConversationManager methods

#' Save current conversation to disk
#' @keywords internal
conv_save_current <- S7::new_generic("conv_save_current", "x")

S7::method(conv_save_current, ConversationManager) <- function(x) {
  conv <- conv_get_current(x)

  if (!is.null(conv)) {
    cassidy_save_conversation(conv)
  }

  invisible(x)
}

#' Load a conversation from disk and set as current
#' @keywords internal
conv_load_and_set <- S7::new_generic("conv_load_and_set", "x")

S7::method(conv_load_and_set, ConversationManager) <- function(
  x,
  conv_id,
  session = NULL
) {
  # Load from disk
  conv <- cassidy_load_conversation(conv_id)

  if (is.null(conv)) {
    cli::cli_warn("Could not load conversation {conv_id}")
    return(invisible(x))
  }

  # Add to conversations list
  convs <- x@conversations()

  # Check if already loaded
  existing_idx <- which(
    vapply(convs, function(c) c$id, character(1)) == conv_id
  )

  if (length(existing_idx) > 0) {
    # Already loaded, just switch to it
    conv_switch_to(x, conv_id, session)
  } else {
    # Add to list and switch
    convs <- c(list(conv), convs)
    x@conversations(convs)
    x@current_id(conv$id)
    x@context_sent(conv$context_sent)
    x@context_files(conv$context_files %||% character())
    x@is_loading(FALSE)
    # NEW: Restore sent tracking from loaded conversation
    x@sent_context_files(conv$sent_context_files %||% character())
    x@sent_data_frames(conv$sent_data_frames %||% character())
    x@context_skills(conv$context_skills %||% character())
    x@sent_skills(conv$sent_skills %||% character())
    x@pending_refresh_files(character())
    x@pending_refresh_data(character())
    x@pending_refresh_skills(character())
    # NEW: Restore token estimate
    x@token_estimate(conv$token_estimate %||% 0L)

    if (!is.null(session)) {
      session$sendCustomMessage("clearInput", list())
      # NEW: Sync UI checkboxes
      session$sendCustomMessage(
        "syncFileCheckboxes",
        conv$sent_context_files %||% list()
      )
      session$sendCustomMessage(
        "syncDataCheckboxes",
        conv$sent_data_frames %||% list()
      )
    }

    cli::cli_alert_success("Loaded conversation: {conv$title}")
  }

  invisible(x)
}
