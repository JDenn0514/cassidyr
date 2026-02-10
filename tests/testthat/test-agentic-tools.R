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
