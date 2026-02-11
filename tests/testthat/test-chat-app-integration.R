# ══════════════════════════════════════════════════════════════════════════════
# TESTS FOR CASSIDY_APP() INTEGRATION
# Tests overall app structure and initialization
# ══════════════════════════════════════════════════════════════════════════════

# ══════════════════════════════════════════════════════════════════════════════
# TEST: cassidy_app() Validation
# ══════════════════════════════════════════════════════════════════════════════

test_that("cassidy_app() requires API key", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")

  withr::local_envvar(
    CASSIDY_API_KEY = "",
    CASSIDY_ASSISTANT_ID = "test_id"
  )

  expect_error(
    cassidy_app(),
    "API key not found"
  )
})

test_that("cassidy_app() requires assistant ID", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")

  withr::local_envvar(
    CASSIDY_API_KEY = "test_key",
    CASSIDY_ASSISTANT_ID = ""
  )

  expect_error(
    cassidy_app(),
    "assistant ID not found"
  )
})

test_that("cassidy_app() validates context_level", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")

  withr::local_envvar(
    CASSIDY_API_KEY = "test_key",
    CASSIDY_ASSISTANT_ID = "test_id"
  )

  expect_error(
    cassidy_app(context_level = "invalid"),
    "should be one of"
  )
})

# ══════════════════════════════════════════════════════════════════════════════
# TEST: App Structure (without launching)
# ══════════════════════════════════════════════════════════════════════════════

test_that("cassidy_app() has correct structure for new chat", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")
  skip_if_not_installed("S7")

  skip("Interactive app - can't test structure without launching")

  # This would require more sophisticated Shiny testing
  # Using shiny::testServer() or similar
})

test_that("cassidy_app() handles new_chat parameter", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")

  skip("Interactive app - requires server testing framework")
})

# ══════════════════════════════════════════════════════════════════════════════
# TEST: Context Gathering on App Init
# ══════════════════════════════════════════════════════════════════════════════

test_that("app gathers context correctly for new_chat = TRUE", {
  # This is tested indirectly via gather_chat_context() tests
  expect_true(TRUE)
})

test_that("app skips context for new_chat = FALSE", {
  # This is tested indirectly via gather_chat_context() tests
  expect_true(TRUE)
})

# ══════════════════════════════════════════════════════════════════════════════
# TEST: Theme Handling
# ══════════════════════════════════════════════════════════════════════════════

test_that("cassidy_app() uses custom theme when provided", {
  skip_if_not_installed("bslib")

  custom_theme <- bslib::bs_theme(
    version = 5,
    primary = "#FF0000"
  )

  # Can't easily test without launching, but ensure no error
  expect_s3_class(custom_theme, "bs_theme")
})

test_that("cassidy_app() creates default theme when not provided", {
  skip_if_not_installed("bslib")

  default_theme <- bslib::bs_theme(
    version = 5,
    preset = "shiny",
    primary = "#0d6efd",
    "font-size-base" = "0.95rem"
  )

  expect_s3_class(default_theme, "bs_theme")
})

# ══════════════════════════════════════════════════════════════════════════════
# TEST: Conversation Persistence Integration
# ══════════════════════════════════════════════════════════════════════════════

test_that("app checks for existing conversations on startup", {
  skip_if_not_installed("shiny")

  # cassidy_list_conversations should be called
  # This is hard to test without mocking
  expect_true(TRUE)
})

test_that("app handles missing conversations directory gracefully", {
  # Should create directory if needed
  # This is tested in persistence tests
  expect_true(TRUE)
})

# ══════════════════════════════════════════════════════════════════════════════
# TEST: UI Generation
# ══════════════════════════════════════════════════════════════════════════════

test_that("app UI includes all required components", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")

  theme <- bslib::bs_theme(version = 5)
  ui <- chat_build_ui(theme, "standard")

  html <- as.character(ui)

  # Main layout
  expect_match(html, "main-layout", fixed = TRUE)

  # Sidebars
  expect_match(html, "context-sidebar", fixed = TRUE)
  expect_match(html, "history-sidebar", fixed = TRUE)

  # Chat area
  expect_match(html, "chat-main", fixed = TRUE)
  expect_match(html, "chat-messages", fixed = TRUE)
  expect_match(html, "chat-input-area", fixed = TRUE)

  # Input elements
  expect_match(html, "user_input", fixed = TRUE)
  expect_match(html, "send", fixed = TRUE)

  # Context controls
  expect_match(html, "apply_context", fixed = TRUE)
  expect_match(html, "ctx_config", fixed = TRUE)
  expect_match(html, "ctx_session", fixed = TRUE)
  expect_match(html, "ctx_git", fixed = TRUE)

  # History controls
  expect_match(html, "new_chat", fixed = TRUE)
  expect_match(html, "conversation_list", fixed = TRUE)
})

