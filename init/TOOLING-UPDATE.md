# Unified Tool System Implementation Plan

## Overview

This plan implements a comprehensive tool system enhancement for cassidyr, incorporating:
- Modular tool architecture (separate functions instead of monolithic list)
- Multiple tool calling formats with empirical testing
- Programmatic tool creation (like `ellmer::tool()`)
- Auto-generation from roxygen2 documentation
- Custom user tools from markdown files
- Enhanced metadata, validation, and discoverability
- Tool calling in both agentic tasks and chat conversations

## Architecture Principles

1. **Shared Tool Registry** - One tool system used by both `cassidy_agentic_task()` and `cassidy_chat()`
2. **Modular Tool Definitions** - Each tool is a separate function, not a list entry
3. **Enhanced Metadata** - All tools support rich metadata (examples, validation, tags, deprecation)
4. **Opt-in Chat Tools** - `cassidy_chat()` works as before unless `tools` parameter is specified
5. **Custom Tools Everywhere** - User tools work in both agentic and chat contexts
6. **Claude-Optimized** - Designed for Claude Sonnet 4.5 through CassidyAI platform

## Platform Constraints

- **API**: CassidyAI platform (not direct Claude API access)
- **Model**: Claude Sonnet 4.5 (consistent)
- **Context Limit**: ~200,000 characters
- **Tool Calling**: Prompt-based (no native API tool calling)
- **Instructions**: Must be included in each message

---

## Phase 0: Tool Architecture Refactor (3-4 hours)

**Goal:** Replace monolithic `.cassidy_tools` list with modular function-based architecture

### 0.1 New Tool Structure

**File:** `R/tools-builtin.R` (new file)

Each built-in tool becomes a documented function:

```r
#' Read File Tool
#'
#' @description Read contents of a file
#' @param filepath Path to the file to read
#' @param working_dir Working directory (default: current)
#' @return File contents as string
#' @keywords internal
#' @examples
#' \dontrun{
#'   tool_read_file("script.R")
#' }
tool_read_file <- function(filepath, working_dir = getwd()) {
  # Resolve path
  full_path <- if (dirname(filepath) == ".") {
    fs::path(working_dir, filepath)
  } else {
    fs::path(filepath)
  }

  # Validate exists
  if (!fs::file_exists(full_path)) {
    cli::cli_abort("File not found: {.file {full_path}}")
  }

  # Read file
  tryCatch({
    content <- readLines(full_path, warn = FALSE)
    paste(content, collapse = "\n")
  }, error = function(e) {
    cli::cli_abort("Failed to read file: {e$message}")
  })
}

#' Write File Tool
#'
#' @description Write content to a file
#' @param filepath Path to write to
#' @param content Content to write
#' @param working_dir Working directory
#' @return Success message
#' @keywords internal
tool_write_file <- function(filepath, content, working_dir = getwd()) {
  # Implementation...
}

#' List Files Tool
#'
#' @description List files in a directory
#' @param path Directory path (default: ".")
#' @param pattern File pattern to match (optional)
#' @param recursive Search recursively (default: FALSE)
#' @param working_dir Working directory
#' @return List of files
#' @keywords internal
tool_list_files <- function(path = ".", pattern = NULL, recursive = FALSE,
                           working_dir = getwd()) {
  # Implementation...
}

# ... similarly for all other built-in tools
```

### 0.2 Tool Registration System

**File:** `R/tools-registry.R` (new file)

