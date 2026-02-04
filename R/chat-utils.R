#' Get project files
#' @keywords internal
.get_project_files <- function(include_hidden = TRUE) {
  # Get all files recursively
  all_paths <- fs::dir_ls(
    recurse = TRUE,
    all = TRUE,
    # type = "file"
  )

  all_files <- as.character(fs::path_rel(all_paths))

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
  file_id <- gsub("[^a-zA-Z0-9]", "_", file)
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
      checked = if (is_selected || is_sent) "checked" else NULL,
      `data-filepath` = file
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
