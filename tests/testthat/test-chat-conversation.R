# tests/testthat/test-chat-conversation.R

test_that("ConversationManager initializes with empty tracking state", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("S7")

  manager <- ConversationManager()

  shiny::isolate({
    expect_equal(conv_sent_context_files(manager), character())
    expect_equal(conv_sent_data_frames(manager), character())
    expect_equal(conv_pending_refresh_files(manager), character())
    expect_equal(conv_pending_refresh_data(manager), character())
  })
})

test_that("sent_context_files getter and setter work correctly", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("S7")

  manager <- ConversationManager()

  shiny::isolate({
    # Initially empty
    expect_equal(conv_sent_context_files(manager), character())

    # Set files
    test_files <- c("R/file1.R", "R/file2.R")
    conv_set_sent_context_files(manager, test_files)
    expect_equal(conv_sent_context_files(manager), test_files)

    # Update files
    new_files <- c("R/file1.R", "R/file2.R", "R/file3.R")
    conv_set_sent_context_files(manager, new_files)
    expect_equal(conv_sent_context_files(manager), new_files)
  })
})

test_that("sent_data_frames getter and setter work correctly", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("S7")

  manager <- ConversationManager()

  shiny::isolate({
    # Initially empty
    expect_equal(conv_sent_data_frames(manager), character())

    # Set data frames
    test_dfs <- c("mtcars", "iris")
    conv_set_sent_data_frames(manager, test_dfs)
    expect_equal(conv_sent_data_frames(manager), test_dfs)
  })
})

test_that("pending_refresh_files getter and setter work correctly", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("S7")

  manager <- ConversationManager()

  shiny::isolate({
    # Initially empty
    expect_equal(conv_pending_refresh_files(manager), character())

    # Set pending files
    pending <- c("R/changed.R")
    conv_set_pending_refresh_files(manager, pending)
    expect_equal(conv_pending_refresh_files(manager), pending)

    # Clear pending
    conv_set_pending_refresh_files(manager, character())
    expect_equal(conv_pending_refresh_files(manager), character())
  })
})

test_that("pending_refresh_data getter and setter work correctly", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("S7")

  manager <- ConversationManager()

  shiny::isolate({
    # Initially empty
    expect_equal(conv_pending_refresh_data(manager), character())

    # Set pending data frames
    pending <- c("updated_df")
    conv_set_pending_refresh_data(manager, pending)
    expect_equal(conv_pending_refresh_data(manager), pending)
  })
})

test_that("conv_create_new clears all tracking state", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("S7")

  manager <- ConversationManager()

  shiny::isolate({
    # Set some tracking state
    conv_set_sent_context_files(manager, c("R/old.R"))
    conv_set_sent_data_frames(manager, c("old_df"))
    conv_set_pending_refresh_files(manager, c("R/pending.R"))
    conv_set_pending_refresh_data(manager, c("pending_df"))

    # Create new conversation (no session)
    conv_create_new(manager, session = NULL)

    # All tracking should be cleared
    expect_equal(conv_sent_context_files(manager), character())
    expect_equal(conv_sent_data_frames(manager), character())
    expect_equal(conv_pending_refresh_files(manager), character())
    expect_equal(conv_pending_refresh_data(manager), character())
  })
})

test_that("conv_create_new initializes conversation with empty tracking", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("S7")

  manager <- ConversationManager()

  shiny::isolate({
    conv_id <- conv_create_new(manager, session = NULL)
    conv <- conv_get_current(manager)

    expect_equal(conv$sent_context_files, character())
    expect_equal(conv$sent_data_frames, character())
  })
})

test_that("conv_switch_to restores tracking state from conversation", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("S7")

  manager <- ConversationManager()

  shiny::isolate({
    # Create first conversation and set tracking
    conv_id_1 <- conv_create_new(manager, session = NULL)
    conv_set_sent_context_files(manager, c("R/file1.R"))
    conv_set_sent_data_frames(manager, c("df1"))
    conv_update_current(
      manager,
      list(
        sent_context_files = c("R/file1.R"),
        sent_data_frames = c("df1")
      )
    )

    # Create second conversation with different tracking
    conv_id_2 <- conv_create_new(manager, session = NULL)
    conv_set_sent_context_files(manager, c("R/file2.R", "R/file3.R"))
    conv_set_sent_data_frames(manager, c("df2"))
    conv_update_current(
      manager,
      list(
        sent_context_files = c("R/file2.R", "R/file3.R"),
        sent_data_frames = c("df2")
      )
    )

    # Switch back to first conversation
    conv_switch_to(manager, conv_id_1, session = NULL)

    # Tracking should be restored from conv 1
    expect_equal(conv_sent_context_files(manager), c("R/file1.R"))
    expect_equal(conv_sent_data_frames(manager), c("df1"))

    # Pending should be cleared on switch
    expect_equal(conv_pending_refresh_files(manager), character())
    expect_equal(conv_pending_refresh_data(manager), character())
  })
})

