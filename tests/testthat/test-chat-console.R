test_that("state management functions work", {
  # Clear state first
  cassidyr:::.clear_state()

  # Initially NULL
  expect_null(cassidyr:::.get_current_conv_id())
  expect_null(cassidyr:::.get_current_thread_id())

  # Set values
  cassidyr:::.set_current_conv_id("conv_test_123")
  cassidyr:::.set_current_thread_id("thread_test_456")

  # Retrieve values
  expect_equal(cassidyr:::.get_current_conv_id(), "conv_test_123")
  expect_equal(cassidyr:::.get_current_thread_id(), "thread_test_456")

  # Clear state
  cassidyr:::.clear_state()
  expect_null(cassidyr:::.get_current_conv_id())
  expect_null(cassidyr:::.get_current_thread_id())
})

test_that("conversation ID generation works", {
  conv_id <- cassidyr:::.generate_conv_id()

  # Should match pattern: conv_YYYYMMDD_HHMMSS_xxxx
  expect_match(conv_id, "^conv_[0-9]{8}_[0-9]{6}_[a-z]{4}$")

  # Multiple calls should generate different IDs
  conv_id2 <- cassidyr:::.generate_conv_id()
  expect_false(conv_id == conv_id2)
})

test_that("title generation works", {
  # Simple message
  title <- cassidyr:::.generate_title("What is R?")
  expect_equal(title, "What is R?")

  # Long message gets truncated
  long_msg <- paste(rep("word", 20), collapse = " ")
  title <- cassidyr:::.generate_title(long_msg, max_length = 30)
  expect_equal(nchar(title), 30)
  expect_match(title, "\\.\\.\\.$")

  # Newlines and whitespace normalized
  messy <- "Line 1\n  Line 2\n\n   Line 3"
  title <- cassidyr:::.generate_title(messy)
  expect_false(grepl("\n", title))
  expect_false(grepl("  ", title))
})

test_that("context gathering for levels works", {
  # Mock gather_context
  local_mocked_bindings(
    gather_context = function(...) {
      args <- list(...)
      paste0("Context: ", paste(names(args), collapse = ", "))
    },
    .package = "cassidyr"
  )

  # Minimal level
  result <- cassidyr:::.gather_context_for_level(
    context_level = "minimal",
    include_data = TRUE,
    include_files = NULL
  )
  expect_match(result, "config")

  # Standard level
  result <- cassidyr:::.gather_context_for_level(
    context_level = "standard",
    include_data = TRUE,
    include_files = c("test.R")
  )
  expect_match(result, "session")

  # Comprehensive level
  result <- cassidyr:::.gather_context_for_level(
    context_level = "comprehensive",
    include_data = TRUE,
    include_files = NULL
  )
  expect_match(result, "git")
})

test_that("new conversation creates properly", {
  skip_on_cran()

  # Mock API functions
  local_mocked_bindings(
    cassidy_create_thread = function(...) "thread_mock_123",
    cassidy_send_message = function(...) {
      structure(
        list(
          content = "Mock response",
          timestamp = Sys.time()
        ),
        class = "cassidy_response"
      )
    },
    gather_context = function(...) "Mock context",
    cassidy_save_conversation = function(conv) {
      expect_type(conv, "list")
      expect_equal(conv$thread_id, "thread_mock_123")
      invisible(NULL)
    },
    .package = "cassidyr"
  )

  # Clear state
  cassidyr:::.clear_state()

  # Call with no current conversation
  result <- cassidy_chat("Test message")

  # Should have created new conversation
  expect_s3_class(result, "cassidy_chat")
  expect_equal(result$thread_id, "thread_mock_123")
  expect_true(!is.null(result$conversation_id))
  expect_equal(result$message, "Test message")

  # State should be updated
  expect_equal(cassidyr:::.get_current_thread_id(), "thread_mock_123")
  expect_true(!is.null(cassidyr:::.get_current_conv_id()))
})

