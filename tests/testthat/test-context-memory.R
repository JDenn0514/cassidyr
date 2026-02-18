# Tests for memory file operations

test_that("memory directory is created automatically", {
  # Get memory dir (should create it)
  memory_dir <- cassidyr:::.get_memory_dir()

  expect_true(fs::dir_exists(memory_dir))
  expect_match(as.character(memory_dir), "cassidyr")
})

test_that("path validation prevents directory traversal", {
  # Test various traversal attempts
  expect_error(
    cassidyr:::.validate_memory_path("../etc/passwd"),
    "directory traversal"
  )

  expect_error(
    cassidyr:::.validate_memory_path("foo/../../etc/passwd"),
    "directory traversal"
  )

  expect_error(
    cassidyr:::.validate_memory_path("foo/../../../etc/passwd"),
    "directory traversal"
  )
})

test_that("path validation prevents URL-encoded traversal", {
  # Test URL-encoded traversal attempts
  expect_error(
    cassidyr:::.validate_memory_path("%2e%2e/passwd"),
    "URL-encoded traversal"
  )

  expect_error(
    cassidyr:::.validate_memory_path("foo/%2E%2E/passwd"),
    "URL-encoded traversal"
  )
})

test_that("path validation rejects empty paths", {
  expect_error(
    cassidyr:::.validate_memory_path(""),
    "Path cannot be empty"
  )

  expect_error(
    cassidyr:::.validate_memory_path(NULL),
    "Path cannot be empty"
  )
})

test_that("path validation accepts valid paths", {
  # These should not error
  expect_no_error(cassidyr:::.validate_memory_path("test.md"))
  expect_no_error(cassidyr:::.validate_memory_path("folder/test.md"))
  expect_no_error(cassidyr:::.validate_memory_path("a/b/c/test.md"))
})

test_that("cassidy_list_memory_files works with empty directory", {
  # Clean memory directory for testing
  memory_dir <- cassidyr:::.get_memory_dir()
  existing_files <- fs::dir_ls(memory_dir, recurse = TRUE, type = "file")
  if (length(existing_files) > 0) {
    fs::file_delete(existing_files)
  }

  files <- cassidy_list_memory_files()

  expect_s3_class(files, "data.frame")
  expect_equal(nrow(files), 0)
  expect_named(files, c("path", "size", "modified", "size_human"))
})

test_that("cassidy_write_memory_file creates files", {
  withr::defer({
    # Cleanup
    tryCatch(
      cassidy_delete_memory_file("test.md"),
      error = function(e) NULL
    )
  })

  # Write a file
  path <- cassidy_write_memory_file("test.md", "# Test\n\nContent here")

  expect_true(fs::file_exists(path))

  # Verify content
  content <- readLines(path, warn = FALSE)
  expect_equal(content[1], "# Test")
  expect_equal(content[3], "Content here")
})

test_that("cassidy_write_memory_file creates subdirectories", {
  withr::defer({
    # Cleanup
    tryCatch(
      cassidy_delete_memory_file("subfolder/test.md"),
      error = function(e) NULL
    )
  })

  # Write to subdirectory
  path <- cassidy_write_memory_file("subfolder/test.md", "Content")

  expect_true(fs::file_exists(path))
  expect_match(as.character(path), "subfolder")
})

test_that("cassidy_read_memory_file reads files", {
  withr::defer({
    tryCatch(
      cassidy_delete_memory_file("read_test.md"),
      error = function(e) NULL
    )
  })

  # Write then read
  cassidy_write_memory_file("read_test.md", "Line 1\nLine 2\nLine 3")
  content <- cassidy_read_memory_file("read_test.md")

  expect_type(content, "character")
  expect_match(content, "Line 1")
  expect_match(content, "Line 2")
  expect_match(content, "Line 3")
})

test_that("cassidy_read_memory_file errors for missing files", {
  expect_error(
    cassidy_read_memory_file("nonexistent.md"),
    "not found"
  )
})

test_that("cassidy_delete_memory_file removes files", {
  withr::defer({
    tryCatch(
      cassidy_delete_memory_file("delete_test.md"),
      error = function(e) NULL
    )
  })

  # Write then delete
  path <- cassidy_write_memory_file("delete_test.md", "Content")
  expect_true(fs::file_exists(path))

  cassidy_delete_memory_file("delete_test.md")
  expect_false(fs::file_exists(path))
})

test_that("cassidy_delete_memory_file errors for missing files", {
  expect_error(
    cassidy_delete_memory_file("nonexistent.md"),
    "not found"
  )
})