```r
# Package environment for tool registry
.tool_registry <- new.env(parent = emptyenv())
.tool_registry$tools <- list()
.tool_registry$cache_timestamp <- NULL

#' Create a Tool Definition
#'
#' @description Programmatically create a tool (similar to ellmer::tool())
#' @param name Tool name (lowercase with underscores)
#' @param title Display title
#' @param description Brief description of what tool does
#' @param handler Function that implements the tool
#' @param group Semantic group (e.g., "files", "data", "code")
#' @param risky Whether tool requires approval (default: FALSE)
#' @param hints List of hints for LLM (read_only, idempotent, etc.)
#' @param parameters List of parameter definitions
#' @param examples List of usage examples
#' @param tags Character vector of tags
#' @param deprecated Deprecation information (list with since, replacement, message)
#' @param can_register Function to check if tool can be registered
#' @return Tool definition object
#' @export
#' @examples
#' \dontrun{
#'   my_tool <- cassidy_create_tool(
#'     name = "my_tool",
#'     title = "My Tool",
#'     description = "Does something useful",
#'     handler = function(input) {
#'       toupper(input)
#'     },
#'     parameters = list(
#'       input = list(
#'         type = "string",
#'         description = "Input string",
#'         required = TRUE
#'       )
#'     )
#'   )
#'  
#'   cassidy_register_tool(my_tool)
#' }
cassidy_create_tool <- function(
  name,
  title = NULL,
  description,
  handler,
  group = "custom",
  risky = FALSE,
  hints = list(),
  parameters = list(),
  examples = list(),
  tags = character(),
  deprecated = NULL,
  can_register = function() TRUE
) {
  # Validate name
  if (!grepl("^[a-z0-9_]+$", name)) {
    cli::cli_abort(c(
      "x" = "Invalid tool name: {.val {name}}",
      "i" = "Tool names must be lowercase with underscores (e.g., 'my_tool')"
    ))
  }

  # Validate handler is a function
  if (!is.function(handler)) {
    cli::cli_abort("handler must be a function")
  }

  # Build tool definition
  structure(
    list(
      name = name,
      title = title %||% tools::toTitleCase(gsub("_", " ", name)),
      description = description,
      group = group,
      risky = risky,
      hints = hints,
      parameters = parameters,
      examples = examples,
      tags = tags,
      deprecated = deprecated,
      handler = handler,
      can_register = can_register
    ),
    class = "cassidy_tool"
  )
}

#' Create Tool from Function with Roxygen2 Documentation
#'
#' @description Auto-generate tool metadata from roxygen2 docs (like ellmer::create_tool_def())
#' @param func Function object or function name as string
#' @param name Tool name (default: function name)
#' @param group Tool group (default: "custom")
#' @param risky Whether tool is risky (default: FALSE)
#' @param hints Additional hints for LLM
#' @param tags Additional tags
#' @export
#' @examples
#' \dontrun{
#' #' Add Two Numbers
#' #'
#' #' @param x First number
#' #' @param y Second number
#' #' @return Sum of x and y
#' add_numbers <- function(x, y) {
#'   x + y
#' }
#'
#' tool <- cassidy_tool_from_roxygen2(add_numbers)
#' cassidy_register_tool(tool)
#' }
cassidy_tool_from_roxygen2 <- function(
  func,
  name = NULL,
  group = "custom",
  risky = FALSE,
  hints = list(),
  tags = character()
) {
  # Get function
  if (is.character(func)) {
    func_name <- func
    func <- get(func, envir = parent.frame())
  } else {
    func_name <- deparse(substitute(func))
  }

  name <- name %||% func_name

  # Try to parse roxygen2 comments
  func_src <- attr(func, "srcref")
  if (!is.null(func_src)) {
    # Parse roxygen2 from source
    src_file <- attr(func_src, "srcfile")
    if (!is.null(src_file)) {
      lines <- readLines(src_file$filename, warn = FALSE)
      func_line <- as.numeric(func_src[1])

      # Extract roxygen2 comments before function
      roxygen_lines <- character()
      i <- func_line - 1
      while (i > 0 && grepl("^\\s*#'", lines[i])) {
        roxygen_lines <- c(lines[i], roxygen_lines)
        i <- i - 1
      }

      if (length(roxygen_lines) > 0) {
        # Parse roxygen2
        parsed <- .parse_roxygen2(roxygen_lines)

        # Build parameters from @param tags
        parameters <- lapply(parsed$params, function(p) {
          list(
            type = "any",  # Can't infer type from roxygen2 alone
            description = p$description,
            required = TRUE  # Conservative default
          )
        })
        names(parameters) <- names(parsed$params)

        # Create tool
        return(cassidy_create_tool(
          name = name,
          title = parsed$title,
          description = parsed$description %||% parsed$title,
          handler = func,
          group = group,
          risky = risky,
          hints = hints,
          parameters = parameters,
          examples = parsed$examples,
          tags = tags
        ))
      }
    }
  }

  # Fallback: minimal tool definition
  cli::cli_warn(c(
    "!" = "Could not parse roxygen2 documentation for {.fn {func_name}}",
    "i" = "Creating minimal tool definition"
  ))

  # Infer parameters from function signature
  args <- formals(func)
  parameters <- lapply(names(args), function(arg_name) {
    list(
      type = "any",
      description = paste("Parameter", arg_name),
      required = !.has_default(args[[arg_name]])
    )
  })
  names(parameters) <- names(args)

  cassidy_create_tool(
    name = name,
    title = tools::toTitleCase(gsub("_", " ", func_name)),
    description = paste("Tool for", func_name),
    handler = func,
    group = group,
    risky = risky,
    hints = hints,
    parameters = parameters,
    tags = tags
  )
}

.parse_roxygen2 <- function(roxygen_lines) {
  # Remove #' prefix
  lines <- sub("^\\s*#'\\s?", "", roxygen_lines)

  result <- list(
    title = NULL,
    description = NULL,
    params = list(),
    return_desc = NULL,
    examples = list()
  )

  # First non-empty line is title
  non_empty <- lines[nzchar(trimws(lines))]
  if (length(non_empty) > 0) {
    result$title <- non_empty[1]
  }

  # Parse @param tags
  param_lines <- grep("^@param", lines, value = TRUE)
  for (line in param_lines) {
    match <- regexec("^@param\\s+(\\w+)\\s+(.+)$", line)
    if (match[[1]][1] != -1) {
      captures <- regmatches(line, match)[[1]]
      param_name <- captures[2]
      param_desc <- captures[3]
      result$params[[param_name]] <- list(description = param_desc)
    }
  }

  # Parse @return
  return_lines <- grep("^@return", lines, value = TRUE)
  if (length(return_lines) > 0) {
    result$return_desc <- sub("^@return\\s+", "", return_lines[1])
  }

  # Parse @description
  desc_lines <- grep("^@description", lines, value = TRUE)
  if (length(desc_lines) > 0) {
    result$description <- sub("^@description\\s+", "", desc_lines[1])
  }

  # Parse @examples
  example_start <- grep("^@examples", lines)
  if (length(example_start) > 0) {
    example_lines <- lines[(example_start[1] + 1):length(lines)]
    example_lines <- example_lines[!grepl("^@", example_lines)]
    if (length(example_lines) > 0) {
      result$examples <- list(list(
        code = paste(example_lines, collapse = "\n"),
        description = "Example usage"
      ))
    }
  }

  result
}

.has_default <- function(arg) {
  !identical(arg, quote(expr = ))
}

#' Register a Tool
#'
#' @description Register a tool in the global registry
#' @param tool Tool definition created with cassidy_create_tool()
#' @export
cassidy_register_tool <- function(tool) {
  if (!inherits(tool, "cassidy_tool")) {
    cli::cli_abort("tool must be created with cassidy_create_tool()")
  }

  # Check if can register
  if (!tool$can_register()) {
    cli::cli_warn(c(
      "!" = "Tool {.field {tool$name}} cannot be registered",
      "i" = "Skipping registration"
    ))
    return(invisible(FALSE))
  }

  # Check for conflicts with existing tools
  existing_tools <- names(.tool_registry$tools)
  if (tool$name %in% existing_tools) {
    cli::cli_warn(c(
      "!" = "Tool {.field {tool$name}} already registered",
      "i" = "Replacing existing tool"
    ))
  }

  # Register
  .tool_registry$tools[[tool$name]] <- tool
  .tool_registry$cache_timestamp <- Sys.time()

  invisible(TRUE)
}

#' Get All Registered Tools
#'
#' @description Get all tools from registry (built-in + custom)
#' @param refresh Force refresh of custom tools
#' @return Named list of tool definitions
#' @keywords internal
.get_all_tools <- function(refresh = FALSE) {
  if (refresh) {
    # Re-discover custom tools
    custom_tools <- .discover_custom_tools()

    # Re-register built-in tools
    .register_builtin_tools()

    # Register custom tools
    for (tool in custom_tools) {
      cassidy_register_tool(tool)
    }

    .tool_registry$cache_timestamp <- Sys.time()
  } else if (length(.tool_registry$tools) == 0) {
    # First time - register all tools
    .register_builtin_tools()
    custom_tools <- .discover_custom_tools()
    for (tool in custom_tools) {
      cassidy_register_tool(tool)
    }
  }

  .tool_registry$tools
}

#' Register Built-in Tools
#'
#' @keywords internal
.register_builtin_tools <- function() {
  # Read file
  cassidy_register_tool(cassidy_create_tool(
    name = "read_file",
    title = "Read File",
    description = "Read contents of a file",
    handler = tool_read_file,
    group = "files",
    risky = FALSE,
    hints = list(read_only = TRUE, idempotent = TRUE),
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
    examples = list(
      list(
        code = 'read_file("script.R")',
        description = "Read an R script"
      )
    ),
    tags = c("io", "read")
  ))

  # Write file
  cassidy_register_tool(cassidy_create_tool(
    name = "write_file",
    title = "Write File",
    description = "Write content to a file",
    handler = tool_write_file,
    group = "files",
    risky = TRUE,
    hints = list(read_only = FALSE, idempotent = FALSE),
    parameters = list(
      filepath = list(
        type = "string",
        description = "Path to write to",
        required = TRUE
      ),
      content = list(
        type = "string",
        description = "Content to write",
        required = TRUE
      ),
      working_dir = list(
        type = "string",
        description = "Working directory",
        required = FALSE,
        default = "getwd()"
      )
    ),
    tags = c("io", "write")
  ))

  # ... register all other built-in tools similarly

  invisible(NULL)
}
```

---

## Phase 0.5: Tool Format Testing (2-3 hours)

**Goal:** Empirically test three INPUT formats to find most reliable with Claude Sonnet 4.5

