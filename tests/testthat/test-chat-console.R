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
