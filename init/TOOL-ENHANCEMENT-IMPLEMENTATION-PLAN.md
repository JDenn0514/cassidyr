# Enhanced Tool System Implementation Plan

## Context

The cassidyr package currently has a functional but basic agentic tool system with 7 built-in tools. The tool system uses a simple list-based registry (`.cassidy_tools`) with direct execution. While this works well, it lacks:

1. **Rich metadata** - Tools only have description and risky flag
2. **Type validation** - No parameter type checking or validation
3. **Tool grouping** - No semantic organization (only presets)
4. **Extensibility** - No way for users to create custom tools
5. **Conditional availability** - Tools are always available regardless of context

This enhancement adds these capabilities while maintaining the simplicity and self-contained nature of cassidyr (no ellmer dependency needed). The goal is to make the tool system more robust, discoverable, and user-extensible while keeping it accessible.

**Comparison with btw:** The btw package uses a more sophisticated system with ellmer integration for multi-provider support. However, cassidyr is CassidyAI-specific and benefits from staying self-contained. We'll adopt btw's better patterns (metadata, validation, grouping) while maintaining cassidyr's simplicity.

## Design Decisions

### ✅ YAML Frontmatter
Use YAML frontmatter for tool metadata (not markdown bold fields). This allows precise parsing and is consistent with many R packages.

### ✅ Function Extraction Markers
Support both automatic extraction AND explicit markers:
- Automatic: Parse entire ```r code block
- Explicit: Look for `# TOOL BEGINS HERE` and `# TOOL ENDS HERE` comments

This gives users flexibility for complex tools.

### ✅ Type Validation with rlang
Use `rlang::is_string()`, `rlang::is_scalar_character()`, etc. for type checking. This is consistent with tidyverse patterns and more robust than base R type checking.

### ✅ Tool Name Conflicts
**Error immediately** when a custom tool name conflicts with:
1. Built-in tools (e.g., user tries to name their tool "read_file")
2. Other custom tools (duplicate names in .cassidy/tools/)

Provide clear error message with suggestion to rename.

### ✅ Tool Caching
Implement simple caching with `refresh` parameter. Consider cassidy_app() integration for future agentic capabilities in the Shiny interface.

### ✅ Security Warning
Add prominent documentation warning that custom tools execute arbitrary R code. Only use tools from trusted sources.

### ✅ Full Working Examples
All three templates (basic, file_operation, data_operation) include complete, runnable examples with error handling and best practices.

### ✅ Use fs Package
All file operations in examples and built-in tools should use `fs::` functions (fs::file_exists, fs::dir_ls, fs::path, etc.)

### ✅ Dry Run Mode
Add `dry_run = TRUE` parameter to `cassidy_agentic_task()` for validation without execution.

## Design Approach

### Phase 1: Enhanced Metadata (Backward Compatible)

Expand the tool definition structure without breaking existing code:

```r
.cassidy_tools <- list(
  read_file = list(
    # Core fields (existing)
    name = "read_file",
    description = "Read contents of a file",
    handler = function(filepath, working_dir = getwd()) { ... },

    # New metadata fields (Phase 1)
    title = "Read File",              # Short display name
    group = "files",                  # Semantic grouping
    risky = FALSE,                    # Existing field
    hints = list(                     # LLM hints for better decisions
      read_only = TRUE,
      idempotent = TRUE,
      open_world = FALSE
    ),

    # Enhanced parameter definitions (Phase 1)
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

    # Conditional availability (Phase 2)
    can_register = function() TRUE    # Always available
  )
)
```

**Backward Compatibility:** All new fields are optional. Existing tools continue working with just `description`, `handler`, and `risky`.

### Phase 2: User Custom Tools

Follow the **skills system pattern** for discovering and loading user-defined tools:

**Tool Discovery Locations:**
- Project-level: `.cassidy/tools/` (shared with team via git)
- Personal-level: `~/.cassidy/tools/` (user-specific, gitignored)

**Tool File Format** (YAML frontmatter + markdown):

```yaml
---
name: custom-reader
title: Custom File Reader
description: Read files with custom encoding and preprocessing
group: files
risky: false
hints:
  read_only: true
  idempotent: true
parameters:
  - name: filepath
    type: string
    required: true
    description: Path to the file to read
  - name: encoding
    type: string
    required: false
    default: "UTF-8"
    description: File encoding
  - name: preprocess
    type: logical
    required: false
    default: false
    description: Apply preprocessing
---

# Custom File Reader

This tool reads files with custom encoding support and optional preprocessing.

## Implementation Details

The handler function:
1. Validates file exists using `fs::file_exists()`
2. Reads file with specified encoding
3. Optionally applies preprocessing
4. Returns cleaned text

## Handler Function

You can use explicit markers for complex functions:

```r
function(filepath, encoding = "UTF-8", preprocess = FALSE) {
  # TOOL BEGINS HERE

  # Validate path
  if (!fs::file_exists(filepath)) {
    cli::cli_abort("File not found: {.file {filepath}}")
  }

  # Read file
  content <- tryCatch({
    readLines(filepath, encoding = encoding, warn = FALSE)
  }, error = function(e) {
    cli::cli_abort("Failed to read file: {e$message}")
  })

  # Optional preprocessing
  if (preprocess) {
    content <- trimws(content)
    content <- content[nzchar(content)]
  }

  # Return as single string
  paste(content, collapse = "\n")

  # TOOL ENDS HERE
}
```

## Testing

Test this tool with:
```r
cassidy_agentic_task(
  "Read README.md using custom-reader",
  tools = c("custom-reader"),
  max_iterations = 2
)
```
```

**Discovery Process:**
1. Scan `.cassidy/tools/*.md` and `~/.cassidy/tools/*.md`
2. Parse YAML frontmatter
3. Extract handler function (look for markers first, then full code block)
4. **Check for name conflicts** with built-in tools and other custom tools
5. Validate and register tools
6. Merge with built-in tools

### Phase 3: Validation & Type Checking

Add runtime parameter validation using rlang type checkers:

```r
.validate_tool_input <- function(tool_name, input) {
  tool <- .get_tool_definition(tool_name)  # Handles built-in + custom

  errors <- character()

  # Skip if no parameters defined (backward compat)
  if (is.null(tool$parameters) || !is.list(tool$parameters)) {
    return(invisible(TRUE))
  }

  for (param_name in names(tool$parameters)) {
    param <- tool$parameters[[param_name]]

    # Check required parameters
    if (isTRUE(param$required) && !param_name %in% names(input)) {
      errors <- c(errors, paste("Missing required parameter:", param_name))
    }

    # Type validation using rlang
    if (param_name %in% names(input)) {
      value <- input[[param_name]]
      expected_type <- param$type

      if (!.validate_type_rlang(value, expected_type)) {
        errors <- c(errors, paste0(
          "Parameter '", param_name, "' should be ", expected_type,
          " but got ", typeof(value)
        ))
      }
    }
  }

  if (length(errors) > 0) {
    cli::cli_abort(c(
      "x" = "Tool input validation failed:",
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
    TRUE  # Unknown type, allow it
  )
}
```

**Supported Types:**
- `string` - Single character value (rlang::is_string)
- `character` - Character vector (rlang::is_character)
- `number` - Numeric value (double or integer)
- `integer` - Integer value
- `logical` - Boolean value
- `list` - List object
- `any` - Accept anything

