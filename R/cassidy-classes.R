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
