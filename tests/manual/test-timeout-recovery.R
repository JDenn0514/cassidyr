# Manual Test: Timeout Recovery System
# Phase 9 of Context Engineering System
#
# This script tests timeout handling with real API calls.
# Run manually with your own API credentials.
#
# Usage:
#   source("tests/manual/test-timeout-recovery.R")
#   test_timeout_recovery()

test_timeout_recovery <- function() {
  library(cassidyr)

  cli::cli_h1("Timeout Recovery System - Manual Tests")
  cli::cli_text("")
  cli::cli_alert_info("Testing timeout detection and retry logic")
  cli::cli_text("")

  # Test 1: Complex planning task (may timeout)
  cli::cli_rule("Test 1: Complex Planning Task")
  cli::cli_text("This test sends a complex task that might require extended thinking time.")
  cli::cli_text("")

  session <- cassidy_session()

  tryCatch(
    {
      result <- chat(
        session,
        paste0(
          "Create a detailed implementation plan for a new authentication system ",
          "with the following features:\n",
          "- OAuth 2.0 integration (Google, GitHub, Microsoft)\n",
          "- JWT-based session management\n",
          "- Refresh token rotation\n",
          "- Role-based access control (RBAC)\n",
          "- Multi-factor authentication (MFA)\n",
          "- Security considerations and best practices\n",
          "- Database schema design\n",
          "- API endpoint specifications\n",
          "- Error handling and validation\n",
          "- Testing strategy"
        )
      )
      cli::cli_alert_success("Response received without timeout")
    },
    error = function(e) {
      cli::cli_alert_danger("Error occurred: {e$message}")
    }
  )

  cli::cli_text("")

  # Test 2: Large input (may timeout with very large size)
  cli::cli_rule("Test 2: Large Input Test")
  cli::cli_text("This test sends a large input to check size validation.")
  cli::cli_text("")

  # Create a large but not extreme input (150k chars)
  large_text <- paste(
    "Analyze the following text for patterns:",
    paste(rep("The quick brown fox jumps over the lazy dog. ", 3000), collapse = "")
  )

  size_info <- .validate_message_size(large_text, warn = TRUE)
  cli::cli_text("Input size: {format(size_info$size, big.mark = ',')} characters")
  cli::cli_text("Risk level: {size_info$risk}")
  cli::cli_text("")

  tryCatch(
    {
      result <- chat(
        session,
        large_text
      )
      cli::cli_alert_success("Response received without timeout")
    },
    error = function(e) {
      cli::cli_alert_danger("Error occurred: {e$message}")
    }
  )

  cli::cli_text("")

  # Test 3: Complex task detection
  cli::cli_rule("Test 3: Complex Task Detection")
  cli::cli_text("Testing automatic detection of complex tasks.")
  cli::cli_text("")

  test_messages <- list(
    list(
      msg = "What is 2+2?",
      expected = FALSE
    ),
    list(
      msg = "Create a comprehensive implementation plan",
      expected = TRUE
    ),
    list(
      msg = "Provide a detailed architectural design",
      expected = TRUE
    ),
    list(
      msg = "Fix this typo",
      expected = FALSE
    )
  )

  for (test_case in test_messages) {
    is_complex <- .is_complex_task(test_case$msg)
    status <- if (is_complex == test_case$expected) "\u2713" else "\u2717"
    cli::cli_text(
      "{status} '{substr(test_case$msg, 1, 40)}...' -> Complex: {is_complex}"
    )
  }

  cli::cli_text("")

  # Test 4: Chunking guidance
  cli::cli_rule("Test 4: Chunking Guidance Application")
  cli::cli_text("Testing automatic chunking guidance for complex tasks.")
  cli::cli_text("")

  simple_msg <- "Hello"
  complex_msg <- "Create a detailed implementation plan"

  simple_result <- .add_chunking_guidance(simple_msg)
  complex_result <- .add_chunking_guidance(complex_msg)

  cli::cli_text("Simple message: {nchar(simple_result)} chars (unchanged: {simple_result == simple_msg})")
  cli::cli_text("Complex message: {nchar(complex_result)} chars (guidance added: {simple_result != complex_msg})")
  cli::cli_text("")

  # Display prompts
  cli::cli_rule("Timeout Prevention Prompt")
  cat(.timeout_prevention_prompt())
  cat("\n\n")

  cli::cli_rule("Timeout Retry Prompt")
  cat(.timeout_retry_prompt())
  cat("\n\n")

  # Summary
  cli::cli_rule("Test Summary")
  cli::cli_text("All timeout handling tests completed.")
  cli::cli_text("")
  cli::cli_alert_info(
    "If timeouts occurred, the system should have automatically retried with chunking guidance."
  )
  cli::cli_text("")

  invisible(session)
}

# Example usage for interactive testing
if (interactive()) {
  cli::cli_alert_info("To run tests: test_timeout_recovery()")
}