### Phase 4: Tool Grouping & Discovery

Add semantic grouping for better organization:

**Groups:**
- `files` - File operations (read, write, list, search)
- `data` - Data frame operations (describe)
- `code` - Code execution
- `context` - Context gathering
- `custom` - User-defined tools (if not in another group)

**New Functions:**
```r
cassidy_tool_groups()                    # List all available groups
cassidy_tools_in_group("files")          # Get tools by group
cassidy_tool_info("read_file")           # Get detailed tool metadata
cassidy_available_tools()                # Only tools that pass can_register()
```

**Enhanced Tool Selection:**
```r
# By group
cassidy_agentic_task("task", tools = cassidy_tools_in_group("files"))

# By availability
cassidy_agentic_task("task", tools = cassidy_available_tools())

# By preset (existing, still works)
cassidy_agentic_task("task", tools = cassidy_tool_preset("read_only"))

# Dry run (validation only)
cassidy_agentic_task("task", tools = "all", dry_run = TRUE)
```

## Implementation Steps

### Step 1: Enhance Tool Registry Structure

**File:** `R/agentic-tools.R`

1. Update `.cassidy_tools` list with enhanced metadata for all built-in tools
2. Add backward compatibility helpers (`.get_tool_field()` with defaults)
3. Keep existing handler functions unchanged
4. Add new helper: `.get_tool_definition()` (merges built-in + custom)
5. **Update all built-in tools to use `fs::` package for file operations**

**New internal functions:**
- `.get_tool_field(tool, field, default)` - Safe field access
- `.get_tool_definition(tool_name)` - Get tool from any source
- `.validate_type_rlang(value, type)` - Type checking with rlang
- `.check_tool_name_conflict(name, built_in_names)` - Error on conflicts

### Step 2: User Tool Discovery System

**New file:** `R/tools-discovery.R`

Follow skills system pattern with name conflict checking:

```r
.discover_custom_tools <- function() {
  tool_dirs <- c(
    fs::path(getwd(), ".cassidy/tools"),    # Project
    fs::path_expand("~/.cassidy/tools")     # Personal
  )

  tool_files <- unlist(lapply(tool_dirs, function(dir) {
    if (fs::dir_exists(dir)) {
      fs::dir_ls(dir, regexp = "\\.md$")
    }
  }))

  if (length(tool_files) == 0) {
    return(list())
  }

  # Parse all tools
  tools <- lapply(tool_files, .parse_tool_file)
  names(tools) <- tools::file_path_sans_ext(basename(tool_files))

  # Remove NULL entries (failed parsing)
  tools <- Filter(Negate(is.null), tools)

  # Check for conflicts with built-in tools
  .check_custom_tool_conflicts(tools)

  tools
}

.check_custom_tool_conflicts <- function(custom_tools) {
  builtin_names <- names(.cassidy_tools)
  custom_names <- names(custom_tools)

  # Check conflicts with built-in tools
  conflicts_builtin <- intersect(custom_names, builtin_names)
  if (length(conflicts_builtin) > 0) {
    cli::cli_abort(c(
      "x" = "Custom tool names conflict with built-in tools:",
      set_names(paste0("  - ", conflicts_builtin), rep("*", length(conflicts_builtin))),
      "i" = "Rename your custom tools to avoid conflicts with built-in tool names",
      "i" = "Built-in tools: {.field {builtin_names}}"
    ))
  }

  # Check for duplicate custom tool names
  if (length(custom_names) != length(unique(custom_names))) {
    duplicates <- custom_names[duplicated(custom_names)]
    cli::cli_abort(c(
      "x" = "Duplicate custom tool names found:",
      set_names(paste0("  - ", unique(duplicates)), rep("*", length(unique(duplicates)))),
      "i" = "Each custom tool must have a unique name"
    ))
  }

  invisible(TRUE)
}

.parse_tool_file <- function(file_path) {
  tryCatch({
    # Read file
    lines <- readLines(file_path, warn = FALSE)

    # Parse YAML frontmatter
    metadata <- .parse_yaml_frontmatter(lines)

    # Extract handler function
    handler <- .extract_handler_function(lines)

    # Build tool definition
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
      "!" = "Failed to parse tool file: {.file {file_path}}",
      "x" = e$message
    ))
    NULL
  })
}

.parse_yaml_frontmatter <- function(lines) {
  # Find YAML frontmatter (between --- markers)
  yaml_start <- which(lines == "---")[1]
  yaml_end <- which(lines == "---")[2]

  if (is.na(yaml_start) || is.na(yaml_end) || yaml_start >= yaml_end) {
    stop("No valid YAML frontmatter found")
  }

  yaml_lines <- lines[(yaml_start + 1):(yaml_end - 1)]
  yaml_text <- paste(yaml_lines, collapse = "\n")

  # Parse YAML (using yaml package if available, else simple parsing)
  if (rlang::is_installed("yaml")) {
    yaml::yaml.load(yaml_text)
  } else {
    .parse_yaml_simple(yaml_lines)
  }
}

.parse_yaml_simple <- function(yaml_lines) {
  # Simple YAML parser for basic key: value pairs
  # This is a fallback if yaml package not available
  result <- list()

  for (line in yaml_lines) {
    if (grepl("^\\s*[a-zA-Z_]+:", line)) {
      parts <- strsplit(line, ":", fixed = TRUE)[[1]]
      key <- trimws(parts[1])
      value <- trimws(paste(parts[-1], collapse = ":"))

      # Convert "true"/"false" to logical
      if (tolower(value) == "true") value <- TRUE
      else if (tolower(value) == "false") value <- FALSE

      result[[key]] <- value
    }
  }

  result
}

.extract_handler_function <- function(lines) {
  # Strategy 1: Look for explicit markers
  begin_marker <- which(grepl("# TOOL BEGINS HERE", lines, fixed = TRUE))
  end_marker <- which(grepl("# TOOL ENDS HERE", lines, fixed = TRUE))

  if (length(begin_marker) > 0 && length(end_marker) > 0) {
    code_lines <- lines[(begin_marker[1] + 1):(end_marker[1] - 1)]
    code_text <- paste(code_lines, collapse = "\n")
  } else {
    # Strategy 2: Extract from ```r code block
    code_start <- which(grepl("^```r\\s*$", lines))
    code_end <- which(grepl("^```\\s*$", lines))

    if (length(code_start) == 0 || length(code_end) == 0) {
      stop("No R code block found (use ```r or # TOOL BEGINS HERE markers)")
    }

    # Find matching end for first start
    code_end <- code_end[code_end > code_start[1]][1]

    if (is.na(code_end)) {
      stop("Unclosed R code block")
    }

    code_lines <- lines[(code_start[1] + 1):(code_end - 1)]
    code_text <- paste(code_lines, collapse = "\n")
  }

  # Parse and evaluate
  tryCatch({
    parsed <- parse(text = code_text)
    handler <- eval(parsed)

    # Validate it's a function
    if (!is.function(handler)) {
      stop("Code block must define a function")
    }

    handler
  }, error = function(e) {
    stop("Failed to parse handler function: ", e$message)
  })
}