### Format Options

#### Format A: Current (Mixed - XML-style with JSON INPUT)
```
<TOOL_DECISION>
ACTION: read_file
INPUT: {"filepath": "script.R", "working_dir": "/path"}
REASONING: Need to read the file
STATUS: continue
</TOOL_DECISION>
```

**Pros:**
- Already partially implemented
- Clear structure with XML-style tags
- JSON for complex parameters

**Cons:**
- Mixed format (XML + JSON)
- More verbose

#### Format B: Pure JSON
```json
{
  "tool_decision": {
    "action": "read_file",
    "input": {
      "filepath": "script.R",
      "working_dir": "/path"
    },
    "reasoning": "Need to read the file",
    "status": "continue"
  }
}
```

**Pros:**
- Single consistent format
- Claude Sonnet 4.5 excellent at JSON
- Easier to parse reliably
- Better error messages when malformed

**Cons:**
- Different from current implementation

#### Format C: Markdown-style
```
<TOOL_DECISION>
ACTION: read_file
REASONING: Need to read the file
STATUS: continue

## Parameters
- filepath: script.R
- working_dir: /path
</TOOL_DECISION>
```

**Pros:**
- More readable
- Natural for markdown context

**Cons:**
- Harder to parse complex parameters
- Ambiguous structure for nested data

### Testing Implementation

**File:** `tests/manual/test-tool-formats.R`

```r
library(cassidyr)

# Test task with various parameter complexities
test_format <- function(format_type = c("xml_json", "pure_json", "markdown")) {
  format_type <- match.arg(format_type)

  # Set format in options
  options(cassidy_tool_format = format_type)

  # Test cases
  test_cases <- list(
    simple = list(
      task = "List all R files in the current directory",
      expected_tool = "list_files",
      complexity = "simple"
    ),
    moderate = list(
      task = "Read the file 'my script.R' (with spaces)",
      expected_tool = "read_file",
      complexity = "moderate"
    ),
    complex = list(
      task = "Search for functions containing 'data' in R files",
      expected_tool = "search_files",
      complexity = "complex"
    )
  )

  results <- list()

  for (test_name in names(test_cases)) {
    test_case <- test_cases[[test_name]]

    cat("\nTesting", format_type, "-", test_name, "...\n")

    result <- tryCatch({
      response <- cassidy_agentic_task(
        task = test_case$task,
        tools = test_case$expected_tool,
        max_iterations = 3,
        verbose = TRUE
      )

      list(
        success = TRUE,
        tool_calls = response$tool_calls,
        iterations = length(response$tool_calls)
      )
    }, error = function(e) {
      list(
        success = FALSE,
        error = e$message
      )
    })

    results[[test_name]] <- result
  }

  # Return summary
  list(
    format = format_type,
    tests = results,
    timestamp = Sys.time()
  )
}

# Run all formats
results_xml_json <- test_format("xml_json")
results_pure_json <- test_format("pure_json")
results_markdown <- test_format("markdown")

# Compare results
compare_formats <- function(results_list) {
  formats <- names(results_list)

  cat("\n=== Format Comparison ===\n\n")

  for (format in formats) {
    result <- results_list[[format]]
    success_rate <- mean(sapply(result$tests, function(t) t$success))
    avg_iterations <- mean(sapply(result$tests, function(t) {
      if (t$success) t$iterations else NA
    }), na.rm = TRUE)

    cat(sprintf("%s: %.0f%% success, avg %.1f iterations\n",
                format, success_rate * 100, avg_iterations))
  }
}

compare_formats(list(
  xml_json = results_xml_json,
  pure_json = results_pure_json,
  markdown = results_markdown
))
```

### Flexible Parser Implementation

**File:** `R/tools-parsing.R` (new file)

```r
#' Parse Tool Decision from Response
#'
#' @description Parse tool decision from LLM response, trying multiple formats
#' @param response Response text from LLM
#' @param available_tools Character vector of available tool names
#' @return List with action, input, reasoning, status
#' @keywords internal
.parse_tool_decision <- function(response, available_tools) {
  # Try Format A (XML-style with JSON)
  result <- .try_parse_xml_json(response)
  if (!is.null(result)) {
    return(result)
  }

  # Try Format B (Pure JSON)
  result <- .try_parse_pure_json(response)
  if (!is.null(result)) {
    return(result)
  }

  # Try Format C (Markdown-style)
  result <- .try_parse_markdown(response)
  if (!is.null(result)) {
    return(result)
  }

  # Fallback: inference mode
  .infer_tool_decision(response, available_tools)
}

.try_parse_xml_json <- function(response) {
  # Look for <TOOL_DECISION> block
  pattern <- "<TOOL_DECISION>(.+?)</TOOL_DECISION>"
  match <- regexec(pattern, response, perl = TRUE)

  if (match[[1]][1] == -1) {
    return(NULL)
  }

  content <- regmatches(response, match)[[1]][2]

  # Extract fields
  action <- .extract_field(content, "ACTION")
  input_json <- .extract_field(content, "INPUT")
  reasoning <- .extract_field(content, "REASONING")
  status <- .extract_field(content, "STATUS")

  if (is.null(action)) {
    return(NULL)
  }

  # Parse JSON input
  input <- tryCatch({
    jsonlite::fromJSON(input_json, simplifyVector = FALSE)
  }, error = function(e) {
    NULL
  })

  if (is.null(input)) {
    return(NULL)
  }

  list(
    action = action,
    input = input,
    reasoning = reasoning %||% "",
    status = status %||% "continue"
  )
}

.try_parse_pure_json <- function(response) {
  # Look for JSON object with tool_decision
  json_pattern <- "\\{[^{}]*\"tool_decision\"[^{}]*\\{[^}]+\\}[^}]*\\}"

  # Try to find JSON block
  matches <- gregexpr(json_pattern, response, perl = TRUE)

  if (matches[[1]][1] == -1) {
    return(NULL)
  }

  json_text <- regmatches(response, matches)[[1]][1]

  # Parse JSON
  parsed <- tryCatch({
    jsonlite::fromJSON(json_text, simplifyVector = FALSE)
  }, error = function(e) {
    NULL
  })

  if (is.null(parsed) || is.null(parsed$tool_decision)) {
    return(NULL)
  }

  td <- parsed$tool_decision

  list(
    action = td$action,
    input = td$input %||% list(),
    reasoning = td$reasoning %||% "",
    status = td$status %||% "continue"
  )
}

.try_parse_markdown <- function(response) {
  # Look for <TOOL_DECISION> with markdown parameters
  pattern <- "<TOOL_DECISION>(.+?)</TOOL_DECISION>"
  match <- regexec(pattern, response, perl = TRUE)

  if (match[[1]][1] == -1) {
    return(NULL)
  }

  content <- regmatches(response, match)[[1]][2]

  # Extract fields
  action <- .extract_field(content, "ACTION")
  reasoning <- .extract_field(content, "REASONING")
  status <- .extract_field(content, "STATUS")

  if (is.null(action)) {
    return(NULL)
  }

  # Parse markdown parameters
  param_section <- sub(".*## Parameters\\s*", "", content)
  param_lines <- strsplit(param_section, "\n")[[1]]
  param_lines <- grep("^\\s*-\\s*", param_lines, value = TRUE)

  input <- list()
  for (line in param_lines) {
    # Parse "- key: value"
    match <- regexec("^\\s*-\\s*(\\w+):\\s*(.+)$", line)
    if (match[[1]][1] != -1) {
      captures <- regmatches(line, match)[[1]]
      key <- captures[2]
      value <- trimws(captures[3])
      input[[key]] <- value
    }
  }

  if (length(input) == 0) {
    return(NULL)
  }

  list(
    action = action,
    input = input,
    reasoning = reasoning %||% "",
    status = status %||% "continue"
  )
}

.extract_field <- function(text, field_name) {
  pattern <- paste0(field_name, ":\\s*(.+?)(?:\n|$)")
  match <- regexec(pattern, text)

  if (match[[1]][1] == -1) {
    return(NULL)
  }

  trimws(regmatches(text, match)[[1]][2])
}

.infer_tool_decision <- function(response, available_tools) {
  # Existing inference logic...
}
```

