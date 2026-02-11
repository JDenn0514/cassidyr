# ══════════════════════════════════════════════════════════════════════════════
# TESTS FOR CHAT HANDLERS
# Tests handler setup and state management logic
# ══════════════════════════════════════════════════════════════════════════════

# ══════════════════════════════════════════════════════════════════════════════
# TEST: Message Renderer
# ══════════════════════════════════════════════════════════════════════════════

test_that("setup_message_renderer() creates output binding", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("S7")

  output <- list()
  conv_manager <- ConversationManager()

  expect_no_error(setup_message_renderer(output, conv_manager))
})

test_that("message renderer handles empty conversation", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("S7")

  output <- list()
  conv_manager <- ConversationManager()

  shiny::isolate({
    conv_create_new(conv_manager, session = NULL)
  })

  # Should not error with empty messages
  expect_no_error(setup_message_renderer(output, conv_manager))
})

test_that("message renderer handles messages with content", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("S7")
  skip_if_not_installed("commonmark")

  output <- list()
  conv_manager <- ConversationManager()

  shiny::isolate({
    conv_create_new(conv_manager, session = NULL)
    conv_add_message(conv_manager, "user", "Test message")
    conv_add_message(conv_manager, "assistant", "Test response")
  })

  # Should not error with messages
  expect_no_error(setup_message_renderer(output, conv_manager))
})

# ══════════════════════════════════════════════════════════════════════════════
# TEST: Conversation List Renderer
# ══════════════════════════════════════════════════════════════════════════════

test_that("setup_conversation_list_renderer() creates output binding", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("S7")

  output <- list()
  conv_manager <- ConversationManager()

  expect_no_error(setup_conversation_list_renderer(output, conv_manager))
})

test_that("conversation list renderer handles empty list", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("S7")

  output <- list()
  conv_manager <- ConversationManager()

  # Should not error with empty list
  expect_no_error(setup_conversation_list_renderer(output, conv_manager))
})

# ══════════════════════════════════════════════════════════════════════════════
# TEST: Context Data Renderer
# ══════════════════════════════════════════════════════════════════════════════

test_that("setup_context_data_renderer() creates output bindings", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("S7")

  output <- list()
  input <- list()
  conv_manager <- ConversationManager()

  expect_no_error(setup_context_data_renderer(output, input, conv_manager))
})

test_that("data count UI setup succeeds with no data frames", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("S7")

  output <- list()
  input <- list()
  conv_manager <- ConversationManager()

  # Should not error with no data frames
  expect_no_error(setup_context_data_renderer(output, input, conv_manager))
})

test_that("data UI setup succeeds with data frames in environment", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("S7")

  withr::defer(rm(test_df, envir = globalenv()))
  assign("test_df", data.frame(x = 1), envir = globalenv())

  output <- list()
  input <- list()
  conv_manager <- ConversationManager()

  # Should not error with data frames present
  expect_no_error(setup_context_data_renderer(output, input, conv_manager))
})

# ══════════════════════════════════════════════════════════════════════════════
# TEST: Context Summary Renderer
# ══════════════════════════════════════════════════════════════════════════════

test_that("setup_context_summary_renderer() creates output binding", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("S7")

  output <- list()
  input <- list()
  conv_manager <- ConversationManager()

  expect_no_error(setup_context_summary_renderer(output, input, conv_manager))
})

test_that("context summary setup succeeds with empty selections", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("S7")

  output <- list()
  input <- list(
    ctx_config = FALSE,
    ctx_session = FALSE,
    ctx_git = FALSE
  )
  conv_manager <- ConversationManager()

  # Should not error with empty selections
  expect_no_error(setup_context_summary_renderer(output, input, conv_manager))
})

# ══════════════════════════════════════════════════════════════════════════════
# TEST: File Context Renderer
# ══════════════════════════════════════════════════════════════════════════════

test_that("setup_file_context_renderer() creates output binding", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("S7")

  output <- list()
  conv_manager <- ConversationManager()

  expect_no_error(setup_file_context_renderer(output, conv_manager))
})

test_that("file context display setup succeeds with empty file list", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("S7")

  output <- list()
  conv_manager <- ConversationManager()

  # Should not error with empty file list
  expect_no_error(setup_file_context_renderer(output, conv_manager))
})

# ══════════════════════════════════════════════════════════════════════════════
# TEST: File Tree Renderer
# ══════════════════════════════════════════════════════════════════════════════

test_that("setup_file_tree_renderer() doesn't error", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("S7")

  output <- list()
  input <- list()
  conv_manager <- ConversationManager()

  expect_no_error(setup_file_tree_renderer(output, input, conv_manager))
})

test_that("file tree renderer setup succeeds with empty conversation", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("S7")

  output <- list()
  input <- list()
  conv_manager <- ConversationManager()

  shiny::isolate({
    conv_create_new(conv_manager, session = NULL)
  })

  # Should not error even with no files
  expect_no_error(setup_file_tree_renderer(output, input, conv_manager))
})