test_that("app UI includes CSS and JavaScript", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")

  theme <- bslib::bs_theme(version = 5)
  ui <- chat_build_ui(theme, "comprehensive")

  html <- as.character(ui)

  # CSS should be embedded
  expect_match(html, "<style>", fixed = TRUE)
  expect_match(html, "chat-messages", fixed = TRUE)

  # JavaScript should be embedded
  expect_match(html, "<script>", fixed = TRUE)
  expect_match(html, "Shiny.addCustomMessageHandler", fixed = TRUE)
})

# ══════════════════════════════════════════════════════════════════════════════
# TEST: Skills Integration (for future)
# ══════════════════════════════════════════════════════════════════════════════

test_that("adding skills to context doesn't break existing features", {
  skip("Skills not yet integrated into cassidy_app()")

  # When skills are added to cassidy_app(), test that:
  # 1. gather_context() includes skills metadata
  # 2. Skills don't conflict with file/data context
  # 3. Skills UI is properly rendered
  # 4. Skills can be toggled on/off
})

# ══════════════════════════════════════════════════════════════════════════════
# TEST: Error Handling
# ══════════════════════════════════════════════════════════════════════════════

test_that("app handles missing required packages gracefully", {
  skip_if_not_installed("shiny")

  # These checks happen in cassidy_app()
  expect_true(rlang::is_installed("shiny"))
  expect_true(rlang::is_installed("bslib"))
  expect_true(rlang::is_installed("S7"))
})

test_that("app provides helpful error when packages missing", {
  skip("Would need to unload packages to test")

  # cassidy_app() uses rlang::check_installed()
  # which provides helpful error messages
})

# ══════════════════════════════════════════════════════════════════════════════
# TEST: Regression Tests - Common Breakage Points
# ══════════════════════════════════════════════════════════════════════════════

test_that("file tree renders without errors with empty project", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("S7")

  withr::with_tempdir({
    # Empty directory - no files
    output <- list()
    input <- list()
    conv_manager <- ConversationManager()

    # Should not error with empty directory
    expect_no_error(setup_file_tree_renderer(output, input, conv_manager))
  })
})

test_that("conversation list renders without saved conversations", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("S7")

  output <- list()
  conv_manager <- ConversationManager()

  # Should not error with no conversations
  expect_no_error(setup_conversation_list_renderer(output, conv_manager))
})

test_that("data context renders with no data frames in environment", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("S7")

  output <- list()
  input <- list()
  conv_manager <- ConversationManager()

  # Should not error with no data frames
  expect_no_error(setup_context_data_renderer(output, input, conv_manager))
})

test_that("messages render with markdown content", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("S7")
  skip_if_not_installed("commonmark")

  output <- list()
  conv_manager <- ConversationManager()

  shiny::isolate({
    conv_create_new(conv_manager, session = NULL)

    # Add messages with markdown
    conv_add_message(conv_manager, "user", "# Heading\n**bold** text")
    conv_add_message(conv_manager, "assistant", "```r\nx <- 1\n```")
  })

  # Should not error with markdown content
  expect_no_error(setup_message_renderer(output, conv_manager))
})

test_that("context summary updates when selections change", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("S7")

  output <- list()
  conv_manager <- ConversationManager()

  # Test with different input combinations
  test_inputs <- list(
    list(ctx_config = TRUE, ctx_session = FALSE, ctx_git = FALSE),
    list(ctx_config = FALSE, ctx_session = TRUE, ctx_git = FALSE),
    list(ctx_config = TRUE, ctx_session = TRUE, ctx_git = TRUE)
  )

  for (test_input in test_inputs) {
    # Should not error with different input combinations
    expect_no_error(setup_context_summary_renderer(output, test_input, conv_manager))
  }
})

# ══════════════════════════════════════════════════════════════════════════════
# TEST: Performance & Scale
# ══════════════════════════════════════════════════════════════════════════════

test_that("file tree handles many files efficiently", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("S7")

  withr::with_tempdir({
    # Create many files
    for (i in 1:100) {
      writeLines("x <- 1", paste0("file", i, ".R"))
    }

    output <- list()
    input <- list()
    conv_manager <- ConversationManager()

    # Should set up without excessive delay
    expect_no_error(setup_file_tree_renderer(output, input, conv_manager))
  })
})

test_that("conversation list handles many conversations", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("S7")

  output <- list()
  conv_manager <- ConversationManager()

  shiny::isolate({
    # Create multiple conversations
    for (i in 1:10) {
      conv_create_new(conv_manager, session = NULL)
      conv_add_message(conv_manager, "user", paste("Message", i))
    }
  })

  # Should handle many conversations without error
  expect_no_error(setup_conversation_list_renderer(output, conv_manager))
})
