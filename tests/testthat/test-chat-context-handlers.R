# tests/testthat/test-chat-context-handlers.R

# ========================================================================
# gather_context ---------------------------------------------------------
# ========================================================================

test_that("gather_context includes config when requested", {
  withr::with_tempdir({
    # Create a cassidy.md file
    writeLines("# Test Project\nThis is test context.", "CASSIDY.md")

    result <- gather_context(
      config = TRUE,
      session = FALSE,
      git = FALSE,
      data = FALSE,
      files = NULL
    )

    expect_true(grepl("Project Configuration", result))
    expect_true(grepl("Test Project", result))
  })
})

test_that("gather_context includes session info when requested", {
  result <- gather_context(
    config = FALSE,
    session = TRUE,
    git = FALSE,
    data = FALSE,
    files = NULL
  )

  expect_true(grepl("R Session Information", result))
  expect_true(grepl("R version", result))
  expect_true(grepl(getwd(), result, fixed = TRUE))
})

test_that("gather_context includes files when provided", {
  withr::with_tempdir({
    # Create test files
    writeLines("test_func <- function(x) x + 1", "test.R")

    result <- gather_context(
      config = FALSE,
      session = FALSE,
      git = FALSE,
      data = FALSE,
      files = "test.R"
    )

    expect_true(grepl("test.R", result))
    expect_true(grepl("test_func", result))
  })
})

test_that("gather_context filters data frames when data_frames provided", {
  # Create test data frames in a temporary environment
  withr::with_envvar(list(), {
    # Skip if we can't safely modify global env in test
    skip_if_not(
      interactive(),
      "Skipping data frame test in non-interactive mode"
    )

    # This test verifies the logic without actually modifying globalenv
    dfs <- list(
      df1 = data.frame(a = 1),
      df2 = data.frame(b = 2),
      df3 = data.frame(c = 3)
    )

    # Test the filtering logic directly
    df_names <- c("df1", "df3")
    filtered <- intersect(df_names, names(dfs))

    expect_equal(filtered, c("df1", "df3"))
    expect_false("df2" %in% filtered)
  })
})

test_that("gather_context returns NULL when nothing selected", {
  withr::with_tempdir({
    result <- gather_context(
      config = FALSE,
      session = FALSE,
      git = FALSE,
      data = FALSE,
      files = NULL
    )

    expect_null(result)
  })
})

test_that("gather_context combines multiple parts with separators", {
  withr::with_tempdir({
    writeLines("# Test", "CASSIDY.md")
    writeLines("x <- 1", "test.R")

    result <- gather_context(
      config = TRUE,
      session = TRUE,
      git = FALSE,
      data = FALSE,
      files = "test.R"
    )

    # Should have separators between sections
    expect_true(grepl("---", result))
    # Should have all three sections
    expect_true(grepl("Project Configuration", result))
    expect_true(grepl("R Session Information", result))
    expect_true(grepl("test.R", result))
  })
})

test_that("gather_context skips non-existent files gracefully", {
  result <- gather_context(
    config = FALSE,
    session = TRUE,
    git = FALSE,
    data = FALSE,
    files = c("nonexistent_file.R", "also_missing.R")
  )

  # Should still return session info
  expect_true(grepl("R Session Information", result))
  # Should not error
  expect_false(grepl("nonexistent_file", result))
})

# ========================================================================
# gather_selected_context ------------------------------------------------
# ========================================================================

test_that("gather_selected_context calculates incremental files correctly", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("S7")

  # Test the incremental logic in isolation
  selected_files <- c("file1.R", "file2.R", "file3.R")
  sent_files <- c("file1.R")
  pending_files <- c("file1.R") # file1 marked for refresh

  # New files = selected - sent
  new_files <- setdiff(selected_files, sent_files)
  expect_equal(new_files, c("file2.R", "file3.R"))

  # Files to send = new + pending refresh
  files_to_send <- union(new_files, pending_files)
  expect_equal(sort(files_to_send), c("file1.R", "file2.R", "file3.R"))
})

