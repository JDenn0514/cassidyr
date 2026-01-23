# R/context-data.R
# Functions for gathering data frame context

#' Gather context from data frames in environment
#'
#' Creates a summary of data frames currently loaded in the global environment,
#' useful for giving Cassidy context about available data.
#'
#' @param detailed Whether to include detailed summaries of each data frame
#' @param method Method to use for detailed summaries: "codebook", "skim", or
#'   "basic"
#'
#' @return Character string with formatted data frame information
#' @export
#'
#' @examples
#' \dontrun{
#'   # Load some data
#'   data(mtcars)
#'   data(iris)
#'
#'   # Basic summary
#'   cassidy_context_data()
#'
#'   # Detailed summary
#'   cassidy_context_data(detailed = TRUE)
#' }
cassidy_context_data <- function(
  detailed = FALSE,
  method = c("codebook", "skim", "basic")
) {
  method <- match.arg(method)

  # Get all data frames from global environment
  obj_names <- ls(envir = .GlobalEnv)
  data_frames <- list()

  for (obj_name in obj_names) {
    obj <- get(obj_name, envir = .GlobalEnv)
    if (is.data.frame(obj)) {
      data_frames[[obj_name]] <- obj
    }
  }

  if (length(data_frames) == 0) {
    return("## Data Context\nNo data frames found in environment")
  }

  context_text <- paste0(
    "## Data Context\n\n",
    length(data_frames),
    " data frame(s) loaded:\n\n"
  )

  if (detailed) {
    # Detailed summaries
    for (name in names(data_frames)) {
      df <- data_frames[[name]]
      desc <- cassidy_describe_df(df, method = method)
      context_text <- paste0(
        context_text,
        "### ",
        name,
        "\n",
        desc$text,
        "\n\n"
      )
    }
  } else {
    # Quick summaries
    for (name in names(data_frames)) {
      df <- data_frames[[name]]
      dims <- dim(df)
      context_text <- paste0(
        context_text,
        "- **",
        name,
        "**: ",
        dims[1],
        " obs x ",
        dims[2],
        " vars\n"
      )
    }
  }

  context_text
}

#' Describe a data frame for AI context
#'
#' Creates a formatted description of a data frame suitable for AI context.
#' Can use different methods to generate the description.
#'
#' @param data A data frame or tibble
#' @param name Optional character string to use as the data frame name.
#'   If NULL, attempts to use the name of the object passed to `data`.
#' @param method Method to use: "codebook" (default), "skim", or "basic"
#' @param include_summary Include statistical summaries (for "basic" method)
#' @param max_vars Maximum variables to show (NULL = all)
#' @param show_sample Include sample values? (Default: TRUE)
#'
#' @details
#' The \code{method} parameter controls how the data frame is described:
#' \itemize{
#'   \item \code{"codebook"}: Uses \code{cassidy_describe_codebook()} which provides
#'     a compact, markdown-formatted description optimized for LLM consumption,
#'     including variable labels, value labels, factor levels, and more
#'   \item \code{"skim"}: Uses \code{skimr::skim()} if available, which provides
#'     summary statistics organized by variable type. Falls back to "basic" if
#'     not installed.
#'   \item \code{"basic"}: Uses base R to provide a simple description with
#'     variable types and basic summaries.
#' }
#'
#' @return An object of class \code{cassidy_df_description} containing the
#'   formatted description text
#'
#' @export
#' @examples
#' \dontrun{
#'   # Using codebook method (most detailed)
#'   desc <- cassidy_describe_df(mtcars, method = "codebook")
#'
#'   # With explicit name
#'   desc <- cassidy_describe_df(my_data, name = "survey_responses", method = "skim")
#'
#'   # Using basic method (lightweight)
#'   desc <- cassidy_describe_df(mtcars, method = "basic")
#'
#'   # Use in chat
#'   cassidy_chat("What analyses would you recommend?", context = desc)
#' }
cassidy_describe_df <- function(
  data,
  name = NULL,
  method = c("codebook", "skim", "basic"),
  include_summary = TRUE,
  max_vars = NULL,
  show_sample = TRUE
) {
  if (!is.data.frame(data)) {
    cli::cli_abort("{.arg data} must be a data frame")
  }

  method <- match.arg(method)

  # Use provided name or try to get from call
  data_name <- name %||% deparse(substitute(data))

  # Try methods in order of preference
  description <- switch(
    method,
    codebook = .describe_with_codebook(data, data_name, max_vars, show_sample),
    skim = .describe_with_skim(data, data_name),
    basic = .describe_basic(data, data_name, include_summary)
  )

  structure(
    list(
      text = description,
      data_name = data_name,
      method = attr(description, "method_used")
    ),
    class = "cassidy_df_description"
  )
}

# ========================================================================
# other data helpers -----------------------------------------------------
# ========================================================================

