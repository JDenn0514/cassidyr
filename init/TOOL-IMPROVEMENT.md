Unified Tool System Implementation Plan

## Overview

Tool Enhancement improves the underlying tool infrastructure used by both agentic tasks and chat, while Tool Calling in Chat extends cassidy_chat() to use that enhanced infrastructure. They should be implemented together as a cohesive system.

## Architecture Principles

1. **Shared Tool Registry** - One tool system used by both cassidy_agentic_task() and cassidy_chat()
2. **Enhanced Metadata** - All tools (built-in and custom) support rich metadata
3. **Opt-in Chat Tools** - cassidy_chat() works as before unless tools parameter is specified
4. **Custom Tools Everywhere** - User tools work in both agentic and chat contexts

---

## Phase 1: Enhanced Tool Foundation (3-4 hours)

**Goal:** Upgrade the tool system with metadata, validation, and extensibility

### 1.1 Enhanced Tool Registry

**File:** R/agentic-tools.R

Update .cassidy_tools structure:

```r
.cassidy_tools <- list(
  read_file = list(
    name = "read_file",
    title = "Read File",
    description = "Read contents of a file",
    group = "files",
    risky = FALSE,
    hints = list(
      read_only = TRUE,
      idempotent = TRUE
    ),
    parameters = list(
      filepath = list(
        type = "string",
        description = "Path to the file to read",
        required = TRUE
      ),
      working_dir = list(
        type = "string",
        description = "Working directory",
        required = FALSE,
        default = "getwd()"
      )
    ),
    handler = function(filepath, working_dir = getwd()) { ... },
    can_register = function() TRUE
  )
  # ... update all other tools similarly
)
```

Add helper functions:

```r
.get_tool_field(tool, field, default = NULL)
.get_tool_definition(tool_name)  # Merges built-in + custom
.get_all_tools(refresh = FALSE)  # With caching
```

### 1.2 Type Validation System

**File:** R/agentic-tools.R

Add validation to .execute_tool():

```r
.validate_tool_input <- function(tool_name, input) {
  tool <- .get_tool_definition(tool_name)
  
  if (is.null(tool$parameters)) {
    return(invisible(TRUE))  # Backward compat
  }
  
  errors <- character()
  
  for (param_name in names(tool$parameters)) {
    param <- tool$parameters[[param_name]]
    
    # Check required
    if (isTRUE(param$required) && !param_name %in% names(input)) {
      errors <- c(errors, paste("Missing required parameter:", param_name))
    }
    
    # Type validation
    if (param_name %in% names(input)) {
      if (!.validate_type_rlang(input[[param_name]], param$type)) {
        errors <- c(errors, paste0(
          "Parameter '", param_name, "' should be ", param$type,
          " but got ", typeof(input[[param_name]])
        ))
      }
    }
  }
  
  if (length(errors) > 0) {
    cli::cli_abort(c(
      "x" = "Tool input validation failed for '{tool_name}':",
      set_names(errors, rep("*", length(errors)))
    ))
  }
  
  invisible(TRUE)
}

.validate_type_rlang <- function(value, type) {
  switch(type,
    string = rlang::is_string(value),
    character = rlang::is_character(value),
    number = rlang::is_double(value) || rlang::is_integer(value),
    integer = rlang::is_integer(value),
    logical = rlang::is_logical(value),
    list = rlang::is_list(value),
    any = TRUE,
    TRUE  # Unknown type = allow
  )
}
```

---

## Phase 2: Custom Tools System (3-4 hours)

**Goal:** Enable user-defined tools in .cassidy/tools/ and ~/.cassidy/tools/

### 2.1 Tool Discovery

**New file:** R/tools-discovery.R