.parse_parameters <- function(params_yaml) {
  if (is.null(params_yaml) || !is.list(params_yaml)) {
    return(list())
  }

  # Convert YAML parameter list to tool parameter format
  result <- list()

  for (param in params_yaml) {
    if (is.list(param) && !is.null(param$name)) {
      result[[param$name]] <- list(
        type = param$type %||% "any",
        description = param$description %||% "",
        required = isTRUE(param$required),
        default = param$default
      )
    }
  }

  result
}
```

**New file:** `R/tools-user.R`

User-facing functions for custom tools:

```r
#' List Custom Tools
#'
#' Display custom tools from project and/or personal tool directories.
#'
#' @param location Character. "all" (default), "project", or "personal"
#' @return Invisibly returns character vector of custom tool names
#' @export
#' @family tool-management
#' @examples
#' \dontrun{
#' cassidy_list_custom_tools()
#' cassidy_list_custom_tools(location = "project")
#' }
cassidy_list_custom_tools <- function(location = c("all", "project", "personal")) {
  location <- match.arg(location)

  all_tools <- .discover_custom_tools()

  # Filter by location
  if (location != "all") {
    base_path <- if (location == "project") {
      fs::path(getwd(), ".cassidy/tools")
    } else {
      fs::path_expand("~/.cassidy/tools")
    }

    all_tools <- Filter(function(t) {
      startsWith(t$file_path, base_path)
    }, all_tools)
  }

  if (length(all_tools) == 0) {
    cli::cli_alert_info("No custom tools found")
    return(invisible(character(0)))
  }

  # Display tools
  cli::cli_h2("Custom Tools ({length(all_tools)})")
  for (name in names(all_tools)) {
    tool <- all_tools[[name]]
    loc_label <- if (grepl(fs::path_expand("~/.cassidy"), tool$file_path)) {
      "[personal]"
    } else {
      "[project]"
    }

    cli::cli_alert_info("{.field {name}} {loc_label}: {tool$description}")
  }

  invisible(names(all_tools))
}

#' Create a Custom Tool
#'
#' Generate a new custom tool from a template.
#'
#' @param name Character. Tool name (lowercase, hyphens only)
#' @param location Character. "project" (.cassidy/tools/) or "personal" (~/.cassidy/tools/)
#' @param template Character. Template: "basic", "file_operation", "data_operation"
#' @param open Logical. Open file in editor after creation?
#' @return File path (invisibly)
#' @export
#' @family tool-management
#' @examples
#' \dontrun{
#' cassidy_create_tool("my-reader", location = "project")
#' cassidy_create_tool("my-helper", location = "personal", template = "basic")
#' }
cassidy_create_tool <- function(
  name,
  location = c("project", "personal"),
  template = c("basic", "file_operation", "data_operation"),
  open = interactive()
) {
  location <- match.arg(location)
  template <- match.arg(template)

  # Validate name
  if (!grepl("^[a-z0-9-]+$", name)) {
    cli::cli_abort(c(
      "x" = "Invalid tool name: {.val {name}}",
      "i" = "Tool names must be lowercase with hyphens only (e.g., 'my-tool')"
    ))
  }

  # Check for conflicts with built-in tools
  builtin_names <- names(.cassidy_tools)
  if (name %in% builtin_names) {
    cli::cli_abort(c(
      "x" = "Tool name conflicts with built-in tool: {.field {name}}",
      "i" = "Built-in tools: {.field {builtin_names}}",
      "i" = "Choose a different name for your custom tool"
    ))
  }

  # Determine directory
  tool_dir <- if (location == "project") {
    fs::path(getwd(), ".cassidy/tools")
  } else {
    fs::path_expand("~/.cassidy/tools")
  }

  # Create directory if needed
  if (!fs::dir_exists(tool_dir)) {
    fs::dir_create(tool_dir, recurse = TRUE)
  }

  # Create file path
  tool_file <- fs::path(tool_dir, paste0(name, ".md"))

  if (fs::file_exists(tool_file)) {
    cli::cli_abort(c(
      "x" = "Tool already exists: {.path {tool_file}}",
      "i" = "Choose a different name or edit the existing tool"
    ))
  }

  # Get template content
  tool_content <- .get_tool_template(name, template)

  # Write file
  writeLines(tool_content, tool_file)

  cli::cli_alert_success("Created tool: {.path {tool_file}}")
  cli::cli_text("")
  cli::cli_text("Next steps:")
  cli::cli_ol(c(
    "Edit the tool file to customize behavior",
    "Test with: {.run cassidy_agentic_task('task', tools = c('{name}'))}",
    "Validate with: {.run cassidy_validate_tool('{name}')}"
  ))

  # Open in editor
  if (open && rlang::is_interactive()) {
    if (rlang::is_installed("rstudioapi") && rstudioapi::isAvailable()) {
      rstudioapi::navigateToFile(tool_file)
    } else {
      utils::file.edit(tool_file)
    }
  }

  invisible(tool_file)
}

#' Validate a Custom Tool
#'
#' Check if a custom tool definition is valid and can be loaded.
#'
#' @param name Character. Tool name to validate
#' @return Invisibly returns TRUE if valid
#' @export
#' @family tool-management
#' @examples
#' \dontrun{
#' cassidy_validate_tool("my-reader")
#' }
cassidy_validate_tool <- function(name) {
  # Try to discover and load the tool
  all_tools <- tryCatch({
    .discover_custom_tools()
  }, error = function(e) {
    cli::cli_abort(c(
      "x" = "Failed to discover custom tools",
      "i" = e$message
    ))
  })

  if (!name %in% names(all_tools)) {
    cli::cli_abort(c(
      "x" = "Tool not found: {.field {name}}",
      "i" = "Available custom tools: {.field {names(all_tools)}}"
    ))
  }

  tool <- all_tools[[name]]

  # Validate components
  cli::cli_alert_success("Tool name: {.field {tool$name}}")
  cli::cli_alert_success("Description: {.emph {tool$description}}")
  cli::cli_alert_success("Group: {.field {tool$group}}")
  cli::cli_alert_success("Risky: {.val {tool$risky}}")

  if (length(tool$parameters) > 0) {
    cli::cli_alert_success("Parameters ({length(tool$parameters)}):")
    for (param_name in names(tool$parameters)) {
      param <- tool$parameters[[param_name]]
      req_label <- if (param$required) "required" else "optional"
      cli::cli_text("  - {.field {param_name}} ({param$type}, {req_label})")
    }
  }

  cli::cli_alert_success("Handler function is valid")

  cli::cli_text("")
  cli::cli_alert_success("Tool is valid and ready to use!")

  invisible(TRUE)
}

#' Validate a Tool File
#'
#' Check if a tool file is valid before moving it to the tools directory.
#'
#' @param filepath Character. Path to tool .md file
#' @return Invisibly returns TRUE if valid
#' @export
#' @family tool-management
#' @examples
#' \dontrun{
#' cassidy_validate_tool_file("my-tool.md")
#' }
cassidy_validate_tool_file <- function(filepath) {
  if (!fs::file_exists(filepath)) {
    cli::cli_abort("File not found: {.file {filepath}}")
  }

  # Try to parse the tool file
  tool <- tryCatch({
    .parse_tool_file(filepath)
  }, error = function(e) {
    cli::cli_abort(c(
      "x" = "Failed to parse tool file",
      "i" = e$message
    ))
  })

  if (is.null(tool)) {
    cli::cli_abort("Tool parsing returned NULL")
  }

  # Validate components (same as cassidy_validate_tool)
  cli::cli_alert_success("Tool name: {.field {tool$name}}")
  cli::cli_alert_success("Description: {.emph {tool$description}}")
  cli::cli_alert_success("Handler function is valid")

  cli::cli_text("")
  cli::cli_alert_success("Tool file is valid!")

  invisible(TRUE)
}
```

### Step 3: Tool Caching System

**File:** `R/agentic-tools.R` (add to existing)

```r
# Tool cache (package environment)
.tool_cache <- new.env(parent = emptyenv())
.tool_cache$all_tools <- NULL
.tool_cache$timestamp <- NULL

