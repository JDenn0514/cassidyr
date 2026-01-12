# Helper file - loaded before all tests run

#' Create a fake API key for testing
fake_api_key <- function() {
  "test_api_key_12345"
}

#' Create a fake assistant ID for testing
fake_assistant_id <- function() {
  "asst_test_12345"
}

#' Create a fake thread ID for testing
fake_thread_id <- function() {
  "thread_test_12345"
}

#' Set up test environment variables
setup_test_env <- function() {
  withr::local_envvar(
    CASSIDY_API_KEY = fake_api_key(),
    CASSIDY_ASSISTANT_ID = fake_assistant_id()
  )
}

#' Clean up test environment
teardown_test_env <- function() {
  withr::defer(Sys.unsetenv(c("CASSIDY_API_KEY", "CASSIDY_ASSISTANT_ID")))
}
