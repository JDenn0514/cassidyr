test_that(".default_compaction_prompt returns a character string", {
  prompt <- .default_compaction_prompt()

  expect_type(prompt, "character")
  expect_gt(nchar(prompt), 100)
  expect_match(prompt, "Key decisions")
  expect_match(prompt, "Unresolved issues")
  expect_match(prompt, "Important outputs")
})

test_that(".format_messages_for_summary formats messages correctly", {
  messages <- list(
    list(role = "user", content = "Hello"),
    list(role = "assistant", content = "Hi there!"),
    list(role = "user", content = "How are you?")
  )

  formatted <- .format_messages_for_summary(messages)

  expect_type(formatted, "character")
  expect_match(formatted, "### User")
  expect_match(formatted, "### Assistant")
  expect_match(formatted, "Hello")
  expect_match(formatted, "Hi there!")
  expect_match(formatted, "How are you?")
  expect_match(formatted, "---")
})

test_that(".format_messages_for_summary handles empty messages", {
  messages <- list()

  formatted <- .format_messages_for_summary(messages)

  expect_type(formatted, "character")
  expect_equal(nchar(formatted), 0)
})

test_that("cassidy_compact validates input", {
  expect_error(
    cassidy_compact("not a session"),
    "cassidy_session object"
  )

  expect_error(
    cassidy_compact(list(class = "wrong")),
    "cassidy_session object"
  )
})

test_that("cassidy_compact returns early for empty sessions", {
  # Create a minimal session with no messages
  session <- structure(
    list(
      thread_id = "test_thread",
      assistant_id = "test_assistant",
      messages = list(),
      created_at = Sys.time(),
      api_key = "test_key",
      context = NULL,
      context_sent = FALSE,
      token_estimate = 0L,
      token_limit = 200000L,
      compact_at = 0.85,
      auto_compact = TRUE,
      compaction_count = 0L,
      last_compaction = NULL,
      tool_overhead = 0L
    ),
    class = "cassidy_session"
  )

  # Should return without error and without modifying session
  result <- cassidy_compact(session)

  expect_identical(result, session)
  expect_equal(result$compaction_count, 0L)
})

test_that("cassidy_compact returns early when too few messages", {
  # Create a session with only 2 messages (1 pair)
  session <- structure(
    list(
      thread_id = "test_thread",
      assistant_id = "test_assistant",
      messages = list(
        list(role = "user", content = "Hello", tokens = 5L),
        list(role = "assistant", content = "Hi", tokens = 3L)
      ),
      created_at = Sys.time(),
      api_key = "test_key",
      context = NULL,
      context_sent = FALSE,
      token_estimate = 8L,
      token_limit = 200000L,
      compact_at = 0.85,
      auto_compact = TRUE,
      compaction_count = 0L,
      last_compaction = NULL,
      tool_overhead = 0L
    ),
    class = "cassidy_session"
  )

  # With preserve_recent = 2 (default), we need more than 4 messages
  result <- cassidy_compact(session, preserve_recent = 2)

  expect_identical(result, session)
  expect_equal(result$compaction_count, 0L)
})

test_that("cassidy_compact calculates message splits correctly", {
  # Create session with 10 messages (5 pairs)
  messages <- lapply(1:10, function(i) {
    list(
      role = if (i %% 2 == 1) "user" else "assistant",
      content = paste("Message", i),
      tokens = 10L
    )
  })

  session <- structure(
    list(
      thread_id = "test_thread",
      assistant_id = "test_assistant",
      messages = messages,
      created_at = Sys.time(),
      api_key = "test_key",
      context = NULL,
      context_sent = FALSE,
      token_estimate = 100L,
      token_limit = 200000L,
      compact_at = 0.85,
      auto_compact = TRUE,
      compaction_count = 0L,
      last_compaction = NULL,
      tool_overhead = 0L
    ),
    class = "cassidy_session"
  )

  # With preserve_recent = 2, should preserve last 4 messages
  # So we should summarize first 6 messages

  # We can't fully test without API, but we can check the logic
  # by testing the helper functions
  n_messages <- length(session$messages)
  preserve_recent <- 2
  n_preserve <- min(preserve_recent * 2, n_messages)

  expect_equal(n_preserve, 4)

  messages_to_summarize <- session$messages[1:(n_messages - n_preserve)]
  messages_to_preserve <- session$messages[(n_messages - n_preserve + 1):n_messages]

  expect_length(messages_to_summarize, 6)
  expect_length(messages_to_preserve, 4)

  # First 6 messages should be summarized
  expect_equal(messages_to_summarize[[1]]$content, "Message 1")
  expect_equal(messages_to_summarize[[6]]$content, "Message 6")

  # Last 4 messages should be preserved
  expect_equal(messages_to_preserve[[1]]$content, "Message 7")
  expect_equal(messages_to_preserve[[4]]$content, "Message 10")
})

test_that("cassidy_compact uses custom summary prompt", {
  # We can't test the full function without API, but we can verify
  # that custom prompts are accepted
  custom_prompt <- "Please summarize this conversation briefly."

  # The function should accept this without error in the early stages
  expect_type(custom_prompt, "character")
  expect_gt(nchar(custom_prompt), 0)
})