test_that("conv_switch_to handles missing tracking fields gracefully", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("S7")

  manager <- ConversationManager()

  shiny::isolate({
    # Create conversation without tracking fields (simulates old conversation)
    conv_id <- conv_create_new(manager, session = NULL)

    # Manually remove tracking fields to simulate old format
    convs <- conv_get_all(manager)
    convs[[1]]$sent_context_files <- NULL
    convs[[1]]$sent_data_frames <- NULL
    manager@conversations(convs)

    # Create another conversation
    conv_id_2 <- conv_create_new(manager, session = NULL)

    # Switch back - should not error, should default to empty
    expect_no_error(conv_switch_to(manager, conv_id, session = NULL))
    expect_equal(conv_sent_context_files(manager), character())
    expect_equal(conv_sent_data_frames(manager), character())
  })
})

test_that("conv_delete clears tracking when deleting current conversation", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("S7")

  manager <- ConversationManager()

  shiny::isolate({
    # Create and set up conversation
    conv_id <- conv_create_new(manager, session = NULL)
    conv_set_sent_context_files(manager, c("R/file.R"))
    conv_set_pending_refresh_files(manager, c("R/pending.R"))

    # Delete it
    conv_delete(manager, conv_id)

    # Tracking should be cleared (no current conversation)
    expect_equal(conv_sent_context_files(manager), character())
    expect_equal(conv_sent_data_frames(manager), character())
    expect_equal(conv_pending_refresh_files(manager), character())
    expect_equal(conv_pending_refresh_data(manager), character())
  })
})

test_that("conv_delete restores tracking from next conversation", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("S7")

  manager <- ConversationManager()

  shiny::isolate({
    # Create first conversation with tracking
    conv_id_1 <- conv_create_new(manager, session = NULL)
    conv_set_sent_context_files(manager, c("R/first.R"))
    conv_update_current(
      manager,
      list(
        sent_context_files = c("R/first.R"),
        sent_data_frames = character()
      )
    )

    # Create second conversation (becomes current)
    conv_id_2 <- conv_create_new(manager, session = NULL)
    conv_set_sent_context_files(manager, c("R/second.R"))

    # Delete second conversation
    conv_delete(manager, conv_id_2)

    # Should restore first conversation's tracking
    expect_equal(conv_sent_context_files(manager), c("R/first.R"))
  })
})

test_that("conv_update_current preserves sent tracking fields", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("S7")

  manager <- ConversationManager()

  shiny::isolate({
    conv_create_new(manager, session = NULL)

    # Update with sent tracking
    conv_update_current(
      manager,
      list(
        sent_context_files = c("R/file1.R", "R/file2.R"),
        sent_data_frames = c("mtcars")
      )
    )

    conv <- conv_get_current(manager)

    expect_equal(conv$sent_context_files, c("R/file1.R", "R/file2.R"))
    expect_equal(conv$sent_data_frames, c("mtcars"))
  })
})

test_that("tracking state is independent per conversation", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("S7")

  manager <- ConversationManager()

  shiny::isolate({
    # Create conv 1
    conv_id_1 <- conv_create_new(manager, session = NULL)
    conv_set_sent_context_files(manager, c("R/a.R"))
    conv_update_current(manager, list(sent_context_files = c("R/a.R")))

    # Create conv 2
    conv_id_2 <- conv_create_new(manager, session = NULL)
    conv_set_sent_context_files(manager, c("R/b.R", "R/c.R"))
    conv_update_current(manager, list(sent_context_files = c("R/b.R", "R/c.R")))

    # Verify conv 1 tracking unchanged
    conv_switch_to(manager, conv_id_1, session = NULL)
    expect_equal(conv_sent_context_files(manager), c("R/a.R"))

    # Verify conv 2 tracking unchanged
    conv_switch_to(manager, conv_id_2, session = NULL)
    expect_equal(conv_sent_context_files(manager), c("R/b.R", "R/c.R"))
  })
})

test_that("adding to pending_refresh accumulates correctly", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("S7")

  manager <- ConversationManager()

  shiny::isolate({
    conv_create_new(manager, session = NULL)

    # Add first file to pending
    current <- conv_pending_refresh_files(manager)
    conv_set_pending_refresh_files(manager, union(current, "R/file1.R"))
    expect_equal(conv_pending_refresh_files(manager), "R/file1.R")

    # Add second file
    current <- conv_pending_refresh_files(manager)
    conv_set_pending_refresh_files(manager, union(current, "R/file2.R"))
    expect_setequal(
      conv_pending_refresh_files(manager),
      c("R/file1.R", "R/file2.R")
    )

    # Adding same file again doesn't duplicate (using union)
    current <- conv_pending_refresh_files(manager)
    conv_set_pending_refresh_files(manager, union(current, "R/file1.R"))
    expect_length(conv_pending_refresh_files(manager), 2)
  })
})
