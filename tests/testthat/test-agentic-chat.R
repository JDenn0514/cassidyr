# ══════════════════════════════════════════════════════════════════════════════
# AGENTIC SYSTEM TESTS
# Tests for agentic task execution and results (without calling real API)
# ══════════════════════════════════════════════════════════════════════════════

test_that("Print method for cassidy_agentic_result works", {
  result <- structure(
    list(
      task = "Test task",
      final_response = "Task completed successfully",
      iterations = 3,
      actions_taken = list(
        list(
          iteration = 1,
          action = "list_files",
          input = list(directory = "."),
          result = "file1.R\nfile2.R",
          success = TRUE
        ),
        list(
          iteration = 2,
          action = "read_file",
          input = list(filepath = "file1.R"),
          result = "# R code here",
          success = TRUE
        )
      ),
      thread_id = "thread_123",
      success = TRUE
    ),
    class = "cassidy_agentic_result"
  )

  # Test that print method returns invisibly
  printed <- print(result)
  expect_identical(printed, result)
})

test_that("cassidy_agentic_task validates inputs", {
  expect_error(
    cassidy_agentic_task(task = ""),
    "Task cannot be empty"
  )

  withr::local_envvar(CASSIDY_ASSISTANT_ID = "")
  expect_error(
    cassidy_agentic_task(task = "Test"),
    "Assistant ID not found"
  )
})

test_that(".build_agentic_prompt creates system prompt", {
  prompt <- .build_agentic_prompt("/home/user/project", 10, c("read_file", "write_file"))

  expect_type(prompt, "character")
  expect_match(prompt, "/home/user/project")
  expect_match(prompt, "10 iterations")
  expect_match(prompt, "expert R programming assistant")
  expect_match(prompt, "read_file")
  expect_match(prompt, "write_file")
})

test_that(".build_agentic_prompt handles unlimited iterations", {
  prompt <- .build_agentic_prompt("/test", Inf, c("read_file"))

  expect_match(prompt, "unlimited iterations")
})

test_that("Print method for cassidy_agentic_result handles failures", {
  result <- structure(
    list(
      task = "Failed task",
      final_response = "Task incomplete",
      iterations = 5,
      actions_taken = list(
        list(
          iteration = 1,
          action = "read_file",
          input = list(filepath = "missing.R"),
          result = "File not found",
          success = FALSE
        )
      ),
      thread_id = "thread_456",
      success = FALSE
    ),
    class = "cassidy_agentic_result"
  )

  # Should handle failed actions
  expect_no_error(print(result))
})

test_that("Print method handles empty actions_taken", {
  result <- structure(
    list(
      task = "Quick task",
      final_response = "Done",
      iterations = 0,
      actions_taken = list(),
      thread_id = "thread_789",
      success = TRUE
    ),
    class = "cassidy_agentic_result"
  )

  expect_no_error(print(result))
})

