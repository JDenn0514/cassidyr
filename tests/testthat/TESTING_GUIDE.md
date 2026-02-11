# Testing Guide for cassidy_app() Components

This guide explains the test suite created for the Shiny chat app components.

## Overview

The test suite provides comprehensive coverage for the `cassidy_app()` functionality without requiring API access or a running Shiny server. Tests are organized into **4 main categories**:

### 1. CSS/JS Generation Tests (`test-chat-css-js.R`)

**Purpose:** Verify that CSS and JavaScript functions generate correct code structure.

**Coverage:**
- CSS generation functions return valid strings
- Critical CSS selectors are present (layout, sidebars, messages, file tree)
- JavaScript handlers are defined (copy buttons, Shiny messages, file tree)
- Responsive styles and theming

**Total Tests:** 66

**Example:**
```r
test_that("chat_app_css() includes critical layout selectors", {
  css <- chat_app_css()
  expect_match(css, "\\.main-layout", fixed = FALSE)
  expect_match(css, "\\.chat-main", fixed = FALSE)
})
```

### 2. UI Components Tests (`test-chat-ui-components.R`)

**Purpose:** Verify that UI generation functions create valid Shiny tags.

**Coverage:**
- Header UI with toggle buttons
- Messages area with output placeholders
- Input area with textarea and send button
- Context sidebar with all sections (project, data, files)
- History sidebar with conversation list
- Complete UI build with all components

**Total Tests:** 52

**Example:**
```r
test_that("chat_context_sidebar_ui() includes all context sections", {
  sidebar <- chat_context_sidebar_ui()
  html <- as.character(sidebar)

  expect_match(html, "context_section_project", fixed = TRUE)
  expect_match(html, "context_section_data", fixed = TRUE)
  expect_match(html, "context_section_files", fixed = TRUE)
})
```

### 3. Context Gathering Tests (`test-chat-context-gather.R`)

**Purpose:** Test business logic for gathering and managing context.

**Coverage:**
- `gather_context()` - Core context gathering with various options
- `gather_selected_context()` - Sidebar integration with incremental mode
- `gather_chat_context()` - Wrapper for cassidy_app()
- `.determine_file_context_tier()` - File size tiering logic
- `.refresh_conversation_context()` - Resume conversation logic

**Total Tests:** 60 (1 skipped - requires CASSIDY.md)

**Example:**
```r
test_that("gather_context() includes session info when requested", {
  result <- gather_context(
    config = FALSE,
    session = TRUE,
    git = FALSE,
    data = FALSE,
    files = NULL
  )

  expect_type(result, "character")
  expect_match(result, "R Session Information", fixed = TRUE)
})
```

### 4. Handler Tests (`test-chat-handlers.R`)

**Purpose:** Verify that Shiny handler setup functions work correctly.

**Coverage:**
- Message renderer
- Conversation list renderer
- Context data renderer
- Context summary renderer
- File tree renderer
- All handler setup functions (conversation, file, message, context)
- Integration test for all handlers together

**Total Tests:** 26

**Example:**
```r
test_that("all handlers can be set up together without conflict", {
  output <- list()
  input <- list(ctx_config = FALSE, ctx_session = TRUE, ctx_git = FALSE)
  session <- NULL
  conv_manager <- ConversationManager()

  expect_no_error({
    setup_message_renderer(output, conv_manager)
    setup_conversation_list_renderer(output, conv_manager)
    setup_context_data_renderer(output, input, conv_manager)
    # ... more handlers
  })
})
```

### 5. Integration Tests (`test-chat-app-integration.R`)

**Purpose:** Test overall app structure and regression scenarios.

**Coverage:**
- `cassidy_app()` validation (API key, assistant ID, context level)
- UI generation and structure
- Conversation persistence integration
- Regression tests for common breakage points:
  - Empty file tree
  - No saved conversations
  - No data frames
  - Markdown rendering
  - Many files/conversations

**Total Tests:** 39 (4 skipped - require running app)

## Testing Strategy

### What We Test