---

## Phase 1: Enhanced Tool Foundation (4-5 hours)

**Goal:** Type validation, enhanced metadata, tool help

### 1.1 Type Validation System

**File:** `R/tools-validation.R` (new file)

```r
#' Validate Tool Input
#'
#' @description Validate tool parameters against tool definition
#' @param tool_name Tool name
#' @param input Named list of input parameters
#' @keywords internal
.validate_tool_input <- function(tool_name, input) {
  tool <- .get_tool_definition(tool_name)

  if (is.null(tool$parameters) || length(tool$parameters) == 0) {
    return(invisible(TRUE))  # No validation needed
  }

  errors <- character()

  for (param_name in names(tool$parameters)) {
    param <- tool$parameters[[param_name]]

    # Check required parameters
    if (isTRUE(param$required) && !param_name %in% names(input)) {
      errors <- c(errors, paste("Missing required parameter:", param_name))
      next
    }

    # Skip if parameter not provided
    if (!param_name %in% names(input)) {
      next
    }

    value <- input[[param_name]]

    # Type validation
    if (!is.null(param$type)) {
      if (!.validate_type_rlang(value, param$type)) {
        errors <- c(errors, paste0(
          "Parameter '", param_name, "' should be ", param$type,
          " but got ", typeof(value)
        ))
      }
    }

    # Additional validation rules
    if (!is.null(param$min) && is.numeric(value)) {
      if (value < param$min) {
        errors <- c(errors, paste0(
          "Parameter '", param_name, "' must be >= ", param$min,
          " (got ", value, ")"
        ))
      }
    }

    if (!is.null(param$max) && is.numeric(value)) {
      if (value > param$max) {
        errors <- c(errors, paste0(
          "Parameter '", param_name, "' must be <= ", param$max,
          " (got ", value, ")"
        ))
      }
    }

    if (!is.null(param$pattern) && is.character(value)) {
      if (!grepl(param$pattern, value)) {
        errors <- c(errors, paste0(
          "Parameter '", param_name, "' must match pattern: ", param$pattern
        ))
      }
    }

    if (!is.null(param$enum)) {
      if (!value %in% param$enum) {
        errors <- c(errors, paste0(
          "Parameter '", param_name, "' must be one of: ",
          paste(param$enum, collapse = ", ")
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

#' Validate Type with rlang
#'
#' @keywords internal
.validate_type_rlang <- function(value, type) {
  switch(type,
    string = rlang::is_string(value),
    character = rlang::is_character(value),
    number = rlang::is_double(value) || rlang::is_integer(value),
    integer = rlang::is_integer(value),
    logical = rlang::is_logical(value),
    list = rlang::is_list(value),
    any = TRUE,
    TRUE  # Unknown type = allow (forward compatibility)
  )
}
```

### 1.2 Tool Help System

**File:** `R/tools-help.R` (new file)

```r
#' Display Tool Help
#'
#' @description Show comprehensive information about a tool
#' @param tool_name Tool name
#' @export
#' @examples
#' \dontrun{
#' cassidy_tool_help("read_file")
#' }
cassidy_tool_help <- function(tool_name) {
  tool <- .get_tool_definition(tool_name)

  if (is.null(tool)) {
    cli::cli_abort("Tool not found: {.field {tool_name}}")
  }

  # Header
  cli::cli_rule(left = paste("Tool:", tool_name))

  # Basic info
  cli::cli_h2(tool$title)
  cli::cli_text(tool$description)
  cli::cli_text("")

  # Metadata
  cli::cli_alert_info("Group: {.field {tool$group}}")
  cli::cli_alert_info("Risky: {.val {tool$risky}}")

  if (length(tool$tags) > 0) {
    cli::cli_alert_info("Tags: {.val {tool$tags}}")
  }

  # Deprecation warning
  if (!is.null(tool$deprecated)) {
    cli::cli_alert_warning("DEPRECATED since {tool$deprecated$since}")
    if (!is.null(tool$deprecated$replacement)) {
      cli::cli_text("  Use {.fn {tool$deprecated$replacement}} instead")
    }
    if (!is.null(tool$deprecated$message)) {
      cli::cli_text("  {tool$deprecated$message}")
    }
    cli::cli_text("")
  }

  # Hints
  if (length(tool$hints) > 0) {
    cli::cli_h3("Hints")
    for (hint_name in names(tool$hints)) {
      cli::cli_text("  {hint_name}: {.val {tool$hints[[hint_name]]}}")
    }
    cli::cli_text("")
  }

  # Parameters
  if (length(tool$parameters) > 0) {
    cli::cli_h3("Parameters")
    for (param_name in names(tool$parameters)) {
      param <- tool$parameters[[param_name]]

      # Build parameter line
      req_label <- if (isTRUE(param$required)) "required" else "optional"
      type_label <- param$type %||% "any"

      cli::cli_text("  {.field {param_name}} ({type_label}, {req_label})")
      cli::cli_text("    {param$description}")

      if (!is.null(param$default)) {
        cli::cli_text("    Default: {.val {param$default}}")
      }

      if (!is.null(param$min)) {
        cli::cli_text("    Min: {.val {param$min}}")
      }

      if (!is.null(param$max)) {
        cli::cli_text("    Max: {.val {param$max}}")
      }

      if (!is.null(param$pattern)) {
        cli::cli_text("    Pattern: {.code {param$pattern}}")
      }

      if (!is.null(param$enum)) {
        cli::cli_text("    Allowed: {.val {param$enum}}")
      }
    }
    cli::cli_text("")
  }

  # Examples
  if (length(tool$examples) > 0) {
    cli::cli_h3("Examples")
    for (i in seq_along(tool$examples)) {
      example <- tool$examples[[i]]
      if (!is.null(example$description)) {
        cli::cli_text("{example$description}:")
      }
      cli::cli_code(example$code)
      if (i < length(tool$examples)) {
        cli::cli_text("")
      }
    }
  }

  cli::cli_rule()

  invisible(tool)
}

#' Run Tool Example
#'
#' @description Execute a tool's example code
#' @param tool_name Tool name
#' @param example_index Which example to run (default: 1)
#' @export
cassidy_tool_example <- function(tool_name, example_index = 1) {
  tool <- .get_tool_definition(tool_name)

  if (is.null(tool)) {
    cli::cli_abort("Tool not found: {.field {tool_name}}")
  }

  if (length(tool$examples) == 0) {
    cli::cli_abort("Tool {.field {tool_name}} has no examples")
  }

  if (example_index > length(tool$examples)) {
    cli::cli_abort(c(
      "x" = "Example index {example_index} out of range",
      "i" = "Tool has {length(tool$examples)} example{?s}"
    ))
  }

  example <- tool$examples[[example_index]]

  cli::cli_alert_info("Running example {example_index} for {.field {tool_name}}")
  if (!is.null(example$description)) {
    cli::cli_text("{example$description}")
  }
  cli::cli_text("")

  # Execute example code
  result <- tryCatch({
    eval(parse(text = example$code), envir = .GlobalEnv)
  }, error = function(e) {
    cli::cli_alert_danger("Example failed: {e$message}")
    return(NULL)
  })

  if (!is.null(result)) {
    cli::cli_alert_success("Example completed successfully")
    print(result)
  }

  invisible(result)
}
```