test_that("conversation continuation works", {
  skip_on_cran()

  # Setup: Create a mock saved conversation
  test_conv <- list(
    id = "conv_test_456",
    title = "Test conversation",
    thread_id = "thread_abc",
    messages = list(
      list(role = "user", content = "First message", timestamp = Sys.time())
    ),
    context_sent = TRUE,
    context_level = "standard",
    context_files = character(),
    created_at = Sys.time(),
    updated_at = Sys.time()
  )

  # Mock functions
  local_mocked_bindings(
    cassidy_load_conversation = function(conv_id) {
      if (conv_id == "conv_test_456") test_conv else NULL
    },
    cassidy_send_message = function(...) {
      structure(
        list(
          content = "Follow-up response",
          timestamp = Sys.time()
        ),
        class = "cassidy_response"
      )
    },
    cassidy_save_conversation = function(conv) {
      expect_equal(length(conv$messages), 3) # Original + 2 new
      invisible(NULL)
    },
    .package = "cassidyr"
  )

  # Set state to existing conversation
  cassidyr:::.set_current_conv_id("conv_test_456")
  cassidyr:::.set_current_thread_id("thread_abc")

  # Send another message (should continue)
  result <- cassidy_chat("Follow-up message")

  # Should have used existing conversation
  expect_equal(result$conversation_id, "conv_test_456")
  expect_equal(result$thread_id, "thread_abc")
  expect_false(result$context_used) # No context on continuation
})

test_that("explicit new conversation works", {
  skip_on_cran()

  # Setup: Have an existing conversation in state
  cassidyr:::.set_current_conv_id("conv_old_123")
  cassidyr:::.set_current_thread_id("thread_old_abc")

  # Mock API functions
  local_mocked_bindings(
    cassidy_create_thread = function(...) "thread_new_xyz",
    cassidy_send_message = function(...) {
      structure(
        list(
          content = "New conversation response",
          timestamp = Sys.time()
        ),
        class = "cassidy_response"
      )
    },
    gather_context = function(...) "New context",
    cassidy_save_conversation = function(conv) invisible(NULL),
    .package = "cassidyr"
  )

  # Explicitly request new conversation
  result <- cassidy_chat("New topic", conversation = "new")

  # Should have created NEW conversation (not continued old one)
  expect_equal(result$thread_id, "thread_new_xyz")
  expect_false(result$conversation_id == "conv_old_123")

  # State should be updated to new conversation
  expect_equal(cassidyr:::.get_current_thread_id(), "thread_new_xyz")
  expect_false(cassidyr:::.get_current_conv_id() == "conv_old_123")
})

test_that("switching conversations works", {
  skip_on_cran()

  # Setup: Mock conversation to switch to
  target_conv <- list(
    id = "conv_target_789",
    title = "Target conversation",
    thread_id = "thread_target_xyz",
    messages = list(
      list(role = "user", content = "Previous message", timestamp = Sys.time())
    ),
    context_level = "standard",
    created_at = Sys.time(),
    updated_at = Sys.time()
  )

  # Mock functions
  local_mocked_bindings(
    cassidy_load_conversation = function(conv_id) {
      if (conv_id == "conv_target_789") target_conv else NULL
    },
    cassidy_send_message = function(...) {
      structure(
        list(
          content = "Response in target conversation",
          timestamp = Sys.time()
        ),
        class = "cassidy_response"
      )
    },
    cassidy_save_conversation = function(conv) invisible(NULL),
    .package = "cassidyr"
  )

  # Start with different conversation
  cassidyr:::.set_current_conv_id("conv_other_123")

  # Switch to specific conversation
  result <- cassidy_chat("Continue here", conversation = "conv_target_789")

  # Should have switched to target conversation
  expect_equal(result$conversation_id, "conv_target_789")
  expect_equal(result$thread_id, "thread_target_xyz")

  # State should be updated
  expect_equal(cassidyr:::.get_current_conv_id(), "conv_target_789")
  expect_equal(cassidyr:::.get_current_thread_id(), "thread_target_xyz")
})

test_that("backward compatibility with thread_id parameter works", {
  skip_on_cran()

  # Mock API function
  local_mocked_bindings(
    cassidy_send_message = function(thread_id, message, ...) {
      structure(
        list(
          content = "Legacy response",
          timestamp = Sys.time()
        ),
        class = "cassidy_response"
      )
    },
    .package = "cassidyr"
  )

  # Clear state
  cassidyr:::.clear_state()

  # Use old thread_id parameter (legacy mode)
  result <- cassidy_chat("Test", thread_id = "thread_legacy_123")

  # Should work but not update package state
  expect_equal(result$thread_id, "thread_legacy_123")
  expect_null(result$conversation_id) # No conversation tracking

  # State should still be empty (legacy mode doesn't use state)
  expect_null(cassidyr:::.get_current_conv_id())
  expect_null(cassidyr:::.get_current_thread_id())
})

