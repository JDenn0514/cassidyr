#' Get the storage directory for conversations
#' @keywords internal
.get_conversations_dir <- function() {
  dir <- file.path(tools::R_user_dir("cassidyr", "data"), "conversations")
  if (!dir.exists(dir)) {
    dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  }
  dir
}

#' Save a conversation to disk
#'
#' Saves conversation state to the user's data directory for later retrieval.
#'
#' @param conversation List containing conversation data (id, thread_id,
#'   messages, etc.)
#' @return Path to saved file (invisibly)
#'
#' @keywords internal
cassidy_save_conversation <- function(conversation) {
  if (is.null(conversation) || is.null(conversation$id)) {
    return(invisible(NULL))
  }

  dir <- .get_conversations_dir()
  filename <- paste0(conversation$id, ".rds")
  path <- file.path(dir, filename)

  # Update the updated_at timestamp
  conversation$updated_at <- Sys.time()

  saveRDS(conversation, path)
  invisible(path)
}

#' Load a conversation from disk
#'
#' Retrieves a previously saved conversation by its ID.
#'
#' @param conv_id Character. The conversation ID to load.
#' @return List containing conversation data, or NULL if not found.
#'
#' @keywords internal
cassidy_load_conversation <- function(conv_id) {
  dir <- .get_conversations_dir()
  filename <- paste0(conv_id, ".rds")
  path <- file.path(dir, filename)

  if (!file.exists(path)) {
    return(NULL)
  }

  tryCatch(
    {
      conv <- readRDS(path)

      # Ensure backwards compatibility with new tracking fields
      conv$sent_context_files <- conv$sent_context_files %||% character()
      conv$sent_data_frames <- conv$sent_data_frames %||% character()
      conv$context_files <- conv$context_files %||% character()

      # ADD THIS: Ensure thread_id exists (even if NULL, make it explicit)
      if (is.null(conv$thread_id)) {
        cli::cli_warn("Loaded conversation {conv_id} has no thread_id")
      }

      conv
    },
    error = function(e) {
      cli::cli_warn("Could not load conversation {conv_id}: {e$message}")
      NULL
    }
  )
}


