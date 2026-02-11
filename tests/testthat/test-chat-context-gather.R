# ══════════════════════════════════════════════════════════════════════════════
# TESTS FOR CHAT CONTEXT GATHERING
# Tests context logic without requiring Shiny app
# ══════════════════════════════════════════════════════════════════════════════

# ══════════════════════════════════════════════════════════════════════════════
# TEST: gather_context() - Core function
# ══════════════════════════════════════════════════════════════════════════════

test_that("gather_context() returns NULL when nothing selected", {
  result <- gather_context(
    config = FALSE,
    session = FALSE,
    git = FALSE,
    data = FALSE,
    files = NULL
  )

  expect_null(result)
})

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
  expect_match(result, R.version.string, fixed = TRUE)
  expect_match(result, getwd(), fixed = TRUE)
})

test_that("gather_context() includes config when available", {
  skip("Requires CASSIDY.md file in test environment")

  # This would need a temp CASSIDY.md file
  # withr::with_tempdir({
  #   writeLines("# Test Config", "CASSIDY.md")
  #   result <- gather_context(config = TRUE, session = FALSE, git = FALSE, data = FALSE)
  #   expect_match(result, "Test Config")
  # })
})

test_that("gather_context() handles git gracefully when not available", {
  # Should not error even if git fails
  result <- gather_context(
    config = FALSE,
    session = FALSE,
    git = TRUE,
    data = FALSE,
    files = NULL
  )

  # Either NULL (no git) or has git info
  expect_true(is.null(result) || is.character(result))
})

test_that("gather_context() includes data frames when requested", {
  skip_if_not_installed("shiny")

  # Create a test data frame in globalenv
  withr::defer(rm(test_df, envir = globalenv()))
  assign("test_df", data.frame(x = 1:3, y = 4:6), envir = globalenv())

  result <- gather_context(
    config = FALSE,
    session = FALSE,
    git = FALSE,
    data = TRUE,
    data_method = "basic",
    files = NULL,
    data_frames = "test_df"
  )

  expect_type(result, "character")
  expect_match(result, "test_df", fixed = TRUE)
  expect_match(result, "3 obs", fixed = TRUE)
})

test_that("gather_context() includes files when provided", {
  withr::with_tempdir({
    # Create a test file
    test_file <- "test.R"
    writeLines(c("# Test", "x <- 1"), test_file)

    result <- gather_context(
      config = FALSE,
      session = FALSE,
      git = FALSE,
      data = FALSE,
      files = test_file
    )

    expect_type(result, "character")
    expect_match(result, "test.R", fixed = TRUE)
  })
})

test_that("gather_context() combines multiple components", {
  withr::with_tempdir({
    test_file <- "test.R"
    writeLines("x <- 1", test_file)

    result <- gather_context(
      config = FALSE,
      session = TRUE,
      git = FALSE,
      data = FALSE,
      files = test_file
    )

    expect_type(result, "character")
    expect_match(result, "R Session Information", fixed = TRUE)
    expect_match(result, "test.R", fixed = TRUE)
    # Should be separated by ---
    expect_match(result, "---", fixed = TRUE)
  })
})

# ══════════════════════════════════════════════════════════════════════════════
# TEST: gather_selected_context() - Sidebar integration
# ══════════════════════════════════════════════════════════════════════════════

test_that("gather_selected_context() handles empty selections", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("S7")

  conv_manager <- ConversationManager()

  # Mock input with nothing selected
  mock_input <- list(
    ctx_config = FALSE,
    ctx_session = FALSE,
    ctx_git = FALSE,
    data_description_method = "basic"
  )

  shiny::isolate({
    result <- gather_selected_context(mock_input, conv_manager, incremental = FALSE)
  })

  # Should be NULL or empty when nothing selected
  expect_true(is.null(result) || !nzchar(result))
})