test_that("error handling works", {
  # Missing message
  expect_error(
    cassidy_chat(),
    "message is required"
  )

  # Empty message
  expect_error(
    cassidy_chat(""),
    "message is required"
  )

  # Invalid conversation ID
  local_mocked_bindings(
    cassidy_load_conversation = function(conv_id) NULL,
    .package = "cassidyr"
  )

  expect_error(
    cassidy_chat("Test", conversation = "conv_nonexistent"),
    "not found"
  )

  # Conversation without thread_id
  bad_conv <- list(
    id = "conv_bad_123",
    thread_id = NULL,
    messages = list()
  )

  cassidyr:::.set_current_conv_id("conv_bad_123")

  local_mocked_bindings(
    cassidy_load_conversation = function(conv_id) bad_conv,
    .package = "cassidyr"
  )

  expect_error(
    cassidy_chat("Test"),
    "has no thread_id"
  )
})

test_that("cassidy_conversations returns enhanced data frame", {
  skip_on_cran()

  # Mock the base function
  local_mocked_bindings(
    cassidy_list_conversations = function(...) {
      data.frame(
        id = c("conv_1", "conv_2"),
        thread_id = c("thread_1", "thread_2"),
        title = c("First", "Second"),
        created_at = rep(Sys.time(), 2),
        updated_at = rep(Sys.time(), 2),
        message_count = c(5, 3),
        stringsAsFactors = FALSE
      )
    },
    .package = "cassidyr"
  )

  result <- cassidy_conversations()

  # Should have custom class
  expect_s3_class(result, "cassidy_conversations")
  expect_s3_class(result, "data.frame")

  # Should have correct structure
  expect_equal(nrow(result), 2)
  expect_true("id" %in% names(result))
  expect_true("title" %in% names(result))
})

test_that("cassidy_current shows info or NULL", {
  # No current conversation
  cassidyr:::.clear_state()

  # Should return NULL invisibly and show message
  result <- cassidy_current()
  expect_null(result)

  # With current conversation
  test_conv <- list(
    id = "conv_current_123",
    title = "Current chat",
    thread_id = "thread_current_abc",
    messages = list(),
    context_sent = TRUE,
    context_level = "standard",
    created_at = Sys.time(),
    updated_at = Sys.time()
  )

  cassidyr:::.set_current_conv_id("conv_current_123")

  local_mocked_bindings(
    cassidy_load_conversation = function(conv_id) test_conv,
    .package = "cassidyr"
  )

  result <- cassidy_current()
  expect_type(result, "list")
  expect_equal(result$id, "conv_current_123")
})

test_that("cassidy_reset clears state", {
  # Set some state
  cassidyr:::.set_current_conv_id("conv_test_123")
  cassidyr:::.set_current_thread_id("thread_test_abc")

  # Reset
  result <- cassidy_reset()

  # State should be clear
  expect_null(cassidyr:::.get_current_conv_id())
  expect_null(cassidyr:::.get_current_thread_id())

  # Returns NULL invisibly
  expect_null(result)
})

test_that("context levels map correctly", {
  # Test each level's parameters
  local_mocked_bindings(
    gather_context = function(...) {
      args <- list(...)
      # Return arguments as list for inspection
      args
    },
    .package = "cassidyr"
  )

  # Minimal
  result <- cassidyr:::.gather_context_for_level(
    "minimal",
    include_data = TRUE,
    include_files = c("test.R")
  )
  expect_true(result$config)
  expect_false(result$session)
  expect_false(result$git)
  expect_false(result$data)

  # Standard
  result <- cassidyr:::.gather_context_for_level(
    "standard",
    include_data = TRUE,
    include_files = c("test.R")
  )
  expect_true(result$config)
  expect_true(result$session)
  expect_false(result$git)
  expect_true(result$data)
  expect_equal(result$data_method, "basic")

  # Comprehensive
  result <- cassidyr:::.gather_context_for_level(
    "comprehensive",
    include_data = TRUE,
    include_files = c("test.R")
  )
  expect_true(result$config)
  expect_true(result$session)
  expect_true(result$git)
  expect_true(result$data)
  expect_equal(result$data_method, "codebook")
})