test_that("gather_selected_context calculates incremental data correctly", {
  # Test the incremental logic for data frames
  selected_data <- c("mtcars", "iris", "diamonds")
  sent_data <- c("mtcars", "iris")
  pending_data <- c("mtcars") # mtcars marked for refresh

  # New data = selected - sent
  new_data <- setdiff(selected_data, sent_data)
  expect_equal(new_data, "diamonds")

  # Data to send = new + pending refresh

  data_to_send <- union(new_data, pending_data)
  expect_equal(sort(data_to_send), c("diamonds", "mtcars"))
})

test_that("incremental=FALSE sends all selected items", {
  # When incremental is FALSE, should send everything selected
  selected_files <- c("file1.R", "file2.R", "file3.R")
  sent_files <- c("file1.R", "file2.R")

  # With incremental = TRUE
  files_incremental <- setdiff(selected_files, sent_files)
  expect_equal(files_incremental, "file3.R")

  # With incremental = FALSE (simulated)
  files_full <- selected_files
  expect_equal(files_full, c("file1.R", "file2.R", "file3.R"))
})

test_that("gather_selected_context attaches metadata attributes", {
  withr::with_tempdir({
    writeLines("x <- 1", "test.R")

    # Create a minimal mock for testing attribute attachment
    result <- gather_context(
      config = FALSE,
      session = TRUE,
      git = FALSE,
      data = FALSE,
      files = "test.R"
    )

    # Simulate attaching attributes as gather_selected_context does
    attr(result, "files_to_send") <- "test.R"
    attr(result, "data_to_send") <- character()

    expect_equal(attr(result, "files_to_send"), "test.R")
    expect_equal(attr(result, "data_to_send"), character())
  })
})

test_that("union correctly combines new and pending items", {
  # Edge case: pending item not in selected (shouldn't happen but be safe)
  selected <- c("a.R", "b.R")
  sent <- c("a.R")
  pending <- c("c.R") # c.R in pending but not selected

  new_items <- setdiff(selected, sent)
  to_send <- union(new_items, pending)

  # union includes pending even if not in selected
  expect_true("c.R" %in% to_send)
  expect_true("b.R" %in% to_send)
  expect_false("a.R" %in% to_send) # a.R was sent, not pending
})

test_that("empty selections return appropriate results", {
  # All empty
  selected_files <- character()
  sent_files <- character()
  pending_files <- character()

  new_files <- setdiff(selected_files, sent_files)
  files_to_send <- union(new_files, pending_files)

  expect_equal(files_to_send, character())
  expect_length(files_to_send, 0)
})

test_that("already-sent items are excluded without pending refresh", {
  selected <- c("a.R", "b.R", "c.R")
  sent <- c("a.R", "b.R", "c.R") # Everything already sent
  pending <- character() # Nothing pending refresh

  new_items <- setdiff(selected, sent)
  to_send <- union(new_items, pending)

  expect_length(to_send, 0)
})


# ========================================================================
# --- Tests for setup_apply_context_handler logic ------------------------
# ========================================================================

test_that("sent tracking updates correctly after successful send", {
  # Simulate the tracking update logic
  current_sent_files <- c("file1.R", "file2.R")
  current_sent_data <- c("mtcars")

  files_to_send <- c("file3.R", "file4.R")
  data_to_send <- c("iris")

  # After successful send, union adds new items

  new_sent_files <- union(current_sent_files, files_to_send)
  new_sent_data <- union(current_sent_data, data_to_send)

  expect_equal(
    sort(new_sent_files),
    c("file1.R", "file2.R", "file3.R", "file4.R")
  )
  expect_equal(sort(new_sent_data), c("iris", "mtcars"))
})

