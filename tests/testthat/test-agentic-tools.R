# ══════════════════════════════════════════════════════════════════════════════
# AGENTIC TOOLS TESTS
# Tests for tool registry and execution
# ══════════════════════════════════════════════════════════════════════════════

test_that("Tool registry is properly defined", {
  expect_true(is.list(.cassidy_tools))
  expect_gt(length(.cassidy_tools), 0)

  # Check expected tools exist
  expected_tools <- c(
    "read_file", "write_file", "execute_code",
    "list_files", "search_files", "get_context", "describe_data"
  )
  expect_true(all(expected_tools %in% names(.cassidy_tools)))
})

test_that("Each tool has required structure", {
  for (tool_name in names(.cassidy_tools)) {
    tool <- .cassidy_tools[[tool_name]]

    # Check required fields
    expect_true("description" %in% names(tool),
                info = paste("Tool", tool_name, "missing description"))
    expect_true("risky" %in% names(tool),
                info = paste("Tool", tool_name, "missing risky flag"))
    expect_true("handler" %in% names(tool),
                info = paste("Tool", tool_name, "missing handler"))

    # Check types
    expect_type(tool$description, "character")
    expect_type(tool$risky, "logical")
    expect_type(tool$handler, "closure")
  }
})

test_that("Risky tools are identified correctly", {
  expect_true(.is_risky_tool("write_file"))
  expect_true(.is_risky_tool("execute_code"))
  expect_false(.is_risky_tool("read_file"))
  expect_false(.is_risky_tool("list_files"))
  expect_false(.is_risky_tool("search_files"))
  expect_false(.is_risky_tool("get_context"))
  expect_false(.is_risky_tool("describe_data"))
})

test_that(".is_risky_tool() handles unknown tools", {
  expect_false(.is_risky_tool("nonexistent_tool"))
})

test_that("Tool execution handles errors gracefully", {
  withr::with_tempdir({
    result <- .execute_tool(
      "read_file",
      list(filepath = "nonexistent.R"),
      working_dir = getwd()
    )

    expect_false(result$success)
    expect_true("error" %in% names(result))
    expect_type(result$error, "character")
  })
})

test_that("list_files tool works correctly", {
  withr::with_tempdir({
    # Create test files
    writeLines("test1", "test1.txt")
    writeLines("test2", "test2.txt")
    dir.create("subdir")
    writeLines("test3", "subdir/test3.txt")

    result <- .execute_tool(
      "list_files",
      list(directory = "."),
      working_dir = getwd()
    )

    expect_true(result$success)
    expect_type(result$result, "character")
    expect_match(result$result, "test1.txt")
    expect_match(result$result, "test2.txt")
  })
})

test_that("list_files tool handles patterns", {
  withr::with_tempdir({
    # Create test files
    writeLines("r code", "test.R")
    writeLines("text", "test.txt")

    result <- .execute_tool(
      "list_files",
      list(directory = ".", pattern = "\\.R$"),
      working_dir = getwd()
    )

    expect_true(result$success)
    expect_match(result$result, "test.R")
    expect_no_match(result$result, "test.txt")
  })
})

test_that("write_file tool creates files", {
  withr::with_tempdir({
    result <- .execute_tool(
      "write_file",
      list(filepath = "test.txt", content = "Hello, World!"),
      working_dir = getwd()
    )

    expect_true(result$success)
    expect_true(file.exists("test.txt"))
    expect_equal(readLines("test.txt"), "Hello, World!")
  })
})

test_that("write_file tool creates directories if needed", {
  withr::with_tempdir({
    result <- .execute_tool(
      "write_file",
      list(filepath = "subdir/test.txt", content = "Nested file"),
      working_dir = getwd()
    )

    expect_true(result$success)
    expect_true(file.exists("subdir/test.txt"))
  })
})

test_that("read_file tool reads files", {
  withr::with_tempdir({
    writeLines(c("Line 1", "Line 2", "Line 3"), "test.txt")

    result <- .execute_tool(
      "read_file",
      list(filepath = "test.txt"),
      working_dir = getwd()
    )

    expect_true(result$success)
    expect_match(result$result, "Line 1")
    expect_match(result$result, "Line 2")
  })
})

test_that("execute_code tool runs R code", {
  result <- .execute_tool(
    "execute_code",
    list(code = "2 + 2")
  )

  expect_true(result$success)
  expect_match(result$result, "4")
})

test_that("execute_code tool captures errors", {
  result <- .execute_tool(
    "execute_code",
    list(code = "stop('Test error')")
  )

  expect_false(result$success)
  expect_match(result$error, "Test error")
})

test_that("search_files tool finds matches", {
  withr::with_tempdir({
    writeLines(c("Hello world", "Goodbye world"), "file1.txt")
    writeLines(c("No match here"), "file2.txt")

    result <- .execute_tool(
      "search_files",
      list(pattern = "world", directory = "."),
      working_dir = getwd()
    )

    expect_true(result$success)
    expect_match(result$result, "file1.txt")
    expect_match(result$result, "Hello world")
  })
})