#' Get All Tools (Built-in + Custom)
#'
#' Returns merged list of built-in and custom tools with caching.
#'
#' @param refresh Logical. Force refresh of custom tools?
#' @return Named list of tool definitions
#' @keywords internal
#' @noRd
.get_all_tools <- function(refresh = FALSE) {
  # Check if cache is valid
  if (!refresh && !is.null(.tool_cache$all_tools)) {
    return(.tool_cache$all_tools)
  }

  # Discover custom tools
  custom_tools <- .discover_custom_tools()

  # Merge with built-in tools
  all_tools <- c(.cassidy_tools, custom_tools)

  # Update cache
  .tool_cache$all_tools <- all_tools
  .tool_cache$timestamp <- Sys.time()

  all_tools
}

#' Refresh Tool Cache
#'
#' Force re-discovery of custom tools. Call this after creating or modifying
#' custom tool files.
#'
#' @return Invisibly returns NULL
#' @export
#' @family tool-management
#' @examples
#' \dontrun{
#' # After creating a new tool
#' cassidy_create_tool("my-tool")
#' cassidy_refresh_tools()
#'
#' # Now it's available
#' cassidy_list_tools()
#' }
cassidy_refresh_tools <- function() {
  .get_all_tools(refresh = TRUE)
  cli::cli_alert_success("Tool cache refreshed")
  invisible(NULL)
}
```

**Note for cassidy_app() integration:** When adding agentic capabilities to the Shiny app, consider:
1. Refresh tools on app launch
2. Add "Refresh Tools" button in UI
3. Show available tools in sidebar
4. Allow tool selection for agentic tasks

### Step 4: Input Validation System

**File:** `R/agentic-tools.R` (add to existing)

```r
.validate_tool_input <- function(tool_name, input) {
  tool <- .get_tool_definition(tool_name)

  # Skip validation if parameters not defined (backward compat)
  if (is.null(tool$parameters) || !is.list(tool$parameters)) {
    return(invisible(TRUE))
  }

  errors <- character()

  for (param_name in names(tool$parameters)) {
    param <- tool$parameters[[param_name]]

    # Check required parameters
    if (isTRUE(param$required) && !param_name %in% names(input)) {
      errors <- c(errors, paste("Missing required parameter:", param_name))
    }

    # Type validation
    if (param_name %in% names(input)) {
      value <- input[[param_name]]
      expected_type <- param$type

      if (!.validate_type_rlang(value, expected_type)) {
        errors <- c(errors, paste0(
          "Parameter '", param_name, "' should be ", expected_type,
          " but got ", typeof(value)
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
    TRUE  # Unknown type, allow it (forward compatibility)
  )
}
```

Update `.execute_tool()` to call validation:

```r
.execute_tool <- function(tool_name, input, working_dir = getwd()) {
  # 1. Validate tool exists
  all_tools <- .get_all_tools()
  if (!tool_name %in% names(all_tools)) {
    return(list(
      success = FALSE,
      error = paste("Unknown tool:", tool_name)
    ))
  }

  # 2. Validate input (NEW)
  validation_result <- tryCatch({
    .validate_tool_input(tool_name, input)
    NULL
  }, error = function(e) {
    e$message
  })

  if (!is.null(validation_result)) {
    return(list(
      success = FALSE,
      error = validation_result
    ))
  }

  # 3. Get tool definition (handles custom tools)
  tool <- all_tools[[tool_name]]

  # 4. Add working_dir if supported
  if ("working_dir" %in% names(tool$parameters)) {
    input$working_dir <- working_dir
  }

  # 5. Execute handler
  result <- tryCatch({
    do.call(tool$handler, input)
  }, error = function(e) {
    return(list(
      success = FALSE,
      error = e$message
    ))
  })

  # Handle error result
  if (is.list(result) && !is.null(result$success) && !result$success) {
    return(result)
  }

  # Success
  list(
    success = TRUE,
    result = result
  )
}
```

### Step 5: Tool Grouping & Discovery Functions

**File:** `R/agentic-helpers.R` (expand existing)

```r
#' List Tool Groups
#'
#' Display all available tool groups with tool counts.
#'
#' @return Character vector of group names (invisibly)
#' @export
#' @family tool-discovery
#' @examples
#' \dontrun{
#' cassidy_tool_groups()
#' }
cassidy_tool_groups <- function() {
  all_tools <- .get_all_tools()

  # Get groups
  groups <- sapply(all_tools, function(t) {
    .get_tool_field(t, "group", "ungrouped")
  })

  # Count tools per group
  group_counts <- table(groups)

  cli::cli_h2("Tool Groups ({length(group_counts)})")
  for (group_name in names(group_counts)) {
    count <- group_counts[[group_name]]
    cli::cli_alert_info("{.field {group_name}}: {count} tool{?s}")
  }

  invisible(names(group_counts))
}

#' Get Tools in a Group
#'
#' Return all tool names belonging to a specific group.
#'
#' @param group Character. Group name (e.g., "files", "data")
#' @return Character vector of tool names
#' @export
#' @family tool-discovery
#' @examples
#' \dontrun{
#' cassidy_tools_in_group("files")
#'
#' # Use in agentic task
#' cassidy_agentic_task(
#'   "List files",
#'   tools = cassidy_tools_in_group("files")
#' )
#' }
cassidy_tools_in_group <- function(group) {
  all_tools <- .get_all_tools()

  tool_names <- names(Filter(function(t) {
    .get_tool_field(t, "group", "ungrouped") == group
  }, all_tools))

  if (length(tool_names) == 0) {
    cli::cli_warn("No tools found in group: {.field {group}}")
  }

  tool_names
}

#' Get Detailed Tool Information
#'
#' Display comprehensive information about a specific tool including
#' metadata, parameters, and hints.
#'
#' @param tool_name Character. Name of the tool
#' @return Tool definition (invisibly)
#' @export
#' @family tool-discovery
#' @examples
#' \dontrun{
#' cassidy_tool_info("read_file")
#' }
cassidy_tool_info <- function(tool_name) {
  tool <- .get_tool_definition(tool_name)

  if (is.null(tool)) {
    cli::cli_abort("Tool not found: {.field {tool_name}}")
  }

  # Display comprehensive info
  cli::cli_rule(left = "Tool: {tool_name}")

  cli::cli_alert_info("Title: {.emph {.get_tool_field(tool, 'title', tool_name)}}")
  cli::cli_alert_info("Description: {.emph {tool$description}}")
  cli::cli_alert_info("Group: {.field {.get_tool_field(tool, 'group', 'ungrouped')}}")
  cli::cli_alert_info("Risky: {.val {tool$risky %||% FALSE}}")

  # Hints
  hints <- .get_tool_field(tool, "hints", list())
  if (length(hints) > 0) {
    cli::cli_h3("Hints")
    for (hint_name in names(hints)) {
      cli::cli_text("  {hint_name}: {.val {hints[[hint_name]]}}")
    }
  }

  # Parameters
  params <- tool$parameters
  if (!is.null(params) && length(params) > 0) {
    cli::cli_h3("Parameters")
    for (param_name in names(params)) {
      param <- params[[param_name]]
      req_label <- if (isTRUE(param$required)) "required" else "optional"
      default_label <- if (!is.null(param$default)) {
        paste0(" (default: ", param$default, ")")
      } else {
        ""
      }

      cli::cli_text("  {.field {param_name}} ({param$type}, {req_label}){default_label}")
      cli::cli_text("    {param$description}")
    }
  }

  cli::cli_rule()

  invisible(tool)
}

#' Get Available Tools
#'
#' Return tools that pass their `can_register()` check. This filters
#' tools that may be conditionally available based on system state.
#'
#' @return Character vector of available tool names
#' @export
#' @family tool-discovery
#' @examples
#' \dontrun{
#' cassidy_available_tools()
#' }
cassidy_available_tools <- function() {
  all_tools <- .get_all_tools()

  # Filter by can_register() function
  available <- Filter(function(t) {
    can_register <- .get_tool_field(t, "can_register", function() TRUE)
    tryCatch(can_register(), error = function(e) FALSE)
  }, all_tools)

  names(available)
}

# Helper function for safe field access
.get_tool_field <- function(tool, field, default = NULL) {
  if (is.null(tool[[field]])) {
    default
  } else {
    tool[[field]]
  }
}

.get_tool_definition <- function(tool_name) {
  all_tools <- .get_all_tools()
  all_tools[[tool_name]]
}
```

Update `cassidy_list_tools()` to show groups:

```r
cassidy_list_tools <- function() {
  all_tools <- .get_all_tools()

  cli::cli_h2("Available Tools ({length(all_tools)})")

  # Group tools
  by_group <- split(names(all_tools), sapply(all_tools, function(t) {
    .get_tool_field(t, "group", "ungrouped")
  }))

  # Display by group
  for (group_name in sort(names(by_group))) {
    cli::cli_h3(tools::toTitleCase(group_name))

    tool_names <- by_group[[group_name]]
    for (tool_name in tool_names) {
      tool <- all_tools[[tool_name]]
      risky <- tool$risky %||% FALSE

      if (risky) {
        cli::cli_alert_warning("{.field {tool_name}}: {tool$description}")
        cli::cli_text("  {cli::col_silver('Requires approval in safe mode')}")
      } else {
        cli::cli_alert_success("{.field {tool_name}}: {tool$description}")
      }
    }
    cli::cli_text("")
  }

  cli::cli_alert_info("Use {.run cassidy_tool_info('tool_name')} for details")
  cli::cli_alert_info("Use {.run cassidy_tools_in_group('group')} to filter by group")

  invisible(names(all_tools))
}
```

### Step 6: Update Agentic System

**File:** `R/agentic-chat.R`

Add dry_run mode and update to use custom tools:

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
  dry_run = FALSE  # NEW: Validation only mode
) {

  # Validate inputs
  if (!nzchar(task)) {
    cli::cli_abort("Task cannot be empty")
  }

  if (!nzchar(assistant_id) && !dry_run) {
    cli::cli_abort(c(
      "Assistant ID not found",
      "i" = "Set {.envvar CASSIDY_ASSISTANT_ID} in your {.file .Renviron}",
      "i" = "Run {.run cassidy_setup()} for guided setup"
    ))
  }

  # Validate tools exist (including custom)
  all_tools <- .get_all_tools()
  invalid_tools <- setdiff(tools, names(all_tools))

  if (length(invalid_tools) > 0) {
    cli::cli_abort(c(
      "x" = "Unknown tools specified: {.field {invalid_tools}}",
      "i" = "Available tools: {.field {names(all_tools)}}"
    ))
  }

  # Dry run: validate and return
  if (dry_run) {
    cli::cli_alert_success("Dry run: All validations passed")
    cli::cli_text("Task: {.emph {task}}")
    cli::cli_text("Tools: {.field {tools}}")
    cli::cli_text("Working dir: {.path {working_dir}}")

    return(structure(
      list(
        task = task,
        tools = tools,
        working_dir = working_dir,
        validated = TRUE,
        dry_run = TRUE
      ),
      class = "cassidy_agentic_dry_run"
    ))
  }

  # Rest of existing function unchanged...
}

#' Print method for dry run results
#' @export
print.cassidy_agentic_dry_run <- function(x, ...) {
  cli::cli_rule(left = "Agentic Task Dry Run")
  cli::cli_alert_success("Validation passed")
  cli::cli_text("Task: {.emph {x$task}}")
  cli::cli_text("Tools ({length(x$tools)}): {.field {x$tools}}")
  cli::cli_text("Working dir: {.path {x$working_dir}}")
  cli::cli_rule()
  invisible(x)
}
```

Update `.build_agentic_prompt()` to document custom tools and include hints:

```r
.build_agentic_prompt <- function(working_dir, max_iterations, available_tools) {
  # Get full tool definitions (built-in + custom)
  all_tool_defs <- .get_all_tools()

  # Build enhanced tool documentation
  tools_doc <- sapply(available_tools, function(tool_name) {
    tool <- all_tool_defs[[tool_name]]
    if (is.null(tool)) return(paste0("  - ", tool_name))

    # Get parameter names
    if (!is.null(tool$parameters) && length(tool$parameters) > 0) {
      param_names <- names(tool$parameters)
      param_str <- paste0("(", paste(param_names, collapse = ", "), ")")
    } else {
      params <- names(formals(tool$handler))
      params <- setdiff(params, "working_dir")
      param_str <- if (length(params) > 0) {
        paste0("(", paste(params, collapse = ", "), ")")
      } else {
        "()"
      }
    }

    # Add hints if available
    hints <- .get_tool_field(tool, "hints", list())
    hint_str <- ""
    if (isTRUE(hints$read_only)) hint_str <- paste0(hint_str, " [read-only]")
    if (isTRUE(hints$idempotent)) hint_str <- paste0(hint_str, " [idempotent]")

    paste0("  - ", tool_name, param_str, ": ", tool$description, hint_str)
  })

  tools_list <- paste0(tools_doc, collapse = "\n")

  # Rest of prompt building...
  paste0(
    "You are an expert R programming assistant working in: ", working_dir, "\n\n",
    "## Available Tools\n",
    "You can ONLY use these tools (with their exact parameter names):\n",
    tools_list, "\n\n",
    "# ... rest of prompt"
  )
}
```

### Step 7: Tool Templates with Full Examples

**File:** `R/tools-user.R` (template functions)

```r
.get_tool_template <- function(name, template) {
  # Convert name to title
  title <- gsub("-", " ", name)
  title <- tools::toTitleCase(title)

  if (template == "basic") {
    return(c(
      "---",
      paste0("name: ", name),
      paste0("title: ", title),
      "description: Brief description of what this tool does",
      "group: custom",
      "risky: false",
      "hints:",
      "  read_only: true",
      "  idempotent: true",
      "parameters:",
      "  - name: input",
      "    type: string",
      "    required: true",
      "    description: Input to process",
      "---",
      "",
      paste0("# ", title),
      "",
      "This is a basic custom tool template.",
      "",
      "## Implementation",
      "",
      "This tool demonstrates:",
      "1. Input validation",
      "2. Error handling with cli",
      "3. Clear return values",
      "",
      "## Handler Function",
      "",
      "```r",
      "function(input) {",
      "  # TOOL BEGINS HERE",
      "  ",
      "  # Validate input",
      "  if (!rlang::is_string(input) || !nzchar(input)) {",
      "    cli::cli_abort(\"Input must be a non-empty string\")",
      "  }",
      "  ",
      "  # Process",
      "  result <- tryCatch({",
      "    toupper(input)  # Example: convert to uppercase",
      "  }, error = function(e) {",
      "    cli::cli_abort(\"Processing failed: {e$message}\")",
      "  })",
      "  ",
      "  # Return result",
      "  result",
      "  ",
      "  # TOOL ENDS HERE",
      "}",
      "```",
      "",
      "## Testing",
      "",
      "Test this tool with:",
      "```r",
      "cassidy_agentic_task(",
      paste0("  \"Use ", name, " to process 'hello'\","),
      paste0("  tools = c(\"", name, "\"),"),
      "  max_iterations = 2",
      ")",
      "```"
    ))

  } else if (template == "file_operation") {
    return(c(
      "---",
      paste0("name: ", name),
      paste0("title: ", title),
      "description: Custom file operation tool",
      "group: files",
      "risky: false",
      "hints:",
      "  read_only: true",
      "  idempotent: true",
      "parameters:",
      "  - name: filepath",
      "    type: string",
      "    required: true",
      "    description: Path to the file",
      "  - name: working_dir",
      "    type: string",
      "    required: false",
      "    description: Working directory",
      "---",
      "",
      paste0("# ", title),
      "",
      "File operation tool using fs package for cross-platform compatibility.",
      "",
      "## Best Practices",
      "",
      "1. **Use fs package** - Cross-platform file operations",
      "2. **Validate paths** - Check existence before operations",
      "3. **Error handling** - Clear messages with cli",
      "4. **Return useful info** - File content or operation status",
      "",
      "## Handler Function",
      "",
      "```r",
      "function(filepath, working_dir = getwd()) {",
      "  # TOOL BEGINS HERE",
      "  ",
      "  # Resolve full path",
      "  full_path <- if (dirname(filepath) == \".\") {",
      "    fs::path(working_dir, filepath)",
      "  } else {",
      "    fs::path(filepath)",
      "  }",
      "  ",
      "  # Validate file exists",
      "  if (!fs::file_exists(full_path)) {",
      "    cli::cli_abort(\"File not found: {.file {full_path}}\")",
      "  }",
      "  ",
      "  # Perform operation",
      "  result <- tryCatch({",
      "    # Example: Read file",
      "    content <- readLines(full_path, warn = FALSE)",
      "    ",
      "    # Get file info",
      "    info <- fs::file_info(full_path)",
      "    ",
      "    # Format result",
      "    list(",
      "      content = paste(content, collapse = \"\\n\"),",
      "      size = info$size,",
      "      modified = info$modification_time",
      "    )",
      "  }, error = function(e) {",
      "    cli::cli_abort(\"Failed to read file: {e$message}\")",
      "  })",
      "  ",
      "  # Return formatted output",
      "  paste0(",
      "    \"File: \", fs::path_file(full_path), \"\\n\",",
      "    \"Size: \", result$size, \" bytes\\n\",",
      "    \"Modified: \", result$modified, \"\\n\\n\",",
      "    result$content",
      "  )",
      "  ",
      "  # TOOL ENDS HERE",
      "}",
      "```",
      "",
      "## Testing",
      "",
      "```r",
      "# Test the tool",
      "cassidy_agentic_task(",
      paste0("  \"Use ", name, " to read README.md\","),
      paste0("  tools = c(\"", name, "\", \"list_files\"),"),
      "  max_iterations = 3",
      ")",
      "```"
    ))

  } else {  # data_operation
    return(c(
      "---",
      paste0("name: ", name),
      paste0("title: ", title),
      "description: Custom data operation tool",
      "group: data",
      "risky: false",
      "hints:",
      "  read_only: true",
      "  idempotent: true",
      "parameters:",
      "  - name: data_name",
      "    type: string",
      "    required: true",
      "    description: Name of data frame in environment",
      "  - name: operation",
      "    type: string",
      "    required: false",
      "    default: \"summary\"",
      "    description: Operation to perform",
      "---",
      "",
      paste0("# ", title),
      "",
      "Data operation tool for analyzing data frames.",
      "",
      "## Features",
      "",
      "1. **Environment access** - Read data frames from .GlobalEnv",
      "2. **Safe operations** - Validate data before processing",
      "3. **Multiple operations** - Extensible operation types",
      "4. **Clear output** - Formatted results",
      "",
      "## Handler Function",
      "",
      "```r",
      "function(data_name, operation = \"summary\") {",
      "  # TOOL BEGINS HERE",
      "  ",
      "  # Check if object exists",
      "  if (!exists(data_name, envir = .GlobalEnv)) {",
      "    cli::cli_abort(\"Data frame not found: {.field {data_name}}\")",
      "  }",
      "  ",
      "  # Get object",
      "  obj <- get(data_name, envir = .GlobalEnv)",
      "  ",
      "  # Validate it's a data frame",
      "  if (!is.data.frame(obj)) {",
      "    cli::cli_abort(\"Object is not a data frame: {.field {data_name}}\")",
      "  }",
      "  ",
      "  # Perform operation",
      "  result <- switch(operation,",
      "    summary = {",
      "      # Basic summary",
      "      paste0(",
      "        \"Data: \", data_name, \"\\n\",",
      "        \"Rows: \", nrow(obj), \"\\n\",",
      "        \"Columns: \", ncol(obj), \"\\n\",",
      "        \"Variables: \", paste(names(obj), collapse = \", \"), \"\\n\\n\",",
      "        paste(capture.output(summary(obj)), collapse = \"\\n\")",
      "      )",
      "    },",
      "    head = {",
      "      # First few rows",
      "      paste(capture.output(print(head(obj))), collapse = \"\\n\")",
      "    },",
      "    names = {",
      "      # Column names",
      "      paste(\"Columns:\", paste(names(obj), collapse = \", \"))",
      "    },",
      "    cli::cli_abort(\"Unknown operation: {.field {operation}}\")",
      "  )",
      "  ",
      "  result",
      "  ",
      "  # TOOL ENDS HERE",
      "}",
      "```",
      "",
      "## Testing",
      "",
      "```r",
      "# Load example data",
      "data(mtcars)",
      "",
      "# Test the tool",
      "cassidy_agentic_task(",
      paste0("  \"Use ", name, " to summarize mtcars data\","),
      paste0("  tools = c(\"", name, "\"),"),
      "  max_iterations = 2",
      ")",
      "```"
    ))
  }
}
```

### Step 8: Testing

**New file:** `tests/testthat/test-tools-custom.R`

```r
test_that("custom tool discovery works", {
  withr::with_tempdir({
    # Create custom tool file with YAML frontmatter
    fs::dir_create(".cassidy/tools")
    writeLines(c(
      "---",
      "name: custom-read",
      "description: Custom file reader",
      "group: files",
      "risky: false",
      "---",
      "```r",
      "function(path) {",
      "  readLines(path, warn = FALSE)",
      "}",
      "```"
    ), ".cassidy/tools/custom-read.md")

    tools <- .discover_custom_tools()
    expect_true("custom-read" %in% names(tools))
    expect_equal(tools[["custom-read"]]$group, "files")
  })
})

