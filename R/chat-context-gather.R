#' Gather context (unified function)
#' @keywords internal
gather_context <- function(
  config = TRUE,
  session = TRUE,
  git = FALSE,
  data = TRUE,
  data_method = "basic",
  files = NULL,
  data_frames = NULL
) {
  context_parts <- list()

  # Config
  if (config) {
    config_text <- cassidy_read_context_file()
    if (!is.null(config_text)) {
      context_parts$config <- paste0(
        "## Project Configuration\n\n",
        "### From cassidy.md:\n\n",
        config_text
      )
    }
  }

  # Session
  if (session) {
    context_parts$session <- paste0(
      "## R Session Information\n\n",
      "**R version:** ",
      R.version.string,
      "\n",
      "**Platform:** ",
      R.version$platform,
      "\n",
      "**Working directory:** ",
      getwd(),
      "\n"
    )
  }

  # Git
  if (git && requireNamespace("gert", quietly = TRUE)) {
    git_info <- tryCatch(
      {
        status <- gert::git_status()
        branch <- gert::git_branch()
        paste0(
          "## Git Status\n\n",
          "**Branch:** ",
          branch,
          "\n",
          "**Modified files:** ",
          sum(status$status == "modified"),
          "\n"
        )
      },
      error = function(e) NULL
    )

    if (!is.null(git_info)) {
      context_parts$git <- git_info
    }
  }

  # Data - use specific data_frames if provided, otherwise all
  if (data) {
    dfs <- .get_env_dataframes()
    df_names <- if (!is.null(data_frames)) {
      intersect(data_frames, names(dfs))
    } else {
      names(dfs)
    }

    for (df_name in df_names) {
      df <- get(df_name, envir = globalenv())
      df_desc <- cassidy_describe_df(df, name = df_name, method = data_method)
      if (!is.null(df_desc)) {
        context_parts[[paste0("data_", df_name)]] <- df_desc$text
      }
    }
  }

  # Files (send full content - let Claude manage its context)
  if (!is.null(files) && length(files) > 0) {
    cli::cli_alert_info(
      "Adding {length(files)} file{?s} to context (full content)"
    )

    for (file_path in files) {
      if (fs::file_exists(file_path)) {
        file_ctx <- cassidy_describe_file(file_path, level = "full")
        if (!is.null(file_ctx)) {
          context_parts[[paste0("file_", basename(file_path))]] <- file_ctx$text
        }
      }
    }
  }

  # Combine
  if (length(context_parts) == 0) {
    return(NULL)
  }
  paste(unlist(context_parts), collapse = "\n\n---\n\n")
}


#' Gather context based on sidebar selections
#' @keywords internal
gather_selected_context <- function(input, conv_manager, incremental = TRUE) {
  # Get selected files ONLY from conv_manager (already updated by JS handler)
  selected_files <- conv_context_files(conv_manager)

  # Get selected data frames from checkboxes (this part works)
  dfs <- .get_env_dataframes()
  selected_data <- names(dfs)[vapply(
    names(dfs),
    function(df_name) {
      input_id <- paste0("ctx_data_", gsub("[^a-zA-Z0-9]", "_", df_name))
      isTRUE(input[[input_id]])
    },
    logical(1)
  )]

  # Calculate what needs to be sent (incremental)
  if (incremental) {
    sent_files <- conv_sent_context_files(conv_manager)
    sent_data <- conv_sent_data_frames(conv_manager)
    pending_files <- conv_pending_refresh_files(conv_manager)
    pending_data <- conv_pending_refresh_data(conv_manager)

    files_to_send <- union(
      setdiff(selected_files, sent_files),
      pending_files
    )

    data_to_send <- union(
      setdiff(selected_data, sent_data),
      pending_data
    )
  } else {
    files_to_send <- selected_files
    data_to_send <- selected_data
  }

  # Call unified gather_context with filtered items
  result <- gather_context(
    config = isTRUE(input$ctx_config),
    session = isTRUE(input$ctx_session),
    git = isTRUE(input$ctx_git),
    data = length(data_to_send) > 0,
    data_method = input$data_description_method %||% "basic",
    files = files_to_send,
    data_frames = data_to_send
  )

  # Attach metadata
  if (!is.null(result)) {
    attr(result, "files_to_send") <- files_to_send
    attr(result, "data_to_send") <- data_to_send
  }

  result
}


#' Gather context for chat app
#' @keywords internal
gather_chat_context <- function(context_level, include_data, include_files) {
  # Just call the unified function
  gather_context(
    config = TRUE,
    session = TRUE,
    git = context_level == "comprehensive",
    data = include_data,
    data_method = "basic",
    files = include_files
  )
}


