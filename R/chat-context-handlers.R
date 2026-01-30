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
      input_id <- paste0("ctx_data_", gsub("[^a-zA-Z0-9]", "_", df_name))
      refresh_id <- paste0("refresh_data_", gsub("[^a-zA-Z0-9]", "_", df_name))

      shiny::div(
        class = "context-data-item",
        id = paste0("data_item_", gsub("[^a-zA-Z0-9]", "_", df_name)),
        shiny::checkboxInput(
          input_id,
          shiny::tagList(
            shiny::div(
              class = "data-info",
              shiny::span(class = "data-name", df_name),
              shiny::span(
                class = "data-dims",
                paste0(df_info$rows, " x ", df_info$cols)
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
      input_id <- paste0("ctx_data_", gsub("[^a-zA-Z0-9]", "_", df_name))
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

    # Gather context based on selections (incremental by default)
    context_text <- gather_selected_context(
      input,
      conv_manager,
      incremental = TRUE
    )

    # Get what was actually gathered (from attributes)
    files_to_send <- attr(context_text, "files_to_send") %||% character()
    data_to_send <- attr(context_text, "data_to_send") %||% character()

    # Check if project items changed (config, session, git)
    # These are always re-sent if selected, so check if any are selected
    project_items_selected <- isTRUE(input$ctx_config) ||
      isTRUE(input$ctx_session) ||
      isTRUE(input$ctx_git)

    # Check if there's anything new to send
    if (
      length(files_to_send) == 0 &&
        length(data_to_send) == 0 &&
        (is.null(context_text) || !nzchar(context_text))
    ) {
      shiny::showNotification(
        "No new context to send - everything selected has already been sent",
        type = "message",
        duration = 3
      )
      cli::cli_alert_info("No new context to send")
      return()
    }

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

    # === SEND CONTEXT ===

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

        # === NEW: Update sent tracking ===
        current_sent_files <- conv_sent_context_files(conv_manager)
        current_sent_data <- conv_sent_data_frames(conv_manager)

        # Add newly sent items to tracking
        conv_set_sent_context_files(
          conv_manager,
          union(current_sent_files, files_to_send)
        )
        conv_set_sent_data_frames(
          conv_manager,
          union(current_sent_data, data_to_send)
        )

        # Clear pending refresh queues
        conv_set_pending_refresh_files(conv_manager, character())
        conv_set_pending_refresh_data(conv_manager, character())

        # Update conversation record for persistence
        conv_update_current(
          conv_manager,
          list(
            sent_context_files = conv_sent_context_files(conv_manager),
            sent_data_frames = conv_sent_data_frames(conv_manager)
          )
        )

        # Clear loading state
        conv_set_loading(conv_manager, FALSE)
        session$sendCustomMessage("setLoading", FALSE)
        session$sendCustomMessage("scrollToBottom", list())

        # Remove sending notification
        shiny::removeNotification("context_sending")

        # Success notification with details
        new_files_count <- length(files_to_send)
        new_data_count <- length(data_to_send)

        detail_msg <- c()
        if (new_files_count > 0) {
          detail_msg <- c(detail_msg, paste0(new_files_count, " file(s)"))
        }
        if (new_data_count > 0) {
          detail_msg <- c(detail_msg, paste0(new_data_count, " data frame(s)"))
        }

        shiny::showNotification(
          shiny::tagList(
            shiny::icon("check"),
            " Context sent successfully!",
            if (length(detail_msg) > 0) {
              paste0(" (", paste(detail_msg, collapse = ", "), ")")
            }
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
  # Refresh all - queue ALL sent items for refresh
  shiny::observeEvent(input$refresh_all_context, {
    # Queue all sent files for refresh
    sent_files <- conv_sent_context_files(conv_manager)
    conv_set_pending_refresh_files(conv_manager, sent_files)

    # Queue all sent data for refresh
    sent_data <- conv_sent_data_frames(conv_manager)
    conv_set_pending_refresh_data(conv_manager, sent_data)

    shiny::showNotification(
      paste0(
        "Queued ",
        length(sent_files),
        " file(s) and ",
        length(sent_data),
        " data frame(s) for refresh - click 'Apply Context'"
      ),
      type = "message",
      duration = 3
    )

    cli::cli_alert_success("All sent context queued for refresh")
  })

  # Individual refresh handlers
  shiny::observeEvent(input$refresh_config, {
    # Config is always re-sent if selected, just notify
    shiny::showNotification(
      "cassidy.md will be refreshed with next 'Apply Context'",
      type = "message",
      duration = 2
    )
  })

  # Data frame refresh handlers - queue for refresh

  shiny::observe({
    dfs <- .get_env_dataframes()

    lapply(names(dfs), function(df_name) {
      refresh_id <- paste0("refresh_data_", gsub("", "_", df_name))

      shiny::observeEvent(
        input[[refresh_id]],
        {
          # Add to pending refresh queue
          current_pending <- conv_pending_refresh_data(conv_manager)
          conv_set_pending_refresh_data(
            conv_manager,
            union(current_pending, df_name)
          )

          shiny::showNotification(
            paste(
              df_name,
              "queued for refresh - click 'Apply Context' to send"
            ),
            type = "message",
            duration = 3
          )

          cli::cli_alert_info("Queued data frame for refresh: {df_name}")
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
    # Only trigger on conversation change, not on refresh buttons
    conv_current_id(conv_manager)

    files <- conv_context_files(conv_manager)
    paste0("(", length(files), " selected)")
  })

  output$context_files_tree_ui <- shiny::renderUI({
    # REMOVED: input$refresh_all_context and input$refresh_all_files
    # Only depend on force refresh and conversation changes
    input$force_file_tree_refresh
    conv_current_id(conv_manager)

    # Get ALL files
    available_files <- .get_project_files()
    selected_files <- conv_context_files(conv_manager)
    sent_files <- conv_sent_context_files(conv_manager)
    pending_files <- conv_pending_refresh_files(conv_manager)

    if (length(available_files) == 0) {
      return(shiny::div(
        class = "file-tree-empty",
        shiny::div(class = "empty-icon", shiny::icon("folder-open")),
        "No files found in project"
      ))
    }

    # Build nested tree structure
    file_tree <- .build_file_tree_nested(available_files)

    # Render the tree
    tree_ui <- .render_file_tree_nested(
      file_tree,
      selected_files,
      sent_files = sent_files,
      pending_files = pending_files,
      path = "",
      level = 0
    )

    # Add controls at the top
    shiny::div(
      shiny::div(
        class = "file-tree-controls",
        shiny::actionButton(
          "expand_all_folders",
          shiny::icon("folder-open"),
          "Expand All",
          class = "btn btn-sm btn-outline-secondary"
        ),
        shiny::actionButton(
          "collapse_all_folders",
          shiny::icon("folder"),
          "Collapse All",
          class = "btn btn-sm btn-outline-secondary"
        )
      ),
      shiny::div(
        class = "file-tree-container",
        shiny::tagList(tree_ui)
      )
    )
  })
}


#' Setup file selection handlers
#' @keywords internal
setup_file_selection_handlers <- function(input, session, conv_manager) {
  # Refresh all files button
  shiny::observeEvent(input$refresh_all_files, {
    # Queue all sent files for refresh
    sent_files <- conv_sent_context_files(conv_manager)
    conv_set_pending_refresh_files(conv_manager, sent_files)

    # Update visual state for all sent files - mark them as pending
    for (file in sent_files) {
      file_id <- gsub("[^a-zA-Z0-9]", "_", file)
      session$sendCustomMessage(
        "markFileAsPending",
        list(fileId = file_id)
      )
    }

    shiny::showNotification(
      paste0(
        "Queued ",
        length(sent_files),
        " file(s) for refresh - click 'Apply Context'"
      ),
      type = "message",
      duration = 3
    )
    cli::cli_alert_info("All sent files queued for refresh")
  })

  # Individual file refresh handlers - use isolate to prevent cascading reactivity
  shiny::observe({
    files <- shiny::isolate(.get_project_files())

    lapply(files, function(file) {
      file_id <- gsub("[^a-zA-Z0-9]", "_", file)
      refresh_id <- paste0("refresh_file_", file_id)

      shiny::observeEvent(
        input[[refresh_id]],
        {
          # Check if file has been sent
          sent_files <- conv_sent_context_files(conv_manager)

          if (!(file %in% sent_files)) {
            shiny::showNotification(
              paste(
                basename(file),
                "hasn't been sent yet. Select it and click 'Apply Context'."
              ),
              type = "warning",
              duration = 3
            )
            return()
          }

          # Add to pending refresh queue
          current_pending <- conv_pending_refresh_files(conv_manager)
          conv_set_pending_refresh_files(
            conv_manager,
            union(current_pending, file)
          )

          # Update visual state without re-rendering
          session$sendCustomMessage(
            "markFileAsPending",
            list(fileId = file_id)
          )

          shiny::showNotification(
            paste(
              basename(file),
              "queued for refresh - click 'Apply Context' to send"
            ),
            type = "message",
            duration = 3
          )

          cli::cli_alert_info("Queued file for refresh: {file}")
        },
        ignoreInit = TRUE
      )
    })
  })
}


#' Get project files
#' @keywords internal
.get_project_files <- function(include_hidden = FALSE) {
  # Get all files recursively
  all_files <- list.files(
    recursive = TRUE,
    all.files = include_hidden,
    no.. = TRUE # Don't include . and ..
  )

  # Exclude only truly unnecessary directories
  exclude_patterns <- c(
    "^\\.Rproj\\.user/", # RStudio temp files
    "^renv/library/", # renv package cache (but keep renv.lock)
    "^\\.git/", # Git internals
    "^\\.quarto/" # Quarto cache
  )

  for (pattern in exclude_patterns) {
    all_files <- all_files[!grepl(pattern, all_files)]
  }

  sort(all_files)
}


#' Build nested file tree structure
#' @keywords internal
.build_file_tree_nested <- function(files) {
  tree <- list()

  for (file in files) {
    tree <- .add_file_to_tree(tree, file)
  }

  tree
}

#' Helper to add a single file to the tree
#' @keywords internal
.add_file_to_tree <- function(tree, file) {
  parts <- strsplit(file, "/")[[1]]

  if (length(parts) == 1) {
    # Root-level file
    tree[["__files__"]] <- c(tree[["__files__"]], file)
  } else {
    # Recursive: add to subfolder
    folder <- parts[1]
    remaining_path <- paste(parts[-1], collapse = "/")

    if (is.null(tree[[folder]])) {
      tree[[folder]] <- list()
    }

    tree[[folder]] <- .add_file_to_tree(tree[[folder]], remaining_path)
  }

  tree
}


#' Render nested file tree UI with collapsible folders
#' @keywords internal
.render_file_tree_nested <- function(
  tree,
  selected_files,
  sent_files = character(),
  pending_files = character(),
  path = "",
  level = 0
) {
  if (length(tree) == 0) {
    return(NULL)
  }

  # Separate folders and files
  folders <- names(tree)[names(tree) != "__files__"]
  files <- tree[["__files__"]]

  ui_elements <- list()

  # Render folders first (sorted alphabetically)
  for (folder in sort(folders)) {
    folder_path <- if (nchar(path) > 0) paste0(path, "/", folder) else folder
    folder_id <- gsub("[^a-zA-Z0-9]", "_", folder_path)

    # Count total files in this folder (recursively)
    file_count <- .count_files_in_tree(tree[[folder]])

    # Create collapsible folder
    ui_elements[[length(ui_elements) + 1]] <- shiny::div(
      class = "file-tree-folder",
      style = paste0("padding-left: ", level * 10, "px;"),

      # Folder header (clickable to toggle)
      shiny::div(
        class = "file-tree-folder-header",
        id = paste0("folder_header_", folder_id),
        onclick = sprintf("toggleFolder('%s')", folder_id),

        shiny::tags$span(
          class = "folder-toggle-icon",
          id = paste0("toggle_icon_", folder_id),
          shiny::HTML("&#9654;") # Right-pointing triangle (collapsed)
        ),
        shiny::icon("folder", class = "folder-icon"),
        shiny::tags$span(class = "folder-name", folder),
        shiny::tags$span(
          class = "folder-count",
          paste0("(", file_count, ")")
        )
      ),

      # Folder contents (initially hidden)
      shiny::div(
        class = "file-tree-folder-contents",
        id = paste0("folder_contents_", folder_id),
        style = "display: none;",
        .render_file_tree_nested(
          tree[[folder]],
          selected_files,
          sent_files = sent_files,
          pending_files = pending_files,
          path = folder_path,
          level = level + 1
        )
      )
    )
  }

  # Render files in this directory
  if (!is.null(files) && length(files) > 0) {
    for (file in sort(files)) {
      # IMPORTANT: Reconstruct full path from current path + filename
      full_file_path <- if (nchar(path) > 0) {
        paste0(path, "/", file)
      } else {
        file
      }

      ui_elements[[length(ui_elements) + 1]] <- .render_file_item_nested(
        full_file_path,
        is_selected = full_file_path %in% selected_files,
        is_sent = full_file_path %in% sent_files,
        needs_refresh = full_file_path %in% pending_files,
        level = level
      )
    }
  }

  ui_elements
}


#' Count total files in a tree (recursive helper)
#' @keywords internal
.count_files_in_tree <- function(tree) {
  count <- 0

  # Count files at this level
  if (!is.null(tree[["__files__"]])) {
    count <- length(tree[["__files__"]])
  }

  # Recursively count files in subdirectories
  folders <- names(tree)[names(tree) != "__files__"]
  for (folder in folders) {
    count <- count + .count_files_in_tree(tree[[folder]])
  }

  count
}

#' Render single file item with proper indentation
#' @keywords internal
.render_file_item_nested <- function(
  file,
  is_selected,
  is_sent,
  needs_refresh = FALSE,
  level
) {
  file_id <- gsub("", "_", file)
  file_name <- basename(file)

  # Determine CSS class based on state:
  # Priority: needs_refresh > is_sent > is_selected
  # - If needs refresh (already sent but queued for re-send): show as pending/orange
  # - If sent: blue (sent)
  # - If selected but not sent: green (pending)
  # - Otherwise: no special class
  item_class <- "file-tree-item"

  if (needs_refresh) {
    item_class <- paste(item_class, "pending")
  } else if (is_sent) {
    item_class <- paste(item_class, "sent")
  } else if (is_selected) {
    item_class <- paste(item_class, "pending")
  }

  shiny::div(
    class = item_class,
    style = paste0("padding-left: ", level * 10 + 8, "px;"),
    id = paste0("file_item_", file_id),
    title = file,

    # Checkbox - checked if sent OR selected
    shiny::tags$input(
      type = "checkbox",
      id = paste0("ctx_file_", file_id),
      class = "form-check-input file-checkbox",
      checked = if (is_selected || is_sent) "checked" else NULL
    ),

    # File label
    shiny::tags$label(
      `for` = paste0("ctx_file_", file_id),
      class = "file-tree-label",
      shiny::tags$span(class = "file-name", file_name)
    ),

    # Refresh button
    shiny::actionButton(
      paste0("refresh_file_", file_id),
      shiny::icon("sync"),
      class = "btn-icon-xs file-refresh-btn",
      title = paste("Refresh", file_name)
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
    existing_files <- previous_files[file.exists(previous_files)]

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
      if (file.exists(file_path)) {
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
gather_selected_context <- function(input, conv_manager, incremental = TRUE) {
  # Get selected files from conv_manager and UI
  selected_files <- conv_context_files(conv_manager)
  available_files <- .get_project_files()

  for (file_path in available_files) {
    input_id <- paste0("ctx_file_", gsub("[^a-zA-Z0-9]", "_", file_path))
    if (isTRUE(input[[input_id]]) && !(file_path %in% selected_files)) {
      selected_files <- c(selected_files, file_path)
    }
  }

  for (file_path in available_files) {
    input_id <- paste0("ctx_file_", gsub("[^a-zA-Z0-9]", "_", file_path))
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
      input_id <- paste0("ctx_data_", gsub("[^a-zA-Z0-9]", "_", df_name))
      isTRUE(input[[input_id]])
    },
    logical(1)
  )]

  # === NEW: Calculate what actually needs to be sent ===
  if (incremental) {
    sent_files <- conv_sent_context_files(conv_manager)
    sent_data <- conv_sent_data_frames(conv_manager)
    pending_files <- conv_pending_refresh_files(conv_manager)
    pending_data <- conv_pending_refresh_data(conv_manager)

    # Only gather new + refreshed items
    files_to_send <- union(
      setdiff(selected_files, sent_files),
      pending_files
    )

    data_to_send <- union(
      setdiff(selected_data, sent_data),
      pending_data
    )
  } else {
    # Full send (for new conversations)
    files_to_send <- selected_files
    data_to_send <- selected_data
  }

  # Store what we're about to send for later tracking update
  attr_files <- files_to_send
  attr_data <- data_to_send

  # Call unified function with filtered items
  result <- gather_context(
    config = isTRUE(input$ctx_config),
    session = isTRUE(input$ctx_session),
    git = isTRUE(input$ctx_git),
    data = length(data_to_send) > 0,
    data_method = input$data_description_method %||% "basic",
    files = files_to_send,
    # Pass specific data frames to gather
    data_frames = data_to_send
  )

  # Attach metadata about what was gathered
  if (!is.null(result)) {
    attr(result, "files_to_send") <- attr_files
    attr(result, "data_to_send") <- attr_data
  }

  result
}