---

## Phase 2: Custom Tools System (3-4 hours)

**Goal:** User-defined tools from markdown files

### 2.1 Tool Discovery

**File:** `R/tools-discovery.R` (new file)

*[Implementation as specified in TOOL-IMPROVEMENT.md Phase 2.1]*

### 2.2 User-Facing Functions

**File:** `R/tools-user.R` (new file)

```r
#' Create a Custom Tool File
#'
#' @description Create a new custom tool from template (markdown file)
#' @param name Tool name (lowercase with hyphens)
#' @param location "project" or "personal"
#' @param template "basic", "file_operation", or "data_operation"
#' @param open Open in editor after creation
#' @export
cassidy_create_tool_file <- function(
  name,
  location = c("project", "personal"),
  template = c("basic", "file_operation", "data_operation"),
  open = interactive()
) {
  # Implementation for creating markdown tool files
  # (As specified in TOOL-ENHANCEMENT plan)
}

#' List Custom Tools
#' @export
cassidy_list_custom_tools <- function(location = c("all", "project", "personal")) {
  # Implementation
}

#' Validate Custom Tool
#' @export
cassidy_validate_tool <- function(name) {
  # Implementation
}

#' Refresh Tool Cache
#' @export
cassidy_refresh_tools <- function() {
  .get_all_tools(refresh = TRUE)
  cli::cli_alert_success("Tool cache refreshed")
  invisible(NULL)
}
```

---

## Phase 3: Tool Grouping & Discovery (1-2 hours)

**File:** `R/tools-discovery-helpers.R` (new file)

```r
#' List Tool Groups
#' @export
cassidy_tool_groups <- function() {
  # Implementation as in previous plan
}

#' Get Tools in a Group
#' @export
cassidy_tools_in_group <- function(group) {
  # Implementation
}

#' Get Detailed Tool Information
#' @export
cassidy_tool_info <- function(tool_name) {
  # Display tool info (simpler than cassidy_tool_help())
  tool <- .get_tool_definition(tool_name)

  if (is.null(tool)) {
    cli::cli_abort("Tool not found: {.field {tool_name}}")
  }

  cli::cli_rule(left = "Tool: {tool_name}")
  cli::cli_alert_info("Title: {.emph {tool$title}}")
  cli::cli_alert_info("Description: {.emph {tool$description}}")
  cli::cli_alert_info("Group: {.field {tool$group}}")
  cli::cli_alert_info("Risky: {.val {tool$risky}}")

  if (length(tool$parameters) > 0) {
    cli::cli_text("")
    cli::cli_h3("Parameters")
    for (param_name in names(tool$parameters)) {
      param <- tool$parameters[[param_name]]
      req <- if (param$required) "required" else "optional"
      cli::cli_text("  {.field {param_name}} ({param$type}, {req})")
    }
  }

  cli::cli_text("")
  cli::cli_text("Use {.run cassidy_tool_help('{tool_name}')} for full documentation")
  cli::cli_rule()

  invisible(tool)
}

#' Get Available Tools
#' @export
cassidy_available_tools <- function() {
  # Implementation
}
```

---

## Phase 4: Tool Calling in Chat (3-4 hours)

**Goal:** Enable `cassidy_chat()` to use tools interactively

### 4.1 Enhanced cassidy_chat()

**File:** `R/chat-core.R`

*[Implementation as specified in TOOL-IMPROVEMENT.md Phase 4.1]*

### 4.2 Tool Calling Loop

**File:** `R/chat-tools-loop.R`

*[Implementation as specified, with flexible format support]*

### 4.3 Claude-Optimized Prompts

**File:** `R/tools-prompts.R` (new file)

```r
#' Build Tool-Aware Message
#'
#' @description Build message with tool instructions optimized for Claude
#' @param message User message
#' @param context Context object
#' @param available_tools Tool names
#' @param mode "brief" or "detailed" documentation
#' @keywords internal
.build_tool_aware_message <- function(
  message,
  context,
  available_tools,
  mode = c("detailed", "brief")
) {
  mode <- match.arg(mode)

  # Get format preference
  format <- getOption("cassidy_tool_format", "pure_json")

  # Build tool documentation
  tool_docs <- .build_tool_documentation(available_tools, mode)

  # Build format instructions
  format_instructions <- switch(format,
    pure_json = .format_instructions_json(),
    xml_json = .format_instructions_xml_json(),
    markdown = .format_instructions_markdown()
  )

  # Combine
  paste0(
    "# Available Tools\n\n",
    tool_docs, "\n\n",
    format_instructions, "\n\n",
    if (!is.null(context)) paste0("# Context\n\n", context$text, "\n\n---\n\n"),
    "# User Question\n\n",
    message
  )
}

#' Build Tool Documentation
#'
#' @keywords internal
.build_tool_documentation <- function(available_tools, mode = c("detailed", "brief")) {
  mode <- match.arg(mode)

  all_tools <- .get_all_tools()

  # Auto-select mode based on number of tools
  if (mode == "brief" || length(available_tools) > 10) {
    # Brief mode: just signatures
    docs <- sapply(available_tools, function(name) {
      tool <- all_tools[[name]]
      if (is.null(tool)) return(paste0("- ", name))

      params <- names(tool$parameters)
      param_str <- if (length(params) > 0) {
        paste0("(", paste(params, collapse = ", "), ")")
      } else {
        "()"
      }

      paste0("- **", name, param_str, "**: ", tool$description)
    })
  } else {
    # Detailed mode: full docs
    docs <- sapply(available_tools, function(name) {
      tool <- all_tools[[name]]
      if (is.null(tool)) return(paste0("### ", name, "\n\nNo documentation available."))

      parts <- c(
        paste0("### ", name),
        paste0("**Description:** ", tool$description)
      )

      # Parameters
      if (length(tool$parameters) > 0) {
        parts <- c(parts, "**Parameters:**")
        for (pname in names(tool$parameters)) {
          param <- tool$parameters[[pname]]
          req <- if (param$required) " (required)" else " (optional)"
          parts <- c(parts, paste0("- `", pname, "` (", param$type, ")", req, ": ", param$description))
        }
      }

      # Hints
      if (length(tool$hints) > 0) {
        hint_parts <- character()
        if (isTRUE(tool$hints$read_only)) hint_parts <- c(hint_parts, "read-only")
        if (isTRUE(tool$hints$idempotent)) hint_parts <- c(hint_parts, "idempotent")
        if (length(hint_parts) > 0) {
          parts <- c(parts, paste0("**Hints:** ", paste(hint_parts, collapse = ", ")))
        }
      }

      # Example
      if (length(tool$examples) > 0 && !is.null(tool$examples[[1]]$code)) {
        parts <- c(parts, paste0("**Example:** `", tool$examples[[1]]$code, "`"))
      }

      paste(parts, collapse = "\n")
    })
  }

  paste(docs, collapse = "\n\n")
}

.format_instructions_json <- function() {
  paste0(
    "## Tool Usage Format\n\n",
    "To use a tool, respond with a JSON object:\n\n",
    "```json\n",
    "{\n",
    "  \"tool_decision\": {\n",
    "    \"action\": \"tool_name\",\n",
    "    \"input\": {\n",
    "      \"param1\": \"value1\",\n",
    "      \"param2\": \"value2\"\n",
    "    },\n",
    "    \"reasoning\": \"Why you're using this tool\",\n",
    "    \"status\": \"continue\"\n",
    "  }\n",
    "}\n",
    "```\n\n",
    "When you have the final answer, respond with:\n\n",
    "TASK COMPLETE: [your answer to the user]\n\n",
    "Do NOT wrap this in JSON - just provide your natural language response."
  )
}