#' Describe a single variable in detail
#'
#' Provides detailed information about a specific variable in a data frame,
#' including summary statistics, distribution, and potential issues.
#'
#' @param data A data frame
#' @param variable Variable name (character) or position (integer)
#' @param max_unique Maximum unique values to display for categorical variables
#'
#' @return Character string with variable description
#' @export
#'
#' @examples
#' \dontrun{
#'   # Describe a numeric variable
#'   cassidy_describe_variable(mtcars, "mpg")
#'
#'   # Describe a factor
#'   cassidy_describe_variable(iris, "Species")
#'
#'   # By position
#'   cassidy_describe_variable(mtcars, 1)
#' }
cassidy_describe_variable <- function(data, variable, max_unique = 10) {
  if (!is.data.frame(data)) {
    cli::cli_abort("{.arg data} must be a data frame")
  }

  # Get variable
  if (is.numeric(variable)) {
    if (variable < 1 || variable > ncol(data)) {
      cli::cli_abort("Variable position {variable} out of range")
    }
    var_name <- names(data)[variable]
    var_data <- data[[variable]]
  } else if (is.character(variable)) {
    if (!variable %in% names(data)) {
      cli::cli_abort("Variable '{variable}' not found in data")
    }
    var_name <- variable
    var_data <- data[[variable]]
  } else {
    cli::cli_abort("{.arg variable} must be character or numeric")
  }

  # Basic info
  var_class <- class(var_data)[1]
  n_total <- length(var_data)
  n_missing <- sum(is.na(var_data))
  pct_missing <- .format_num(n_missing / n_total * 100, 1)

  desc <- paste0("## Variable: ", var_name, "\n\n")
  desc <- paste0(desc, "- **Type**: ", var_class, "\n")
  desc <- paste0(desc, "- **Length**: ", n_total, "\n")
  desc <- paste0(desc, "- **Missing**: ", n_missing, " (", pct_missing, "%)\n")

  # Type-specific summaries
  if (is.numeric(var_data)) {
    if (n_missing < n_total) {
      desc <- paste0(desc, "\n### Summary Statistics:\n")
      desc <- paste0(
        desc,
        "- Min: ",
        .format_num(min(var_data, na.rm = TRUE)),
        "\n"
      )
      desc <- paste0(
        desc,
        "- Q1: ",
        .format_num(stats::quantile(var_data, 0.25, na.rm = TRUE)),
        "\n"
      )
      desc <- paste0(
        desc,
        "- Median: ",
        .format_num(stats::median(var_data, na.rm = TRUE)),
        "\n"
      )
      desc <- paste0(
        desc,
        "- Mean: ",
        .format_num(mean(var_data, na.rm = TRUE)),
        "\n"
      )
      desc <- paste0(
        desc,
        "- Q3: ",
        .format_num(stats::quantile(var_data, 0.75, na.rm = TRUE)),
        "\n"
      )
      desc <- paste0(
        desc,
        "- Max: ",
        .format_num(max(var_data, na.rm = TRUE)),
        "\n"
      )
      desc <- paste0(
        desc,
        "- SD: ",
        .format_num(stats::sd(var_data, na.rm = TRUE)),
        "\n"
      )
    }
  } else if (is.factor(var_data) || is.character(var_data)) {
    n_unique <- length(unique(var_data[!is.na(var_data)]))
    desc <- paste0(desc, "- **Unique values**: ", n_unique, "\n")

    if (n_unique <= max_unique && n_unique > 0) {
      desc <- paste0(desc, "\n### Value Counts:\n")
      counts <- table(var_data, useNA = "no")
      counts <- sort(counts, decreasing = TRUE)
      for (i in seq_along(counts)) {
        val <- names(counts)[i]
        cnt <- counts[i]
        pct <- .format_num(cnt / (n_total - n_missing) * 100, 1)
        desc <- paste0(desc, "- ", val, ": ", cnt, " (", pct, "%)\n")
      }
    }
  } else if (is.logical(var_data)) {
    n_true <- sum(var_data, na.rm = TRUE)
    n_false <- sum(!var_data, na.rm = TRUE)
    pct_true <- .format_num(n_true / (n_total - n_missing) * 100, 1)
    desc <- paste0(desc, "\n### Values:\n")
    desc <- paste0(desc, "- TRUE: ", n_true, " (", pct_true, "%)\n")
    desc <- paste0(
      desc,
      "- FALSE: ",
      n_false,
      " (",
      100 - as.numeric(pct_true),
      "%)\n"
    )
  }

  desc
}

