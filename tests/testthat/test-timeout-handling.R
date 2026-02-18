# Tests for Timeout Management System (Phase 9)

test_that("complex task detection works", {
  expect_true(.is_complex_task("Create a detailed implementation plan"))
  expect_true(.is_complex_task("Comprehensive analysis of the system"))
  expect_true(.is_complex_task("Provide step by step instructions"))
  expect_true(.is_complex_task("Design the architecture for this"))
  expect_true(.is_complex_task("Thoroughly analyze the codebase"))

  expect_false(.is_complex_task("What is 2+2?"))
  expect_false(.is_complex_task("Hello"))
  expect_false(.is_complex_task("Fix this bug"))
  expect_false(.is_complex_task("Explain this function"))
})

test_that("input size validation categorizes correctly", {
  small <- paste(rep("a", 1000), collapse = "")
  medium <- paste(rep("a", 150000), collapse = "")
  large <- paste(rep("a", 300000), collapse = "")

  expect_equal(.validate_message_size(small, warn = FALSE)$risk, "low")
  expect_equal(.validate_message_size(medium, warn = FALSE)$risk, "medium")
  expect_equal(.validate_message_size(large, warn = FALSE)$risk, "high")
})

test_that("input size validation returns correct size", {
  test_text <- paste(rep("x", 50000), collapse = "")
  result <- .validate_message_size(test_text, warn = FALSE)

  expect_equal(result$size, 50000)
  expect_equal(result$risk, "low")
})

test_that("chunking guidance is added to complex tasks", {
  simple <- "Hello"
  complex <- "Create a comprehensive implementation plan"

  simple_result <- .add_chunking_guidance(simple)
  complex_result <- .add_chunking_guidance(complex)

  expect_equal(simple_result, simple)
  expect_match(complex_result, "incrementally")
  expect_match(complex_result, "outline")
  expect_true(nchar(complex_result) > nchar(complex))
})

test_that("chunking guidance is not added to simple tasks", {
  messages <- c(
    "What time is it?",
    "Fix this typo",
    "Explain this code",
    "Help me debug"
  )

  for (msg in messages) {
    result <- .add_chunking_guidance(msg)
    expect_equal(result, msg)
  }
})

test_that("timeout prevention prompt returns text", {
  prompt <- .timeout_prevention_prompt()

  expect_type(prompt, "character")
  expect_true(nchar(prompt) > 0)
  expect_match(prompt, "Response Delivery Guidelines")
  expect_match(prompt, "incrementally")
})

test_that("timeout retry prompt returns text", {
  prompt <- .timeout_retry_prompt()

  expect_type(prompt, "character")
  expect_true(nchar(prompt) > 0)
  expect_match(prompt, "IMPORTANT")
  expect_match(prompt, "timed out")
  expect_match(prompt, "Original task")
})

test_that("timeout error patterns constant is defined", {
  expect_true(exists(".CASSIDY_TIMEOUT_ERROR_PATTERNS"))
  expect_type(.CASSIDY_TIMEOUT_ERROR_PATTERNS, "character")
  expect_true(length(.CASSIDY_TIMEOUT_ERROR_PATTERNS) > 0)
  expect_true("524" %in% .CASSIDY_TIMEOUT_ERROR_PATTERNS)
})

test_that("input threshold constants are defined", {
  expect_true(exists(".CASSIDY_LARGE_INPUT_THRESHOLD"))
  expect_true(exists(".CASSIDY_VERY_LARGE_INPUT_THRESHOLD"))

  expect_type(.CASSIDY_LARGE_INPUT_THRESHOLD, "integer")
  expect_type(.CASSIDY_VERY_LARGE_INPUT_THRESHOLD, "integer")

  expect_true(.CASSIDY_LARGE_INPUT_THRESHOLD < .CASSIDY_VERY_LARGE_INPUT_THRESHOLD)
})

test_that("validate_message_size handles edge cases", {
  # Empty message
  expect_equal(.validate_message_size("", warn = FALSE)$risk, "low")

  # Exactly at threshold
  threshold_text <- paste(rep("a", .CASSIDY_LARGE_INPUT_THRESHOLD), collapse = "")
  result <- .validate_message_size(threshold_text, warn = FALSE)
  expect_true(result$risk %in% c("low", "medium"))

  # Just over threshold
  over_threshold <- paste(rep("a", .CASSIDY_LARGE_INPUT_THRESHOLD + 1), collapse = "")
  result <- .validate_message_size(over_threshold, warn = FALSE)
  expect_equal(result$risk, "medium")
})

test_that("complex task detection is case insensitive", {
  expect_true(.is_complex_task("IMPLEMENTATION PLAN"))
  expect_true(.is_complex_task("Implementation Plan"))
  expect_true(.is_complex_task("implementation plan"))
})

test_that("complex task detection handles partial matches", {
  expect_true(.is_complex_task("I need an implementation plan for authentication"))
  expect_true(.is_complex_task("Can you do a comprehensive analysis?"))
  expect_true(.is_complex_task("Create detailed documentation"))
})
