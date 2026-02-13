# Package Usage Patterns

This guide documents **how to use** the package dependencies in cassidyr. Follow these patterns to ensure consistency across the codebase.

---

## File System Operations

### Use `fs` package for project files

**Use `fs::` functions** for file-system operations

```r
# ✅ CORRECT - Use fs package
if (fs::file_exists(path)) {
  size <- fs::file_size(path)
  files <- fs::dir_ls(path, recurse = TRUE, regexp = "\\.R$")
  new_path <- fs::path(dir, filename)
}

# ✅ CORRECT - Use base R for reading/writing file content
lines <- readLines(path)
writeLines(lines, new_path)
```

---

## Git Operations

### Always use `gert` package

**DO NOT use system calls** - always use `gert::` functions:

```r
# ✅ CORRECT - Use gert
status <- gert::git_status(repo = ".")
branch <- gert::git_branch(repo = ".")
info <- gert::git_info(repo = ".")
commits <- gert::git_log(max = 10, repo = ".")

# ❌ DO NOT DO THIS - System calls
system("git status")
system2("git", c("log", "-10"))
```

**Why:** System git calls are unreliable across platforms and environments. `gert` provides consistent, programmatic access to git functionality.

---

## HTTP Requests

### Use `httr2` with pipe pattern

Follow the established pipe pattern for HTTP operations:

```r
# ✅ CORRECT - httr2 with pipes
resp <- httr2::request(base_url) |>
  httr2::req_headers(
    `x-api-key` = api_key,
    `Content-Type` = "application/json"
  ) |>
  httr2::req_body_json(body_data) |>
  httr2::req_retry(
    max_tries = 3,
    is_transient = function(resp) {
      httr2::resp_status(resp) %in% c(429, 503, 504)
    }
  ) |>
  httr2::req_timeout(120) |>
  httr2::req_error(body = function(resp) {
    body <- httr2::resp_body_json(resp)
    body$message %||% "Unknown API error"
  }) |>
  httr2::req_perform()

# Extract response
result <- httr2::resp_body_json(resp)
```

**Key patterns:**
- Always use pipe `|>` for chaining requests
- Include retry logic for transient errors
- Set reasonable timeouts
- Provide custom error messages
- Use `resp_body_json()` for JSON responses

---

## User-Facing Messages

### Use `cli` package for all messages

**Errors with context:**

```r
# ✅ CORRECT - Informative errors
cli::cli_abort(c(
  "x" = "File not found: {.file {path}}",
  "i" = "Check that the path is correct",
  "i" = "Use {.fn list.files} to see available files"
))

# With multiple issues
cli::cli_abort(c(
  "!" = "CASSIDY_API_KEY not found.",
  "i" = "Set it with {.run cassidy_setup()} or in .Renviron",
  "i" = "Run {.run usethis::edit_r_environ()} to edit your environment"
))
```

**Warnings:**

```r
# ✅ CORRECT - Warnings with context
cli::cli_warn(c(
  "!" = "Could not load {.val {filename}}",
  "i" = "Continuing with remaining files"
))
```

**Informational messages:**

```r
# ✅ CORRECT - User feedback
cli::cli_alert_success("File saved to {.path {output_path}}")
cli::cli_alert_info("Processing {length(files)} files")
cli::cli_alert_warning("Large file detected: {.file {filename}}")

# Headers and sections
cli::cli_h1("Main Title")
cli::cli_h2("Section Title")
```

**Format helpers:**
- `{.file {path}}` - file paths
- `{.path {directory}}` - directory paths
- `{.fn function_name}` - function names
- `{.val {value}}` - values/variables
- `{.run code}` - runnable code
- `{.code text}` - inline code

---

## Package Availability Checks

### Use `rlang` functions

**For required packages** (prompts user to install):

```r
# ✅ CORRECT - Required package
rlang::check_installed("shiny", reason = "to use cassidy_app()")
rlang::check_installed("rstudioapi", reason = "to open files in RStudio")
```

**For optional/conditional features:**

```r
# ✅ CORRECT - Conditional check
if (rlang::is_installed("rstudioapi")) {
  # Use RStudio-specific features
  rstudioapi::navigateToFile(path)
} else {
  # Fallback behavior
  message("Open file manually: ", path)
}

# Check multiple packages
if (rlang::is_installed("base64enc") && rlang::is_installed("htmltools")) {
  # Use both packages
}
```

---

## JSON Operations

### Use `jsonlite` for JSON

**Parsing JSON:**

```r
# ✅ CORRECT - Parse JSON
data <- jsonlite::fromJSON(json_string, simplifyVector = FALSE)
```