```r
.discover_custom_tools <- function() {
  tool_dirs <- c(
    fs::path(getwd(), ".cassidy/tools"),
    fs::path_expand("~/.cassidy/tools")
  )
  
  tool_files <- unlist(lapply(tool_dirs, function(dir) {
    if (fs::dir_exists(dir)) {
      fs::dir_ls(dir, regexp = "\\.md$")
    }
  }))
  
  if (length(tool_files) == 0) return(list())
  
  tools <- lapply(tool_files, .parse_tool_file)
  names(tools) <- tools::file_path_sans_ext(basename(tool_files))
  tools <- Filter(Negate(is.null), tools)
  
  .check_custom_tool_conflicts(tools)
  
  tools
}

.parse_tool_file <- function(file_path) {
  tryCatch({
    lines <- readLines(file_path, warn = FALSE)
    metadata <- .parse_yaml_frontmatter(lines)
    handler <- .extract_handler_function(lines)
    
    list(
      name = metadata$name,
      title = metadata$title %||% metadata$name,
      description = metadata$description,
      group = metadata$group %||% "custom",
      risky = isTRUE(metadata$risky),
      hints = metadata$hints %||% list(),
      parameters = .parse_parameters(metadata$parameters),
      handler = handler,
      file_path = file_path,
      can_register = function() TRUE
    )
  }, error = function(e) {
    cli::cli_warn(c(
      "!" = "Failed to parse tool: {.file {file_path}}",
      "x" = e$message
    ))
    NULL
  })
}

.check_custom_tool_conflicts <- function(custom_tools) {
  builtin_names <- names(.cassidy_tools)
  custom_names <- names(custom_tools)
  
  conflicts <- intersect(custom_names, builtin_names)
  if (length(conflicts) > 0) {
    cli::cli_abort(c(
      "x" = "Custom tools conflict with built-in tools:",
      set_names(paste0("  - ", conflicts), rep("*", length(conflicts))),
      "i" = "Rename your custom tools to avoid conflicts"
    ))
  }
  
  invisible(TRUE)
}
```

### 2.2 User-Facing Functions

**New file:** R/tools-user.R

```r
#' Create a Custom Tool
#' @export
cassidy_create_tool <- function(
  name,
  location = c("project", "personal"),
  template = c("basic", "file_operation", "data_operation"),
  open = interactive()
) {
  # Validation, template generation, file creation
  # (Full implementation as in TOOL-ENHANCEMENT plan)
}

#' List Custom Tools
#' @export
cassidy_list_custom_tools <- function(location = c("all", "project", "personal")) {
  # Discovery and display
}

#' Validate a Custom Tool
#' @export
cassidy_validate_tool <- function(name) {
  # Validation logic
}

#' Refresh Tool Cache
#' @export
cassidy_refresh_tools <- function() {
  .get_all_tools(refresh = TRUE)
  cli::cli_alert_success("Tool cache refreshed")
  invisible(NULL)
}
```

### 2.3 Tool Caching

**File:** R/agentic-tools.R

```r
.tool_cache <- new.env(parent = emptyenv())
.tool_cache$all_tools <- NULL
.tool_cache$timestamp <- NULL

.get_all_tools <- function(refresh = FALSE) {
  if (!refresh && !is.null(.tool_cache$all_tools)) {
    return(.tool_cache$all_tools)
  }
  
  custom_tools <- .discover_custom_tools()
  all_tools <- c(.cassidy_tools, custom_tools)
  
  .tool_cache$all_tools <- all_tools
  .tool_cache$timestamp <- Sys.time()
  
  all_tools
}
```

---

## Phase 3: Tool Grouping & Discovery (1-2 hours)

**Goal:** Add semantic organization and discovery functions

**File:** R/agentic-helpers.R (expand existing)