test_that("cassidy_rename_memory_file moves files", {
  withr::defer({
    tryCatch({
      cassidy_delete_memory_file("rename_old.md")
      cassidy_delete_memory_file("rename_new.md")
    }, error = function(e) NULL)
  })

  # Write then rename
  cassidy_write_memory_file("rename_old.md", "Content")
  cassidy_rename_memory_file("rename_old.md", "rename_new.md")

  memory_dir <- cassidyr:::.get_memory_dir()
  old_path <- fs::path(memory_dir, "rename_old.md")
  new_path <- fs::path(memory_dir, "rename_new.md")

  expect_false(fs::file_exists(old_path))
  expect_true(fs::file_exists(new_path))
})

test_that("cassidy_rename_memory_file moves to subdirectories", {
  withr::defer({
    tryCatch({
      cassidy_delete_memory_file("move_test.md")
      cassidy_delete_memory_file("archive/move_test.md")
    }, error = function(e) NULL)
  })

  # Write then move to subdirectory
  cassidy_write_memory_file("move_test.md", "Content")
  cassidy_rename_memory_file("move_test.md", "archive/move_test.md")

  memory_dir <- cassidyr:::.get_memory_dir()
  old_path <- fs::path(memory_dir, "move_test.md")
  new_path <- fs::path(memory_dir, "archive", "move_test.md")

  expect_false(fs::file_exists(old_path))
  expect_true(fs::file_exists(new_path))
})

test_that("cassidy_rename_memory_file errors for missing files", {
  expect_error(
    cassidy_rename_memory_file("nonexistent.md", "new.md"),
    "not found"
  )
})

test_that("cassidy_rename_memory_file errors for existing destination", {
  withr::defer({
    tryCatch({
      cassidy_delete_memory_file("existing1.md")
      cassidy_delete_memory_file("existing2.md")
    }, error = function(e) NULL)
  })

  # Create two files
  cassidy_write_memory_file("existing1.md", "Content 1")
  cassidy_write_memory_file("existing2.md", "Content 2")

  # Try to rename over existing file
  expect_error(
    cassidy_rename_memory_file("existing1.md", "existing2.md"),
    "already exists"
  )
})

test_that("cassidy_list_memory_files shows files with metadata", {
  withr::defer({
    tryCatch({
      cassidy_delete_memory_file("list_test1.md")
      cassidy_delete_memory_file("list_test2.md")
    }, error = function(e) NULL)
  })

  # Create some files
  cassidy_write_memory_file("list_test1.md", "Short content")
  cassidy_write_memory_file("list_test2.md", paste(rep("Long content", 100), collapse = "\n"))

  files <- cassidy_list_memory_files()

  expect_s3_class(files, "data.frame")
  expect_gt(nrow(files), 0)
  expect_true("list_test1.md" %in% files$path)
  expect_true("list_test2.md" %in% files$path)

  # Check metadata columns
  expect_true("size" %in% names(files))
  expect_true("modified" %in% names(files))
  expect_true("size_human" %in% names(files))

  # Verify size_human formatting
  expect_match(files$size_human[1], "B$|K$|M$")
})

test_that("cassidy_format_memory_listing works with empty directory", {
  # Clean memory directory
  memory_dir <- cassidyr:::.get_memory_dir()
  existing_files <- fs::dir_ls(memory_dir, recurse = TRUE, type = "file")
  if (length(existing_files) > 0) {
    fs::file_delete(existing_files)
  }

  listing <- cassidy_format_memory_listing()

  expect_type(listing, "character")
  expect_match(listing, "No memory files yet")
})

test_that("cassidy_format_memory_listing shows file info", {
  withr::defer({
    tryCatch({
      cassidy_delete_memory_file("format_test.md")
    }, error = function(e) NULL)
  })

  # Create a file
  cassidy_write_memory_file("format_test.md", "Test content")

  listing <- cassidy_format_memory_listing()

  expect_type(listing, "character")
  expect_match(listing, "Memory Directory")
  expect_match(listing, "format_test.md")
  expect_match(listing, "(ago|just now)")  # Time ago format or "just now"
  expect_match(listing, "Use the memory tool")
})

test_that("memory tool is registered in agentic tools", {
  tools <- names(cassidyr:::.cassidy_tools)

  expect_true("memory" %in% tools)

  # Check tool properties
  memory_tool <- cassidyr:::.cassidy_tools$memory
  expect_false(memory_tool$risky)
  expect_true("handler" %in% names(memory_tool))
  expect_true("parameters" %in% names(memory_tool))
})

test_that("memory tool view command works", {
  withr::defer({
    tryCatch({
      cassidy_delete_memory_file("tool_test.md")
    }, error = function(e) NULL)
  })

  # Create a test file
  cassidy_write_memory_file("tool_test.md", "Content")

  # Execute view command
  result <- cassidyr:::.cassidy_tools$memory$handler(command = "view")

  expect_type(result, "character")
  expect_match(result, "Memory Directory")
  expect_match(result, "tool_test.md")
})

