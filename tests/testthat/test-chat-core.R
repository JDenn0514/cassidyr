# ══════════════════════════════════════════════════════════════════════════════
# TESTS FOR CHAT INTERFACE (Core)
# Tests that DON'T need API (always run on CRAN)
# ══════════════════════════════════════════════════════════════════════════════

# ══════════════════════════════════════════════════════════════════════════════
# TEST: cassidy_session()
# ══════════════════════════════════════════════════════════════════════════════

test_that("cassidy_session() validates assistant_id", {
  withr::local_envvar(
    CASSIDY_API_KEY = "test_key",
    CASSIDY_ASSISTANT_ID = ""
  )

  # Should error because no assistant_id
  expect_error(
    cassidy_session(),
    "CASSIDY_ASSISTANT_ID"
  )
})

test_that("cassidy_session() creates correct structure", {
  # Mock cassidy_create_thread to avoid API call
  local_mocked_bindings(
    cassidy_create_thread = function(...) "thread_mock_123"
  )

  withr::local_envvar(
    CASSIDY_API_KEY = "test_key",
    CASSIDY_ASSISTANT_ID = "asst_test"
  )

  session <- suppressMessages(cassidy_session())

  # Check structure
  expect_s3_class(session, "cassidy_session")
  expect_named(
    session,
    c(
      "thread_id",
      "assistant_id",
      "messages",
      "created_at",
      "api_key",
      "context",
      "context_sent",
      "token_estimate",
      "token_limit",
      "compact_at",
      "auto_compact",
      "compaction_count",
      "last_compaction",
      "tool_overhead"
    )
  )
  expect_equal(session$thread_id, "thread_mock_123")
  expect_equal(session$assistant_id, "asst_test")
  expect_equal(length(session$messages), 0)
  expect_s3_class(session$created_at, "POSIXct")
})

# ══════════════════════════════════════════════════════════════════════════════
# TEST: cassidy_chat()
# ══════════════════════════════════════════════════════════════════════════════

test_that("cassidy_chat() validates message input", {
  expect_error(
    cassidy_chat(NULL),
    "message is required"
  )

  expect_error(
    cassidy_chat(""),
    "message is required"
  )

  expect_error(
    cassidy_chat(),
    "message is required and cannot be empty"
  )
})

test_that("cassidy_chat() creates thread when thread_id is NULL", {
  # Clear state to ensure clean test
  cassidyr:::.clear_state()

  # Mock functions needed for unified interface
  local_mocked_bindings(
    cassidy_create_thread = function(...) "thread_new_123",
    cassidy_send_message = function(thread_id, message, ...) {
      structure(
        list(
          content = "Mock response",
          thread_id = thread_id,
          timestamp = Sys.time(),
          raw = list()
        ),
        class = "cassidy_response"
      )
    },
    gather_context = function(...) "Mock context",
    cassidy_save_conversation = function(conv) invisible(NULL)
  )

  withr::local_envvar(
    CASSIDY_API_KEY = "test_key",
    CASSIDY_ASSISTANT_ID = "asst_test"
  )

  result <- suppressMessages(cassidy_chat("Test message"))

  # Check structure (updated for unified interface)
  expect_s3_class(result, "cassidy_chat")
  expect_true("thread_id" %in% names(result))
  expect_true("conversation_id" %in% names(result))
  expect_true("response" %in% names(result))
  expect_equal(result$thread_id, "thread_new_123")
  expect_equal(result$message, "Test message")
  expect_s3_class(result$response, "cassidy_response")
})

test_that("cassidy_chat() uses existing thread_id when provided", {
  # Mock send_message only (shouldn't call create_thread)
  local_mocked_bindings(
    cassidy_send_message = function(thread_id, message, ...) {
      structure(
        list(
          content = "Mock response",
          thread_id = thread_id,
          timestamp = Sys.time(),
          raw = list()
        ),
        class = "cassidy_response"
      )
    }
  )

  withr::local_envvar(CASSIDY_API_KEY = "test_key")

  result <- cassidy_chat("Test", thread_id = "thread_existing_123")

  expect_equal(result$thread_id, "thread_existing_123")
})

# ══════════════════════════════════════════════════════════════════════════════
# TEST: cassidy_continue()
# ══════════════════════════════════════════════════════════════════════════════