```r
#' List Tool Groups
#' @export
cassidy_tool_groups <- function() {
  all_tools <- .get_all_tools()
  groups <- sapply(all_tools, function(t) {
    .get_tool_field(t, "group", "ungrouped")
  })
  group_counts <- table(groups)
  
  cli::cli_h2("Tool Groups ({length(group_counts)})")
  for (group_name in names(group_counts)) {
    cli::cli_alert_info("{.field {group_name}}: {group_counts[[group_name]]} tool{?s}")
  }
  
  invisible(names(group_counts))
}

#' Get Tools in a Group
#' @export
cassidy_tools_in_group <- function(group) {
  all_tools <- .get_all_tools()
  names(Filter(function(t) {
    .get_tool_field(t, "group", "ungrouped") == group
  }, all_tools))
}

#' Get Detailed Tool Information
#' @export
cassidy_tool_info <- function(tool_name) {
  tool <- .get_tool_definition(tool_name)
  # Display comprehensive info with cli
}

#' Get Available Tools
#' @export
cassidy_available_tools <- function() {
  all_tools <- .get_all_tools()
  names(Filter(function(t) {
    can_register <- .get_tool_field(t, "can_register", function() TRUE)
    tryCatch(can_register(), error = function(e) FALSE)
  }, all_tools))
}
```

Update cassidy_list_tools() to show groups.

---

## Phase 4: Tool Calling in Chat (3-4 hours)

**Goal:** Enable cassidy_chat() to use tools interactively

### 4.1 Enhanced cassidy_chat()

**File:** R/chat-core.R

```r
cassidy_chat <- function(
  message,
  assistant_id = Sys.getenv("CASSIDY_ASSISTANT_ID"),
  thread_id = NULL,
  context = NULL,
  api_key = Sys.getenv("CASSIDY_API_KEY"),
  timeout = 120,
  tools = NULL,              # NEW
  max_tool_iterations = 5,   # NEW (lower than agentic default)
  safe_mode = TRUE,          # NEW
  approval_callback = NULL,  # NEW
  verbose = FALSE            # NEW
) {
  # Existing validation...
  
  # NEW: Tool calling path
  if (!is.null(tools)) {
    return(.chat_with_tools(
      message = message,
      thread_id = thread_id,
      context = context,
      tools = tools,
      max_tool_iterations = max_tool_iterations,
      safe_mode = safe_mode,
      approval_callback = approval_callback,
      verbose = verbose,
      assistant_id = assistant_id,
      api_key = api_key,
      timeout = timeout
    ))
  }
  
  # Existing simple chat logic...
}
```

### 4.2 Tool Calling Loop

**New file:** R/chat-tools-loop.R