.format_instructions_xml_json <- function() {
  paste0(
    "## Tool Usage Format\n\n",
    "To use a tool, respond with:\n\n",
    "<TOOL_DECISION>\n",
    "ACTION: tool_name\n",
    "INPUT: {\"param1\": \"value1\", \"param2\": \"value2\"}\n",
    "REASONING: Why you're using this tool\n",
    "STATUS: continue\n",
    "</TOOL_DECISION>\n\n",
    "When done:\n\n",
    "TASK COMPLETE: [your answer]"
  )
}

.format_instructions_markdown <- function() {
  paste0(
    "## Tool Usage Format\n\n",
    "To use a tool:\n\n",
    "<TOOL_DECISION>\n",
    "ACTION: tool_name\n",
    "REASONING: Why you're using this tool\n",
    "STATUS: continue\n\n",
    "## Parameters\n",
    "- param1: value1\n",
    "- param2: value2\n",
    "</TOOL_DECISION>\n\n",
    "When done:\n\n",
    "TASK COMPLETE: [your answer]"
  )
}
```

---

## Phase 5: Create Skill Tool (2 hours)

**File:** `R/tools-builtin.R`

Add `tool_create_skill()` function and register it.

*[Implementation as specified in TOOL-IMPROVEMENT.md Phase 5]*

---

## Phase 6: Update Agentic System (1 hour)

**File:** `R/agentic-chat.R`

*[Update to use `.get_all_tools()` and add dry_run mode as specified]*

---

## Phase 6.5: Tool-Aware Token Budgeting (2-3 hours)

**Goal:** Estimate and track token overhead for tools to improve context management

**Context:** Moved from context engineering system - makes more sense with enhanced tool metadata

### Why This Belongs Here

Tool overhead tracking integrates perfectly with the new tool system:
- **Enhanced metadata** - Add `token_overhead` field to tool definitions
- **Tool registry** - Centralized place to track overhead per tool
- **Validation system** - Check token budgets before tool execution
- **Tool documentation** - Include overhead in tool help/info

### 6.5.1 Add Token Overhead Metadata

**File:** `R/tools-registry.R`

Update `cassidy_create_tool()` to include token overhead:

```r
cassidy_create_tool <- function(
  name,
  title = NULL,
  description,
  handler,
  group = "custom",
  risky = FALSE,
  hints = list(),
  parameters = list(),
  examples = list(),
  tags = character(),
  deprecated = NULL,
  can_register = function() TRUE,
  token_overhead = NULL  # NEW: estimated tokens for tool definition
) {
  # ... validation ...

  # Auto-calculate token overhead if not provided
  if (is.null(token_overhead)) {
    token_overhead <- .estimate_single_tool_overhead(
      description = description,
      parameters = parameters,
      examples = examples
    )
  }

  structure(
    list(
      name = name,
      title = title %||% tools::toTitleCase(gsub("_", " ", name)),
      description = description,
      group = group,
      risky = risky,
      hints = hints,
      parameters = parameters,
      examples = examples,
      tags = tags,
      deprecated = deprecated,
      handler = handler,
      can_register = can_register,
      token_overhead = as.integer(token_overhead)  # NEW
    ),
    class = "cassidy_tool"
  )
}
```

### 6.5.2 Tool Overhead Estimation

**File:** `R/tools-overhead.R` (new file)

```r
#' Estimate token overhead for a single tool definition
#'
#' @description Calculate tokens needed to describe a tool to the LLM
#' @param description Tool description
#' @param parameters Parameter list
#' @param examples Example list
#' @return Integer token estimate
#' @keywords internal
.estimate_single_tool_overhead <- function(description, parameters, examples) {
  # Base overhead: tool name + description
  overhead <- cassidy_estimate_tokens(description)

  # Add parameter documentation
  if (length(parameters) > 0) {
    param_text <- paste(
      sapply(names(parameters), function(pname) {
        param <- parameters[[pname]]
        paste0(pname, " (", param$type, "): ", param$description)
      }),
      collapse = "\n"
    )
    overhead <- overhead + cassidy_estimate_tokens(param_text)
  }

  # Add first example if present (others usually not sent)
  if (length(examples) > 0 && !is.null(examples[[1]]$code)) {
    overhead <- overhead + cassidy_estimate_tokens(examples[[1]]$code)
  }

  # Add format overhead (10% for JSON structure, formatting, etc.)
  overhead <- ceiling(overhead * 1.1)

  as.integer(overhead)
}

