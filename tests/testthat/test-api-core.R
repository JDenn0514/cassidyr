# ══════════════════════════════════════════════════════════════════════════════
# API CORE TESTS - SECURITY FIRST
# All tests use mocked API responses - no real credentials needed
# ══════════════════════════════════════════════════════════════════════════════

# Safety check: ensure no real credentials
verify_no_real_credentials()

# ══════════════════════════════════════════════════════════════════════════════
# TEST: .cassidy_client() internal helper
# ══════════════════════════════════════════════════════════════════════════════

test_that(".cassidy_client() requires API key", {
  withr::local_envvar(CASSIDY_API_KEY = "")

  expect_error(
    .cassidy_client(),
    "CASSIDY_API_KEY not found"
  )
})

test_that(".cassidy_client() creates proper request object", {
  setup_test_env()

  client <- .cassidy_client()

  expect_s3_class(client, "httr2_request")
  expect_match(client$url, "https://app.cassidyai.com/api")
})

# ══════════════════════════════════════════════════════════════════════════════
# TEST: cassidy_create_thread()
# ══════════════════════════════════════════════════════════════════════════════

httptest2::without_internet({
  test_that("cassidy_create_thread() requires assistant_id", {
    withr::local_envvar(
      CASSIDY_API_KEY = fake_api_key(),
      CASSIDY_ASSISTANT_ID = ""
    )

    expect_error(
      cassidy_create_thread(),
      "CASSIDY_ASSISTANT_ID not found"
    )
  })

  test_that("cassidy_create_thread() makes correct API request", {
    setup_test_env()

    expect_error(
      cassidy_create_thread(),
      "POST https://app.cassidyai.com/api/assistants/thread/create"
    )
  })
})

httptest2::with_mock_api({
  test_that("cassidy_create_thread() returns thread_id", {
    setup_test_env()

    thread_id <- cassidy_create_thread()

    expect_type(thread_id, "character")
    expect_gt(nchar(thread_id), 10)

    # Ensure it's a mock ID (security check)
    expect_match(thread_id, "mock")
  })
})

# ══════════════════════════════════════════════════════════════════════════════
# TEST: cassidy_send_message()
# ══════════════════════════════════════════════════════════════════════════════

test_that("cassidy_send_message() validates inputs", {
  expect_error(
    cassidy_send_message(thread_id = NULL, message = "test"),
    "thread_id is required"
  )

  expect_error(
    cassidy_send_message(thread_id = "", message = "test"),
    "thread_id is required"
  )

  expect_error(
    cassidy_send_message(thread_id = "thread_123", message = NULL),
    "message cannot be empty"
  )

  expect_error(
    cassidy_send_message(thread_id = "thread_123", message = ""),
    "message cannot be empty"
  )
})

httptest2::without_internet({
  test_that("cassidy_send_message() makes correct API request", {
    setup_test_env()

    expect_error(
      cassidy_send_message(fake_thread_id(), "Hello, world!"),
      "POST https://app.cassidyai.com/api/assistants/message/create"
    )
  })
})

httptest2::with_mock_api({
  test_that("cassidy_send_message() returns cassidy_response object", {
    setup_test_env()

    response <- cassidy_send_message(fake_thread_id(), "Hello!")

    expect_s3_class(response, "cassidy_response")
    expect_named(response, c("content", "thread_id", "timestamp", "raw"))
    expect_type(response$content, "character")
    expect_s3_class(response$timestamp, "POSIXct")
  })
})

# ══════════════════════════════════════════════════════════════════════════════
# TEST: cassidy_get_thread()
# ══════════════════════════════════════════════════════════════════════════════

test_that("cassidy_get_thread() validates thread_id", {
  expect_error(
    cassidy_get_thread(thread_id = NULL),
    "thread_id is required"
  )

  expect_error(
    cassidy_get_thread(thread_id = ""),
    "thread_id is required"
  )
})

httptest2::without_internet({
  test_that("cassidy_get_thread() makes correct API request", {
    setup_test_env()

    expect_error(
      cassidy_get_thread(fake_thread_id()),
      "GET https://app.cassidyai.com/api/assistants/thread/get"
    )
  })
})