test_that("custom tool name conflicts are caught", {
  withr::with_tempdir({
    # Try to create tool with same name as built-in
    fs::dir_create(".cassidy/tools")
    writeLines(c(
      "---",
      "name: read_file",  # Conflicts with built-in
      "description: Duplicate",
      "---",
      "```r",
      "function() NULL",
      "```"
    ), ".cassidy/tools/read_file.md")

    # Should error
    expect_error(
      .discover_custom_tools(),
      "conflict"
    )
  })
})

test_that("tool extraction with markers works", {
  withr::with_tempdir({
    fs::dir_create(".cassidy/tools")
    writeLines(c(
      "---",
      "name: marker-test",
      "description: Test markers",
      "---",
      "```r",
      "# Some setup code",
      "x <- 1",
      "# TOOL BEGINS HERE",
      "function(input) {",
      "  paste('Result:', input)",
      "}",
      "# TOOL ENDS HERE",
      "# Some cleanup",
      "```"
    ), ".cassidy/tools/marker-test.md")

    tools <- .discover_custom_tools()
    expect_true("marker-test" %in% names(tools))
    expect_true(is.function(tools[["marker-test"]]$handler))
  })
})

test_that("custom tools can be executed", {
  withr::with_tempdir({
    fs::dir_create(".cassidy/tools")
    writeLines(c(
      "---",
      "name: echo",
      "description: Echo input",
      "---",
      "```r",
      "function(message) {",
      "  paste('Echo:', message)",
      "}",
      "```"
    ), ".cassidy/tools/echo.md")

    # Refresh cache to pick up new tool
    .get_all_tools(refresh = TRUE)

    result <- .execute_tool(
      "echo",
      list(message = "Hello"),
      working_dir = getwd()
    )

    expect_true(result$success)
    expect_equal(result$result, "Echo: Hello")
  })
})