#' List all saved conversations
#'
#' Returns metadata for all saved conversations, sorted by last update time.
#' This function lists your **locally saved** conversations from the cassidyr
#' app, not threads from the Cassidy API.
#'
#' @param n Integer. Maximum number of conversations to return.
#'   Default is 8.
#'
#' @return Data frame with columns:
#'   \describe{
#'     \item{id}{Local conversation ID (e.g., "conv_20260131_1234")}
#'     \item{thread_id}{Cassidy API thread ID for this conversation}
#'     \item{title}{Conversation title (first message preview)}
#'     \item{created_at}{When the conversation was created}
#'     \item{updated_at}{When the conversation was last updated}
#'     \item{message_count}{Number of messages in the conversation}
#'   }
#'
#' @details
#' ## Understanding IDs
#'
#' This package uses two types of identifiers:
#'
#' - **Conversation ID** (`id`): Your local app's identifier (e.g.,
#'   "conv_20260131_1234"). Use this with [cassidy_export_conversation()],
#'   [cassidy_delete_conversation()], and [cassidy_get_thread_id()].
#'
#' - **Thread ID** (`thread_id`): The Cassidy API's identifier for the
#'   conversation on their servers. Use this with API functions like
#'   [cassidy_get_thread()], [cassidy_send_message()], etc.
#'
#' To get the thread_id from a conversation_id, use [cassidy_get_thread_id()].
#'
#' @family chat-app
#'
#' @examples
#' \dontrun{
#'   # List recent conversations
#'   convs <- cassidy_list_conversations()
#'   print(convs)
#'
#'   # Export the most recent conversation (use conversation ID)
#'   cassidy_export_conversation(convs$id[1])
#'
#'   # Get API thread details (use thread ID)
#'   thread <- cassidy_get_thread(convs$thread_id[1])
#' }
#'
#' @export
cassidy_list_conversations <- function(n = 8) {
  dir <- .get_conversations_dir()

  if (!dir.exists(dir)) {
    return(data.frame(
      id = character(0),
      thread_id = character(0),
      title = character(0),
      created_at = as.POSIXct(character(0)),
      updated_at = as.POSIXct(character(0)),
      message_count = integer(0),
      stringsAsFactors = FALSE
    ))
  }

  files <- list.files(dir, pattern = "\\.rds$", full.names = TRUE)

  if (length(files) == 0) {
    return(data.frame(
      id = character(0),
      thread_id = character(0), # ADD THIS
      title = character(0),
      created_at = as.POSIXct(character(0)),
      updated_at = as.POSIXct(character(0)),
      message_count = integer(0),
      stringsAsFactors = FALSE
    ))
  }

  # Extract metadata from each file
  metadata <- lapply(files, function(f) {
    tryCatch(
      {
        conv <- readRDS(f)
        list(
          id = conv$id,
          thread_id = conv$thread_id %||% NA_character_,
          title = conv$title,
          created_at = conv$created_at,
          updated_at = conv$updated_at %||% conv$created_at,
          message_count = length(conv$messages)
        )
      },
      error = function(e) NULL
    )
  })

  # Remove NULL entries (failed loads)
  metadata <- Filter(Negate(is.null), metadata)

  if (length(metadata) == 0) {
    return(data.frame(
      id = character(0),
      thread_id = character(0),
      title = character(0),
      created_at = as.POSIXct(character(0)),
      updated_at = as.POSIXct(character(0)),
      message_count = integer(0),
      stringsAsFactors = FALSE
    ))
  }

  # Convert to data frame
  df <- data.frame(
    id = vapply(metadata, function(x) x$id, character(1)),
    thread_id = vapply(metadata, function(x) x$thread_id, character(1)),
    title = vapply(metadata, function(x) x$title, character(1)),
    created_at = do.call(c, lapply(metadata, function(x) x$created_at)),
    updated_at = do.call(c, lapply(metadata, function(x) x$updated_at)),
    message_count = vapply(metadata, function(x) x$message_count, integer(1)),
    stringsAsFactors = FALSE
  )

  # Sort by updated_at (most recent first)
  df <- df[order(df$updated_at, decreasing = TRUE), ]

  # Limit to n most recent
  if (nrow(df) > n) {
    df <- df[1:n, ]
  }

  rownames(df) <- NULL
  df
}

#' Delete a saved conversation
#'
#' Permanently removes a conversation from disk.
#'
#' @param conv_id Character. The conversation ID to delete.
#' @return TRUE if deleted successfully, FALSE otherwise (invisibly).
#'
#' @family chat-app
#'
#' @examples
#' \dontrun{
#'   # Delete a conversation
#'   cassidy_delete_conversation("conv_20260116_1234")
#' }
#'
#' @export
cassidy_delete_conversation <- function(conv_id) {
  dir <- .get_conversations_dir()
  filename <- paste0(conv_id, ".rds")
  path <- file.path(dir, filename)

  if (file.exists(path)) {
    success <- file.remove(path)
    if (success) {
      cli::cli_alert_success("Deleted conversation: {conv_id}")
    }
    return(invisible(success))
  }

  invisible(FALSE)
}

