# ══════════════════════════════════════════════════════════════════════════════
# TESTS FOR CHAT UI COMPONENTS
# Tests UI generation functions
# ══════════════════════════════════════════════════════════════════════════════

# ══════════════════════════════════════════════════════════════════════════════
# TEST: Header UI
# ══════════════════════════════════════════════════════════════════════════════

test_that("chat_header_ui() returns valid shiny tag", {
  skip_if_not_installed("shiny")

  header <- chat_header_ui("standard")

  expect_s3_class(header, "shiny.tag")
  expect_equal(header$name, "div")
  expect_true("app-header" %in% strsplit(header$attribs$class, " ")[[1]])
})

test_that("chat_header_ui() includes toggle buttons", {
  skip_if_not_installed("shiny")

  header <- chat_header_ui("standard")
  html <- as.character(header)

  expect_match(html, "context_sidebar_toggle", fixed = TRUE)
  expect_match(html, "history_sidebar_toggle", fixed = TRUE)
})

test_that("chat_header_ui() includes title", {
  skip_if_not_installed("shiny")

  header <- chat_header_ui("comprehensive")
  html <- as.character(header)

  expect_match(html, "Cassidy Chat", fixed = TRUE)
})

# ══════════════════════════════════════════════════════════════════════════════
# TEST: Messages UI
# ══════════════════════════════════════════════════════════════════════════════

test_that("chat_messages_ui() returns valid shiny tag", {
  skip_if_not_installed("shiny")

  messages <- chat_messages_ui()

  expect_s3_class(messages, "shiny.tag")
  expect_equal(messages$name, "div")
  expect_true("chat-messages" %in% strsplit(messages$attribs$class, " ")[[1]])
})

test_that("chat_messages_ui() includes output placeholder", {
  skip_if_not_installed("shiny")

  messages <- chat_messages_ui()
  html <- as.character(messages)

  expect_match(html, "messages", fixed = TRUE)
  expect_match(html, "shiny-html-output", fixed = TRUE)
})

# ══════════════════════════════════════════════════════════════════════════════
# TEST: Input UI
# ══════════════════════════════════════════════════════════════════════════════

test_that("chat_input_ui() returns valid shiny tag", {
  skip_if_not_installed("shiny")

  input_ui <- chat_input_ui()

  expect_s3_class(input_ui, "shiny.tag")
  expect_equal(input_ui$name, "div")
  expect_true("chat-input-area" %in% strsplit(input_ui$attribs$class, " ")[[1]])
})

test_that("chat_input_ui() includes textarea and send button", {
  skip_if_not_installed("shiny")

  input_ui <- chat_input_ui()
  html <- as.character(input_ui)

  expect_match(html, "user_input", fixed = TRUE)
  expect_match(html, "send", fixed = TRUE)
  expect_match(html, "textarea", fixed = TRUE)
})

# ══════════════════════════════════════════════════════════════════════════════
# TEST: Context Sidebar UI
# ══════════════════════════════════════════════════════════════════════════════

test_that("chat_context_sidebar_ui() returns valid shiny tag", {
  skip_if_not_installed("shiny")

  sidebar <- chat_context_sidebar_ui()

  expect_s3_class(sidebar, "shiny.tag")
  expect_equal(sidebar$name, "div")
  expect_true("context-sidebar" %in% strsplit(sidebar$attribs$class, " ")[[1]])
})

test_that("chat_context_sidebar_ui() includes all context sections", {
  skip_if_not_installed("shiny")

  sidebar <- chat_context_sidebar_ui()
  html <- as.character(sidebar)

  # Project section
  expect_match(html, "context_section_project", fixed = TRUE)
  expect_match(html, "ctx_config", fixed = TRUE)
  expect_match(html, "ctx_session", fixed = TRUE)
  expect_match(html, "ctx_git", fixed = TRUE)

  # Data section
  expect_match(html, "context_section_data", fixed = TRUE)
  expect_match(html, "data_description_method", fixed = TRUE)

  # Files section
  expect_match(html, "context_section_files", fixed = TRUE)
  expect_match(html, "add_files", fixed = TRUE)
})