#' Determine appropriate context tier based on file count and size
#' @keywords internal
.determine_file_context_tier <- function(file_paths) {
  if (length(file_paths) == 0) {
    return(list(
      tier = "full",
      reason = "No files selected",
      total_lines = 0,
      total_files = 0,
      total_size_kb = 0
    ))
  }

  # Calculate total lines across all files
  total_lines <- 0
  total_size <- 0
  file_line_counts <- integer(length(file_paths))

  for (i in seq_along(file_paths)) {
    path <- file_paths[i]
    if (!fs::file_exists(path)) {
      next
    }
    tryCatch(
      {
        lines <- length(readLines(path, warn = FALSE))
        file_line_counts[i] <- lines
        total_lines <- total_lines + lines

        total_size <- total_size + fs::file_size(path)
      },
      error = function(e) NULL
    )
  }

  # Thresholds (tuned for typical R package files)
  # These are conservative to avoid hitting API limits
  TIER_1_MAX_LINES <- 2000 # ~50-60K chars --> FULL content
  TIER_2_MAX_LINES <- 5000 # ~120K chars --> SUMMARY with previews
  # Above that --> INDEX only

  # Additional heuristic: if individual files are very large, drop to summary sooner
  max_single_file <- max(file_line_counts, na.rm = TRUE)
  has_large_file <- max_single_file > 800

  # Determine tier
  if (total_lines <= TIER_1_MAX_LINES && !has_large_file) {
    tier <- "full"
    reason <- paste0(
      "Small context (",
      format(total_lines, big.mark = ","),
      " lines across ",
      length(file_paths),
      " file(s)) - sending complete files"
    )
  } else if (total_lines <= TIER_2_MAX_LINES) {
    tier <- "summary"
    reason <- paste0(
      "Medium context (",
      format(total_lines, big.mark = ","),
      " lines across ",
      length(file_paths),
      " file(s)) - sending summaries with previews. ",
      "Request specific files using [REQUEST_FILE:path] for full content"
    )
  } else {
    tier <- "index"
    reason <- paste0(
      "Large context (",
      format(total_lines, big.mark = ","),
      " lines across ",
      length(file_paths),
      " file(s)) - sending index only. ",
      "Please request specific files using [REQUEST_FILE:path] syntax"
    )
  }

  list(
    tier = tier,
    reason = reason,
    total_lines = total_lines,
    total_files = length(file_paths),
    total_size_kb = round(total_size / 1024, 1),
    max_file_lines = max_single_file
  )
}


#' Refresh context for a resumed conversation
#' @keywords internal
.refresh_conversation_context <- function(
  previous_files,
  previous_data = NULL,
  conv_manager
) {
  context_parts <- list()

  # Define unicode symbols
  checkmark <- stringi::stri_unescape_unicode("\\u2713")
  warning_sign <- stringi::stri_unescape_unicode("\\u26A0")

  # 1. ALWAYS: Refresh CASSIDY.md files
  memory_text <- cassidy_read_context_file()
  if (!is.null(memory_text)) {
    context_parts$memory <- memory_text
    cli::cli_alert_success("{checkmark} Loaded fresh CASSIDY.md")
  }

  # 2. ALWAYS: R session info (lightweight, always useful)
  context_parts$session <- paste0(
    "## R Session Information\n\n",
    "**R version:** ",
    R.version.string,
    "\n",
    "**Platform:** ",
    R.version$platform,
    "\n",
    "**Working directory:** ",
    getwd(),
    "\n"
  )

  # 3. Refresh previously selected files (if they still exist)
  if (length(previous_files) > 0) {
    cli::cli_alert_info("Refreshing {length(previous_files)} file{?s}...")

    # Check which files still exist
    existing_files <- previous_files[fs::file_exists(previous_files)]

    if (length(existing_files) < length(previous_files)) {
      missing <- setdiff(previous_files, existing_files)
      cli::cli_alert_warning(
        "{warning_sign} {length(missing)} file{?s} no longer exist: {.file {missing}}"
      )
    }

    if (length(existing_files) > 0) {
      # Determine appropriate tier
      tier_info <- .determine_file_context_tier(existing_files)

      # Read files with appropriate tier
      for (file_path in existing_files) {
        file_ctx <- cassidy_describe_file(file_path, level = tier_info$tier)
        if (!is.null(file_ctx)) {
          context_parts[[paste0("file_", basename(file_path))]] <- file_ctx$text
        }
      }

      cli::cli_alert_success(
        "{checkmark} Refreshed {length(existing_files)} file{?s} ({tier_info$tier} tier)"
      )

      # Update the conversation manager with existing files
      conv_set_context_files(conv_manager, existing_files)
    }
  }

  # 4. Refresh previously selected data frames (if specified)
  if (!is.null(previous_data) && length(previous_data) > 0) {
    current_dfs <- .get_env_dataframes()
    existing_dfs <- intersect(previous_data, names(current_dfs))

    if (length(existing_dfs) > 0) {
      cli::cli_alert_info("Refreshing {length(existing_dfs)} data frame{?s}...")

      for (df_name in existing_dfs) {
        df <- get(df_name, envir = globalenv())
        df_desc <- cassidy_describe_df(df, name = df_name, method = "basic")
        if (!is.null(df_desc)) {
          context_parts[[paste0("data_", df_name)]] <- df_desc$text
        }
      }

      cli::cli_alert_success(
        "{checkmark} Refreshed {length(existing_dfs)} data frame{?s}"
      )
    }

    if (length(existing_dfs) < length(previous_data)) {
      missing_dfs <- setdiff(previous_data, existing_dfs)
      cli::cli_alert_warning(
        "{warning_sign} {length(missing_dfs)} data frame{?s} no longer in environment: {missing_dfs}"
      )
    }
  }

  # Combine all parts
  if (length(context_parts) == 0) {
    return(NULL)
  }

  paste(unlist(context_parts), collapse = "\n\n---\n\n")
}