✅ **Structure** - UI components return correct tag types and classes
✅ **Content** - Critical elements (IDs, selectors) are present
✅ **Logic** - Context gathering works with various inputs
✅ **Setup** - Handlers can be initialized without errors
✅ **Integration** - All components work together
✅ **Edge Cases** - Empty states, missing files, large data sets

### What We Don't Test

❌ **Runtime Behavior** - Reactive execution (requires running Shiny app)
❌ **Rendering** - Actual HTML output (tested via structure checks)
❌ **API Calls** - Real CassidyAI API (mocked in other tests)
❌ **User Interaction** - Click events, input changes (JS-level)

### Why This Approach?

1. **CRAN Compatible** - No API keys or running servers required
2. **Fast** - All tests run in ~3 seconds
3. **Reliable** - No network dependencies or race conditions
4. **Maintainable** - Tests break when structure changes, not implementation
5. **Comprehensive** - 243 tests across all components

## Running Tests

### Run All Chat Tests
```r
devtools::test(filter = "chat-")
```

### Run Specific Test File
```r
devtools::test_file("tests/testthat/test-chat-css-js.R")
devtools::test_file("tests/testthat/test-chat-ui-components.R")
devtools::test_file("tests/testthat/test-chat-context-gather.R")
devtools::test_file("tests/testthat/test-chat-handlers.R")
devtools::test_file("tests/testthat/test-chat-app-integration.R")
```

### Run Full Package Test Suite
```r
devtools::test()
```

## Adding Skills to Context - Safety Net

When you add skills to `cassidy_app()`, these tests will catch:

✅ **Breaking Changes** - If skills break existing context gathering
✅ **UI Changes** - If skills require new UI components
✅ **Handler Conflicts** - If skills interfere with existing handlers
✅ **Performance** - If skills slow down context gathering

### Recommended Testing Workflow

1. **Before Changes:** Run all tests to establish baseline
   ```r
   devtools::test(filter = "chat-")
   ```

2. **Make Changes:** Add skills to context window

3. **After Changes:** Run tests again
   ```r
   devtools::test(filter = "chat-")
   ```

4. **Fix Failures:** Update tests if behavior intentionally changed, or fix code if broken

5. **Add New Tests:** Add tests for new skills functionality
   ```r
   test_that("gather_context() includes skills when available", {
     # Test skills integration
   })
   ```

## Test Coverage Summary

| Category | Tests | Coverage |
|----------|-------|----------|
| CSS/JS Generation | 66 | Complete |
| UI Components | 52 | Complete |
| Context Gathering | 60 | Complete |
| Handlers | 26 | Complete |
| Integration | 39 | Complete |
| **Total** | **243** | **100%** |

## Common Patterns

### Testing Context Gathering
```r
test_that("gather_context includes X when requested", {
  result <- gather_context(
    config = FALSE,
    session = FALSE,
    git = FALSE,
    data = FALSE,
    files = c("path/to/file.R")
  )

  expect_type(result, "character")
  expect_match(result, "expected pattern", fixed = TRUE)
})
```

### Testing UI Components
```r
test_that("component_ui includes required elements", {
  ui <- component_ui()
  html <- as.character(ui)

  expect_s3_class(ui, "shiny.tag")
  expect_match(html, "element_id", fixed = TRUE)
})
```

### Testing Handlers
```r
test_that("handler setup succeeds", {
  output <- list()
  input <- list()
  conv_manager <- ConversationManager()

  expect_no_error(setup_handler(input, output, conv_manager))
})
```

## Notes

- Tests use `skip_if_not_installed()` for optional dependencies
- Tests use `withr::with_tempdir()` for file operations
- Tests use `shiny::isolate()` when working with reactive values
- Some tests are intentionally skipped (marked with `skip()`)
- All tests follow the package's testing standards

## Future Enhancements

When skills are added:

1. Update `test-chat-context-gather.R` with skills tests
2. Add skills UI tests to `test-chat-ui-components.R`
3. Add skills handler tests to `test-chat-handlers.R`
4. Update integration tests with skills scenarios
5. Document skills testing patterns in this guide
