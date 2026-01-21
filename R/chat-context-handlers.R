#' Setup context data renderer
#' @keywords internal
setup_context_data_renderer <- function(output, input, conv_manager) {
  # Render data count
  output$data_count_ui <- shiny::renderUI({
    # Trigger refresh when button clicked
    input$refresh_all_context
    input$refresh_data

    dfs <- .get_env_dataframes()
    paste0("(", length(dfs), ")")
  })

  # Render data frame list
  output$context_data_ui <- shiny::renderUI({
    # Trigger refresh
    input$refresh_all_context
    input$refresh_data

    dfs <- .get_env_dataframes()

    if (length(dfs) == 0) {
      return(shiny::div(
        class = "no-data-message",
        shiny::icon("database"),
        shiny::br(),
        "No data frames in environment"
      ))
    }

    lapply(names(dfs), function(df_name) {
      df_info <- dfs[[df_name]]
      input_id <- paste0("ctx_data_", gsub("", "_", df_name))
      refresh_id <- paste0("refresh_data_", gsub("", "_", df_name))

      shiny::div(
        class = "context-data-item",
        id = paste0("data_item_", gsub("", "_", df_name)),
        shiny::checkboxInput(
          input_id,
          shiny::tagList(
            shiny::div(
              class = "data-info",
              shiny::span(class = "data-name", df_name),
              shiny::span(
                class = "data-dims",
                paste0(df_info$rows, " × ", df_info$cols)
              )
            )
          ),
          value = FALSE
        ),
        shiny::actionButton(
          refresh_id,
          shiny::icon("sync"),
          class = "btn-icon-xs",
          title = paste("Refresh", df_name)
        )
      )
    })
  })
}

#' Setup context summary renderer
#' @keywords internal
setup_context_summary_renderer <- function(output, input, conv_manager) {
  output$context_summary <- shiny::renderUI({
    # Count selected project items
    config_selected <- isTRUE(input$ctx_config)
    session_selected <- isTRUE(input$ctx_session)
    git_selected <- isTRUE(input$ctx_git)

    project_items <- c()
    if (config_selected) {
      project_items <- c(project_items, "cassidy.md")
    }
    if (session_selected) {
      project_items <- c(project_items, "R session")
    }
    if (git_selected) {
      project_items <- c(project_items, "Git")
    }

    # Count selected data frames
    dfs <- .get_env_dataframes()
    data_items <- c()
    for (df_name in names(dfs)) {
      input_id <- paste0("ctx_data_", gsub("", "_", df_name))
      if (isTRUE(input[[input_id]])) {
        data_items <- c(data_items, df_name)
      }
    }

    # Get files
    file_items <- conv_context_files(conv_manager)

    # Check if context has been applied
    context_applied <- !is.null(conv_context_text(conv_manager))

    shiny::div(
      shiny::div(
        class = "summary-title",
        shiny::icon("layer-group"),
        "Selected Context",
        if (context_applied) {
          shiny::span(
            class = "context-applied-badge",
            shiny::icon("check"),
            "Applied"
          )
        }
      ),
      shiny::div(
        class = "summary-items",
        shiny::div(
          class = paste(
            "summary-item",
            if (length(project_items) > 0) "has-items" else "no-items"
          ),
          shiny::icon(
            if (length(project_items) > 0) "check-circle" else "circle"
          ),
          paste0(
            "Project: ",
            if (length(project_items) > 0) {
              paste(project_items, collapse = ", ")
            } else {
              "none"
            }
          )
        ),
        shiny::div(
          class = paste(
            "summary-item",
            if (length(data_items) > 0) "has-items" else "no-items"
          ),
          shiny::icon(
            if (length(data_items) > 0) "check-circle" else "circle"
          ),
          paste0(
            "Data: ",
            if (length(data_items) > 0) {
              paste(data_items, collapse = ", ")
            } else {
              "none"
            }
          )
        ),
        shiny::div(
          class = paste(
            "summary-item",
            if (length(file_items) > 0) "has-items" else "no-items"
          ),
          shiny::icon(
            if (length(file_items) > 0) "check-circle" else "circle"
          ),
          paste0(
            "Files: ",
            if (length(file_items) > 0) {
              paste(basename(file_items), collapse = ", ")
            } else {
              "none"
            }
          )
        )
      )
    )
  })
}