httptest2::with_mock_api({
  test_that("cassidy_get_thread() returns cassidy_thread object", {
    setup_test_env()

    thread <- cassidy_get_thread(fake_thread_id())

    expect_s3_class(thread, "cassidy_thread")
    expect_named(
      thread,
      c(
        "thread_id",
        "messages",
        "assistant_id",
        "created_at",
        "message_count",
        "raw"
      )
    )
    expect_type(thread$messages, "list")
    expect_type(thread$message_count, "integer")
  })

  test_that("cassidy_get_thread() parses messages correctly", {
    setup_test_env()

    thread <- cassidy_get_thread(fake_thread_id())

    if (thread$message_count > 0) {
      first_msg <- thread$messages[[1]]
      expect_named(first_msg, c("role", "content", "timestamp"))
      expect_true(first_msg$role %in% c("user", "assistant", "system"))
      expect_type(first_msg$content, "character")
    }
  })
})

# ══════════════════════════════════════════════════════════════════════════════
# TEST: cassidy_list_threads()
# ══════════════════════════════════════════════════════════════════════════════

test_that("cassidy_list_threads() requires assistant_id", {
  withr::local_envvar(
    CASSIDY_API_KEY = fake_api_key(),
    CASSIDY_ASSISTANT_ID = ""
  )

  expect_error(
    cassidy_list_threads(),
    "CASSIDY_ASSISTANT_ID not found"
  )
})

httptest2::without_internet({
  test_that("cassidy_list_threads() makes correct API request", {
    setup_test_env()

    expect_error(
      cassidy_list_threads(),
      "GET https://app.cassidyai.com/api/assistants/threads/get"
    )
  })
})

httptest2::with_mock_api({
  test_that("cassidy_list_threads() returns cassidy_thread_list object", {
    setup_test_env()

    thread_list <- cassidy_list_threads()

    expect_s3_class(thread_list, "cassidy_thread_list")
    expect_named(thread_list, c("threads", "assistant_id", "total", "raw"))
    expect_s3_class(thread_list$threads, "data.frame")
    expect_type(thread_list$total, "integer")
  })

  test_that("cassidy_list_threads() data frame has correct structure", {
    setup_test_env()

    thread_list <- cassidy_list_threads()
    df <- thread_list$threads

    expect_named(
      df,
      c("thread_id", "created_at", "last_message", "message_count")
    )
    expect_type(df$thread_id, "character")
    expect_type(df$message_count, "integer")
  })
})

# ══════════════════════════════════════════════════════════════════════════════
# TEST: Print methods
# ══════════════════════════════════════════════════════════════════════════════

test_that("print.cassidy_response() returns invisibly", {
  response <- structure(
    list(
      content = "Test response content",
      thread_id = fake_thread_id(),
      timestamp = Sys.time(),
      raw = list()
    ),
    class = "cassidy_response"
  )

  result <- print(response)
  expect_identical(result, response)
})

test_that("print.cassidy_thread() returns invisibly", {
  thread <- structure(
    list(
      thread_id = fake_thread_id(),
      messages = list(
        list(role = "user", content = "Hello", timestamp = Sys.time()),
        list(role = "assistant", content = "Hi there", timestamp = Sys.time())
      ),
      assistant_id = fake_assistant_id(),
      created_at = "2024-01-12T10:00:00Z",
      message_count = 2L,
      raw = list()
    ),
    class = "cassidy_thread"
  )

  result <- print(thread)
  expect_identical(result, thread)
})

test_that("print.cassidy_thread_list() returns invisibly", {
  thread_list <- structure(
    list(
      threads = data.frame(
        thread_id = c("thread_1", "thread_2"),
        created_at = c("2024-01-12", "2024-01-11"),
        last_message = c("Hello", "Goodbye"),
        message_count = c(2L, 5L),
        stringsAsFactors = FALSE
      ),
      assistant_id = fake_assistant_id(),
      total = 2L,
      raw = list()
    ),
    class = "cassidy_thread_list"
  )

  result <- print(thread_list)
  expect_identical(result, thread_list)
})

# ══════════════════════════════════════════════════════════════════════════════
# TEST: %||% operator
# ══════════════════════════════════════════════════════════════════════════════

test_that("%||% returns left side if not NULL", {
  expect_equal("value" %||% "default", "value")
  expect_equal(123 %||% 456, 123)
  expect_equal(FALSE %||% TRUE, FALSE)
})

test_that("%||% returns right side if left is NULL", {
  expect_equal(NULL %||% "default", "default")
  expect_equal(NULL %||% 456, 456)
  expect_equal(NULL %||% TRUE, TRUE)
})
