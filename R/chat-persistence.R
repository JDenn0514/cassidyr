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
#'
#' @param n Integer. Maximum number of conversations to return.
#'   Default is 8.
#' @return Data frame with columns: id, title, created_at, updated_at,
#'   message_count
#'
#' @family chat-app
#'
#' @examples
#' \dontrun{
#'   # List recent conversations
#'   convs <- cassidy_list_conversations()
#'   print(convs)
#' }
#'
#' @export
cassidy_list_conversations <- function(n = 8) {
  dir <- .get_conversations_dir()

  if (!dir.exists(dir)) {
    return(data.frame(
      id = character(0),
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