#' Setup apply context handler
#' @keywords internal
setup_apply_context_handler <- function(
  input,
  session,
  conv_manager,
  assistant_id,
  api_key,
  timeout
) {
  shiny::observeEvent(input$apply_context, {
    cli::cli_alert_info("Applying context...")

    # Gather context based on selections
    context_text <- gather_selected_context(input, conv_manager)

    if (is.null(context_text) || !nzchar(context_text)) {
      shiny::showNotification(
        "No context items selected",
        type = "warning",
        duration = 3
      )
      return()
    }

    # Show size
    context_size <- nchar(context_text)
    cli::cli_alert_success(
      "Context gathered: {format(context_size, big.mark = ',')} characters"
    )

    # Store in conversation manager
    conv_set_context(conv_manager, context_text)

    # === NEW: SEND CONTEXT IMMEDIATELY ===

    # Ensure we have a conversation
    if (is.null(conv_current_id(conv_manager))) {
      conv_create_new(conv_manager, session)
    }

    # Show loading state
    conv_set_loading(conv_manager, TRUE)
    session$sendCustomMessage("setLoading", TRUE)

    shiny::showNotification(
      "Sending context to Cassidy...",
      id = "context_sending",
      type = "message",
      duration = NULL
    )

    # Send context to Cassidy
    tryCatch(
      {
        conv <- conv_get_current(conv_manager)
        thread_id <- conv$thread_id

        # Create thread if needed
        if (is.null(thread_id)) {
          thread_id <- cassidy_create_thread(
            assistant_id = assistant_id,
            api_key = api_key
          )
          conv_update_current(conv_manager, list(thread_id = thread_id))
          cli::cli_alert_success("Created new conversation thread")
        }

        # Send context to API
        context_message <- paste0(
          "# Project Context\n\n",
          context_text,
          "\n\n---\n\n",
          "I've shared my project context with you. Please acknowledge that you've received it ",
          "and let me know you're ready to help with this project.",

          if (grepl("INDEX mode", context_text, fixed = TRUE)) {
            paste0(
              "Note: Files are in INDEX mode. To see full file contents, ",
              "respond with [REQUEST_FILE:path/to/file.R] and I'll automatically send them. ",
              "Please acknowledge and let me know you're ready."
            )
          } else {
            "Please acknowledge that you've received it and let me know you're ready to help."
          }
        )

        response <- cassidy_send_message(
          thread_id = thread_id,
          message = context_message,
          api_key = api_key,
          timeout = timeout
        )

        # Add system message to UI
        conv_add_message(
          conv_manager,
          "system",
          sprintf(
            "**System:** Applied context (%s characters)",
            format(context_size, big.mark = ",")
          )
        )

        # Add Cassidy's acknowledgment
        conv_add_message(conv_manager, "assistant", response$content)

        # Mark context as sent
        conv_set_context_sent(conv_manager, TRUE)
        conv_update_current(conv_manager, list(context_sent = TRUE))

        # Clear loading state
        conv_set_loading(conv_manager, FALSE)
        session$sendCustomMessage("setLoading", FALSE)
        session$sendCustomMessage("scrollToBottom", list())

        # Remove sending notification
        shiny::removeNotification("context_sending")

        # Success notification
        shiny::showNotification(
          shiny::tagList(
            shiny::icon("check"),
            " Context sent successfully! Cassidy has acknowledged."
          ),
          type = "message",
          duration = 5
        )

        cli::cli_alert_success(
          "Context sent and acknowledged ({format(context_size, big.mark = ',')} chars)"
        )
      },
      error = function(e) {
        # Clear loading state
        conv_set_loading(conv_manager, FALSE)
        session$sendCustomMessage("setLoading", FALSE)

        # Remove sending notification
        shiny::removeNotification("context_sending")

        # Error notification
        shiny::showNotification(
          shiny::tagList(
            shiny::icon("exclamation-triangle"),
            sprintf(" Error sending context: %s", e$message)
          ),
          type = "error",
          duration = 8
        )

        cli::cli_warn("Failed to send context: {e$message}")
      }
    )
  })
}