test_that("cassidy_continue() works with cassidy_chat object", {
  # Create a mock previous result
  previous <- structure(
    list(
      thread_id = "thread_123",
      response = structure(
        list(
          content = "Previous response",
          thread_id = "thread_123",
          timestamp = Sys.time(),
          raw = list()
        ),
        class = "cassidy_response"
      ),
      message = "Previous message",
      timestamp = Sys.time()
    ),
    class = "cassidy_chat"
  )

  # Mock the send
  local_mocked_bindings(
    cassidy_send_message = function(thread_id, message, ...) {
      structure(
        list(
          content = "Continuation response",
          thread_id = thread_id,
          timestamp = Sys.time(),
          raw = list()
        ),
        class = "cassidy_response"
      )
    }
  )

  withr::local_envvar(CASSIDY_API_KEY = "test_key")

  result <- cassidy_continue(previous, "Follow-up message")

  expect_s3_class(result, "cassidy_chat")
  expect_equal(result$thread_id, "thread_123")
  expect_equal(result$message, "Follow-up message")
})

test_that("cassidy_continue() works with cassidy_session object", {
  session <- structure(
    list(
      thread_id = "thread_456",
      assistant_id = "asst_test",
      messages = list(),
      created_at = Sys.time(),
      api_key = "test_key"
    ),
    class = "cassidy_session"
  )

  local_mocked_bindings(
    cassidy_send_message = function(thread_id, message, ...) {
      structure(
        list(
          content = "Response",
          thread_id = thread_id,
          timestamp = Sys.time(),
          raw = list()
        ),
        class = "cassidy_response"
      )
    }
  )

  withr::local_envvar(CASSIDY_API_KEY = "test_key")

  result <- cassidy_continue(session, "Message")

  expect_equal(result$thread_id, "thread_456")
})

test_that("cassidy_continue() errors on invalid input", {
  expect_error(
    cassidy_continue(list(), "Message"),
    "cassidy_chat or cassidy_session"
  )

  expect_error(
    cassidy_continue("thread_123", "Message"),
    "cassidy_chat or cassidy_session"
  )
})

# ══════════════════════════════════════════════════════════════════════════════
# TEST: chat() generic
# ══════════════════════════════════════════════════════════════════════════════

test_that("chat() works with cassidy_session", {
  session <- structure(
    list(
      thread_id = "thread_789",
      assistant_id = "asst_test",
      messages = list(),
      created_at = Sys.time(),
      api_key = "test_key",
      context = NULL,
      context_sent = FALSE
    ),
    class = "cassidy_session"
  )

  local_mocked_bindings(
    cassidy_send_message = function(thread_id, message, ...) {
      structure(
        list(
          content = "Response content",
          thread_id = thread_id,
          timestamp = Sys.time(),
          raw = list()
        ),
        class = "cassidy_response"
      )
    }
  )

  withr::local_envvar(CASSIDY_API_KEY = "test_key")

  # chat() should update session invisibly
  result <- suppressMessages(chat(session, "Test message"))

  expect_s3_class(result, "cassidy_session")
  expect_equal(length(result$messages), 2) # user + assistant

  # Check message structure
  expect_equal(result$messages[[1]]$role, "user")
  expect_equal(result$messages[[1]]$content, "Test message")
  expect_equal(result$messages[[2]]$role, "assistant")
  expect_equal(result$messages[[2]]$content, "Response content")
})

test_that("chat() works with character thread_id", {
  local_mocked_bindings(
    cassidy_send_message = function(thread_id, message, ...) {
      structure(
        list(
          content = "Response",
          thread_id = thread_id,
          timestamp = Sys.time(),
          raw = list()
        ),
        class = "cassidy_response"
      )
    }
  )

  withr::local_envvar(CASSIDY_API_KEY = "test_key")

  result <- chat("thread_direct_123", "Test message")

  expect_s3_class(result, "cassidy_chat")
  expect_equal(result$thread_id, "thread_direct_123")
})

test_that("chat() errors on invalid input", {
  expect_error(
    chat(123, "Message"),
    "cassidy_session object or thread_id"
  )

  expect_error(
    chat(list(), "Message"),
    "cassidy_session object or thread_id"
  )
})

# ══════════════════════════════════════════════════════════════════════════════
# TEST: chat_text() helper
# ══════════════════════════════════════════════════════════════════════════════

