#' Format data frame description for LLM context
#'
#' Creates a compact, markdown-formatted description of a data frame
#' optimized for LLM consumption.
#'
#' @param data A data.frame
#' @param name Optional name for the data (defaults to object name)
#' @param max_vars Maximum variables to show (NULL = all)
#' @param show_sample Include sample values? (Default: TRUE)
#'
#' @returns Character string in markdown format
#' @export
codebook_for_llm <- function(
  data,
  name = NULL,
  max_vars = NULL,
  show_sample = TRUE
) {
  if (!is.data.frame(data)) {
    cli::cli_abort("{.arg data} must be a data.frame")
  }

  name <- name %||% deparse(substitute(data))
  n_vars <- ncol(data)
  truncated <- FALSE

  if (!is.null(max_vars) && n_vars > max_vars) {
    truncated <- TRUE
    vars_to_show <- names(data)[1:max_vars]
  } else {
    vars_to_show <- names(data)
  }

  # Header
  lines <- c(
    paste0("## Data: `", name, "`"),
    paste0(nrow(data), " rows x ", n_vars, " columns"),
    ""
  )

  # Per-variable descriptions
  for (var in vars_to_show) {
    x <- data[[var]]
    var_lines <- format_variable_for_llm(x, var, show_sample)
    lines <- c(lines, var_lines, "")
  }

  if (truncated) {
    lines <- c(
      lines,
      paste0("*... and ", n_vars - max_vars, " more variables*")
    )
  }

  paste(lines, collapse = "\n")
}


#' @keywords internal
format_variable_for_llm <- function(x, var_name, show_sample = TRUE) {
  # Primary line: name, label, type
  label <- attr(x, "label", exact = TRUE)
  type_abbr <- vctrs::vec_ptype_abbr(x)
  n_miss <- sum(is.na(x))
  n_total <- length(x)

  # Build primary line
  primary <- paste0("### `", var_name, "`")
  if (!is.null(label) && nzchar(label)) {
    primary <- paste0(primary, " - ", label)
  }

  # Type and missing info
  type_info <- paste0("*", type_abbr, "*")
  if (n_miss > 0) {
    pct_miss <- round(100 * n_miss / n_total, 1)
    type_info <- paste0(type_info, " | ", n_miss, " missing (", pct_miss, "%)")
  }

  lines <- c(primary, type_info)

  # Value labels (for labelled vectors)
  val_labels <- attr(x, "labels", exact = TRUE)
  if (!is.null(val_labels) && length(val_labels) > 0) {
    formatted <- paste0(
      val_labels,
      " = \"",
      names(val_labels),
      "\"",
      collapse = ", "
    )
    lines <- c(lines, paste0("- Values: ", formatted))
  }

  # Factor levels
  if (is.factor(x)) {
    lvls <- levels(x)
    if (length(lvls) <= 10) {
      lines <- c(lines, paste0("- Levels: ", paste(lvls, collapse = ", ")))
    } else {
      lines <- c(
        lines,
        paste0(
          "- Levels: ",
          paste(lvls[1:10], collapse = ", "),
          " ... (",
          length(lvls),
          " total)"
        )
      )
    }
  }

  # Numeric range
  if (is.numeric(x) && !all(is.na(x))) {
    rng <- range(x, na.rm = TRUE)
    lines <- c(lines, paste0("- Range: ", rng[1], " to ", rng[2]))
  }

  # Sample unique values (helpful for cleaning context)
  if (show_sample && !is.numeric(x)) {
    unique_vals <- unique(x[!is.na(x)])
    if (length(unique_vals) <= 8) {
      sample_str <- paste0("\"", unique_vals, "\"", collapse = ", ")
    } else {
      sample_str <- paste0(
        paste0("\"", unique_vals[1:5], "\"", collapse = ", "),
        " ... (",
        length(unique_vals),
        " unique)"
      )
    }
    lines <- c(lines, paste0("- Sample values: ", sample_str))
  }

  # Transformation note
  transform <- attr(x, "transformation", exact = TRUE)
  if (!is.null(transform) && nzchar(transform)) {
    lines <- c(lines, paste0("- Transform: ", transform))
  }

  # Question preface (for survey data)
  preface <- attr(x, "question_preface", exact = TRUE)
  if (!is.null(preface) && nzchar(preface)) {
    lines <- c(lines, paste0("- Question: ", preface))
  }

  lines
}
