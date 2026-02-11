# ══════════════════════════════════════════════════════════════════════════════
# TESTS FOR CHAT CSS/JS GENERATION
# Tests styling and JavaScript functions
# ══════════════════════════════════════════════════════════════════════════════

# ══════════════════════════════════════════════════════════════════════════════
# TEST: CSS Generation
# ══════════════════════════════════════════════════════════════════════════════

test_that("chat_app_css() returns non-empty string", {
  css <- chat_app_css()

  expect_type(css, "character")
  expect_true(nchar(css) > 0)
})

test_that("chat_app_css() includes critical layout selectors", {
  css <- chat_app_css()

  # Main layout
  expect_match(css, "\\.main-layout", fixed = FALSE)
  expect_match(css, "\\.chat-main", fixed = FALSE)

  # Sidebars
  expect_match(css, "\\.context-sidebar", fixed = FALSE)
  expect_match(css, "\\.history-sidebar", fixed = FALSE)

  # Messages
  expect_match(css, "\\.message-user", fixed = FALSE)
  expect_match(css, "\\.message-assistant", fixed = FALSE)

  # Chat area
  expect_match(css, "\\.chat-messages", fixed = FALSE)
  expect_match(css, "\\.chat-input-area", fixed = FALSE)
})

test_that("chat_app_css() includes file tree styles", {
  css <- chat_app_css()

  expect_match(css, "\\.file-tree-folder", fixed = FALSE)
  expect_match(css, "\\.file-tree-item", fixed = FALSE)
  expect_match(css, "\\.file-checkbox", fixed = FALSE)

  # File states
  expect_match(css, "\\.file-tree-item\\.sent", fixed = FALSE)
  expect_match(css, "\\.file-tree-item\\.pending", fixed = FALSE)
})

test_that("chat_app_css() includes responsive styles", {
  css <- chat_app_css()

  expect_match(css, "@media", fixed = TRUE)
  expect_match(css, "max-width: 768px", fixed = TRUE)
})

test_that("chat_app_css() includes copy code button styles", {
  css <- chat_app_css()

  expect_match(css, "\\.copy-code-btn", fixed = FALSE)
  expect_match(css, "\\.code-block-wrapper", fixed = FALSE)
})

test_that("individual CSS functions return strings", {
  expect_type(css_layout(), "character")
  expect_type(css_sidebars(), "character")
  expect_type(css_context_sections(), "character")
  expect_type(css_file_tree(), "character")
  expect_type(css_chat_area(), "character")
  expect_type(css_messages(), "character")
  expect_type(css_conversations(), "character")
  expect_type(css_responsive(), "character")
  expect_type(css_downloads(), "character")
  expect_type(css_context_states(), "character")
  expect_type(css_loading(), "character")
})

# ══════════════════════════════════════════════════════════════════════════════
# TEST: JavaScript Generation
# ══════════════════════════════════════════════════════════════════════════════

test_that("chat_app_js() returns non-empty string", {
  js <- chat_app_js()

  expect_type(js, "character")
  expect_true(nchar(js) > 0)
})

test_that("chat_app_js() includes sidebar toggle handlers", {
  js <- chat_app_js()

  expect_match(js, "context_sidebar_toggle", fixed = TRUE)
  expect_match(js, "history_sidebar_toggle", fixed = TRUE)
  expect_match(js, "toggleClass\\('collapsed'\\)", fixed = FALSE)
})

test_that("chat_app_js() includes copy button functionality", {
  js <- chat_app_js()

  expect_match(js, "addCopyButtons", fixed = TRUE)
  expect_match(js, "copy-code-btn", fixed = TRUE)
  expect_match(js, "navigator.clipboard", fixed = TRUE)
})

test_that("chat_app_js() includes Shiny message handlers", {
  js <- chat_app_js()

  expect_match(js, "Shiny.addCustomMessageHandler", fixed = TRUE)
  expect_match(js, "scrollToBottom", fixed = TRUE)
  expect_match(js, "syncFileCheckboxes", fixed = TRUE)
  expect_match(js, "syncDataCheckboxes", fixed = TRUE)
  expect_match(js, "clearInput", fixed = TRUE)
  expect_match(js, "setLoading", fixed = TRUE)
})

test_that("chat_app_js() includes file tree handlers", {
  js <- chat_app_js()

  expect_match(js, "toggleFolder", fixed = TRUE)
  expect_match(js, "expand_all_folders", fixed = TRUE)
  expect_match(js, "collapse_all_folders", fixed = TRUE)
})

test_that("chat_app_js() includes textarea behavior", {
  js <- chat_app_js()

  expect_match(js, "user_input", fixed = TRUE)
  expect_match(js, "this.style.height", fixed = TRUE)
  expect_match(js, "Enter.*shiftKey", fixed = FALSE)
})

test_that("chat_app_js() handles file checkbox changes", {
  js <- chat_app_js()

  expect_match(js, "file_checkbox_changed", fixed = TRUE)
  expect_match(js, "data-filepath", fixed = TRUE)
  expect_match(js, "Shiny.setInputValue", fixed = TRUE)
})

test_that("individual JS functions return strings", {
  expect_type(.js_sidebar_toggles(), "character")
  expect_type(.js_copy_buttons(), "character")
  expect_type(.js_shiny_handlers(), "character")
  expect_type(.js_textarea_behavior(), "character")
  expect_type(.js_init(), "character")
  expect_type(.js_helper_functions(), "character")
})

# ══════════════════════════════════════════════════════════════════════════════
# TEST: Stability - CSS/JS structure doesn't break
# ══════════════════════════════════════════════════════════════════════════════

test_that("CSS structure is stable", {
  css <- chat_app_css()

  # Count critical selectors to ensure they're all present
  sidebar_count <- length(gregexpr("\\.context-sidebar", css)[[1]])
  message_count <- length(gregexpr("\\.message-", css)[[1]])
  file_count <- length(gregexpr("\\.file-tree-", css)[[1]])

  expect_gte(sidebar_count, 2)  # At least 2 sidebar references
  expect_gte(message_count, 3)  # At least 3 message types
  expect_gte(file_count, 5)     # At least 5 file tree selectors
})

test_that("JS functions are defined", {
  js <- chat_app_js()

  # Check that key functions are defined
  expect_match(js, "function\\s+addCopyButtons", fixed = FALSE)
  expect_match(js, "function\\s+fallbackCopy", fixed = FALSE)
  expect_match(js, "window.toggleContextSection", fixed = TRUE)
  expect_match(js, "window.toggleFolder", fixed = TRUE)
})