#' Detect potential data quality issues
#'
#' Scans a data frame for common issues like missing data, outliers,
#' constant columns, high cardinality, etc.
#'
#' @param data A data frame
#' @param missing_threshold Percent missing to flag (default: 20)
#' @param outlier_method Method for outlier detection: "iqr" or "zscore"
#' @param outlier_threshold Threshold for outlier detection (default: 3 for IQR,
#'   3 for z-score)
#'
#' @return A list with detected issues
#' @export
#'
#' @examples
#' \dontrun{
#'   # Check for issues
#'   issues <- cassidy_detect_issues(mtcars)
#'
#'   # More sensitive missing data detection
#'   issues <- cassidy_detect_issues(mtcars, missing_threshold = 10)
#' }
cassidy_detect_issues <- function(
  data,
  missing_threshold = 20,
  outlier_method = c("iqr", "zscore"),
  outlier_threshold = 3
) {
  if (!is.data.frame(data)) {
    cli::cli_abort("{.arg data} must be a data frame")
  }

  outlier_method <- match.arg(outlier_method)

  issues <- list(
    missing_data = list(),
    constant_columns = character(),
    high_cardinality = list(),
    outliers = list(),
    duplicates = NULL
  )

  # Check missing data
  for (col in names(data)) {
    pct_missing <- sum(is.na(data[[col]])) / nrow(data) * 100
    if (pct_missing > missing_threshold) {
      issues$missing_data[[col]] <- pct_missing
    }
  }

  # Check constant columns
  for (col in names(data)) {
    n_unique <- length(unique(data[[col]]))
    if (n_unique == 1) {
      issues$constant_columns <- c(issues$constant_columns, col)
    }
  }

  # Check high cardinality (for character/factor with many unique values)
  for (col in names(data)) {
    if (is.character(data[[col]]) || is.factor(data[[col]])) {
      n_unique <- length(unique(data[[col]]))
      if (n_unique > nrow(data) * 0.8) {
        # More than 80% unique
        issues$high_cardinality[[col]] <- n_unique
      }
    }
  }

  # Check for outliers in numeric columns
  for (col in names(data)) {
    if (is.numeric(data[[col]])) {
      outliers <- .detect_outliers(
        data[[col]],
        method = outlier_method,
        threshold = outlier_threshold
      )
      if (length(outliers) > 0) {
        issues$outliers[[col]] <- length(outliers)
      }
    }
  }

  # Check for duplicate rows
  n_duplicates <- sum(duplicated(data))
  if (n_duplicates > 0) {
    issues$duplicates <- n_duplicates
  }

  structure(issues, class = "cassidy_data_issues")
}

# Helper: Detect outliers
.detect_outliers <- function(x, method = "iqr", threshold = 3) {
  x <- x[!is.na(x)]
  if (length(x) == 0) {
    return(integer(0))
  }

  if (method == "iqr") {
    q1 <- quantile(x, 0.25)
    q3 <- quantile(x, 0.75)
    iqr <- q3 - q1
    lower <- q1 - threshold * iqr
    upper <- q3 + threshold * iqr
    which(x < lower | x > upper)
  } else if (method == "zscore") {
    z <- abs((x - mean(x)) / sd(x))
    which(z > threshold)
  }
}

# ========================================================================
# codebook method --------------------------------------------------------
# ========================================================================