#' Setup refresh context handlers
#' @keywords internal
setup_refresh_context_handler <- function(
  input,
  session,
  conv_manager,
  assistant_id,
  api_key,
  timeout
) {
  # Refresh all
  shiny::observeEvent(input$refresh_all_context, {
    shiny::showNotification(
      "Refreshing all context...",
      type = "message",
      duration = 2
    )

    # Re-gather context
    context_text <- gather_selected_context(input, conv_manager)
    if (!is.null(context_text)) {
      conv_set_context(conv_manager, context_text)
      conv_set_context_sent(conv_manager, FALSE) # Mark as needing to be sent
    }

    cli::cli_alert_success("All context refreshed")
  })

  # Individual refresh handlers - similar pattern
  shiny::observeEvent(input$refresh_config, {
    shiny::showNotification(
      "Refreshed cassidy.md",
      type = "message",
      duration = 2
    )

    # Mark context as needing update
    conv_set_context_sent(conv_manager, FALSE)
    cli::cli_alert_success("Refreshed cassidy.md")
  })

  # ... similar for other refresh buttons

  # Data frame refresh handlers
  shiny::observe({
    dfs <- .get_env_dataframes()

    lapply(names(dfs), function(df_name) {
      refresh_id <- paste0("refresh_data_", gsub("", "_", df_name))

      shiny::observeEvent(
        input[[refresh_id]],
        {
          shiny::showNotification(
            paste("Refreshed", df_name),
            type = "message",
            duration = 2
          )

          # Mark context as needing update
          conv_set_context_sent(conv_manager, FALSE)

          cli::cli_alert_success("Refreshed data frame: {df_name}")
        },
        ignoreInit = TRUE
      )
    })
  })
}

#' Setup file tree renderer
#' @keywords internal
setup_file_tree_renderer <- function(output, input, conv_manager) {
  # Render file count
  output$files_count_ui <- shiny::renderUI({
    input$refresh_all_context
    input$refresh_all_files
    # Trigger on conversation change
    conv_current_id(conv_manager)

    files <- conv_context_files(conv_manager)
    paste0("(", length(files), " selected)")
  })

  # Render file tree
  output$context_files_tree_ui <- shiny::renderUI({
    input$refresh_all_context
    input$refresh_all_files
    # Trigger on conversation change
    conv_current_id(conv_manager)

    # Get available files
    available_files <- .get_project_files()
    selected_files <- conv_context_files(conv_manager)

    if (length(available_files) == 0) {
      return(shiny::div(
        class = "file-tree-empty",
        shiny::div(class = "empty-icon", shiny::icon("folder-open")),
        "No files found in project"
      ))
    }

    # Group files by directory
    file_tree <- .build_file_tree(available_files)

    # Render tree
    .render_file_tree(file_tree, selected_files)
  })
}


#' Setup file selection handlers
#' @keywords internal
setup_file_selection_handlers <- function(input, session, conv_manager) {
  # Individual file refresh handlers
  shiny::observe({
    files <- .get_project_files()

    lapply(files, function(file) {
      file_id <- gsub("", "_", file)
      refresh_id <- paste0("refresh_file_", file_id)

      shiny::observeEvent(
        input[[refresh_id]],
        {
          # Check if file is in context
          current_files <- conv_context_files(conv_manager)

          if (!(file %in% current_files)) {
            shiny::showNotification(
              paste(basename(file), "is not in context. Select it first."),
              type = "warning",
              duration = 3
            )
            return()
          }

          # Re-read the file and update context
          tryCatch(
            {
              file_ctx <- cassidy_describe_file(file)

              # Update the stored context
              context_text <- conv_context_text(conv_manager)
              if (!is.null(context_text)) {
                # Mark context as needing to be re-sent
                conv_set_context_sent(conv_manager, FALSE)
              }

              shiny::showNotification(
                shiny::tagList(
                  shiny::icon("check"),
                  paste(
                    " Refreshed",
                    basename(file),
                    "- will be sent with next message"
                  )
                ),
                type = "message",
                duration = 3
              )
              cli::cli_alert_success("Refreshed file: {file}")
            },
            error = function(e) {
              shiny::showNotification(
                paste("Error refreshing", basename(file), ":", e$message),
                type = "error",
                duration = 5
              )
            }
          )
        },
        ignoreInit = TRUE
      )
    })
  })

  # Refresh all files
  shiny::observeEvent(input$refresh_all_files, {
    shiny::showNotification(
      "Refreshing file list...",
      type = "message",
      duration = 2
    )
  })

  # Individual file refresh handlers
  shiny::observe({
    files <- .get_project_files()

    lapply(files, function(file) {
      file_id <- gsub("", "_", file)
      refresh_id <- paste0("refresh_file_", file_id)

      shiny::observeEvent(
        input[[refresh_id]],
        {
          shiny::showNotification(
            paste("Refreshed", basename(file)),
            type = "message",
            duration = 2
          )
          cli::cli_alert_success("Refreshed file: {file}")
        },
        ignoreInit = TRUE
      )
    })
  })
}