test_that("gather_selected_context() respects incremental mode", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("S7")

  conv_manager <- ConversationManager()

  withr::with_tempdir({
    test_file <- "test.R"
    writeLines("x <- 1", test_file)

    shiny::isolate({
      # Set up: file already sent
      conv_set_context_files(conv_manager, test_file)
      conv_set_sent_context_files(conv_manager, test_file)
    })

    mock_input <- list(
      ctx_config = FALSE,
      ctx_session = FALSE,
      ctx_git = FALSE,
      data_description_method = "basic"
    )

    shiny::isolate({
      # Incremental mode - should skip already sent file
      result <- gather_selected_context(mock_input, conv_manager, incremental = TRUE)

      # Should be NULL because file was already sent
      expect_true(is.null(result) || !nzchar(result))
    })
  })
})

test_that("gather_selected_context() includes pending refresh files", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("S7")

  conv_manager <- ConversationManager()

  withr::with_tempdir({
    test_file <- "test.R"
    writeLines("x <- 1", test_file)

    shiny::isolate({
      # File was sent, now marked for refresh
      conv_set_context_files(conv_manager, test_file)
      conv_set_sent_context_files(conv_manager, test_file)
      conv_set_pending_refresh_files(conv_manager, test_file)
    })

    mock_input <- list(
      ctx_config = FALSE,
      ctx_session = FALSE,
      ctx_git = FALSE,
      data_description_method = "basic"
    )

    shiny::isolate({
      result <- gather_selected_context(mock_input, conv_manager, incremental = TRUE)

      # Should include file even though it was sent, because it's pending refresh
      expect_type(result, "character")
      expect_match(result, "test.R", fixed = TRUE)

      # Check metadata
      files_to_send <- attr(result, "files_to_send")
      expect_equal(files_to_send, test_file)
    })
  })
})

# ══════════════════════════════════════════════════════════════════════════════
# TEST: gather_chat_context() - Wrapper for cassidy_app()
# ══════════════════════════════════════════════════════════════════════════════

test_that("gather_chat_context() respects context_level", {
  # Minimal
  result_minimal <- gather_chat_context(
    context_level = "minimal",
    include_data = FALSE,
    include_files = NULL
  )

  expect_type(result_minimal, "character")
  expect_match(result_minimal, "R Session", fixed = TRUE)

  # Standard (includes config + session)
  result_standard <- gather_chat_context(
    context_level = "standard",
    include_data = FALSE,
    include_files = NULL
  )

  expect_type(result_standard, "character")
  # Should have session
  expect_match(result_standard, "R Session", fixed = TRUE)
})

test_that("gather_chat_context() includes data when requested", {
  withr::defer(rm(test_df, envir = globalenv()))
  assign("test_df", data.frame(a = 1), envir = globalenv())

  result <- gather_chat_context(
    context_level = "minimal",
    include_data = TRUE,
    include_files = NULL
  )

  expect_type(result, "character")
  expect_match(result, "test_df", fixed = TRUE)
})

# ══════════════════════════════════════════════════════════════════════════════
# TEST: .determine_file_context_tier() - Tiering logic
# ══════════════════════════════════════════════════════════════════════════════

test_that(".determine_file_context_tier() returns full for empty list", {
  result <- .determine_file_context_tier(character(0))

  expect_equal(result$tier, "full")
  expect_equal(result$total_lines, 0)
  expect_equal(result$total_files, 0)
})

test_that(".determine_file_context_tier() returns full for small files", {
  withr::with_tempdir({
    # Create small file (under 2000 lines)
    small_file <- "small.R"
    writeLines(rep("x <- 1", 50), small_file)

    result <- .determine_file_context_tier(small_file)

    expect_equal(result$tier, "full")
    expect_equal(result$total_lines, 50)
    expect_equal(result$total_files, 1)
  })
})

test_that(".determine_file_context_tier() returns summary for medium files", {
  withr::with_tempdir({
    # Create medium-sized file (2001-5000 lines)
    medium_file <- "medium.R"
    writeLines(rep("x <- 1", 2500), medium_file)

    result <- .determine_file_context_tier(medium_file)

    expect_equal(result$tier, "summary")
    expect_equal(result$total_lines, 2500)
    expect_match(result$reason, "Medium context", fixed = TRUE)
  })
})