# ══════════════════════════════════════════════════════════════════════════════
# TEST: Handler Setup Functions Don't Error
# ══════════════════════════════════════════════════════════════════════════════

test_that("setup_conversation_switch_handler() doesn't error", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("S7")

  input <- list()
  session <- NULL
  conv_manager <- ConversationManager()

  expect_no_error(setup_conversation_switch_handler(input, session, conv_manager))
})

test_that("setup_conversation_delete_handlers() doesn't error", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("S7")

  input <- list()
  session <- NULL
  conv_manager <- ConversationManager()

  expect_no_error(setup_conversation_delete_handlers(input, session, conv_manager))
})

test_that("setup_new_chat_handler() doesn't error", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("S7")

  input <- list()
  session <- NULL
  conv_manager <- ConversationManager()

  expect_no_error(setup_new_chat_handler(input, session, conv_manager))
})

test_that("setup_conversation_load_handler() doesn't error", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("S7")

  input <- list()
  session <- NULL
  conv_manager <- ConversationManager()

  expect_no_error(setup_conversation_load_handler(input, session, conv_manager))
})

test_that("setup_conversation_export_handler() doesn't error", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("S7")

  input <- list()
  session <- NULL
  conv_manager <- ConversationManager()

  expect_no_error(setup_conversation_export_handler(input, session, conv_manager))
})

test_that("setup_file_selection_handlers() doesn't error", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("S7")

  input <- list()
  session <- NULL
  conv_manager <- ConversationManager()

  expect_no_error(setup_file_selection_handlers(input, session, conv_manager))
})

# ══════════════════════════════════════════════════════════════════════════════
# TEST: Handler Setup with API Parameters
# ══════════════════════════════════════════════════════════════════════════════

test_that("setup_send_message_handler() doesn't error", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("S7")

  input <- list()
  session <- NULL
  conv_manager <- ConversationManager()

  expect_no_error(
    setup_send_message_handler(
      input = input,
      session = session,
      conv_manager = conv_manager,
      assistant_id = "test_id",
      api_key = "test_key",
      timeout = 120
    )
  )
})

test_that("setup_apply_context_handler() doesn't error", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("S7")

  input <- list()
  session <- NULL
  conv_manager <- ConversationManager()

  expect_no_error(
    setup_apply_context_handler(
      input = input,
      session = session,
      conv_manager = conv_manager,
      assistant_id = "test_id",
      api_key = "test_key",
      timeout = 120
    )
  )
})

test_that("setup_refresh_context_handler() doesn't error", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("S7")

  input <- list()
  session <- NULL
  conv_manager <- ConversationManager()

  expect_no_error(
    setup_refresh_context_handler(
      input = input,
      session = session,
      conv_manager = conv_manager,
      assistant_id = "test_id",
      api_key = "test_key",
      timeout = 120
    )
  )
})

test_that("setup_file_context_handlers() doesn't error", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("S7")

  input <- list()
  session <- NULL
  conv_manager <- ConversationManager()

  expect_no_error(
    setup_file_context_handlers(
      input = input,
      session = session,
      conv_manager = conv_manager,
      assistant_id = "test_id",
      api_key = "test_key",
      timeout = 120
    )
  )
})

test_that("setup_new_chat_confirm_handler() doesn't error", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("S7")

  input <- list()
  session <- NULL
  conv_manager <- ConversationManager()

  expect_no_error(
    setup_new_chat_confirm_handler(
      input = input,
      session = session,
      conv_manager = conv_manager,
      assistant_id = "test_id",
      api_key = "test_key",
      timeout = 120
    )
  )
})

# ══════════════════════════════════════════════════════════════════════════════
# TEST: Integration - Multiple Handlers Together
# ══════════════════════════════════════════════════════════════════════════════

test_that("all handlers can be set up together without conflict", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("S7")

  output <- list()
  input <- list(
    ctx_config = FALSE,
    ctx_session = TRUE,
    ctx_git = FALSE
  )
  session <- NULL
  conv_manager <- ConversationManager()

  expect_no_error({
    # Renderers
    setup_message_renderer(output, conv_manager)
    setup_conversation_list_renderer(output, conv_manager)
    setup_context_data_renderer(output, input, conv_manager)
    setup_context_summary_renderer(output, input, conv_manager)
    setup_file_tree_renderer(output, input, conv_manager)

    # Handlers
    setup_conversation_switch_handler(input, session, conv_manager)
    setup_conversation_delete_handlers(input, session, conv_manager)
    setup_new_chat_handler(input, session, conv_manager)
    setup_file_selection_handlers(input, session, conv_manager)

    # Handlers with API params
    setup_send_message_handler(
      input, session, conv_manager,
      "test_id", "test_key", 120
    )
    setup_apply_context_handler(
      input, session, conv_manager,
      "test_id", "test_key", 120
    )
  })
})