```r
.chat_with_tools <- function(
  message, thread_id, context, tools,
  max_tool_iterations, safe_mode, approval_callback, verbose,
  assistant_id, api_key, timeout
) {
  # Resolve tools (built-in + custom)
  available_tools <- .resolve_tools_list(tools)
  
  # Create thread if needed
  if (is.null(thread_id)) {
    thread_id <- cassidy_create_thread(assistant_id, api_key)
  }
  
  # Build tool-aware message
  initial_message <- .build_tool_aware_message(
    message = message,
    context = context,
    available_tools = available_tools
  )
  
  # Tool calling loop
  current_message <- initial_message
  iteration <- 0
  tool_calls_made <- list()
  
  repeat {
    if (iteration >= max_tool_iterations) {
      if (verbose) cli::cli_alert_warning("Max iterations reached")
      break
    }
    
    iteration <- iteration + 1
    if (verbose) cli::cli_alert_info("Iteration {iteration}/{max_tool_iterations}")
    
    # Send message
    response <- cassidy_send_message(
      thread_id = thread_id,
      message = current_message,
      api_key = api_key,
      timeout = timeout
    )
    
    # Parse for tools (reuse agentic system)
    decision <- .parse_tool_decision(
      response = response$content,
      available_tools = available_tools
    )
    
    # Done?
    if (decision$status == "final" || is.null(decision$action)) {
      return(structure(
        list(
          thread_id = thread_id,
          response = response,
          message = message,
          timestamp = Sys.time(),
          context_used = !is.null(context),
          tool_calls = tool_calls_made
        ),
        class = "cassidy_chat"
      ))
    }
    
    # Validate tool exists
    if (!decision$action %in% available_tools) {
      current_message <- paste0(
        "ERROR: Tool '", decision$action, "' not available.\n",
        "Available: ", paste(available_tools, collapse = ", ")
      )
      next
    }
    
    # Check approval for risky tools (reuse agentic system)
    if (safe_mode && .is_risky_tool(decision$action)) {
      approval <- .request_approval(
        action = decision$action,
        input = decision$input,
        reasoning = decision$reasoning,
        callback = approval_callback
      )
      
      if (!approval$approved) {
        current_message <- "DENIED: User rejected action. Try different approach."
        next
      }
      
      decision$input <- approval$input
    }
    
    # Execute tool (reuse agentic system)
    if (verbose) cli::cli_alert_info("Executing: {decision$action}")
    
    result <- .execute_tool(
      tool_name = decision$action,
      input = decision$input,
      working_dir = getwd()
    )
    
    # Record call
    tool_calls_made <- c(tool_calls_made, list(list(
      iteration = iteration,
      action = decision$action,
      input = decision$input,
      result = if (result$success) result$result else result$error,
      success = result$success
    )))
    
    # Format result for next message
    if (result$success) {
      if (verbose) cli::cli_alert_success("Tool executed successfully")
      current_message <- paste0(
        "RESULT (", decision$action, "):\n",
        if (is.character(result$result)) result$result
        else paste(capture.output(print(result$result)), collapse = "\n")
      )
    } else {
      if (verbose) cli::cli_alert_danger("Tool failed: {result$error}")
      current_message <- paste0(
        "ERROR (", decision$action, "):\n",
        result$error, "\n\nTry different approach."
      )
    }
  }
  
  # Max iterations reached
  structure(
    list(
      thread_id = thread_id,
      response = response,
      message = message,
      timestamp = Sys.time(),
      context_used = !is.null(context),
      tool_calls = tool_calls_made,
      incomplete = TRUE
    ),
    class = "cassidy_chat"
  )
}

.resolve_tools_list <- function(tools) {
  if (is.null(tools)) return(character(0))
  if (identical(tools, "auto")) return(names(.get_all_tools()))
  if (is.character(tools)) {
    all_tools <- .get_all_tools()
    invalid <- setdiff(tools, names(all_tools))
    if (length(invalid) > 0) {
      cli::cli_abort(c(
        "Unknown tools: {.val {invalid}}",
        "i" = "Available: {.val {names(all_tools)}}"
      ))
    }
    return(tools)
  }
  cli::cli_abort("tools must be NULL, 'auto', or character vector")
}

.build_tool_aware_message <- function(message, context, available_tools) {
  # Build tool documentation from enhanced metadata
  all_tool_defs <- .get_all_tools()
  
  tools_doc <- sapply(available_tools, function(tool_name) {
    tool <- all_tool_defs[[tool_name]]
    if (is.null(tool)) return(paste0("  - ", tool_name))
    
    # Get parameters
    if (!is.null(tool$parameters) && length(tool$parameters) > 0) {
      param_names <- names(tool$parameters)
      param_str <- paste0("(", paste(param_names, collapse = ", "), ")")
    } else {
      params <- names(formals(tool$handler))
      params <- setdiff(params, "working_dir")
      param_str <- if (length(params) > 0) {
        paste0("(", paste(params, collapse = ", "), ")")
      } else "()"
    }
    
    # Add hints
    hints <- .get_tool_field(tool, "hints", list())
    hint_str <- ""
    if (isTRUE(hints$read_only)) hint_str <- paste0(hint_str, " [read-only]")
    if (isTRUE(hints$idempotent)) hint_str <- paste0(hint_str, " [idempotent]")
    
    paste0("  - ", tool_name, param_str, ": ", tool$description, hint_str)
  })
  
  tools_list <- paste(tools_doc, collapse = "\n")
  
  tool_instructions <- paste0(
    "# Available Tools\n\n",
    "You can use these tools:\n\n",
    tools_list, "\n\n",
    "## Tool Format\n\n",
    "To use a tool:\n\n",
    "<TOOL_DECISION>\n",
    "ACTION: tool_name\n",
    "INPUT: {\"param\": \"value\"}\n",
    "REASONING: Why using this tool\n",
    "STATUS: continue\n",
    "</TOOL_DECISION>\n\n",
    "When done:\n\n",
    "TASK COMPLETE: [your answer]\n\n",
    "---\n\n"
  )
  
  paste0(
    tool_instructions,
    if (!is.null(context)) paste0("# Context\n\n", context$text, "\n\n---\n\n"),
    "# User Question\n\n",
    message
  )
}
```