# Helper: Use cassidy_describe_codebook for LLM-optimized output
.describe_with_codebook <- function(
  data,
  data_name,
  max_vars = NULL,
  show_sample = TRUE
) {
  description <- cassidy_describe_codebook(
    data = data,
    name = data_name,
    max_vars = max_vars,
    show_sample = show_sample
  )

  attr(description, "method_used") <- "codebook"
  description
}

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
cassidy_describe_codebook <- function(
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


# ========================================================================
# skim method ------------------------------------------------------------
# ========================================================================

.describe_with_skim <- function(data, data_name) {
  if (!requireNamespace("skimr", quietly = TRUE)) {
    cli::cli_alert_info(
      "{.pkg skimr} not installed, falling back to {.code basic} method"
    )
    return(.describe_basic(data, data_name, include_summary = TRUE))
  }

  tryCatch(
    {
      skim_output <- skimr::skim(data)

      description <- paste0(
        "# Data Frame: ",
        data_name,
        "\n\n",
        nrow(data),
        " observations x ",
        ncol(data),
        " variables\n\n"
      )

      description <- paste0(
        description,
        "## Summary Statistics (via skimr::skim)\n\n"
      )

      skim_text <- utils::capture.output(print(skim_output))
      description <- paste0(description, paste(skim_text, collapse = "\n"))

      attr(description, "method_used") <- "skim"
      description
    },
    error = function(e) {
      cli::cli_alert_warning(
        "Error using {.pkg skimr}, falling back to {.code basic} method"
      )
      .describe_basic(data, data_name, include_summary = TRUE)
    }
  )
}


# ========================================================================
# basic method -----------------------------------------------------------
# ========================================================================

.describe_basic <- function(data, data_name, include_summary = TRUE) {
  dims <- dim(data)
  var_types <- vapply(data, function(x) class(x)[1], character(1))

  description <- paste0(
    "# Data Frame: ",
    data_name,
    "\n\n",
    dims[1],
    " observations x ",
    dims[2],
    " variables\n\n"
  )

  description <- paste0(description, "## Variables\n\n")

  for (i in seq_along(data)) {
    var_name <- names(data)[i]
    var_type <- var_types[i]

    if (include_summary) {
      if (is.numeric(data[[i]])) {
        na_count <- sum(is.na(data[[i]]))
        if (na_count == length(data[[i]])) {
          summary_text <- "all missing"
        } else {
          min_val <- .format_num(min(data[[i]], na.rm = TRUE))
          max_val <- .format_num(max(data[[i]], na.rm = TRUE))
          mean_val <- .format_num(mean(data[[i]], na.rm = TRUE))
          summary_text <- paste0(
            "range: [",
            min_val,
            ", ",
            max_val,
            "], ",
            "mean: ",
            mean_val,
            ", ",
            "NAs: ",
            na_count
          )
        }
      } else if (is.factor(data[[i]]) || is.character(data[[i]])) {
        n_unique <- length(unique(data[[i]]))
        na_count <- sum(is.na(data[[i]]))

        if (n_unique <= 5 && is.factor(data[[i]])) {
          levels_text <- paste(levels(data[[i]]), collapse = ", ")
          summary_text <- paste0(
            n_unique,
            " levels: ",
            levels_text,
            ", NAs: ",
            na_count
          )
        } else {
          summary_text <- paste0(n_unique, " unique values, NAs: ", na_count)
        }
      } else if (is.logical(data[[i]])) {
        n_true <- sum(data[[i]], na.rm = TRUE)
        n_false <- sum(!data[[i]], na.rm = TRUE)
        na_count <- sum(is.na(data[[i]]))
        summary_text <- paste0(
          "TRUE: ",
          n_true,
          ", FALSE: ",
          n_false,
          ", NAs: ",
          na_count
        )
      } else {
        summary_text <- ""
      }

      description <- paste0(
        description,
        "- **",
        var_name,
        "** (",
        var_type,
        "): ",
        summary_text,
        "\n"
      )
    } else {
      description <- paste0(
        description,
        "- **",
        var_name,
        "** (",
        var_type,
        ")\n"
      )
    }
  }

  # Overall missing data summary
  if (any(is.na(data))) {
    n_missing <- sum(is.na(data))
    pct_missing <- .format_num(n_missing / prod(dims) * 100, 1)
    description <- paste0(
      description,
      "\n## Missing Data\nTotal: ",
      n_missing,
      " cells (",
      pct_missing,
      "%)\n"
    )
  }

  attr(description, "method_used") <- "basic"
  description
}

#' @export
print.cassidy_df_description <- function(x, ...) {
  cli::cli_h2("Data Frame Description: {x$data_name}")
  cli::cli_alert_info("Method: {x$method}")
  cat("\n")
  cat(x$text)
  invisible(x)
}

#' @export
#' @export
print.cassidy_data_issues <- function(x, ...) {
  cli::cli_h2("Data Quality Issues")

  has_issues <- FALSE

  if (length(x$missing_data) > 0) {
    has_issues <- TRUE
    cli::cli_h3("High Missing Data:")
    for (col in names(x$missing_data)) {
      pct <- format(x$missing_data[[col]], digits = 1, nsmall = 1)
      cli::cli_alert_warning("{col}: {pct}% missing")
    }
  }

  if (length(x$constant_columns) > 0) {
    has_issues <- TRUE
    cli::cli_h3("Constant Columns:")
    cli::cli_alert_warning(paste(x$constant_columns, collapse = ", "))
  }

  if (length(x$high_cardinality) > 0) {
    has_issues <- TRUE
    cli::cli_h3("High Cardinality:")
    for (col in names(x$high_cardinality)) {
      n_unique <- x$high_cardinality[[col]]
      cli::cli_alert_warning("{col}: {n_unique} unique values")
    }
  }

  if (length(x$outliers) > 0) {
    has_issues <- TRUE
    cli::cli_h3("Outliers Detected:")
    for (col in names(x$outliers)) {
      n_outliers <- x$outliers[[col]]
      cli::cli_alert_info("{col}: {n_outliers} potential outliers")
    }
  }

  if (!is.null(x$duplicates) && x$duplicates > 0) {
    has_issues <- TRUE
    cli::cli_h3("Duplicates:")
    n_dups <- x$duplicates
    cli::cli_alert_warning("{n_dups} duplicate rows found")
  }

  if (!has_issues) {
    cli::cli_alert_success("No major issues detected!")
  }

  invisible(x)
}