**Creating JSON:**

```r
# ✅ CORRECT - Generate JSON
json <- jsonlite::toJSON(
  data,
  pretty = TRUE,
  auto_unbox = TRUE
)
```

**Common parameters:**
- `simplifyVector = FALSE` - Keep as lists (useful for nested data)
- `pretty = TRUE` - Format with indentation (for readability)
- `auto_unbox = TRUE` - Convert length-1 vectors to scalars

---

## Default Values

### Use `%||%` operator

The `%||%` operator (defined in `utils.R`) provides NULL-coalescing:

```r
# ✅ CORRECT - Default values
value <- user_input %||% default_value
title <- conv$title %||% "Untitled"
updated_at <- conv$updated_at %||% conv$created_at
thread_id <- result$thread_id %||% NA_character_

# Equivalent to:
if (is.null(user_input)) user_input <- default_value
```

**When to use:**
- Setting default values for NULL inputs
- Providing fallbacks for optional fields
- Simplifying NULL checks

---

## S3 Print Methods

### Standard pattern for print methods

All S3 classes should follow this pattern:

```r
#' @export
print.cassidy_object <- function(x, ...) {
  # Use cli for formatted output (goes to stderr)
  cli::cli_h1("Object Type")
  cli::cli_alert_info("Key: {x$key}")
  cli::cli_alert_info("Status: {x$status}")

  # Use cat() for actual content (goes to stdout)
  if (!is.null(x$content)) {
    cat("\n")
    cat(x$content, "\n")
  }

  # Always return invisibly
  invisible(x)
}
```

**Key points:**
- `cli::` functions write to **stderr** (formatting/metadata)
- `cat()` writes to **stdout** (actual content)
- Always return `invisible(x)` so object doesn't print twice
- Use appropriate `cli` functions for structure (`cli_h1`, `cli_alert_*`)

---

## String Operations

### Use `paste0()` for concatenation

```r
# ✅ CORRECT - Use paste0()
message <- paste0("File: ", filename, " (", size, " KB)")
path <- paste0(dir, "/", filename)

# ✅ CORRECT - Use paste() with collapse
all_items <- paste(items, collapse = "\n")
formatted <- paste(items, collapse = ", ")

# ❌ AVOID - sprintf()
message <- sprintf("File: %s (%s KB)", filename, size)
```

**When to use which:**
- `paste0()` - Concatenating strings (no separator)
- `paste()` with `collapse =` - Joining vectors into single string
- `paste()` with `sep =` - Joining with separator between elements

---

## Non-

## Summary Table

| Operation | Package | Use When |
|-----------|---------|----------|
| File exists check | `fs::file_exists()` | Project file operations |
| List files | `fs::dir_ls()` | Project file discovery |
| File size | `fs::file_size()` | Getting file metadata |
| Path construction | `fs::path()` | Building file paths |
| Directory ops | `dir.exists()`, `dir.create()` | Simple directory checks |
| Read/write text | `readLines()`, `writeLines()` | Text file I/O |
| Git operations | `gert::git_*()` | All git operations |
| HTTP requests | `httr2::request()` | API calls |
| Error messages | `cli::cli_abort()` | Throwing errors |
| Warnings | `cli::cli_warn()` | Non-fatal issues |
| Info messages | `cli::cli_alert_*()` | User feedback |
| Check package | `rlang::check_installed()` | Required packages |
| Test package | `rlang::is_installed()` | Optional features |
| Parse JSON | `jsonlite::fromJSON()` | Reading JSON |
| Create JSON | `jsonlite::toJSON()` | Writing JSON |
| Default values | `%||%` | NULL-coalescing |
| String concat | `paste0()` | Joining strings |
| Vector join | `paste(collapse=)` | Vector to string |

---

## Quick Reference

```r
# File operations
fs::file_exists(path)
fs::dir_ls(path, recurse = TRUE, regexp = "\\.R$")
fs::path(dir, file)
fs::file_size(path)

# Git operations
gert::git_status()
gert::git_branch()
gert::git_log(max = 10)

# HTTP
httr2::request(url) |> httr2::req_perform()

# Messages
cli::cli_abort(c("x" = "Error", "i" = "Info"))
cli::cli_warn("Warning")
cli::cli_alert_success("Success!")

# Packages
rlang::check_installed("pkg", reason = "for feature")
if (rlang::is_installed("pkg")) { }

# JSON
jsonlite::fromJSON(json)
jsonlite::toJSON(data, pretty = TRUE)

# Defaults
value <- x %||% default

# Strings
paste0("a", "b", "c")
paste(vec, collapse = "\n")
```