#' Estimate total tool overhead for a set of tools
#'
#' @description Calculate total tokens needed for tool system + definitions
#' @param tool_names Character vector of tool names to include
#' @param include_results Logical. Whether to estimate tokens for tool results
#'   in history (requires session object)
#' @param session Optional cassidy_session object to count tool result tokens
#' @return Integer. Estimated token overhead
#' @keywords internal
.estimate_tool_overhead <- function(tool_names, include_results = FALSE, session = NULL) {
  all_tools <- .get_all_tools()

  # Base overhead for tool system instructions
  # (Instructions on how to use tools, format, etc.)
  base_overhead <- 500L

  # Sum individual tool overheads
  tool_overhead <- 0L
  for (tool_name in tool_names) {
    tool <- all_tools[[tool_name]]
    if (!is.null(tool) && !is.null(tool$token_overhead)) {
      tool_overhead <- tool_overhead + tool$token_overhead
    } else {
      # Fallback: assume 150 tokens per tool
      tool_overhead <- tool_overhead + 150L
    }
  }

  total_overhead <- base_overhead + tool_overhead

  # Optionally count tool results in history
  if (include_results && !is.null(session)) {
    tool_result_tokens <- 0L
    for (msg in session$messages) {
      if (!is.null(msg$is_tool_result) && msg$is_tool_result) {
        tool_result_tokens <- tool_result_tokens +
          (msg$tokens %||% cassidy_estimate_tokens(msg$content))
      }
    }
    total_overhead <- total_overhead + tool_result_tokens
  }

  as.integer(total_overhead)
}

#' Get tool overhead for display
#'
#' @description Get formatted tool overhead information
#' @param tool_names Character vector of tool names
#' @return List with overhead details
#' @export
cassidy_tool_overhead <- function(tool_names) {
  all_tools <- .get_all_tools()

  overhead_by_tool <- sapply(tool_names, function(name) {
    tool <- all_tools[[name]]
    if (!is.null(tool)) {
      list(
        name = name,
        overhead = tool$token_overhead %||% 150L,
        description = tool$description
      )
    } else {
      list(name = name, overhead = 150L, description = "Unknown tool")
    }
  }, simplify = FALSE)

  total_overhead <- .estimate_tool_overhead(tool_names)

  structure(
    list(
      tools = overhead_by_tool,
      base_overhead = 500L,
      total_overhead = total_overhead,
      tool_count = length(tool_names)
    ),
    class = "cassidy_tool_overhead"
  )
}

#' @export
print.cassidy_tool_overhead <- function(x, ...) {
  cli::cli_h2("Tool Overhead Estimate")

  cli::cli_text("Base system overhead: {format(x$base_overhead, big.mark = ',')} tokens")
  cli::cli_text("")

  cli::cli_h3("Individual Tools ({x$tool_count})")
  for (tool in x$tools) {
    cli::cli_text(
      "  {.field {tool$name}}: {format(tool$overhead, big.mark = ',')} tokens"
    )
  }
  cli::cli_text("")

  cli::cli_text(
    "{.strong Total overhead}: {format(x$total_overhead, big.mark = ',')} tokens"
  )

  pct <- round(100 * x$total_overhead / 200000, 1)
  cli::cli_text("({pct}% of 200k token limit)")

  invisible(x)
}
```

### 6.5.3 Update Built-in Tools with Overhead

**File:** `R/tools-builtin.R`

Add token overhead estimates to all built-in tools:

```r
.register_builtin_tools <- function() {
  # Read file - simple tool, low overhead
  cassidy_register_tool(cassidy_create_tool(
    name = "read_file",
    title = "Read File",
    description = "Read contents of a file",
    handler = tool_read_file,
    group = "files",
    risky = FALSE,
    hints = list(read_only = TRUE, idempotent = TRUE),
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
    examples = list(
      list(
        code = 'read_file("script.R")',
        description = "Read an R script"
      )
    ),
    tags = c("io", "read"),
    token_overhead = 120L  # NEW: Manually calibrated or auto-calculated
  ))

  # Write file - slightly higher overhead (more parameters)
  cassidy_register_tool(cassidy_create_tool(
    name = "write_file",
    title = "Write File",
    description = "Write content to a file",
    handler = tool_write_file,
    group = "files",
    risky = TRUE,
    hints = list(read_only = FALSE, idempotent = FALSE),
    parameters = list(
      filepath = list(
        type = "string",
        description = "Path to write to",
        required = TRUE
      ),
      content = list(
        type = "string",
        description = "Content to write",
        required = TRUE
      ),
      working_dir = list(
        type = "string",
        description = "Working directory",
        required = FALSE,
        default = "getwd()"
      )
    ),
    tags = c("io", "write"),
    token_overhead = 150L  # NEW
  ))

  # ... similar for all other tools
}
```

### 6.5.4 Integrate with Agentic System

**File:** `R/agentic-chat.R`

Update `cassidy_agentic_task()` to track tool overhead:

```r
cassidy_agentic_task <- function(
  task,
  assistant_id = Sys.getenv("CASSIDY_ASSISTANT_ID"),
  api_key = Sys.getenv("CASSIDY_API_KEY"),
  tools = names(.cassidy_tools),
  working_dir = getwd(),
  max_iterations = 10,
  initial_context = NULL,
  safe_mode = TRUE,
  approval_callback = NULL,
  verbose = TRUE
) {
  # ... existing validation ...

  # NEW: Estimate tool overhead
  tool_overhead <- .estimate_tool_overhead(tools)

  if (verbose) {
    cli::cli_alert_info(
      "Tool overhead: {format(tool_overhead, big.mark = ',')} tokens ({length(tools)} tools)"
    )
  }

  # Reserve headroom for tools in messages
  # (This information could be passed to context gathering functions
  #  so they know how much space they have available)
  effective_context_limit <- 200000L - tool_overhead - 10000L  # Reserve 10k for response

  # ... rest of function ...

  # Track tool overhead in result
  result$tool_overhead <- tool_overhead
  result$effective_limit <- effective_context_limit

  result
}
```

### 6.5.5 Show Tool Overhead in Help

**File:** `R/tools-help.R`

Update `cassidy_tool_help()` to show overhead:

```r
cassidy_tool_help <- function(tool_name) {
  tool <- .get_tool_definition(tool_name)

  # ... existing code ...

  # NEW: Show token overhead
  if (!is.null(tool$token_overhead)) {
    cli::cli_text("")
    cli::cli_alert_info(
      "Token overhead: {format(tool$token_overhead, big.mark = ',')} tokens"
    )
    cli::cli_text(
      "{.emph (Tokens needed to describe this tool to the LLM)}"
    )
  }

  # ... rest of function ...
}
```

### 6.5.6 Integration with Console Chat

**File:** `R/chat-core.R`

When tools are used in `cassidy_chat()`, track overhead:

```r
chat.cassidy_session <- function(x, message, tools = NULL, ...) {
  # ... existing code ...

  # NEW: If tools are active, add overhead to token estimate
  if (!is.null(tools) && length(tools) > 0) {
    tool_overhead <- .estimate_tool_overhead(tools)
    x$tool_overhead <- tool_overhead

    # Warn if tools consume significant context
    if (tool_overhead > 20000) {  # >10% of limit
      cli::cli_alert_warning(
        "Tools consume {format(tool_overhead, big.mark = ',')} tokens ({round(100 * tool_overhead / 200000)}%)"
      )
    }
  }

  # ... rest of function ...
}
```

### Testing

**File:** `tests/testthat/test-tools-overhead.R`

```r
test_that("tool overhead estimation works", {
  # Single tool
  overhead <- .estimate_single_tool_overhead(
    description = "Read a file",
    parameters = list(
      path = list(type = "string", description = "File path", required = TRUE)
    ),
    examples = list()
  )

  expect_type(overhead, "integer")
  expect_gt(overhead, 0)
  expect_lt(overhead, 500)  # Reasonable upper bound
})

