test_that("cassidy_estimate_tokens works correctly", {
  # Basic estimation
  text <- "Hello world"
  tokens <- cassidy_estimate_tokens(text)
  expect_type(tokens, "integer")
  expect_gt(tokens, 0)

  # Empty text
  expect_equal(cassidy_estimate_tokens(""), 0L)
  expect_equal(cassidy_estimate_tokens(NULL), 0L)
  expect_equal(cassidy_estimate_tokens(character(0)), 0L)

  # Different methods
  text <- paste(rep("test", 100), collapse = " ")
  fast <- cassidy_estimate_tokens(text, method = "fast")
  conservative <- cassidy_estimate_tokens(text, method = "conservative")
  optimistic <- cassidy_estimate_tokens(text, method = "optimistic")

  expect_gt(conservative, fast)
  expect_lt(optimistic, fast)
})

test_that("token limits are defined correctly", {
  expect_equal(.CASSIDY_TOKEN_LIMIT, 200000L)
  expect_equal(.CASSIDY_DEFAULT_COMPACT_AT, 0.85)
  expect_equal(.CASSIDY_WARNING_AT, 0.80)
  expect_equal(.CASSIDY_CHAR_LIMIT_SINGLE, 250000L)
  expect_equal(.CASSIDY_CHAR_LIMIT_THREAD, 585000L)
})

test_that("cassidy_estimate_session_tokens counts correctly", {
  # Create mock session
  session <- structure(
    list(
      context = list(text = paste(rep("word", 100), collapse = " ")),
      context_sent = TRUE,
      messages = list(
        list(role = "user", content = "Hello"),
        list(role = "assistant", content = "Hi there!")
      )
    ),
    class = "cassidy_session"
  )

  tokens <- cassidy_estimate_session_tokens(session)
  expect_type(tokens, "integer")
  expect_gt(tokens, 0)

  # Session without context sent
  session2 <- structure(
    list(
      context = list(text = paste(rep("word", 100), collapse = " ")),
      context_sent = FALSE,
      messages = list(
        list(role = "user", content = "Hello")
      )
    ),
    class = "cassidy_session"
  )

  tokens2 <- cassidy_estimate_session_tokens(session2)
  expect_type(tokens2, "integer")
  expect_gt(tokens2, 0)
  expect_lt(tokens2, tokens)  # Should be less without context
})

test_that("safety_factor parameter works correctly", {
  text <- "This is a test message"

  # Default safety factor (1.15)
  default_tokens <- cassidy_estimate_tokens(text)

  # No safety factor
  no_safety <- cassidy_estimate_tokens(text, safety_factor = 1.0)

  # Higher safety factor
  high_safety <- cassidy_estimate_tokens(text, safety_factor = 1.5)

  expect_lt(no_safety, default_tokens)
  expect_gt(high_safety, default_tokens)
})

test_that("cassidy_estimate_tokens handles vector input correctly", {
  # Multiple text elements are collapsed with newline
  vec <- c("First line", "Second line", "Third line")
  tokens <- cassidy_estimate_tokens(vec)

  expect_type(tokens, "integer")
  expect_gt(tokens, 0)

  # Should be similar to concatenated version
  concatenated <- paste(vec, collapse = "\n")
  tokens_concat <- cassidy_estimate_tokens(concatenated)

  expect_equal(tokens, tokens_concat)
})

test_that("token estimation is consistent", {
  # Same text should always give same result
  text <- "Consistency is key in software development"

  result1 <- cassidy_estimate_tokens(text)
  result2 <- cassidy_estimate_tokens(text)
  result3 <- cassidy_estimate_tokens(text)

  expect_equal(result1, result2)
  expect_equal(result2, result3)
})

test_that("conservative method estimates higher token count", {
  # For same text, conservative should give more tokens
  # (assumes fewer chars per token, so more tokens total)
  text <- paste(rep("test", 1000), collapse = " ")

  fast <- cassidy_estimate_tokens(text, method = "fast")
  conservative <- cassidy_estimate_tokens(text, method = "conservative")

  expect_gt(conservative, fast)
})

test_that("optimistic method estimates lower token count", {
  # For same text, optimistic should give fewer tokens
  # (assumes more chars per token, so fewer tokens total)
  text <- paste(rep("test", 1000), collapse = " ")

  fast <- cassidy_estimate_tokens(text, method = "fast")
  optimistic <- cassidy_estimate_tokens(text, method = "optimistic")

  expect_lt(optimistic, fast)
})