test_that("print method for cassidy_conversations works", {
  # Empty conversations
  empty_df <- data.frame(
    id = character(0),
    thread_id = character(0),
    title = character(0),
    created_at = as.POSIXct(character(0)),
    updated_at = as.POSIXct(character(0)),
    message_count = integer(0),
    stringsAsFactors = FALSE
  )
  class(empty_df) <- c("cassidy_conversations", "data.frame")

  expect_no_error(print(empty_df))

  # With conversations
  convs_df <- data.frame(
    id = c("conv_1", "conv_2"),
    thread_id = c("thread_1", "thread_2"),
    title = c("First conversation", "Second conversation"),
    created_at = rep(Sys.time(), 2),
    updated_at = rep(Sys.time(), 2),
    message_count = c(5, 3),
    stringsAsFactors = FALSE
  )
  class(convs_df) <- c("cassidy_conversations", "data.frame")

  expect_no_error(print(convs_df))
})

test_that("include_skills parameter works in context gathering", {
  local_mocked_bindings(
    gather_context = function(...) {
      args <- list(...)
      args
    },
    .package = "cassidyr"
  )

  # With skills
  result <- cassidyr:::.gather_context_for_level(
    "standard",
    include_data = FALSE,
    include_files = NULL,
    include_skills = c("skill1", "skill2")
  )

  expect_equal(result$skills, c("skill1", "skill2"))

  # Without skills
  result <- cassidyr:::.gather_context_for_level(
    "minimal",
    include_data = FALSE,
    include_files = NULL,
    include_skills = NULL
  )

  expect_null(result$skills)
})

test_that("conversation includes skill tracking", {
  skip_on_cran()

  # Mock functions
  local_mocked_bindings(
    cassidy_create_thread = function(...) "thread_skill_test",
    cassidy_send_message = function(...) {
      structure(
        list(content = "Response", timestamp = Sys.time()),
        class = "cassidy_response"
      )
    },
    gather_context = function(...) "Context with skills",
    cassidy_save_conversation = function(conv) {
      # Check that skills are tracked
      expect_true("sent_skills" %in% names(conv))
      expect_equal(conv$sent_skills, c("apa-tables"))
      invisible(NULL)
    },
    .package = "cassidyr"
  )

  cassidyr:::.clear_state()

  # Create conversation with skills
  result <- cassidy_chat(
    "Test with skills",
    include_skills = c("apa-tables")
  )

  expect_s3_class(result, "cassidy_chat")
})

# ===========================================================================
# PHASE 7: TOKEN TRACKING IN CONSOLE CHAT
# ===========================================================================

test_that("new conversation includes token tracking when enabled", {
  skip_on_cran()

  # Mock functions
  local_mocked_bindings(
    cassidy_create_thread = function(...) "thread_token_test",
    cassidy_send_message = function(...) {
      structure(
        list(content = "Response with some content here", timestamp = Sys.time()),
        class = "cassidy_response"
      )
    },
    gather_context = function(...) paste(rep("context", 100), collapse = " "),
    cassidy_save_conversation = function(conv) {
      # Check that token fields are present and non-zero
      expect_true("token_estimate" %in% names(conv))
      expect_true("token_limit" %in% names(conv))
      expect_type(conv$token_estimate, "integer")
      expect_gt(conv$token_estimate, 0L)
      expect_equal(conv$token_limit, .CASSIDY_TOKEN_LIMIT)

      # Check that messages have token counts
      expect_true("tokens" %in% names(conv$messages[[1]]))
      expect_type(conv$messages[[1]]$tokens, "integer")
      expect_gt(conv$messages[[1]]$tokens, 0L)

      invisible(NULL)
    },
    .package = "cassidyr"
  )

  cassidyr:::.clear_state()

  # Create conversation with token tracking
  result <- cassidy_chat("Test message", track_tokens = TRUE)

  expect_s3_class(result, "cassidy_chat")
})

test_that("new conversation omits token tracking when disabled", {
  skip_on_cran()

  # Mock functions
  local_mocked_bindings(
    cassidy_create_thread = function(...) "thread_no_token",
    cassidy_send_message = function(...) {
      structure(
        list(content = "Response", timestamp = Sys.time()),
        class = "cassidy_response"
      )
    },
    gather_context = function(...) "Context",
    cassidy_save_conversation = function(conv) {
      # Check that token estimate is 0 when disabled
      expect_equal(conv$token_estimate, 0L)
      expect_equal(conv$messages[[1]]$tokens, 0L)
      invisible(NULL)
    },
    .package = "cassidyr"
  )

  cassidyr:::.clear_state()

  # Create conversation without token tracking
  result <- cassidy_chat("Test", track_tokens = FALSE)

  expect_s3_class(result, "cassidy_chat")
})