test_that("memory tool read command works", {
  withr::defer({
    tryCatch({
      cassidy_delete_memory_file("read_tool_test.md")
    }, error = function(e) NULL)
  })

  # Create and read via tool
  cassidy_write_memory_file("read_tool_test.md", "Test content\nLine 2")

  result <- cassidyr:::.cassidy_tools$memory$handler(
    command = "read",
    path = "read_tool_test.md"
  )

  expect_type(result, "character")
  expect_match(result, "File: read_tool_test.md")
  expect_match(result, "Test content")
  expect_match(result, "Line 2")
})

test_that("memory tool write command works", {
  withr::defer({
    tryCatch({
      cassidy_delete_memory_file("write_tool_test.md")
    }, error = function(e) NULL)
  })

  # Write via tool
  result <- cassidyr:::.cassidy_tools$memory$handler(
    command = "write",
    path = "write_tool_test.md",
    content = "Written by tool"
  )

  expect_match(result, "written")

  # Verify content
  content <- cassidy_read_memory_file("write_tool_test.md")
  expect_equal(content, "Written by tool")
})

test_that("memory tool delete command works", {
  withr::defer({
    tryCatch({
      cassidy_delete_memory_file("delete_tool_test.md")
    }, error = function(e) NULL)
  })

  # Create then delete via tool
  cassidy_write_memory_file("delete_tool_test.md", "Content")

  result <- cassidyr:::.cassidy_tools$memory$handler(
    command = "delete",
    path = "delete_tool_test.md"
  )

  expect_match(result, "deleted")

  # Verify deletion
  memory_dir <- cassidyr:::.get_memory_dir()
  path <- fs::path(memory_dir, "delete_tool_test.md")
  expect_false(fs::file_exists(path))
})

test_that("memory tool rename command works", {
  withr::defer({
    tryCatch({
      cassidy_delete_memory_file("rename_tool_old.md")
      cassidy_delete_memory_file("rename_tool_new.md")
    }, error = function(e) NULL)
  })

  # Create and rename via tool
  cassidy_write_memory_file("rename_tool_old.md", "Content")

  result <- cassidyr:::.cassidy_tools$memory$handler(
    command = "rename",
    path = "rename_tool_old.md",
    new_path = "rename_tool_new.md"
  )

  expect_match(result, "renamed")

  # Verify rename
  memory_dir <- cassidyr:::.get_memory_dir()
  old_path <- fs::path(memory_dir, "rename_tool_old.md")
  new_path <- fs::path(memory_dir, "rename_tool_new.md")
  expect_false(fs::file_exists(old_path))
  expect_true(fs::file_exists(new_path))
})

test_that("memory tool validates commands", {
  expect_error(
    cassidyr:::.cassidy_tools$memory$handler(command = "invalid"),
    "Invalid memory command"
  )
})

test_that("memory tool requires path for read/write/delete/rename", {
  expect_error(
    cassidyr:::.cassidy_tools$memory$handler(command = "read"),
    "'path' parameter required"
  )

  expect_error(
    cassidyr:::.cassidy_tools$memory$handler(command = "write", path = "test.md"),
    "'content' parameter required"
  )

  expect_error(
    cassidyr:::.cassidy_tools$memory$handler(command = "delete"),
    "'path' parameter required"
  )

  expect_error(
    cassidyr:::.cassidy_tools$memory$handler(command = "rename", path = "old.md"),
    "'new_path' parameter required"
  )
})

test_that("memory listing is included in project context", {
  withr::defer({
    tryCatch({
      cassidy_delete_memory_file("context_test.md")
    }, error = function(e) NULL)
  })

  # Create a memory file
  cassidy_write_memory_file("context_test.md", "Test content")

  # Get project context without config to avoid truncation
  ctx <- cassidy_context_project(
    level = "minimal",
    include_memory = TRUE,
    include_config = FALSE,
    include_skills = FALSE
  )

  expect_match(ctx$text, "Memory Directory")
  expect_match(ctx$text, "context_test.md")
})

test_that("memory listing can be excluded from project context", {
  withr::defer({
    tryCatch({
      cassidy_delete_memory_file("exclude_test.md")
    }, error = function(e) NULL)
  })

  # Create a memory file
  cassidy_write_memory_file("exclude_test.md", "Test content")

  # Get context without memory
  ctx <- cassidy_context_project(
    level = "minimal",
    include_memory = FALSE,
    include_config = FALSE,
    include_skills = FALSE
  )

  expect_false(grepl("Memory Directory", ctx$text))
  expect_false(grepl("exclude_test.md", ctx$text))
})