test_that("chat_text() extracts text from cassidy_chat", {
  chat_obj <- structure(
    list(
      thread_id = "thread_123",
      response = structure(
        list(
          content = "This is the response text",
          thread_id = "thread_123",
          timestamp = Sys.time(),
          raw = list()
        ),
        class = "cassidy_response"
      ),
      message = "Query",
      timestamp = Sys.time()
    ),
    class = "cassidy_chat"
  )

  text <- chat_text(chat_obj)
  expect_equal(text, "This is the response text")
})

test_that("chat_text() extracts text from cassidy_response", {
  response_obj <- structure(
    list(
      content = "Direct response text",
      thread_id = "thread_123",
      timestamp = Sys.time(),
      raw = list()
    ),
    class = "cassidy_response"
  )

  text <- chat_text(response_obj)
  expect_equal(text, "Direct response text")
})

test_that("chat_text() errors on invalid input", {
  expect_error(
    chat_text("not a chat object"),
    "cassidy_chat or cassidy_response"
  )

  expect_error(
    chat_text(list(content = "text")),
    "cassidy_chat or cassidy_response"
  )
})

# ══════════════════════════════════════════════════════════════════════════════
# TEST: Print methods
# ══════════════════════════════════════════════════════════════════════════════

test_that("print.cassidy_session() doesn't error", {
  session <- structure(
    list(
      thread_id = "thread_123",
      assistant_id = "asst_test",
      messages = list(
        list(role = "user", content = "Hello", timestamp = Sys.time()),
        list(role = "assistant", content = "Hi there", timestamp = Sys.time())
      ),
      created_at = Sys.time(),
      api_key = "test_key"
    ),
    class = "cassidy_session"
  )

  # Should not error
  expect_no_error(print(session))

  # Should return invisibly
  result <- print(session)
  expect_identical(result, session)
})

test_that("print.cassidy_session() handles empty messages", {
  session <- structure(
    list(
      thread_id = "thread_123",
      assistant_id = "asst_test",
      messages = list(),
      created_at = Sys.time(),
      api_key = "test_key"
    ),
    class = "cassidy_session"
  )

  expect_no_error(print(session))
})

test_that("print.cassidy_chat() doesn't error", {
  chat_obj <- structure(
    list(
      thread_id = "thread_123",
      response = structure(
        list(
          content = "Response text",
          thread_id = "thread_123",
          timestamp = Sys.time(),
          raw = list()
        ),
        class = "cassidy_response"
      ),
      message = "Query",
      timestamp = Sys.time()
    ),
    class = "cassidy_chat"
  )

  expect_no_error(print(chat_obj))

  result <- print(chat_obj)
  expect_identical(result, chat_obj)
})

# ══════════════════════════════════════════════════════════════════════════════
# TEST: Edge cases
# ══════════════════════════════════════════════════════════════════════════════

##### TODO: FIX THIS #####
# test_that("Functions handle missing environment variables gracefully", {
#   withr::local_envvar(
#     CASSIDY_API_KEY = "",
#     CASSIDY_ASSISTANT_ID = ""
#   )

#   expect_error(cassidy_session(), "CASSIDY_ASSISTANT_ID")
#   expect_error(cassidy_chat("Test"), "CASSIDY_ASSISTANT_ID")
# })

test_that("Sessions track messages correctly", {
  session <- structure(
    list(
      thread_id = "thread_123",
      assistant_id = "asst_test",
      messages = list(),
      created_at = Sys.time(),
      api_key = "test_key",
      context = NULL,
      context_sent = FALSE
    ),
    class = "cassidy_session"
  )

  local_mocked_bindings(
    cassidy_send_message = function(thread_id, message, ...) {
      structure(
        list(
          content = paste("Response to:", message),
          thread_id = thread_id,
          timestamp = Sys.time(),
          raw = list()
        ),
        class = "cassidy_response"
      )
    }
  )

  # Send multiple messages
  session <- suppressMessages(chat(session, "First message"))
  expect_equal(length(session$messages), 2)

  session <- suppressMessages(chat(session, "Second message"))
  expect_equal(length(session$messages), 4)

  session <- suppressMessages(chat(session, "Third message"))
  expect_equal(length(session$messages), 6)

  # Check order
  expect_equal(session$messages[[1]]$role, "user")
  expect_equal(session$messages[[2]]$role, "assistant")
  expect_equal(session$messages[[3]]$role, "user")
  expect_equal(session$messages[[4]]$role, "assistant")
})
