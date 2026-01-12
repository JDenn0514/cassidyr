#' Null coalescing operator
#'
#' Returns left side if not NULL, otherwise returns right side.
#'
#' @param x Primary value
#' @param y Fallback value if x is NULL
#' @return x if not NULL, otherwise y
#' @keywords internal
#' @noRd
#'
#' @examples
#' \dontrun{
#' NULL %||% "default"  # "default"
#' "value" %||% "default"  # "value"
#' }
`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}
