# ══════════════════════════════════════════════════════════════════════════════
# LAYER 1: API FOUNDATION
# Core functions for communicating with the CassidyAI REST API
# ══════════════════════════════════════════════════════════════════════════════

#' Internal helper to build base httr2 client
#'
#' @param api_key Character. CassidyAI API key.
#' @param timeout_seconds Numeric. Request timeout in seconds. Default is 120.
#' @return An httr2 request object with authentication and retry logic.
#' @keywords internal
#' @noRd
.cassidy_client <- function(
  api_key = Sys.getenv("CASSIDY_API_KEY"),
  timeout_seconds = 120
) {
  if (api_key == "") {
    cli::cli_abort(c(
      "!" = "CASSIDY_API_KEY not found.",
      "i" = "Set it with {.run cassidy_setup()} or manually in .Renviron",
      "i" = "Run {.run usethis::edit_r_environ()} to edit your environment file"
    ))
  }

  httr2::request("https://app.cassidyai.com/api") |>
    httr2::req_headers(
      Authorization = paste("Bearer", api_key),
      `Content-Type` = "application/json"
    ) |>
    # Retry on rate limits (429) and server errors (503)
    httr2::req_retry(
      max_tries = 3,
      is_transient = function(resp) {
        httr2::resp_status(resp) %in% c(429, 503, 504)
      }
    ) |>
    # Set user agent for good API citizenship
    httr2::req_user_agent(
      "cassidyr (https://github.com/yourusername/cassidyr)"
    ) |>
    # Add timeout to prevent hanging
    httr2::req_timeout(timeout_seconds)
}

#' Create a new CassidyAI conversation thread
#'
#' Creates a new conversation thread with a specified CassidyAI assistant.
#' Each thread maintains its own conversation history, allowing context to
#' persist across multiple messages within that thread.
#'
#' @param assistant_id Character. The CassidyAI assistant ID. Defaults to
#'   the `CASSIDY_ASSISTANT_ID` environment variable. Find this in your
#'   assistant's External Deployments settings.
#' @param api_key Character. Your CassidyAI API key. Defaults to
#'   the `CASSIDY_API_KEY` environment variable.
#'
#' @return Character. The thread ID for the new conversation. Save this to
#'   continue the conversation with [cassidy_send_message()].
#'
#' @family api-functions
#' @export
#'
#' @examples
#' \dontrun{
#' # Create a new thread
#' thread_id <- cassidy_create_thread()
#'
#' # Or specify assistant explicitly
#' thread_id <- cassidy_create_thread(assistant_id = "asst_abc123")
#' }
cassidy_create_thread <- function(
  assistant_id = Sys.getenv("CASSIDY_ASSISTANT_ID"),
  api_key = Sys.getenv("CASSIDY_API_KEY"),
  is_verbose = FALSE
) {
  # Validate assistant_id
  if (assistant_id == "") {
    cli::cli_abort(c(
      "!" = "CASSIDY_ASSISTANT_ID not found.",
      "i" = "Set it with {.run cassidy_setup()} or in .Renviron",
      "i" = "Find your assistant ID in External Deployments settings"
    ))
  }

  # Make API request
  resp <- .cassidy_client(api_key) |>
    httr2::req_url_path_append("assistants/thread/create") |>
    httr2::req_body_json(list(assistant_id = assistant_id)) |>
    httr2::req_error(body = function(resp) {
      body <- httr2::resp_body_json(resp)
      body$message %||% "Unknown API error"
    }) |>
    httr2::req_perform()

  # Extract and return thread_id
  result <- httr2::resp_body_json(resp)
  thread_id <- result$thread_id

  if (is.null(thread_id)) {
    cli::cli_abort("API returned no thread_id")
  }

  if (is_verbose) {
    cli::cli_alert_success("Created thread: {.val {thread_id}}")
  }

  thread_id
}