#' Get project files
#' @keywords internal
.get_project_files <- function() {
  patterns <- c(
    "\\.R$",
    "\\.Rmd$",
    "\\.qmd$",
    "\\.md$",
    "\\.txt$",
    "\\.yml$",
    "\\.yaml$"
  )

  files <- unlist(lapply(patterns, function(p) {
    list.files(pattern = p, recursive = TRUE, ignore.case = TRUE)
  }))

  # Exclude common non-essential directories
  exclude_patterns <- c("^renv/", "^\\.Rproj", "^packrat/", "^\\.git/")
  for (pattern in exclude_patterns) {
    files <- files[!grepl(pattern, files)]
  }

  sort(unique(files))
}

#' Build file tree structure
#' @keywords internal
.build_file_tree <- function(files) {
  tree <- list()

  for (file in files) {
    parts <- strsplit(file, "/")[[1]]

    if (length(parts) == 1) {
      # Root level file
      if (is.null(tree[["."]])) {
        tree[["./"]] <- character()
      }
      tree[["./"]] <- c(tree[["./"]], file)
    } else {
      # File in subdirectory
      dir <- paste(parts[-length(parts)], collapse = "/")
      if (is.null(tree[[dir]])) {
        tree[[dir]] <- character()
      }
      tree[[dir]] <- c(tree[[dir]], file)
    }
  }

  tree
}

#' Render file tree UI
#' @keywords internal
.render_file_tree <- function(tree, selected_files) {
  # Sort directories (root first, then alphabetically)
  dirs <- names(tree)
  dirs <- c(
    dirs[dirs == "./"],
    sort(dirs[dirs != "./"])
  )

  lapply(dirs, function(dir) {
    files <- tree[[dir]]
    dir_display <- if (dir == "./") "Root" else dir
    dir_id <- gsub("", "_", dir)

    shiny::div(
      class = "file-tree-folder",
      id = paste0("folder_", dir_id),
      # Folder header
      shiny::div(
        class = "file-tree-folder-header",
        onclick = paste0("toggleFileFolder('", dir_id, "')"),
        shiny::icon("chevron-down", class = "folder-chevron"),
        shiny::icon("folder", class = "folder-icon"),
        shiny::span(class = "folder-name", dir_display),
        shiny::span(class = "folder-count", paste0("(", length(files), ")"))
      ),
      # Folder contents
      shiny::div(
        class = "file-tree-folder-contents",
        lapply(files, function(file) {
          .render_file_item(file, file %in% selected_files)
        })
      )
    )
  })
}

#' Render single file item
#' @keywords internal
.render_file_item <- function(file, is_selected) {
  file_id <- gsub("", "_", file)
  file_ext <- tolower(tools::file_ext(file))

  # Determine icon based on extension
  icon_class <- switch(
    file_ext,
    "r" = "r-file",
    "rmd" = "md-file",
    "qmd" = "qmd-file",
    "md" = "md-file",
    ""
  )

  icon_name <- switch(
    file_ext,
    "r" = "code",
    "rmd" = "file-code",
    "qmd" = "file-code",
    "md" = "file-alt",
    "yml" = "cog",
    "yaml" = "cog",
    "file"
  )

  shiny::div(
    class = paste("file-tree-item", if (is_selected) "selected" else ""),
    id = paste0("file_item_", file_id),
    # Checkbox (without label)
    shiny::tags$input(
      type = "checkbox",
      id = paste0("ctx_file_", file_id),
      class = "form-check-input file-checkbox",
      checked = if (is_selected) "checked" else NULL
    ),
    # Label as separate element
    shiny::tags$label(
      `for` = paste0("ctx_file_", file_id),
      class = "file-tree-label",
      shiny::icon(icon_name, class = paste("file-icon", icon_class)),
      shiny::span(class = "file-name", basename(file))
    ),
    # Refresh button
    shiny::actionButton(
      paste0("refresh_file_", file_id),
      shiny::icon("sync"),
      class = "btn-icon-xs file-refresh-btn",
      title = paste("Refresh", basename(file))
    )
  )
}

#' Get data frames from global environment
#' @keywords internal
.get_env_dataframes <- function(envir = globalenv()) {
  objects <- ls(envir = envir)

  dfs <- list()
  for (obj_name in objects) {
    obj <- tryCatch(
      get(obj_name, envir = envir),
      error = function(e) NULL
    )

    if (is.data.frame(obj)) {
      dfs[[obj_name]] <- list(
        name = obj_name,
        rows = nrow(obj),
        cols = ncol(obj),
        class = class(obj)[1]
      )
    }
  }

  dfs
}