test_that("custom tool validation works", {
  withr::with_tempdir({
    fs::dir_create(".cassidy/tools")
    writeLines(c(
      "---",
      "name: validator",
      "description: Test validation",
      "parameters:",
      "  - name: required_param",
      "    type: string",
      "    required: true",
      "    description: Must be provided",
      "---",
      "```r",
      "function(required_param) {",
      "  required_param",
      "}",
      "```"
    ), ".cassidy/tools/validator.md")

    # Refresh cache
    .get_all_tools(refresh = TRUE)

    # Should fail without required parameter
    result <- .execute_tool("validator", list())
    expect_false(result$success)
    expect_match(result$error, "required_param")

    # Should succeed with parameter
    result <- .execute_tool("validator", list(required_param = "test"))
    expect_true(result$success)
  })
})

test_that("tool caching works", {
  withr::with_tempdir({
    # First call discovers tools
    tools1 <- .get_all_tools()

    # Second call uses cache
    tools2 <- .get_all_tools()
    expect_identical(tools1, tools2)

    # Refresh clears cache
    tools3 <- .get_all_tools(refresh = TRUE)
    expect_identical(tools1, tools3)
  })
})

test_that("tool grouping functions work", {
  groups <- suppressMessages(cassidy_tool_groups())
  expect_type(groups, "character")
  expect_true("files" %in% groups)

  file_tools <- cassidy_tools_in_group("files")
  expect_true("read_file" %in% file_tools)
})