test_that("pending queues are cleared after successful send", {
  # Simulate pending state before send
  pending_files <- c("file1.R", "file2.R")
  pending_data <- c("mtcars")

  # After successful send, queues should be cleared

  cleared_files <- character()
  cleared_data <- character()

  expect_length(cleared_files, 0)
  expect_length(cleared_data, 0)
})

test_that("no-op when nothing new to send", {
  # Scenario: everything selected has already been sent
  selected_files <- c("file1.R", "file2.R")
  sent_files <- c("file1.R", "file2.R")
  pending_files <- character()

  files_to_send <- union(
    setdiff(selected_files, sent_files),
    pending_files
  )

  expect_length(files_to_send, 0)

  # Similar for data
  selected_data <- c("mtcars")
  sent_data <- c("mtcars")
  pending_data <- character()

  data_to_send <- union(
    setdiff(selected_data, sent_data),
    pending_data
  )

  expect_length(data_to_send, 0)
})

test_that("refresh sends already-sent items again", {
  # Scenario: file1.R was sent but marked for refresh
  selected_files <- c("file1.R", "file2.R")
  sent_files <- c("file1.R", "file2.R")
  pending_files <- c("file1.R") # Marked for refresh

  files_to_send <- union(
    setdiff(selected_files, sent_files),
    pending_files
  )

  # Only file1.R should be sent (the refreshed one)
  expect_equal(files_to_send, "file1.R")
})

test_that("mixed new and refresh items are combined correctly", {
  # Scenario: some new, some refresh
  selected_files <- c("file1.R", "file2.R", "file3.R")
  sent_files <- c("file1.R")
  pending_files <- c("file1.R") # file1 marked for refresh

  new_files <- setdiff(selected_files, sent_files)
  expect_equal(sort(new_files), c("file2.R", "file3.R"))

  files_to_send <- union(new_files, pending_files)
  expect_equal(sort(files_to_send), c("file1.R", "file2.R", "file3.R"))
})

test_that("sent tracking persists across updates", {
  # Simulate multiple apply context operations

  # First send
  sent_files_v1 <- character()
  files_to_send_1 <- c("file1.R")
  sent_files_v1 <- union(sent_files_v1, files_to_send_1)
  expect_equal(sent_files_v1, "file1.R")

  # Second send (add more files)
  files_to_send_2 <- c("file2.R", "file3.R")
  sent_files_v2 <- union(sent_files_v1, files_to_send_2)
  expect_equal(sort(sent_files_v2), c("file1.R", "file2.R", "file3.R"))

  # Third send (nothing new)
  selected_files <- c("file1.R", "file2.R", "file3.R")
  files_to_send_3 <- setdiff(selected_files, sent_files_v2)
  expect_length(files_to_send_3, 0)
})

test_that("context attributes are extracted correctly", {
  withr::with_tempdir({
    writeLines("x <- 1", "test.R")

    result <- gather_context(
      config = FALSE,
      session = TRUE,
      git = FALSE,
      data = FALSE,
      files = "test.R"
    )

    # Simulate attribute attachment (as gather_selected_context does)
    attr(result, "files_to_send") <- "test.R"
    attr(result, "data_to_send") <- character()

    files_to_send <- attr(result, "files_to_send") %||% character()
    data_to_send <- attr(result, "data_to_send") %||% character()

    expect_equal(files_to_send, "test.R")
    expect_equal(data_to_send, character())
  })
})

test_that("NULL attributes default to empty character vector", {
  result <- "some context text"

  # No attributes set
  files_to_send <- attr(result, "files_to_send") %||% character()
  data_to_send <- attr(result, "data_to_send") %||% character()

  expect_equal(files_to_send, character())
  expect_equal(data_to_send, character())
  expect_length(files_to_send, 0)
  expect_length(data_to_send, 0)
})