test_that("continuation warns when approaching token limit", {
  skip_on_cran()

  # Setup: conversation with high token usage
  high_token_conv <- list(
    id = "conv_high_tokens",
    title = "High token conversation",
    thread_id = "thread_high",
    messages = list(
      list(role = "user", content = "Message 1", timestamp = Sys.time(), tokens = 50000L),
      list(role = "assistant", content = "Response 1", timestamp = Sys.time(), tokens = 50000L),
      list(role = "user", content = "Message 2", timestamp = Sys.time(), tokens = 50000L),
      list(role = "assistant", content = "Response 2", timestamp = Sys.time(), tokens = 50000L)
    ),
    context_sent = TRUE,
    context_level = "standard",
    context_files = character(),
    created_at = Sys.time(),
    updated_at = Sys.time(),
    token_estimate = 165000L,  # 82.5% of 200,000
    token_limit = .CASSIDY_TOKEN_LIMIT
  )

  # Mock functions
  local_mocked_bindings(
    cassidy_load_conversation = function(conv_id) high_token_conv,
    cassidy_send_message = function(...) {
      structure(
        list(content = "Response", timestamp = Sys.time()),
        class = "cassidy_response"
      )
    },
    cassidy_save_conversation = function(conv) invisible(NULL),
    .package = "cassidyr"
  )

  cassidyr:::.set_current_conv_id("conv_high_tokens")

  # Should warn about high usage
  expect_message(
    cassidy_chat("Continue", track_tokens = TRUE),
    "Token usage is high"
  )
})

test_that("continuation with auto_compact suggests cassidy_session", {
  skip_on_cran()

  # Setup: conversation approaching limit
  high_conv <- list(
    id = "conv_auto_compact_test",
    title = "Test",
    thread_id = "thread_test",
    messages = list(
      list(role = "user", content = "Msg", timestamp = Sys.time(), tokens = 80000L),
      list(role = "assistant", content = "Resp", timestamp = Sys.time(), tokens = 85000L)
    ),
    context_sent = TRUE,
    context_level = "standard",
    context_files = character(),
    created_at = Sys.time(),
    updated_at = Sys.time(),
    token_estimate = 165000L,
    token_limit = .CASSIDY_TOKEN_LIMIT
  )

  local_mocked_bindings(
    cassidy_load_conversation = function(conv_id) high_conv,
    cassidy_send_message = function(...) {
      structure(
        list(content = "Response", timestamp = Sys.time()),
        class = "cassidy_response"
      )
    },
    cassidy_save_conversation = function(conv) invisible(NULL),
    .package = "cassidyr"
  )

  cassidyr:::.set_current_conv_id("conv_auto_compact_test")

  # Should mention cassidy_session when auto_compact is TRUE
  expect_message(
    cassidy_chat("Test", track_tokens = TRUE, auto_compact = TRUE),
    "cassidy_session"
  )
})

test_that("continuation updates token estimate correctly", {
  skip_on_cran()

  # Setup: conversation with initial tokens
  test_conv <- list(
    id = "conv_update_tokens",
    title = "Test",
    thread_id = "thread_test",
    messages = list(
      list(role = "user", content = "First", timestamp = Sys.time(), tokens = 10L),
      list(role = "assistant", content = "Response", timestamp = Sys.time(), tokens = 20L)
    ),
    context_sent = TRUE,
    context_level = "standard",
    context_files = character(),
    created_at = Sys.time(),
    updated_at = Sys.time(),
    token_estimate = 30L,
    token_limit = .CASSIDY_TOKEN_LIMIT
  )

  saved_estimate <- NULL

  local_mocked_bindings(
    cassidy_load_conversation = function(conv_id) test_conv,
    cassidy_send_message = function(...) {
      structure(
        list(content = "New response", timestamp = Sys.time()),
        class = "cassidy_response"
      )
    },
    cassidy_save_conversation = function(conv) {
      # Capture the updated token estimate
      saved_estimate <<- conv$token_estimate
      invisible(NULL)
    },
    .package = "cassidyr"
  )

  cassidyr:::.set_current_conv_id("conv_update_tokens")

  # Send a message
  result <- cassidy_chat("New message", track_tokens = TRUE)

  # Token estimate should have increased
  expect_true(!is.null(saved_estimate))
  expect_gt(saved_estimate, 30L)
})