test_that("multiple tool overhead sums correctly", {
  tools <- c("read_file", "write_file", "list_files")
  overhead <- .estimate_tool_overhead(tools)

  expect_type(overhead, "integer")
  expect_gt(overhead, 500)  # At least base overhead
})

test_that("cassidy_tool_overhead formats correctly", {
  result <- cassidy_tool_overhead(c("read_file", "write_file"))

  expect_s3_class(result, "cassidy_tool_overhead")
  expect_equal(result$tool_count, 2)
  expect_true(result$total_overhead > 0)
})
```

### Documentation

Add to tool vignette:

```markdown
## Tool Token Overhead

When using tools, the AI assistant needs to know what tools are available.
This information consumes tokens from your context budget.

### Understanding Overhead

- **Base overhead**: ~500 tokens for tool system instructions
- **Per-tool overhead**: 100-200 tokens per tool (varies by complexity)
- **Tool results**: Variable (depends on what the tool returns)

### Checking Overhead

```r
# See overhead for specific tools
cassidy_tool_overhead(c("read_file", "write_file", "execute_code"))

# Output:
# Tool Overhead Estimate
# Base system overhead: 500 tokens
#
# Individual Tools (3)
#   read_file: 120 tokens
#   write_file: 150 tokens
#   execute_code: 180 tokens
#
# Total overhead: 950 tokens (0.5% of 200k token limit)
```

### Best Practices

1. **Limit tool count**: Only enable tools you actually need
2. **Tool presets**: Use presets (read_only, code_generation) to avoid loading all tools
3. **Monitor overhead**: Check `cassidy_tool_overhead()` for large tool sets
4. **Context budgeting**: Reserve tokens for tools when gathering context
```

---

## Phase 7: Testing (3-4 hours)

### Test Files

1. **Format testing:**
   - `tests/manual/test-tool-formats.R` - Compare three formats

2. **Enhanced tools:**
   - `tests/testthat/test-tools-registry.R` - Registration system
   - `tests/testthat/test-tools-validation.R` - Type validation, rules
   - `tests/testthat/test-tools-creation.R` - cassidy_create_tool(), from_roxygen2
   - `tests/testthat/test-tools-help.R` - Help system

3. **Custom tools:**
   - `tests/testthat/test-tools-custom.R` - Discovery from markdown
   - `tests/testthat/test-tools-grouping.R` - Grouping functions

4. **Chat with tools:**
   - `tests/testthat/test-chat-tools.R` - Tool calling in chat
   - `tests/manual/test-chat-tools-live.R` - Live testing

---

## Phase 8: Documentation (2-3 hours)

1. Update roxygen2 docs for all new functions
2. Create vignette: `vignettes/creating-tools.Rmd`
3. Update README with tool system examples
4. Update NEWS.md
5. Update `.claude/rules/file-structure.md`
6. Update `.claude/rules/roadmap.md`

---

## Implementation Timeline

| Phase | Description | Time | Cumulative |
|-------|-------------|------|------------|
| 0 | Tool architecture refactor | 3-4h | 3-4h |
| 0.5 | Format testing | 2-3h | 5-7h |
| 1 | Enhanced tool foundation | 4-5h | 9-12h |
| 2 | Custom tools system | 3-4h | 12-16h |
| 3 | Tool grouping & discovery | 1-2h | 13-18h |
| 4 | Tool calling in chat | 3-4h | 16-22h |
| 5 | Create skill tool | 2h | 18-24h |
| 6 | Update agentic system | 1h | 19-25h |
| 7 | Testing | 3-4h | 22-29h |
| 8 | Documentation | 2-3h | 24-32h |

**Total: 24-32 hours**

---

## Key Features Summary

### Tool Creation Methods

1. **Programmatic (in R code):**
   ```r
   tool <- cassidy_create_tool(
     name = "my_tool",
     description = "Does something",
     handler = function(x) { x * 2 },
     parameters = list(...)
   )
   cassidy_register_tool(tool)
   ```

2. **From roxygen2:**
   ```r
   #' My Function
   #' @param x A number
   my_func <- function(x) { x * 2 }

   tool <- cassidy_tool_from_roxygen2(my_func, risky = FALSE)
   cassidy_register_tool(tool)
   ```

3. **From markdown file:**
   ```r
   cassidy_create_tool_file("my-tool", location = "project")
   # Edit .cassidy/tools/my-tool.md
   cassidy_refresh_tools()
   ```

### Enhanced Metadata

- **Title, description, group**
- **Parameters with advanced validation** (type, min, max, pattern, enum)
- **Examples** with code and descriptions
- **Tags** for categorization
- **Hints** for LLM (read_only, idempotent)
- **Deprecation** support with migration paths
- **can_register()** for conditional availability

### Discovery & Help

- `cassidy_list_tools()` - All tools with groups
- `cassidy_tool_groups()` - List groups
- `cassidy_tools_in_group("files")` - Filter by group
- `cassidy_tool_info("tool_name")` - Quick info
- `cassidy_tool_help("tool_name")` - Comprehensive help
- `cassidy_tool_example("tool_name")` - Run example

### Format Flexibility

Three INPUT formats tested:
1. XML-style with JSON INPUT (current)
2. Pure JSON (likely winner with Claude)
3. Markdown-style (most readable)

Parser tries all three, falls back to inference.

### Claude Optimizations

- Context-aware documentation (brief vs detailed)
- Clear format instructions with examples
- Prompt engineering for reliability
- ~200k character limit awareness

---

## Success Criteria

- [ ] All existing tests pass
- [ ] Tool architecture refactored (separate functions)
- [ ] Format testing complete with winner chosen
- [ ] `cassidy_create_tool()` works programmatically
- [ ] `cassidy_tool_from_roxygen2()` auto-generates metadata
- [ ] Enhanced metadata on all built-in tools
- [ ] Custom tools discoverable from `.cassidy/tools/`
- [ ] Advanced validation (type, min, max, pattern, enum)
- [ ] Tool help system functional
- [ ] Tool grouping functions work
- [ ] `cassidy_chat()` can use tools
- [ ] Tool calling loop respects max iterations
- [ ] Safe mode approval works in chat
- [ ] `create_skill` tool creates valid skills
- [ ] Agentic system uses enhanced tools
- [ ] All documentation complete
- [ ] `devtools::check()` passes

---

## Migration Path

**For existing code:**
- All existing agentic code works unchanged
- Existing `.cassidy_tools` can be converted gradually
- New registry automatically includes old tools

**Converting old tools:**
```r
# Old (still works):
.cassidy_tools$read_file

# New (better):
tool_read_file <- function(...) { }
cassidy_register_tool(cassidy_create_tool(
  name = "read_file",
  handler = tool_read_file,
  ...
))
```

**Timeline:**
1. Phase 0 adds new architecture alongside old
2. Phase 1-6 build on new architecture
3. Phase 7+ migrate built-in tools incrementally
4. Old `.cassidy_tools` deprecated in future version