#' Send Message to Cassidy Thread
#'
#' Sends a message to an existing Cassidy thread and retrieves the assistant's
#' response.
#'
#' @param thread_id Character. The thread ID from [cassidy_create_thread()].
#' @param message Character. The message content to send.
#' @param api_key Character. Cassidy API key. Defaults to
#'   `CASSIDY_API_KEY` environment variable.
#' @param timeout Numeric. Request timeout in seconds. Default is 120.
#'
#' @return A `cassidy_response` object containing:
#'   - `content`: The assistant's response text
#'   - `thread_id`: The thread ID
#'   - `timestamp`: When the response was received
#'
#' @family api-functions
#' @export
cassidy_send_message <- function(
  thread_id,
  message,
  api_key = Sys.getenv("CASSIDY_API_KEY"),
  timeout = 120
) {
  if (!nzchar(api_key)) {
    cli::cli_abort(c(
      "Cassidy API key not found.",
      "i" = "Set {.envvar CASSIDY_API_KEY} in your {.file .Renviron} file."
    ))
  }

  if (!nzchar(thread_id)) {
    cli::cli_abort("Thread ID is required")
  }

  if (!nzchar(message)) {
    cli::cli_abort("Message cannot be empty")
  }

  req <- httr2::request(
    "https://app.cassidyai.com/api/assistants/message/create"
  ) |>
    httr2::req_method("POST") |>
    httr2::req_headers(
      Authorization = paste("Bearer", api_key),
      `Content-Type` = "application/json"
    ) |>
    httr2::req_body_json(
      list(
        thread_id = thread_id,
        message = message
      )
    ) |>
    httr2::req_timeout(timeout) |>
    httr2::req_retry(
      max_tries = 3,
      is_transient = function(resp) {
        status <- httr2::resp_status(resp)
        status %in% c(429, 503, 504)
      }
    ) |>
    httr2::req_error(body = function(resp) {
      # === IMPROVED ERROR HANDLING ===
      status <- httr2::resp_status(resp)
      content_type <- httr2::resp_content_type(resp)

      # Try to get error message from JSON
      error_msg <- tryCatch(
        {
          body <- httr2::resp_body_json(resp)
          body$message %||% body$error %||% "Unknown API error"
        },
        error = function(e) {
          # If JSON parsing fails, try to get text
          tryCatch(
            {
              text <- httr2::resp_body_string(resp)
              # If it's HTML, extract title or show truncated version
              if (grepl("text/html", content_type, fixed = TRUE)) {
                # Try to extract <title> from HTML
                title_match <- regmatches(
                  text,
                  regexec("<title>(.*?)</title>", text, ignore.case = TRUE)
                )
                if (length(title_match[[1]]) > 1) {
                  paste0("Server error: ", title_match[[1]][2])
                } else {
                  "Server returned HTML error page (likely 500/502/503 error)"
                }
              } else {
                # Truncate long text responses
                if (nchar(text) > 200) {
                  paste0(substr(text, 1, 200), "...")
                } else {
                  text
                }
              }
            },
            error = function(e2) {
              "Could not parse error response"
            }
          )
        }
      )

      paste0(
        "Cassidy API request failed (HTTP ",
        status,
        "): ",
        error_msg
      )
    })

  resp <- httr2::req_perform(req)
  body <- httr2::resp_body_json(resp)

  # Extract response content
  content <- body$message %||% body$response %||% body$content %||% ""

  if (!nzchar(content)) {
    cli::cli_warn("API returned empty response")
  }

  structure(
    list(
      content = content,
      thread_id = thread_id,
      timestamp = Sys.time()
    ),
    class = "cassidy_response"
  )
}


#' Retrieve conversation history from a thread
#'
#' Gets the full message history from an existing CassidyAI thread, including
#' both user messages and assistant responses. Useful for reviewing past
#' conversations or resuming work.
#'
#' @param thread_id Character. The thread ID to retrieve.
#' @param api_key Character. Your CassidyAI API key. Defaults to
#'   the `CASSIDY_API_KEY` environment variable.
#'
#' @return A `cassidy_thread` S3 object with:
#'   \describe{
#'     \item{thread_id}{The thread identifier}
#'     \item{messages}{List of messages, each with role, content, and timestamp}
#'     \item{assistant_id}{The assistant this thread belongs to}
#'     \item{created_at}{When the thread was created}
#'     \item{message_count}{Number of messages in the thread}
#'   }
#'
#' @family api-functions
#' @export
#'
#' @examples
#' \dontrun{
#' # Retrieve a thread's history
#' thread <- cassidy_get_thread("thread_abc123")
#' print(thread)
#'
#' # Access messages
#' thread$messages
#' }
cassidy_get_thread <- function(
  thread_id,
  api_key = Sys.getenv("CASSIDY_API_KEY")
) {
  # Validate input
  if (missing(thread_id) || is.null(thread_id) || thread_id == "") {
    cli::cli_abort("thread_id is required")
  }

  # Make API request
  resp <- .cassidy_client(api_key) |>
    httr2::req_url_path_append("assistants/thread/get") |>
    httr2::req_url_query(thread_id = thread_id) |>
    httr2::req_error(body = function(resp) {
      body <- httr2::resp_body_json(resp)
      body$message %||% "Unknown API error"
    }) |>
    httr2::req_perform()

  result <- httr2::resp_body_json(resp)

  # Parse messages into more usable format
  messages <- if (!is.null(result$messages) && length(result$messages) > 0) {
    lapply(result$messages, function(msg) {
      list(
        role = msg$role %||% "unknown",
        content = msg$content %||% msg$message %||% "",
        timestamp = msg$timestamp %||% msg$created_at %||% NA
      )
    })
  } else {
    list()
  }

  # Return structured S3 object
  structure(
    list(
      thread_id = thread_id,
      messages = messages,
      assistant_id = result$assistant_id %||% NA_character_,
      created_at = result$created_at %||% NA_character_,
      message_count = length(messages),
      raw = result
    ),
    class = "cassidy_thread"
  )
}