test_that(".get_tool_info returns correct structure", {
  info <- .get_tool_info("read_file")

  expect_type(info, "list")
  expect_equal(info$name, "read_file")
  expect_type(info$description, "character")
  expect_type(info$risky, "logical")
  expect_type(info$parameters, "list")
})

test_that(".get_tool_info handles unknown tools", {
  info <- .get_tool_info("nonexistent_tool")
  expect_null(info)
})

test_that("Tool execution validates tool existence", {
  result <- .execute_tool("nonexistent_tool", list())

  expect_false(result$success)
  expect_match(result$error, "Unknown tool")
})

# ══════════════════════════════════════════════════════════════════════════════
# Additional Tool Tests
# ══════════════════════════════════════════════════════════════════════════════

test_that("get_context tool executes successfully", {
  result <- .execute_tool(
    "get_context",
    list(level = "minimal"),
    working_dir = getwd()
  )

  expect_true(result$success)
  expect_type(result$result, "character")
  expect_gt(nchar(result$result), 0)
})

test_that("get_context tool handles different levels", {
  # Test minimal level
  result_min <- .execute_tool(
    "get_context",
    list(level = "minimal")
  )
  expect_true(result_min$success)

  # Test standard level
  result_std <- .execute_tool(
    "get_context",
    list(level = "standard")
  )
  expect_true(result_std$success)

  # Standard should have at least as much content as minimal
  # (may be equal in test environment with minimal project structure)
  expect_gte(nchar(result_std$result), nchar(result_min$result))
})

test_that("describe_data tool works with data frames", {
  # Create test data in global environment
  test_df <- data.frame(
    x = 1:10,
    y = letters[1:10],
    z = rnorm(10)
  )
  assign("test_df", test_df, envir = .GlobalEnv)

  result <- .execute_tool(
    "describe_data",
    list(name = "test_df", method = "basic")
  )

  expect_true(result$success)
  expect_type(result$result, "character")
  expect_match(result$result, "x|y|z")

  # Cleanup
  rm("test_df", envir = .GlobalEnv)
})

test_that("describe_data tool errors on non-existent object", {
  result <- .execute_tool(
    "describe_data",
    list(name = "nonexistent_df")
  )

  expect_false(result$success)
  expect_match(result$error, "Object not found")
})

test_that("describe_data tool errors on non-data-frame", {
  # Create non-data-frame object
  assign("not_a_df", "just a string", envir = .GlobalEnv)

  result <- .execute_tool(
    "describe_data",
    list(name = "not_a_df")
  )

  expect_false(result$success)
  expect_match(result$error, "not a data frame")

  # Cleanup
  rm("not_a_df", envir = .GlobalEnv)
})

test_that("describe_data tool handles different methods", {
  test_df <- data.frame(x = 1:5, y = 6:10)
  assign("test_df", test_df, envir = .GlobalEnv)

  # Test basic method
  result_basic <- .execute_tool(
    "describe_data",
    list(name = "test_df", method = "basic")
  )
  expect_true(result_basic$success)

  # Test skim method (if skimr available)
  result_skim <- .execute_tool(
    "describe_data",
    list(name = "test_df", method = "skim")
  )
  expect_true(result_skim$success)

  # Cleanup
  rm("test_df", envir = .GlobalEnv)
})

# ══════════════════════════════════════════════════════════════════════════════
# Edge Cases and Error Handling
# ══════════════════════════════════════════════════════════════════════════════

test_that("list_files handles empty directory", {
  withr::with_tempdir({
    result <- .execute_tool(
      "list_files",
      list(directory = ".")
    )

    # Should succeed but return no files message
    expect_true(result$success)
    expect_match(result$result, "No files found")
  })
})

test_that("list_files handles non-existent directory", {
  result <- .execute_tool(
    "list_files",
    list(directory = "/nonexistent/path/12345")
  )

  expect_false(result$success)
  expect_match(result$error, "Directory not found")
})

test_that("list_files accepts 'path' parameter as alias", {
  withr::with_tempdir({
    writeLines("test", "file.txt")

    result <- .execute_tool(
      "list_files",
      list(path = ".")
    )

    expect_true(result$success)
    expect_match(result$result, "file.txt")
  })
})

test_that("read_file handles file not found", {
  result <- .execute_tool(
    "read_file",
    list(filepath = "/nonexistent/file.R")
  )

  expect_false(result$success)
  expect_match(result$error, "File not found")
})

test_that("read_file handles R files with cassidy_describe_file", {
  withr::with_tempdir({
    # Create a simple R file
    writeLines(c(
      "# Test function",
      "test_func <- function(x) {",
      "  x + 1",
      "}"
    ), "test.R")

    result <- .execute_tool(
      "read_file",
      list(filepath = "test.R"),
      working_dir = getwd()
    )

    expect_true(result$success)
    expect_match(result$result, "test_func")
  })
})