test_that("rlang type validation works", {
  expect_true(.validate_type_rlang("test", "string"))
  expect_true(.validate_type_rlang(c("a", "b"), "character"))
  expect_true(.validate_type_rlang(123, "number"))
  expect_true(.validate_type_rlang(123L, "integer"))
  expect_true(.validate_type_rlang(TRUE, "logical"))
  expect_true(.validate_type_rlang(list(a = 1), "list"))
  expect_true(.validate_type_rlang("anything", "any"))

  expect_false(.validate_type_rlang(123, "string"))
  expect_false(.validate_type_rlang("test", "logical"))
})
```

### Step 9: Documentation Updates

**Update:** `.claude/rules/file-structure.md`

Add to Agentic System section:

```markdown
### Agentic System (7 files)
- `agentic-chat.R` - Main agentic loop and orchestration
- `agentic-workflow.R` - Direct parsing of tool decisions
- `agentic-tools.R` - Tool registry with built-in tools
- `agentic-approval.R` - Interactive approval system
- `agentic-helpers.R` - User utilities (list tools, presets)
- `tools-discovery.R` - Custom tool discovery & parsing (NEW)
- `tools-user.R` - User-facing custom tool functions (NEW)
```

**Update:** `.claude/rules/roadmap.md`

Replace Phase 6 section:

```markdown
### ✅ Phase 6: Enhanced Tool System (Complete)

**Core Features:**
- Enhanced metadata (title, group, hints, type-safe parameters)
- Tool grouping and discovery functions
- User custom tools (.cassidy/tools/, ~/.cassidy/tools/)
- Input validation with rlang type checking
- Conditional tool availability (can_register)
- Tool caching for performance
- Dry run mode for validation

**Functions:**
- `cassidy_tool_groups()` - List all tool groups
- `cassidy_tools_in_group(group)` - Get tools by group
- `cassidy_tool_info(name)` - Display tool details
- `cassidy_available_tools()` - Only tools that can register
- `cassidy_create_tool()` - Create custom tool from template
- `cassidy_list_custom_tools()` - List user-defined tools
- `cassidy_validate_tool()` - Validate custom tool
- `cassidy_validate_tool_file()` - Validate tool file before installation
- `cassidy_refresh_tools()` - Refresh tool cache