test_that("session tokens include all components", {
  # Session with context and multiple messages
  session <- structure(
    list(
      context = list(text = paste(rep("context", 50), collapse = " ")),
      context_sent = TRUE,
      messages = list(
        list(role = "user", content = "First message"),
        list(role = "assistant", content = "First response"),
        list(role = "user", content = "Second message"),
        list(role = "assistant", content = "Second response")
      )
    ),
    class = "cassidy_session"
  )

  # Calculate expected tokens manually
  context_tokens <- cassidy_estimate_tokens(session$context$text)
  msg1_tokens <- cassidy_estimate_tokens(session$messages[[1]]$content)
  msg2_tokens <- cassidy_estimate_tokens(session$messages[[2]]$content)
  msg3_tokens <- cassidy_estimate_tokens(session$messages[[3]]$content)
  msg4_tokens <- cassidy_estimate_tokens(session$messages[[4]]$content)

  expected_total <- context_tokens + msg1_tokens + msg2_tokens + msg3_tokens + msg4_tokens

  actual_total <- cassidy_estimate_session_tokens(session)

  expect_equal(actual_total, expected_total)
})

test_that("empty session returns zero tokens", {
  # Session with no context and no messages
  session <- structure(
    list(
      context = NULL,
      context_sent = FALSE,
      messages = list()
    ),
    class = "cassidy_session"
  )

  tokens <- cassidy_estimate_session_tokens(session)
  expect_equal(tokens, 0L)
})


# Phase 2: Session Tracking Tests ---------------------------------------------

test_that("cassidy_session_stats works correctly", {
  # Create mock session with token tracking
  session <- structure(
    list(
      thread_id = "test_thread_123",
      created_at = Sys.time(),
      context = list(text = paste(rep("word", 100), collapse = " ")),
      context_sent = TRUE,
      messages = list(
        list(role = "user", content = "Hello", tokens = 5L),
        list(role = "assistant", content = "Hi there!", tokens = 7L),
        list(role = "user", content = "How are you?", tokens = 6L),
        list(role = "assistant", content = "I'm doing well!", tokens = 8L)
      ),
      token_estimate = 200L,
      token_limit = .CASSIDY_TOKEN_LIMIT,
      compact_at = .CASSIDY_DEFAULT_COMPACT_AT,
      auto_compact = TRUE,
      compaction_count = 0L,
      last_compaction = NULL,
      tool_overhead = 0L
    ),
    class = "cassidy_session"
  )

  stats <- cassidy_session_stats(session)

  expect_s3_class(stats, "cassidy_session_stats")
  expect_equal(stats$session_id, "test_thread_123")
  expect_equal(stats$total_messages, 4)
  expect_equal(stats$user_messages, 2)
  expect_equal(stats$assistant_messages, 2)
  expect_equal(stats$token_estimate, 200L)
  expect_equal(stats$token_limit, .CASSIDY_TOKEN_LIMIT)
  expect_true(stats$auto_compact)
  expect_equal(stats$compaction_count, 0L)
  expect_null(stats$last_compaction)
})

test_that("cassidy_session_stats calculates percentages correctly", {
  session <- structure(
    list(
      thread_id = "test_thread",
      created_at = Sys.time(),
      context = NULL,
      context_sent = FALSE,
      messages = list(),
      token_estimate = 100000L,  # 50% of limit
      token_limit = 200000L,
      compact_at = 0.85,
      auto_compact = TRUE,
      compaction_count = 0L,
      last_compaction = NULL,
      tool_overhead = 0L
    ),
    class = "cassidy_session"
  )

  stats <- cassidy_session_stats(session)

  expect_equal(stats$token_percentage, 50.0)
  expect_equal(stats$tokens_remaining, 100000L)
})

test_that("cassidy_session_stats handles missing fields gracefully", {
  # Old-style session without token fields
  session <- structure(
    list(
      thread_id = "old_thread",
      created_at = Sys.time(),
      context = NULL,
      context_sent = FALSE,
      messages = list(
        list(role = "user", content = "Hello")
      )
    ),
    class = "cassidy_session"
  )

  stats <- cassidy_session_stats(session)

  expect_s3_class(stats, "cassidy_session_stats")
  expect_equal(stats$token_estimate, 0L)
  expect_equal(stats$token_limit, .CASSIDY_TOKEN_LIMIT)
  expect_equal(stats$compaction_count, 0L)
  expect_true(stats$auto_compact)
})

test_that("cassidy_session_stats requires cassidy_session object", {
  expect_error(
    cassidy_session_stats("not a session"),
    "session must be a cassidy_session object"
  )

  expect_error(
    cassidy_session_stats(list(thread_id = "test")),
    "session must be a cassidy_session object"
  )
})

test_that("print.cassidy_session_stats produces output", {
  session <- structure(
    list(
      thread_id = "test_thread",
      created_at = Sys.time(),
      context = NULL,
      context_sent = FALSE,
      messages = list(),
      token_estimate = 50000L,
      token_limit = 200000L,
      compact_at = 0.85,
      auto_compact = TRUE,
      compaction_count = 1L,
      last_compaction = Sys.time(),
      tool_overhead = 500L
    ),
    class = "cassidy_session"
  )

  stats <- cassidy_session_stats(session)

  # Should not error when printing
  expect_no_error(print(stats))

  # Return value should be invisible
  result <- withVisible(print(stats))
  expect_false(result$visible)
  expect_s3_class(result$value, "cassidy_session_stats")
})