#' List all threads for an assistant
#'
#' Retrieves a list of all conversation threads for a specified assistant.
#' Useful for finding and resuming previous conversations.
#'
#' @param assistant_id Character. The CassidyAI assistant ID. Defaults to
#'   the `CASSIDY_ASSISTANT_ID` environment variable.
#' @param api_key Character. Your CassidyAI API key. Defaults to
#'   the `CASSIDY_API_KEY` environment variable.
#' @param limit Integer. Maximum number of threads to return (if supported by API).
#'   Default is 100.
#'
#' @return A `cassidy_thread_list` S3 object containing:
#'   \describe{
#'     \item{threads}{A data frame with thread_id, created_at, last_message, and message_count}
#'     \item{assistant_id}{The assistant these threads belong to}
#'     \item{total}{Total number of threads}
#'   }
#'
#' @family api-functions
#' @export
#'
#' @examples
#' \dontrun{
#' # List all threads
#' threads <- cassidy_list_threads()
#' print(threads)
#'
#' # Access as data frame
#' threads$threads
#'
#' # Get most recent thread
#' recent <- threads$threads[1, ]
#' cassidy_get_thread(recent$thread_id)
#' }
cassidy_list_threads <- function(
  assistant_id = Sys.getenv("CASSIDY_ASSISTANT_ID"),
  api_key = Sys.getenv("CASSIDY_API_KEY"),
  limit = 100
) {
  # Validate assistant_id
  if (assistant_id == "") {
    cli::cli_abort(c(
      "!" = "CASSIDY_ASSISTANT_ID not found.",
      "i" = "Set it with {.run cassidy_setup()} or in .Renviron"
    ))
  }

  # Make API request
  resp <- .cassidy_client(api_key) |>
    httr2::req_url_path_append("assistants/threads/get") |>
    httr2::req_url_query(
      assistant_id = assistant_id,
      limit = limit
    ) |>
    httr2::req_error(body = function(resp) {
      body <- httr2::resp_body_json(resp)
      body$message %||% "Unknown API error"
    }) |>
    httr2::req_perform()

  result <- httr2::resp_body_json(resp)

  # Parse threads into data frame
  if (!is.null(result$threads) && length(result$threads) > 0) {
    threads_df <- do.call(
      rbind,
      lapply(result$threads, function(thread) {
        data.frame(
          thread_id = thread$thread_id %||% NA_character_,
          created_at = thread$created_at %||% NA_character_,
          last_message = thread$last_message %||% NA_character_,
          message_count = thread$message_count %||% 0L,
          stringsAsFactors = FALSE
        )
      })
    )

    # Sort by created_at descending (most recent first)
    if (
      "created_at" %in% names(threads_df) && !all(is.na(threads_df$created_at))
    ) {
      threads_df <- threads_df[
        order(threads_df$created_at, decreasing = TRUE),
      ]
      rownames(threads_df) <- NULL
    }
  } else {
    # Return empty data frame with correct structure
    threads_df <- data.frame(
      thread_id = character(0),
      created_at = character(0),
      last_message = character(0),
      message_count = integer(0),
      stringsAsFactors = FALSE
    )
  }

  # Return structured S3 object
  structure(
    list(
      threads = threads_df,
      assistant_id = assistant_id,
      total = nrow(threads_df),
      raw = result
    ),
    class = "cassidy_thread_list"
  )
}

# ══════════════════════════════════════════════════════════════════════════════
# S3 PRINT METHODS
# ══════════════════════════════════════════════════════════════════════════════

#' @export
print.cassidy_response <- function(x, ...) {
  cli::cli_rule(left = "Cassidy Response") # Remove line = 2
  cat(x$content)
  cli::cli_rule() # Remove line = 2
  invisible(x)
}


#' @export
print.cassidy_thread <- function(x, ...) {
  cli::cli_h1("Cassidy Thread")
  cli::cli_text("Thread ID: {.val {x$thread_id}}")
  cli::cli_text("Assistant: {.val {x$assistant_id}}")
  cli::cli_text("Messages: {.val {x$message_count}}")
  cli::cli_text("Created: {.val {x$created_at}}")

  if (x$message_count > 0) {
    cli::cli_h2("Recent Messages")
    # Show last 3 messages
    recent <- utils::tail(x$messages, 3)
    for (msg in recent) {
      cli::cli_alert_info(
        "{.field {msg$role}}: {.emph {substr(msg$content, 1, 100)}}{if(nchar(msg$content) > 100) '...' else ''}"
      )
    }
    if (x$message_count > 3) {
      cli::cli_text("{.emph ... and {x$message_count - 3} more messages}")
    }
  }

  invisible(x)
}

#' @export
print.cassidy_thread_list <- function(x, ...) {
  cli::cli_h1("Cassidy Threads")
  cli::cli_text("Assistant: {.val {x$assistant_id}}")
  cli::cli_text("Total threads: {.val {x$total}}")

  if (x$total > 0) {
    cli::cli_text("")
    print(x$threads, row.names = FALSE)
  } else {
    cli::cli_alert_info("No threads found")
  }

  invisible(x)
}