**Custom Tool Format:**
- YAML frontmatter for metadata
- Handler function in R code block
- Optional explicit markers (# TOOL BEGINS HERE / # TOOL ENDS HERE)
- Parameter definitions with rlang types
- Project (.cassidy/tools/) and personal (~/.cassidy/tools/) scope

**Security:**
- Prominent documentation warning about custom tool code execution
- Tool name conflict prevention
- Type validation with rlang
- Safe mode still applies to risky custom tools
```

**Create:** `NEWS.md` entry

```markdown
## cassidyr 0.x.0

### New features

* Added custom tool system allowing users to define their own tools in
  `.cassidy/tools/` (project) or `~/.cassidy/tools/` (personal) using YAML
  frontmatter and R code blocks (#XX).

* Added tool grouping and discovery functions: `cassidy_tool_groups()`,
  `cassidy_tools_in_group()`, `cassidy_tool_info()`, and
  `cassidy_available_tools()` (#XX).

* Added `cassidy_create_tool()` to generate custom tools from templates
  (basic, file_operation, data_operation) (#XX).

* Enhanced tool metadata with titles, groups, hints, and type-safe parameter
  definitions using rlang type checking (#XX).

* Added input validation for tool parameters with clear, actionable error
  messages (#XX).

* Added `dry_run` parameter to `cassidy_agentic_task()` for validation without
  execution (#XX).

* Added tool caching system with `cassidy_refresh_tools()` for better
  performance (#XX).

* Added `cassidy_validate_tool()` and `cassidy_validate_tool_file()` for
  testing custom tools before use (#XX).

### Breaking changes

* None - all changes are backward compatible with existing code.

### Security

* Added clear documentation warnings that custom tools execute arbitrary R code.
  Only use custom tools from trusted sources. Review tool code before adding to
  project tools that will be shared via git.
```

**Create/Update:** Vignette or README section

Add to README.md or create `vignettes/custom-tools.Rmd`:

```markdown
## Creating Custom Tools

cassidyr's agentic system can be extended with custom tools that execute R code
to accomplish specialized tasks.

### Quick Start

Create a custom tool:

```r
cassidy_create_tool("my-analyzer", location = "project", template = "data_operation")
```

This creates `.cassidy/tools/my-analyzer.md` with a template. Edit the file to
customize:

1. **YAML frontmatter** - Define metadata (name, description, group, parameters)
2. **Handler function** - Write R code to implement the tool
3. **Testing section** - Example usage

### Tool File Format

Custom tools use YAML frontmatter for metadata:

```yaml
---
name: my-tool
title: My Custom Tool
description: What this tool does
group: custom
risky: false
hints:
  read_only: true
  idempotent: true
parameters:
  - name: input
    type: string
    required: true
    description: Input to process
---

# My Custom Tool

Implementation details here.

## Handler Function

```r
function(input) {
  # TOOL BEGINS HERE

  # Your R code here
  result <- process(input)

  return(result)

  # TOOL ENDS HERE
}
```
```

### Using Custom Tools

Once created, custom tools work exactly like built-in tools:

```r
# List all tools (including custom)
cassidy_list_tools()

# Use in agentic tasks
cassidy_agentic_task(
  "Analyze data using my-analyzer",
  tools = c("my-analyzer", "describe_data")
)

# Validate before using
cassidy_validate_tool("my-analyzer")
```

### Tool Locations

- **Project tools**: `.cassidy/tools/` - Shared with team via git
- **Personal tools**: `~/.cassidy/tools/` - User-specific, gitignored

### Security Warning

**⚠️ Important:** Custom tools execute arbitrary R code and can perform any
operation your R session can. Only use custom tools from trusted sources.

Review tool code before adding to project tools (`.cassidy/tools/`) that will
be shared via git. Personal tools (`~/.cassidy/tools/`) are your responsibility.

### Best Practices

1. **Use fs package** for file operations (cross-platform compatibility)
2. **Validate inputs** with rlang type checking
3. **Error handling** with cli for clear messages
4. **Working examples** in the testing section
5. **Clear parameters** with types and descriptions
6. **Explicit markers** (# TOOL BEGINS HERE) for complex functions

### Templates

Three templates are available:

- **basic** - Simple tool with input validation
- **file_operation** - File reading/writing with fs package
- **data_operation** - Data frame analysis

Each includes complete working examples with error handling.

### Tool Discovery

Custom tools are automatically discovered from:
- `.cassidy/tools/*.md` (project scope)
- `~/.cassidy/tools/*.md` (personal scope)

Refresh tool cache after creating new tools:

```r
cassidy_refresh_tools()
```

### Type Validation

Parameters are validated using rlang type checkers:

- `string` - Single character value
- `character` - Character vector
- `number` - Numeric value
- `integer` - Integer value
- `logical` - Boolean value
- `list` - List object
- `any` - Accept anything

### Tool Grouping

Organize tools by semantic groups:

```r
# List all groups
cassidy_tool_groups()

# Get tools in a group
cassidy_tools_in_group("files")

# Get detailed tool info
cassidy_tool_info("my-tool")
```

### Dry Run Mode

Test tasks without execution:

```r
cassidy_agentic_task(
  "Complex task",
  tools = c("my-tool", "read_file"),
  dry_run = TRUE  # Validates without executing
)
```

This checks that all tools exist and validates tool definitions without making
API calls or executing tools.
```

## Implementation Order

1. **Phase 1:** Enhanced metadata + helpers (2 hours)
   - Modify `R/agentic-tools.R`
   - Add `.get_tool_field()`, `.get_tool_definition()`, `.get_all_tools()`
   - Update tests in `test-agentic-tools.R`

2. **Phase 2:** Custom tool discovery (3 hours)
   - Create `R/tools-discovery.R`
   - Implement YAML parsing and function extraction
   - Add name conflict checking
   - Test discovery and parsing

3. **Phase 3:** User-facing functions (2 hours)
   - Create `R/tools-user.R`
   - Implement `cassidy_create_tool()`, `cassidy_list_custom_tools()`, etc.
   - Create templates with full examples
   - Test tool creation workflow

4. **Phase 4:** Tool caching + grouping (1-2 hours)
   - Add caching to `.get_all_tools()`
   - Add grouping functions to `R/agentic-helpers.R`
   - Update `cassidy_list_tools()` to show groups
   - Test caching and grouping

5. **Phase 5:** Validation system (2 hours)
   - Add `.validate_tool_input()` with rlang types
   - Update `.execute_tool()`
   - Test validation errors
   - Verify backward compatibility

6. **Phase 6:** Integration + dry run (1-2 hours)
   - Update `R/agentic-chat.R` for dry run mode
   - Update `.build_agentic_prompt()` for hints
   - Test full agentic workflow with custom tools
   - Verify all existing tests still pass

7. **Phase 7:** Documentation (2 hours)
   - Update `.claude/rules/` files
   - Create NEWS.md entry
   - Add vignette or README section
   - Add security warnings
   - Document all new functions

**Total Estimated Time:** 13-15 hours of focused development

## Success Criteria

✅ **Backward Compatibility:**
- All existing tests pass without modification
- Old tool definitions work without changes
- Preset system (`cassidy_tool_preset()`) still works

✅ **Enhanced Metadata:**
- Built-in tools have complete metadata (title, group, hints, parameters)
- Metadata is accessible via helper functions
- Grouping functions work correctly

✅ **Custom Tools:**
- Users can create tools with YAML frontmatter
- Custom tools are discovered and merged with built-in tools
- Custom tools work in `cassidy_agentic_task()`
- Tool templates are complete with working examples
- Name conflicts are caught with clear errors

✅ **Validation:**
- Input validation catches missing required parameters
- Type validation works with rlang type checkers
- Validation errors are clear and actionable

✅ **Caching:**
- Tool discovery is cached for performance
- `cassidy_refresh_tools()` updates cache
- Cache works correctly across tool operations

✅ **Discovery:**
- `cassidy_tool_groups()` shows all groups
- `cassidy_tools_in_group()` filters correctly
- `cassidy_tool_info()` displays comprehensive information
- `cassidy_available_tools()` respects `can_register()`

✅ **Dry Run:**
- `dry_run = TRUE` validates without executing
- Returns structured validation result
- Catches tool and parameter errors early

✅ **Security:**
- Clear warnings in documentation about code execution
- Name conflict prevention
- Type validation with rlang
- Safe mode applies to custom tools marked as risky

✅ **Documentation:**
- All new functions have roxygen2 docs with examples
- Vignette or README explains custom tool creation
- Security warnings prominently displayed
- Templates include best practices
- file-structure.md, roadmap.md, NEWS.md updated

## Future Enhancements (Not in This Phase)

- Tool dependencies (like skills system has)
- Tool versioning
- Remote tool registry (install tools from GitHub)
- Tool permissions/sandboxing beyond risky flag
- Tool telemetry (track usage statistics)
- Visual tool builder (Shiny app to create tools without markdown)
- Tool marketplace/sharing platform
- Integration with cassidy_app() for agentic capabilities in Shiny

These can be added later based on user feedback and demand.