test_that("chat_context_sidebar_ui() includes apply button", {
  skip_if_not_installed("shiny")

  sidebar <- chat_context_sidebar_ui()
  html <- as.character(sidebar)

  expect_match(html, "apply_context", fixed = TRUE)
  expect_match(html, "Apply Context", fixed = TRUE)
})

test_that("chat_context_sidebar_ui() includes refresh buttons", {
  skip_if_not_installed("shiny")

  sidebar <- chat_context_sidebar_ui()
  html <- as.character(sidebar)

  expect_match(html, "refresh_all_context", fixed = TRUE)
  expect_match(html, "refresh_config", fixed = TRUE)
  expect_match(html, "refresh_session", fixed = TRUE)
  expect_match(html, "refresh_git", fixed = TRUE)
})

# ══════════════════════════════════════════════════════════════════════════════
# TEST: History Sidebar UI
# ══════════════════════════════════════════════════════════════════════════════

test_that("chat_history_sidebar_ui() returns valid shiny tag", {
  skip_if_not_installed("shiny")

  sidebar <- chat_history_sidebar_ui()

  expect_s3_class(sidebar, "shiny.tag")
  expect_equal(sidebar$name, "div")
  expect_true("history-sidebar" %in% strsplit(sidebar$attribs$class, " ")[[1]])
})

test_that("chat_history_sidebar_ui() includes new chat button", {
  skip_if_not_installed("shiny")

  sidebar <- chat_history_sidebar_ui()
  html <- as.character(sidebar)

  expect_match(html, "new_chat", fixed = TRUE)
  expect_match(html, "New Chat", fixed = TRUE)
})

test_that("chat_history_sidebar_ui() includes conversation list", {
  skip_if_not_installed("shiny")

  sidebar <- chat_history_sidebar_ui()
  html <- as.character(sidebar)

  expect_match(html, "conversation_list", fixed = TRUE)
  expect_match(html, "conversation-list", fixed = TRUE)
})

# ══════════════════════════════════════════════════════════════════════════════
# TEST: Complete UI Build
# ══════════════════════════════════════════════════════════════════════════════

test_that("chat_build_ui() returns valid bslib page", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")

  theme <- bslib::bs_theme(version = 5)
  ui <- chat_build_ui(theme, "standard")

  expect_s3_class(ui, "bslib_page")
})

test_that("chat_build_ui() includes CSS and JavaScript", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")

  theme <- bslib::bs_theme(version = 5)
  ui <- chat_build_ui(theme, "standard")
  html <- as.character(ui)

  # Check for CSS presence (partial match)
  expect_match(html, "main-layout", fixed = TRUE)

  # Check for JS presence (partial match)
  expect_match(html, "toggleContextSection", fixed = TRUE)
})

test_that("chat_build_ui() includes all major components", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")

  theme <- bslib::bs_theme(version = 5)
  ui <- chat_build_ui(theme, "comprehensive")
  html <- as.character(ui)

  # Context sidebar
  expect_match(html, "context-sidebar", fixed = TRUE)

  # Chat area
  expect_match(html, "chat-main", fixed = TRUE)
  expect_match(html, "chat-messages", fixed = TRUE)
  expect_match(html, "chat-input-area", fixed = TRUE)

  # History sidebar
  expect_match(html, "history-sidebar", fixed = TRUE)
})

# ══════════════════════════════════════════════════════════════════════════════
# TEST: UI Stability
# ══════════════════════════════════════════════════════════════════════════════

test_that("UI structure has expected element counts", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")

  theme <- bslib::bs_theme(version = 5)
  ui <- chat_build_ui(theme, "standard")
  html <- as.character(ui)

  # Should have multiple context sections
  context_sections <- gregexpr("context-section", html, fixed = TRUE)
  expect_gte(length(context_sections[[1]]), 3)

  # Should have both sidebars
  expect_match(html, "context_sidebar", fixed = TRUE)
  expect_match(html, "history_sidebar", fixed = TRUE)
})
