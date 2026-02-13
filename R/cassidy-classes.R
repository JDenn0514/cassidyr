#' @export
print.cassidy_context <- function(x, ...) {
  cli::cli_h1("Cassidy Context")
  cli::cli_alert_info("Level: {x$level}")
  cli::cli_alert_info("Parts: {paste(x$parts, collapse = ', ')}")
  cli::cli_alert_info("Size: {nchar(x$text)} characters")
  cat("\n")
  cat(x$text)
  invisible(x)
}

#' @export
print.cassidy_conversations <- function(x, ...) {
  if (nrow(x) == 0) {
    cli::cli_alert_info("No saved conversations")
    cli::cli_text("Use {.fn cassidy_chat} to start a conversation")
    return(invisible(x))
  }

  cli::cli_h1("Saved Conversations")
  cli::cli_text("{.emph Showing {nrow(x)} conversation{?s}}")
  cat("\n")

  for (i in seq_len(nrow(x))) {
    row <- x[i, ]

    # Format timestamps
    created <- format(row$created_at, "%Y-%m-%d %H:%M")
    updated <- format(row$updated_at, "%Y-%m-%d %H:%M")

    # Show conversation info
    cli::cli_text("{.strong [{i}]} {.val {row$title}}")
    cli::cli_text(
      "    {.field ID}: {.val {row$id}}  {.field Messages}: {row$message_count}"
    )
    cli::cli_text(
      "    {.field Created}: {created}  {.field Updated}: {updated}"
    )

    if (i < nrow(x)) {
      cat("\n")
    }
  }

  cat("\n")
  cli::cli_text("{.emph Use {.code cassidy_chat(msg, conversation = id)} to resume}")

  invisible(x)
}
