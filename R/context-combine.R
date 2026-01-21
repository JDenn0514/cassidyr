# R/context-combine.R
# Functions for combining multiple context objects

#' Combine Multiple Contexts
#'
#' Combines multiple context objects into a single context for use with
#' [cassidy_chat()]. Contexts are joined with separators to maintain clarity.
#'
#' @param ... Context objects to combine. Can be `cassidy_context` objects,
#'   `cassidy_df_description` objects, character strings, or lists.
#' @param sep Character string used to separate contexts. Defaults to a
#'   horizontal rule for readability.
#'
#' @return A `cassidy_context` object containing all combined contexts.
#'
#' @examples
#' \dontrun{
#'   # Combine project context with a file
#'   combined <- cassidy_context_combined(
#'     cassidy_context_project(),
#'     cassidy_describe_file("R/my-function.R")
#'   )
#'
#'   # Use directly in chat
#'   cassidy_chat("Review this code", context = combined)
#'
#'   # Combine multiple files
#'   cassidy_chat("Compare these implementations", context =
#'     cassidy_context_combined(
#'       cassidy_describe_file("R/old-approach.R"),
#'       cassidy_describe_file("R/new-approach.R")
#'     )
#'   )
#' }
#'
#' @seealso [cassidy_context_project()], [cassidy_describe_file()],
#'   [cassidy_context_data()], [cassidy_chat()]
#' @export
cassidy_context_combined <- function(..., sep = "\n\n---\n\n") {
  contexts <- list(...)

  if (length(contexts) == 0) {
    cli::cli_abort("At least one context must be provided.")
  }

  # Flatten if a single list was passed
  if (
    length(contexts) == 1 &&
      is.list(contexts[[1]]) &&
      !inherits(contexts[[1]], c("cassidy_context", "cassidy_df_description"))
  ) {
    contexts <- contexts[[1]]
  }

  # Convert each context to character
  context_strings <- vapply(
    contexts,
    function(x) {
      if (inherits(x, c("cassidy_context", "cassidy_df_description"))) {
        x$text
      } else if (is.character(x)) {
        paste(x, collapse = "\n")
      } else if (is.list(x) && "text" %in% names(x)) {
        x$text
      } else {
        # Fallback: capture print output
        paste(utils::capture.output(print(x)), collapse = "\n")
      }
    },
    character(1)
  )

  # Remove empty contexts
  context_strings <- context_strings[nzchar(trimws(context_strings))]

  if (length(context_strings) == 0) {
    cli::cli_abort("All provided contexts were empty.")
  }

  combined <- paste(context_strings, collapse = sep)

  structure(
    list(
      text = combined,
      n_contexts = length(context_strings),
      parts = "combined"
    ),
    class = "cassidy_context"
  )
}