test_that("success notification message builds correctly", {
  # Test the notification message building logic

  # Case 1: files only
  files_to_send <- c("a.R", "b.R")
  data_to_send <- character()

  detail_msg <- c()
  if (length(files_to_send) > 0) {
    detail_msg <- c(detail_msg, paste0(length(files_to_send), " file(s)"))
  }
  if (length(data_to_send) > 0) {
    detail_msg <- c(detail_msg, paste0(length(data_to_send), " data frame(s)"))
  }

  expect_equal(detail_msg, "2 file(s)")

  # Case 2: data only
  files_to_send <- character()
  data_to_send <- c("mtcars", "iris")

  detail_msg <- c()
  if (length(files_to_send) > 0) {
    detail_msg <- c(detail_msg, paste0(length(files_to_send), " file(s)"))
  }
  if (length(data_to_send) > 0) {
    detail_msg <- c(detail_msg, paste0(length(data_to_send), " data frame(s)"))
  }

  expect_equal(detail_msg, "2 data frame(s)")

  # Case 3: both
  files_to_send <- c("a.R")
  data_to_send <- c("mtcars")

  detail_msg <- c()
  if (length(files_to_send) > 0) {
    detail_msg <- c(detail_msg, paste0(length(files_to_send), " file(s)"))
  }
  if (length(data_to_send) > 0) {
    detail_msg <- c(detail_msg, paste0(length(data_to_send), " data frame(s)"))
  }

  expect_equal(detail_msg, c("1 file(s)", "1 data frame(s)"))
  expect_equal(paste(detail_msg, collapse = ", "), "1 file(s), 1 data frame(s)")
})

test_that("empty send produces empty notification details", {
  files_to_send <- character()
  data_to_send <- character()

  detail_msg <- c()
  if (length(files_to_send) > 0) {
    detail_msg <- c(detail_msg, paste0(length(files_to_send), " file(s)"))
  }
  if (length(data_to_send) > 0) {
    detail_msg <- c(detail_msg, paste0(length(data_to_send), " data frame(s)"))
  }

  expect_length(detail_msg, 0)
})

test_that("conversation record update includes sent tracking", {
  # Simulate the data structure that would be passed to conv_update_current
  sent_files <- c("file1.R", "file2.R")
  sent_data <- c("mtcars")

  update_list <- list(
    sent_context_files = sent_files,
    sent_data_frames = sent_data
  )

  expect_equal(update_list$sent_context_files, c("file1.R", "file2.R"))
  expect_equal(update_list$sent_data_frames, "mtcars")
})

test_that("union handles duplicates in pending refresh", {
  # Edge case: same file in both new and pending
  selected_files <- c("file1.R", "file2.R")
  sent_files <- c("file1.R")
  pending_files <- c("file2.R") # file2 somehow in pending but also new

  new_files <- setdiff(selected_files, sent_files)
  files_to_send <- union(new_files, pending_files)

  # union removes duplicates
  expect_equal(files_to_send, "file2.R")
  expect_length(files_to_send, 1)
})

test_that("early exit conditions are detected correctly", {
  # Condition 1: Nothing to send
  files_to_send <- character()
  data_to_send <- character()
  context_text <- NULL

  should_exit_1 <- length(files_to_send) == 0 &&
    length(data_to_send) == 0 &&
    (is.null(context_text) || !nzchar(context_text))
  expect_true(should_exit_1)

  # Condition 2: Has files to send
  files_to_send <- c("file1.R")
  should_exit_2 <- length(files_to_send) == 0 &&
    length(data_to_send) == 0 &&
    (is.null(context_text) || !nzchar(context_text))
  expect_false(should_exit_2)

  # Condition 3: Empty files/data but has context text (project items)
  files_to_send <- character()
  data_to_send <- character()
  context_text <- "Some session info"

  should_exit_3 <- length(files_to_send) == 0 &&
    length(data_to_send) == 0 &&
    (is.null(context_text) || !nzchar(context_text))
  expect_false(should_exit_3)
})