#' Detect if Cassidy is requesting files
#' @keywords internal
.detect_file_requests <- function(response_text) {
  # styler: off
  pattern <- "\```math
REQUEST_FILE:([^\
```]+)\\]"
  # styler: on

  matches <- gregexpr(pattern, response_text, perl = TRUE)

  if (matches[[1]][1] == -1) {
    return(list(
      has_requests = FALSE,
      files = character(0)
    ))
  }

  # Extract file paths
  matched_text <- regmatches(response_text, matches)[[1]]

  # styler: off
  requested_files <- gsub(
    "\```math
REQUEST_FILE:([^\
```]+)\\]",
    "\\1",
    matched_text
  )
  # styler: on

  requested_files <- trimws(requested_files)

  cli::cli_alert_info(
    "Detected file requests: {paste(requested_files, collapse = ', ')}"
  )

  return(list(
    has_requests = TRUE,
    files = unique(requested_files)
  ))
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
    if (!file.exists(path)) {
      next
    }

    tryCatch(
      {
        lines <- length(readLines(path, warn = FALSE))
        file_line_counts[i] <- lines
        total_lines <- total_lines + lines

        info <- file.info(path)
        total_size <- total_size + info$size
      },
      error = function(e) NULL
    )
  }

  # Thresholds (tuned for typical R package files)
  # These are conservative to avoid hitting API limits
  TIER_1_MAX_LINES <- 2000 # ~50-60K chars → FULL content
  TIER_2_MAX_LINES <- 5000 # ~120K chars → SUMMARY with previews
  # Above that → INDEX only

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

#' Gather context (unified function)
#' @keywords internal
gather_context <- function(
  config = TRUE,
  session = TRUE,
  git = FALSE,
  data = TRUE,
  data_method = "basic",
  files = NULL
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

  # Data
  if (data) {
    dfs <- .get_env_dataframes()
    for (df_name in names(dfs)) {
      df <- get(df_name, envir = globalenv())
      df_desc <- cassidy_describe_df(df, name = df_name, method = data_method)
      if (!is.null(df_desc)) {
        context_parts[[paste0("data_", df_name)]] <- df_desc$text
      }
    }
  }

  # Files (with adaptive tiers)
  if (!is.null(files) && length(files) > 0) {
    # Determine tier
    total_lines <- sum(vapply(
      files,
      function(f) {
        if (file.exists(f)) length(readLines(f, warn = FALSE)) else 0
      },
      integer(1)
    ))

    if (total_lines <= 1500 && length(files) <= 5) {
      tier <- "full"
    } else if (total_lines <= 4000 && length(files) <= 12) {
      tier <- "summary"
    } else {
      tier <- "index"
    }

    cli::cli_alert_info(
      "File tier: {tier} ({length(files)} files, {total_lines} lines)"
    )

    for (file_path in files) {
      if (file.exists(file_path)) {
        file_ctx <- cassidy_describe_file(file_path, level = tier)
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


#' Gather context based on sidebar selections
#' @keywords internal
gather_selected_context <- function(input, conv_manager) {
  # Get selected files from conv_manager and UI
  selected_files <- conv_context_files(conv_manager)
  available_files <- .get_project_files()

  for (file_path in available_files) {
    file_id <- gsub("", "_", file_path)
    input_id <- paste0("ctx_file_", file_id)
    if (isTRUE(input[[input_id]]) && !(file_path %in% selected_files)) {
      selected_files <- c(selected_files, file_path)
    }
  }

  for (file_path in available_files) {
    file_id <- gsub("", "_", file_path)
    input_id <- paste0("ctx_file_", file_id)
    if (!is.null(input[[input_id]]) && !isTRUE(input[[input_id]])) {
      selected_files <- setdiff(selected_files, file_path)
    }
  }

  conv_set_context_files(conv_manager, selected_files)

  # Get selected data frames
  dfs <- .get_env_dataframes()
  selected_data <- names(dfs)[vapply(
    names(dfs),
    function(df_name) {
      input_id <- paste0("ctx_data_", gsub("", "_", df_name))
      isTRUE(input[[input_id]])
    },
    logical(1)
  )]

  # Call unified function
  gather_context(
    config = isTRUE(input$ctx_config),
    session = isTRUE(input$ctx_session),
    git = isTRUE(input$ctx_git),
    data = length(selected_data) > 0,
    data_method = input$data_description_method %||% "basic",
    files = selected_files
  )
}