### 4.3 Update Print Method

**File:** R/cassidy-classes.R

Update print.cassidy_chat() to show tool calls:

```r
#' @export
print.cassidy_chat <- function(x, ...) {
  cli::cli_h2("Cassidy Chat Response")
  cli::cli_alert_info("Thread ID: {x$thread_id}")
  cli::cli_alert_info("Timestamp: {x$timestamp}")
  
  if (!is.null(x$tool_calls) && length(x$tool_calls) > 0) {
    cli::cli_alert_info("Tool calls: {length(x$tool_calls)}")
    for (i in seq_along(x$tool_calls)) {
      call <- x$tool_calls[[i]]
      status <- if (call$success) "\u2713" else "\u2717"
      cli::cli_text("  {i}. {call$action} {status}")
    }
  }
  
  if (isTRUE(x$incomplete)) {
    cli::cli_alert_warning("Incomplete (max iterations reached)")
  }
  
  cat("\n")
  cat(x$response$content, "\n")
  
  invisible(x)
}
```

---

## Phase 5: Create Skill Tool (2 hours)

**Goal:** Add create_skill tool for interactive skill creation via chat

**File:** R/agentic-tools.R

Add to .cassidy_tools list:

```r
create_skill = list(
  name = "create_skill",
  title = "Create Skill",
  description = "Create a new skill file with metadata",
  group = "custom",
  risky = TRUE,  # Writes files
  hints = list(read_only = FALSE, idempotent = FALSE),
  parameters = list(
    name = list(
      type = "string",
      description = "Skill filename in kebab-case",
      required = TRUE
    ),
    title = list(
      type = "string",
      description = "Display title",
      required = TRUE
    ),
    description = list(
      type = "string",
      description = "Brief description",
      required = TRUE
    ),
    auto_invoke = list(
      type = "logical",
      description = "Can be auto-invoked",
      required = FALSE,
      default = "TRUE"
    ),
    requires = list(
      type = "character",
      description = "Skill dependencies",
      required = FALSE
    ),
    content = list(
      type = "string",
      description = "Full markdown content",
      required = TRUE
    ),
    location = list(
      type = "string",
      description = "Where to save: 'project' or 'personal'",
      required = FALSE,
      default = "project"
    )
  ),
  handler = function(name, title, description, auto_invoke = TRUE,
                    requires = character(0), content, location = "project") {
    # Validate name
    if (!grepl("^[a-z0-9-]+$", name)) {
      stop("Skill name must be kebab-case")
    }
    
    # Build frontmatter (uses existing format from skills system)
    frontmatter <- c(
      paste0("**Name:** ", title),
      paste0("**Description:** ", description),
      paste0("**Auto-invoke:** ", if (auto_invoke) "Yes" else "No")
    )
    
    if (length(requires) > 0) {
      frontmatter <- c(
        frontmatter,
        paste0("**Requires:** ", paste(requires, collapse = ", "))
      )
    }
    
    full_content <- c(frontmatter, "", content)
    
    # Determine location
    skill_dir <- if (location == "project") {
      file.path(getwd(), ".cassidy/skills")
    } else {
      path.expand("~/.cassidy/skills")
    }
    
    if (!dir.exists(skill_dir)) {
      dir.create(skill_dir, recursive = TRUE, showWarnings = FALSE)
    }
    
    skill_file <- file.path(skill_dir, paste0(name, ".md"))
    
    if (file.exists(skill_file)) {
      stop(paste0("Skill already exists: ", skill_file))
    }
    
    writeLines(full_content, skill_file)
    
    paste0(
      "Created skill: ", skill_file, "\n\n",
      "Next steps:\n",
      "- Test: cassidy_use_skill('", name, "')\n",
      "- Use in tasks: cassidy_use_skill('", name, "', task = 'your task')"
    )
  },
  can_register = function() TRUE
)
```