test_that(".determine_file_context_tier() returns index for large files", {
  withr::with_tempdir({
    # Create large file (>5000 lines)
    large_file <- "large.R"
    writeLines(rep("x <- 1", 6000), large_file)

    result <- .determine_file_context_tier(large_file)

    expect_equal(result$tier, "index")
    expect_equal(result$total_lines, 6000)
    expect_match(result$reason, "Large context", fixed = TRUE)
  })
})

test_that(".determine_file_context_tier() handles multiple files", {
  withr::with_tempdir({
    # Create multiple small files that add up to large
    files <- c("f1.R", "f2.R", "f3.R")
    for (f in files) {
      writeLines(rep("x <- 1", 1900), f)
    }

    result <- .determine_file_context_tier(files)

    # 3 * 1900 = 5700 lines total
    expect_equal(result$tier, "index")
    expect_equal(result$total_files, 3)
    expect_equal(result$total_lines, 5700)
  })
})

test_that(".determine_file_context_tier() handles missing files gracefully", {
  result <- .determine_file_context_tier("nonexistent.R")

  expect_equal(result$tier, "full")
  expect_equal(result$total_lines, 0)
})

# ══════════════════════════════════════════════════════════════════════════════
# TEST: .refresh_conversation_context() - Resume logic
# ══════════════════════════════════════════════════════════════════════════════

test_that(".refresh_conversation_context() always includes session info", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("S7")

  conv_manager <- ConversationManager()

  result <- .refresh_conversation_context(
    previous_files = character(),
    previous_data = NULL,
    conv_manager = conv_manager
  )

  expect_type(result, "character")
  expect_match(result, "R Session Information", fixed = TRUE)
})

test_that(".refresh_conversation_context() refreshes previous files", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("S7")

  withr::with_tempdir({
    test_file <- "test.R"
    writeLines("# Updated content", test_file)

    conv_manager <- ConversationManager()

    result <- .refresh_conversation_context(
      previous_files = test_file,
      previous_data = NULL,
      conv_manager = conv_manager
    )

    expect_type(result, "character")
    expect_match(result, "test.R", fixed = TRUE)
    expect_match(result, "Updated content", fixed = TRUE)
  })
})

test_that(".refresh_conversation_context() handles missing files", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("S7")

  conv_manager <- ConversationManager()

  # File that doesn't exist
  result <- .refresh_conversation_context(
    previous_files = "nonexistent.R",
    previous_data = NULL,
    conv_manager = conv_manager
  )

  # Should still return something (session info at minimum)
  expect_type(result, "character")
  expect_match(result, "R Session Information", fixed = TRUE)
  # Should NOT include the missing file
  expect_no_match(result, "nonexistent.R", fixed = TRUE)
})

test_that(".refresh_conversation_context() refreshes data frames", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("S7")

  withr::defer(rm(test_df, envir = globalenv()))
  assign("test_df", data.frame(x = 1:10, y = 11:20), envir = globalenv())

  conv_manager <- ConversationManager()

  result <- .refresh_conversation_context(
    previous_files = character(),
    previous_data = "test_df",
    conv_manager = conv_manager
  )

  expect_type(result, "character")
  expect_match(result, "test_df", fixed = TRUE)
  expect_match(result, "10 obs", fixed = TRUE)
})

test_that(".refresh_conversation_context() handles missing data frames", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("S7")

  conv_manager <- ConversationManager()

  # Data frame that doesn't exist
  result <- .refresh_conversation_context(
    previous_files = character(),
    previous_data = "nonexistent_df",
    conv_manager = conv_manager
  )

  # Should still work, just skip the missing data frame
  expect_type(result, "character")
  expect_match(result, "R Session Information", fixed = TRUE)
})

# ══════════════════════════════════════════════════════════════════════════════
# TEST: Edge Cases
# ══════════════════════════════════════════════════════════════════════════════

test_that("Context functions handle NULL inputs gracefully", {
  expect_no_error(gather_context(files = NULL))
  expect_no_error(gather_context(data_frames = NULL))
})

test_that("Context functions handle empty inputs gracefully", {
  expect_no_error(gather_context(files = character()))
  expect_no_error(gather_context(data_frames = character()))
})