#' Export a conversation as Markdown
#'
#' Exports a saved conversation to a Markdown file for sharing or archiving.
#'
#' @param conv_id Character. The conversation ID to export.
#' @param path Character. Output file path. If NULL, creates a file in the
#'   current working directory with the conversation title as filename.
#' @return Path to exported file (invisibly).
#'
#' @family chat-app
#'
#' @examples
#' \dontrun{
#'   # Export to default location
#'   cassidy_export_conversation("conv_20260116_1234")
#'
#'   # Export to specific path
#'   cassidy_export_conversation(
#'     "conv_20260116_1234",
#'     "~/Documents/my_conversation.md"
#'   )
#' }
#'
#' @export
cassidy_export_conversation <- function(conv_id, path = NULL) {
  # Load conversation
  conv <- cassidy_load_conversation(conv_id)

  if (is.null(conv)) {
    cli::cli_abort("Conversation {conv_id} not found.")
  }

  # Generate markdown content
  header <- paste0(
    "# ",
    conv$title,
    "\n\n",
    "*Created: ",
    format(conv$created_at, "%Y-%m-%d %H:%M:%S"),
    "*  \n",
    "*Updated: ",
    format(conv$updated_at %||% conv$created_at, "%Y-%m-%d %H:%M:%S"),
    "*  \n",
    "*Messages: ",
    length(conv$messages),
    "*\n\n",
    "---\n\n"
  )

  # Format messages
  messages_md <- paste(
    vapply(
      conv$messages,
      function(msg) {
        paste0(
          "## ",
          tools::toTitleCase(msg$role),
          "\n\n",
          msg$content,
          "\n\n"
        )
      },
      character(1)
    ),
    collapse = ""
  )

  full_md <- paste0(header, messages_md)

  # Determine output path
  if (is.null(path)) {
    # Create safe filename from title
    safe_title <- gsub("[^a-zA-Z0-9_-]", "_", conv$title)
    safe_title <- gsub("_{2,}", "_", safe_title) # Remove multiple underscores
    safe_title <- substr(safe_title, 1, 50) # Limit length

    path <- file.path(getwd(), paste0(safe_title, ".md"))

    # Add number if file exists
    counter <- 1
    while (file.exists(path)) {
      path <- file.path(getwd(), paste0(safe_title, "_", counter, ".md"))
      counter <- counter + 1
    }
  }

  # Write to file
  writeLines(full_md, path)

  cli::cli_alert_success("Exported conversation to {.file {path}}")
  invisible(path)
}

#' Get thread ID from conversation ID
#'
#' Retrieves the Cassidy API thread_id associated with a saved conversation.
#' This is the bridge between your locally saved conversations and the Cassidy
#' API functions.
#'
#' @param conv_id Character. The **local conversation ID** from
#'   [cassidy_list_conversations()] (e.g., "conv_20260131_1234").
#'
#' @return Character. The Cassidy API thread_id, or NULL if the conversation
#'   has no thread_id. Returns NULL with a warning if the conversation doesn't
#'   exist.
#'
#' @details
#' ## Why You Need This Function
#'
#' The cassidyr package uses two different ID systems:
#'
#' 1. **Conversation IDs** (local): Generated by the cassidyr app when you save
#'    conversations. Format: `"conv_YYYYMMDD_HHMMSS_RAND"`. Used with:
#'    - [cassidy_export_conversation()]
#'    - [cassidy_delete_conversation()]
#'    - [cassidy_app()] (for resuming)
#'
#' 2. **Thread IDs** (API): Generated by Cassidy's servers when you create a
#'    thread. Format: UUID-like string from Cassidy. Used with:
#'    - [cassidy_get_thread()]
#'    - [cassidy_send_message()]
#'    - All other API functions
#'
#' This function converts from local conversation IDs to API thread IDs.
#'
#' @family chat-app
#'
#' @seealso
#' - [cassidy_list_conversations()] to see both IDs side-by-side
#' - [cassidy_get_thread()] to retrieve thread history from the API
#'
#' @examples
#' \dontrun{
#'   # List your saved conversations
#'   convs <- cassidy_list_conversations()
#'   print(convs)  # Shows both id and thread_id columns
#'
#'   # Get thread_id from conversation_id
#'   conv_id <- convs$id[1]  # e.g., "conv_20260131_1234"
#'   thread_id <- cassidy_get_thread_id(conv_id)
#'
#'   # Now use it with API functions
#'   if (!is.null(thread_id)) {
#'     thread <- cassidy_get_thread(thread_id)
#'     print(thread)
#'   }
#'
#'   # Or skip the conversion - thread_id is in the table!
#'   thread_id <- convs$thread_id[1]
#'   thread <- cassidy_get_thread(thread_id)
#' }
#'
#' @export
cassidy_get_thread_id <- function(conv_id) {
  conv <- cassidy_load_conversation(conv_id)

  if (is.null(conv)) {
    cli::cli_abort(c(
      "x" = "Conversation {.val {conv_id}} not found.",
      "i" = "Use {.fn cassidy_list_conversations} to see available conversations"
    ))
  }

  if (is.null(conv$thread_id)) {
    cli::cli_warn(c(
      "!" = "Conversation {.val {conv_id}} has no thread_id.",
      "i" = "This might be an incomplete or corrupted conversation"
    ))
    return(NULL)
  }

  conv$thread_id
}