---

## Phase 6: Update Agentic System (1 hour)

**Goal:** Ensure agentic system uses enhanced tools

**File:** R/agentic-chat.R

```r
cassidy_agentic_task <- function(
  task,
  assistant_id = Sys.getenv("CASSIDY_ASSISTANT_ID"),
  api_key = Sys.getenv("CASSIDY_API_KEY"),
  tools = names(.get_all_tools()),  # CHANGED: Include custom tools
  working_dir = getwd(),
  max_iterations = 10,
  initial_context = NULL,
  safe_mode = TRUE,
  approval_callback = NULL,
  verbose = TRUE,
  dry_run = FALSE  # NEW
) {
  # Validate tools (now includes custom)
  all_tools <- .get_all_tools()
  invalid <- setdiff(tools, names(all_tools))
  if (length(invalid) > 0) {
    cli::cli_abort(c(
      "x" = "Unknown tools: {.field {invalid}}",
      "i" = "Available: {.field {names(all_tools)}}"
    ))
  }
  
  # Dry run mode
  if (dry_run) {
    cli::cli_alert_success("Dry run: Validations passed")
    cli::cli_text("Task: {.emph {task}}")
    cli::cli_text("Tools: {.field {tools}}")
    return(structure(
      list(task = task, tools = tools, validated = TRUE, dry_run = TRUE),
      class = "cassidy_agentic_dry_run"
    ))
  }
  
  # Rest of existing implementation...
}
```

Update .build_agentic_prompt() to use enhanced metadata (same as chat).

---

## Phase 7: Testing (2-3 hours)

### Test Files

**Enhanced tools:**
- tests/testthat/test-tools-enhanced.R - Metadata, validation
- tests/testthat/test-tools-custom.R - Custom tool discovery
- tests/testthat/test-tools-grouping.R - Grouping functions

**Chat with tools:**
- tests/testthat/test-chat-tools.R - Tool calling in chat
- tests/manual/test-chat-tools-live.R - Live testing

---

## Phase 8: Documentation (2 hours)

1. Update roxygen2 docs for all new functions
2. Add vignette: vignettes/custom-tools.Rmd
3. Update README with tool system examples
4. Update NEWS.md
5. Update .claude/rules/ files

---

## Implementation Timeline

| Phase | Description               | Time  | Cumulative |
|-------|---------------------------|-------|------------|
| 1     | Enhanced tool foundation  | 3-4h  | 3-4h       |
| 2     | Custom tools system       | 3-4h  | 6-8h       |
| 3     | Tool grouping & discovery | 1-2h  | 7-10h      |
| 4     | Tool calling in chat      | 3-4h  | 10-14h     |
| 5     | Create skill tool         | 2h    | 12-16h     |
| 6     | Update agentic system     | 1h    | 13-17h     |
| 7     | Testing                   | 2-3h  | 15-20h     |
| 8     | Documentation             | 2h    | 17-22h     |

**Total: 17-22 hours**

---

## Key Benefits of Unified Approach

1. **Single Tool System** - Both agentic and chat use same infrastructure
2. **Custom Tools Everywhere** - User tools work in both contexts
3. **Consistent Experience** - Same validation, approval, execution patterns
4. **Backward Compatible** - Existing code works unchanged
5. **Progressive Enhancement** - Each phase adds value independently
6. **Shared Code** - Maximum reuse of parsing, execution, approval logic

---

## Success Criteria

- All existing tests pass
- Enhanced metadata on all built-in tools
- Custom tools discoverable from .cassidy/tools/
- Type validation with rlang works
- Tool grouping functions work
- cassidy_chat() can use tools when tools parameter set
- Tool calling loop respects max iterations
- Safe mode approval works in chat
- create_skill tool creates valid skills
- Agentic system uses enhanced tools
- All documentation complete
- devtools::check() passes