test_that("cassidy_current displays token usage", {
  # Setup conversation with token tracking
  conv_with_tokens <- list(
    id = "conv_with_tokens",
    title = "Token test",
    thread_id = "thread_tokens",
    messages = list(),
    context_sent = FALSE,
    context_level = "standard",
    created_at = Sys.time(),
    updated_at = Sys.time(),
    token_estimate = 50000L,
    token_limit = .CASSIDY_TOKEN_LIMIT
  )

  cassidyr:::.set_current_conv_id("conv_with_tokens")

  local_mocked_bindings(
    cassidy_load_conversation = function(conv_id) conv_with_tokens,
    .package = "cassidyr"
  )

  # Should display without error
  result <- cassidy_current()

  expect_type(result, "list")
  expect_equal(result$token_estimate, 50000L)
})

test_that("cassidy_current warns about high token usage", {
  # Setup conversation with high token usage (>80%)
  conv_high_tokens <- list(
    id = "conv_high_warn",
    title = "High usage",
    thread_id = "thread_high",
    messages = list(),
    context_sent = FALSE,
    context_level = "standard",
    created_at = Sys.time(),
    updated_at = Sys.time(),
    token_estimate = 170000L,  # 85% of 200,000
    token_limit = .CASSIDY_TOKEN_LIMIT
  )

  cassidyr:::.set_current_conv_id("conv_high_warn")

  local_mocked_bindings(
    cassidy_load_conversation = function(conv_id) conv_high_tokens,
    .package = "cassidyr"
  )

  # Should show warning
  expect_message(
    cassidy_current(),
    "Token usage is high"
  )
})

test_that("token tracking handles backward compatibility", {
  skip_on_cran()

  # Old conversation without token fields
  old_conv <- list(
    id = "conv_old_format",
    title = "Old",
    thread_id = "thread_old",
    messages = list(
      list(role = "user", content = "Message", timestamp = Sys.time())
    ),
    context_sent = TRUE,
    context_level = "standard",
    context_files = character(),
    created_at = Sys.time(),
    updated_at = Sys.time()
    # No token_estimate or token_limit fields
  )

  local_mocked_bindings(
    cassidy_load_conversation = function(conv_id) old_conv,
    cassidy_send_message = function(...) {
      structure(
        list(content = "Response", timestamp = Sys.time()),
        class = "cassidy_response"
      )
    },
    cassidy_save_conversation = function(conv) {
      # Should add token tracking on save
      expect_true("token_estimate" %in% names(conv))
      invisible(NULL)
    },
    .package = "cassidyr"
  )

  cassidyr:::.set_current_conv_id("conv_old_format")

  # Should work without errors
  expect_no_error(
    cassidy_chat("Continue", track_tokens = TRUE)
  )
})

test_that("warn_at parameter customizes warning threshold", {
  skip_on_cran()

  # Conversation at 70% usage (below default 80% but above custom 60%)
  conv_70pct <- list(
    id = "conv_custom_warn",
    title = "Test",
    thread_id = "thread_test",
    messages = list(
      list(role = "user", content = "Msg", timestamp = Sys.time(), tokens = 70000L),
      list(role = "assistant", content = "Resp", timestamp = Sys.time(), tokens = 70000L)
    ),
    context_sent = TRUE,
    context_level = "standard",
    context_files = character(),
    created_at = Sys.time(),
    updated_at = Sys.time(),
    token_estimate = 140000L,  # 70% of 200,000
    token_limit = .CASSIDY_TOKEN_LIMIT
  )

  local_mocked_bindings(
    cassidy_load_conversation = function(conv_id) conv_70pct,
    cassidy_send_message = function(...) {
      structure(
        list(content = "Response", timestamp = Sys.time()),
        class = "cassidy_response"
      )
    },
    cassidy_save_conversation = function(conv) invisible(NULL),
    .package = "cassidyr"
  )

  cassidyr:::.set_current_conv_id("conv_custom_warn")

  # With default warn_at (0.80), should NOT warn
  expect_no_message(
    result1 <- cassidy_chat("Test", track_tokens = TRUE, warn_at = 0.80)
  )

  # Reset for next test
  cassidyr:::.set_current_conv_id("conv_custom_warn")

  # With custom warn_at (0.60), SHOULD warn
  expect_message(
    result2 <- cassidy_chat("Test", track_tokens = TRUE, warn_at = 0.60),
    "Token usage is high"
  )
})