test_that("read_file falls back to plain text for non-R files", {
  withr::with_tempdir({
    writeLines(c("Line 1", "Line 2"), "test.txt")

    result <- .execute_tool(
      "read_file",
      list(filepath = "test.txt"),
      working_dir = getwd()
    )

    expect_true(result$success)
    expect_match(result$result, "Line 1")
    expect_match(result$result, "Line 2")
  })
})

test_that("write_file handles nested directory creation", {
  withr::with_tempdir({
    result <- .execute_tool(
      "write_file",
      list(
        filepath = "a/b/c/deep.txt",
        content = "Deep nested file"
      ),
      working_dir = getwd()
    )

    expect_true(result$success)
    expect_true(file.exists("a/b/c/deep.txt"))
    expect_equal(readLines("a/b/c/deep.txt"), "Deep nested file")
  })
})

test_that("write_file overwrites existing files", {
  withr::with_tempdir({
    # Create initial file
    writeLines("Original", "test.txt")

    # Overwrite it
    result <- .execute_tool(
      "write_file",
      list(filepath = "test.txt", content = "Updated"),
      working_dir = getwd()
    )

    expect_true(result$success)
    expect_equal(readLines("test.txt"), "Updated")
  })
})

test_that("execute_code captures both output and result", {
  result <- .execute_tool(
    "execute_code",
    list(code = "print('Hello'); 42")
  )

  expect_true(result$success)
  expect_match(result$result, "Hello")
  expect_match(result$result, "42")
})

test_that("execute_code handles multi-line code", {
  code <- "x <- 1:5
y <- x * 2
sum(y)"

  result <- .execute_tool("execute_code", list(code = code))

  expect_true(result$success)
  expect_match(result$result, "30")
})

test_that("execute_code isolates environment", {
  # Code should not affect global environment
  result <- .execute_tool(
    "execute_code",
    list(code = "isolated_var <- 999")
  )

  expect_true(result$success)
  expect_false(exists("isolated_var", envir = .GlobalEnv))
})

test_that("search_files handles no matches", {
  withr::with_tempdir({
    writeLines(c("Hello world"), "file1.txt")

    result <- .execute_tool(
      "search_files",
      list(pattern = "nonexistent", directory = ".")
    )

    expect_true(result$success)
    expect_match(result$result, "No matches found")
  })
})

test_that("search_files handles file_pattern parameter", {
  withr::with_tempdir({
    writeLines("R code", "test.R")
    writeLines("Text content", "test.txt")

    result <- .execute_tool(
      "search_files",
      list(
        pattern = "code|content",
        directory = ".",
        file_pattern = "\\.R$"
      )
    )

    expect_true(result$success)
    expect_match(result$result, "test.R")
    # Should not match .txt file
    expect_no_match(result$result, "test.txt")
  })
})

test_that("search_files handles non-existent directory", {
  result <- .execute_tool(
    "search_files",
    list(pattern = "test", directory = "/nonexistent/path")
  )

  expect_false(result$success)
  expect_match(result$error, "Directory not found")
})

test_that("search_files handles empty directory", {
  withr::with_tempdir({
    result <- .execute_tool(
      "search_files",
      list(pattern = "test", directory = ".")
    )

    expect_true(result$success)
    expect_match(result$result, "No files to search")
  })
})

test_that("search_files skips unreadable files gracefully", {
  withr::with_tempdir({
    # Create a regular file
    writeLines("searchable content", "file1.txt")

    result <- .execute_tool(
      "search_files",
      list(pattern = "searchable", directory = ".")
    )

    # Should find the readable file
    expect_true(result$success)
    expect_match(result$result, "file1.txt")
  })
})

test_that("Tool execution adds working_dir when supported", {
  withr::with_tempdir({
    writeLines("content", "test.txt")

    # read_file supports working_dir parameter
    result <- .execute_tool(
      "read_file",
      list(filepath = "test.txt"),
      working_dir = getwd()
    )

    expect_true(result$success)
    expect_match(result$result, "content")
  })
})

test_that("Tool execution handles absolute paths", {
  withr::with_tempdir({
    full_path <- file.path(getwd(), "test.txt")
    writeLines("absolute path test", full_path)

    result <- .execute_tool(
      "read_file",
      list(filepath = full_path),
      working_dir = getwd()
    )

    expect_true(result$success)
    expect_match(result$result, "absolute path test")
  })
})

test_that("Tool registry has parameters defined", {
  for (tool_name in names(.cassidy_tools)) {
    tool <- .cassidy_tools[[tool_name]]

    # Parameters can be NULL or a list
    expect_true(
      is.null(tool$parameters) || is.list(tool$parameters),
      info = paste("Tool", tool_name, "has invalid parameters")
    )
  }
})
