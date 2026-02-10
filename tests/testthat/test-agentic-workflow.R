# ══════════════════════════════════════════════════════════════════════════════
# AGENTIC WORKFLOW TESTS
# Tests for workflow integration (without calling real API)
# ══════════════════════════════════════════════════════════════════════════════

test_that(".call_tool_workflow validates webhook URL", {
  withr::local_envvar(CASSIDY_WORKFLOW_WEBHOOK = "")

  expect_error(
    .call_tool_workflow(
      reasoning = "Test reasoning",
      available_tools = c("read_file", "list_files")
    ),
    "Workflow webhook URL not found"
  )
})

test_that("cassidy_setup_workflow displays instructions", {
  # Just test that it runs without error
  expect_no_error(cassidy_setup_workflow())
})

test_that("cassidy_setup_workflow returns invisibly", {
  result <- cassidy_setup_workflow()
  expect_null(result)
})

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
  prompt <- .build_agentic_prompt("/home/user/project", 10)

  expect_type(prompt, "character")
  expect_match(prompt, "/home/user/project")
  expect_match(prompt, "10 iterations")
  expect_match(prompt, "expert R programming assistant")
})
