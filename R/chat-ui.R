#' Launch Cassidy Interactive Chat Application
#'
#' Opens an interactive Shiny-based chat interface for conversing with
#' Cassidy AI assistants. The app automatically gathers project context
#' and supports conversation persistence.
#'
#' @param assistant_id Character. The Cassidy assistant ID to use.
#'   Defaults to `CASSIDY_ASSISTANT_ID` environment variable.
#' @param api_key Character. The Cassidy API key.
#'   Defaults to `CASSIDY_API_KEY` environment variable.
#' @param new_chat Logical. If `TRUE`, starts a fresh conversation with new
#'   context. If `FALSE` (default), resumes the most recent conversation.
#' @param context_level Character. Level of context to include when starting
#'   a new chat: "minimal", "standard", or "comprehensive". Default is
#'   "standard". Ignored when `new_chat = FALSE`.
#' @param include_data Logical. Whether to include data frame context
#'   from the global environment when starting a new chat. Default is TRUE.
#'   Ignored when `new_chat = FALSE`.
#' @param include_files Character vector of file paths to include in initial
#'   context when starting a new chat. Ignored when `new_chat = FALSE`.
#' @param timeout Numeric. API timeout in seconds. Default is 300.
#' @param theme A bslib theme object. Default uses a clean modern theme.
#'
#' @return Launches a Shiny app (called for side effects).
#'
#' @details
#' The app provides:
#' - Real-time chat with Cassidy AI
#' - Automatic project context injection (on new chats)
#' - Conversation history with sidebar navigation
#' - Ability to switch between multiple conversations
#' - Mobile-responsive design
#'
#' ## Continuing vs Starting New
#'
#' By default (`new_chat = FALSE`), the app resumes your most recent
#' conversation. This is useful when you close the app to run code and
#' want to continue discussing results.
#'
#' Use `new_chat = TRUE` when you want to start fresh with updated project
#' context. This is recommended when:
#' - You've made significant changes to your code
#' - You're starting a new task or topic
#' - You want to include different files in context
#'
#' @seealso
#' - [cassidy_list_conversations()] to view saved conversations
#' - [cassidy_export_conversation()] to export a conversation as Markdown
#' - [cassidy_delete_conversation()] to remove old conversations
#'
#' @family chat-app
#'
#' @examples
#' \dontrun{
#'   # Resume most recent conversation (default)
#'   cassidy_app()
#'
#'   # Start a new conversation with standard context
#'   cassidy_app(new_chat = TRUE)
#'
#'   # Start new with comprehensive context
#'   cassidy_app(new_chat = TRUE, context_level = "comprehensive")
#'
#'   # Start new with specific files
#'   cassidy_app(
#'     new_chat = TRUE,
#'     include_files = c("R/my-analysis.R", "data/codebook.md")
#'   )
#' }
#'
#' @export
cassidy_app <- function(
  assistant_id = Sys.getenv("CASSIDY_ASSISTANT_ID"),
  api_key = Sys.getenv("CASSIDY_API_KEY"),
  new_chat = FALSE,
  context_level = c("standard", "minimal", "comprehensive"),
  include_data = TRUE,
  include_files = NULL,
  timeout = 300,
  theme = NULL
) {
  # ---- Input validation ----
  if (!nzchar(api_key)) {
    cli::cli_abort(c(
      "Cassidy API key not found.",
      "i" = "Set {.envvar CASSIDY_API_KEY} in your {.file .Renviron} file.",
      "i" = "Or pass {.arg api_key} directly to {.fn cassidy_app}."
    ))
  }

  if (!nzchar(assistant_id)) {
    cli::cli_abort(c(
      "Cassidy assistant ID not found.",
      "i" = "Set {.envvar CASSIDY_ASSISTANT_ID} in your {.file .Renviron} file.",
      "i" = "Or pass {.arg assistant_id} directly to {.fn cassidy_app}."
    ))
  }

  context_level <- match.arg(context_level)

  # Check for required packages
  rlang::check_installed("shiny", reason = "to use cassidy_app()")
  rlang::check_installed("bslib", reason = "to use cassidy_app()")
  rlang::check_installed("S7", reason = "to use cassidy_app()")

  # ---- Gather context (only for new chats) ----
  context_text <- NULL
  if (new_chat) {
    cli::cli_alert_info("Gathering project context ({context_level})...")
    context_text <- gather_chat_context(
      context_level,
      include_data,
      include_files
    )
  } else {
    cli::cli_alert_info("Resuming previous conversation (no new context)")
  }

  # ---- Check for existing conversations ----
  saved_convs <- cassidy_list_conversations(n = 1)
  has_previous <- nrow(saved_convs) > 0
  resume_id <- if (!new_chat && has_previous) saved_convs$id[1] else NULL

  if (!new_chat && !has_previous) {
    cli::cli_alert_warning("No previous conversations found, starting new chat")
    new_chat <- TRUE
    cli::cli_alert_info("Gathering project context ({context_level})...")
    context_text <- gather_chat_context(
      context_level,
      include_data,
      include_files
    )
  }

  # ---- Default theme ----
  if (is.null(theme)) {
    theme <- bslib::bs_theme(
      version = 5,
      preset = "shiny",
      primary = "#0d6efd",
      "font-size-base" = "0.95rem"
    )
  }

  # ---- UI ----
  ui <- chat_build_ui(theme, if (new_chat) context_level else "resumed")

  # ---- Server ----
  server <- function(input, output, session) {
    # Initialize conversation manager
    conv_manager <- ConversationManager()

    # Startup initialization
    shiny::observeEvent(
      session$clientData$url_search,
      {
        if (!is.null(resume_id)) {
          # === RESUME PREVIOUS CONVERSATION ===
          cli::cli_alert_info("Resuming conversation: {resume_id}")
          conv_load_and_set(conv_manager, resume_id, session)

          # Get the loaded conversation to see what was selected
          conv <- conv_get_current(conv_manager)

          # ADD THIS CHECK:
          if (is.null(conv$thread_id)) {
            cli::cli_alert_warning(
              "Conversation has no thread_id - creating new thread"
            )

            # Create a new thread for this conversation
            tryCatch(
              {
                thread_id <- cassidy_create_thread(
                  assistant_id = assistant_id,
                  api_key = api_key
                )
                conv_update_current(conv_manager, list(thread_id = thread_id))
                cli::cli_alert_success("Created new thread: {thread_id}")
              },
              error = function(e) {
                cli::cli_abort(
                  "Failed to create thread for resumed conversation: {e$message}"
                )
              }
            )
          }

          previous_files <- conv$context_files %||% character(0)
          previous_data <- conv$context_data %||% character(0)

          if (length(previous_files) > 0) {
            conv_set_context_files(conv_manager, previous_files)
            cli::cli_alert_success(
              "Restored {length(previous_files)} file selection{?s}"
            )
          }

          if (length(previous_files) > 0) {
            conv_set_context_files(conv_manager, previous_files)
            cli::cli_alert_success(
              "Restored {length(previous_files)} file selection{?s}"
            )

            # Force file tree to re-render with updated selections
            session$sendCustomMessage("triggerFileTreeRefresh", list())
          }

          # === RESTORE SIDEBAR UI STATE ===
          cli::cli_alert_info("Restoring context selections...")

          # Restore data frame checkboxes
          if (length(previous_data) > 0) {
            for (df_name in previous_data) {
              df_id <- gsub("[^a-zA-Z0-9]", "_", df_name)
              input_id <- paste0("ctx_data_", df_id)
              shiny::updateCheckboxInput(session, input_id, value = TRUE)
            }
          }

          # === REFRESH AND SEND CONTEXT ===
          cli::cli_alert_info("Refreshing context with latest data...")

          refreshed_context <- .refresh_conversation_context(
            previous_files = previous_files,
            previous_data = previous_data,
            conv_manager = conv_manager
          )

          if (!is.null(refreshed_context) && !is.null(conv$thread_id)) {
            conv_set_context(conv_manager, refreshed_context)

            # Show loading state
            conv_set_loading(conv_manager, TRUE)
            session$sendCustomMessage("setLoading", TRUE)

            shiny::showNotification(
              "Sending refreshed context to Cassidy...",
              id = "context_refresh_sending",
              type = "message",
              duration = NULL
            )

            tryCatch(
              {
                # Send refreshed context
                context_message <- paste0(
                  "# Refreshed Project Context\n\n",
                  "I'm resuming our conversation. Here's the latest project context:\n\n",
                  refreshed_context,
                  "\n\n---\n\n",
                  "Please acknowledge that you have the updated context. ",
                  "We can continue where we left off."
                )

                response <- cassidy_send_message(
                  thread_id = conv$thread_id,
                  message = context_message,
                  api_key = api_key,
                  timeout = timeout
                )

                # Add system message
                conv_add_message(
                  conv_manager,
                  "system",
                  sprintf(
                    "**System:** Refreshed context on resume (%s characters)",
                    format(nchar(refreshed_context), big.mark = ",")
                  )
                )

                # Add Cassidy's acknowledgment
                conv_add_message(conv_manager, "assistant", response$content)

                # Mark as sent
                conv_set_context_sent(conv_manager, TRUE)

                # Clear loading
                conv_set_loading(conv_manager, FALSE)
                session$sendCustomMessage("setLoading", FALSE)
                session$sendCustomMessage("scrollToBottom", list())

                shiny::removeNotification("context_refresh_sending")

                shiny::showNotification(
                  "Context refreshed and sent!",
                  type = "message",
                  duration = 3
                )

                cli::cli_alert_success("Refreshed context sent to Cassidy")
              },
              error = function(e) {
                conv_set_loading(conv_manager, FALSE)
                session$sendCustomMessage("setLoading", FALSE)
                shiny::removeNotification("context_refresh_sending")

                shiny::showNotification(
                  paste("Error sending refreshed context:", e$message),
                  type = "warning",
                  duration = 5
                )

                cli::cli_alert_warning(
                  "Failed to send refreshed context: {e$message}"
                )
                cli::cli_alert_info(
                  "Context stored locally - use 'Apply Context' to retry"
                )
              }
            )
          } else if (!is.null(refreshed_context)) {
            # No thread_id yet, just store context
            conv_set_context(conv_manager, refreshed_context)
            cli::cli_alert_success(
              "Context refreshed from disk (will send with first message)"
            )
          }
        } else {
          # === NEW CONVERSATION ===
          conv_create_new(conv_manager, session)
          if (!is.null(context_text)) {
            conv_set_context(conv_manager, context_text)
            conv_set_context_sent(conv_manager, FALSE)

            # === AUTO-SEND THE CONTEXT ===
            cli::cli_alert_info("Auto-sending context to Cassidy...")

            # Create thread with context
            tryCatch(
              {
                thread_id <- cassidy_create_thread(
                  assistant_id = assistant_id,
                  api_key = api_key
                )
                conv_update_current(conv_manager, list(thread_id = thread_id))

                # Send context as first message
                context_message <- paste0(
                  "# Project Context\n\n",
                  context_text,
                  "\n\n---\n\n",
                  "I've shared my project context with you. Please acknowledge that you've received it ",
                  "and let me know you're ready to help with this project."
                )

                response <- cassidy_send_message(
                  thread_id = thread_id,
                  message = context_message,
                  api_key = api_key,
                  timeout = timeout
                )

                # Add system message
                conv_add_message(
                  conv_manager,
                  "system",
                  sprintf(
                    "**System:** Applied context (%s characters)",
                    format(nchar(context_text), big.mark = ",")
                  )
                )

                # Add Cassidy's response
                conv_add_message(conv_manager, "assistant", response$content)

                # Mark as sent
                conv_set_context_sent(conv_manager, TRUE)
                conv_update_current(conv_manager, list(context_sent = TRUE))

                cli::cli_alert_success("Context sent successfully!")
              },
              error = function(e) {
                cli::cli_alert_warning("Failed to send context: {e$message}")
                # Context is still stored, can be sent manually via Apply Context button
              }
            )
          }
        }

        # Show saved conversations count
        all_saved <- cassidy_list_conversations(n = 8)
        if (nrow(all_saved) > 0) {
          cli::cli_alert_info(
            "Found {nrow(all_saved)} saved conversation{?s} in sidebar"
          )
        }
      },
      once = TRUE,
      ignoreNULL = FALSE,
      ignoreInit = FALSE
    )

    # Setup renderers
    setup_message_renderer(output, conv_manager)
    setup_conversation_list_renderer(output, conv_manager)
    setup_file_context_renderer(output, conv_manager)

    # Setup context renderers and handlers
    setup_context_data_renderer(output, input, conv_manager)
    setup_context_summary_renderer(output, input, conv_manager)
    setup_refresh_context_handler(
      input,
      session,
      conv_manager,
      assistant_id,
      api_key,
      timeout
    )
    setup_apply_context_handler(
      input,
      session,
      conv_manager,
      assistant_id,
      api_key,
      timeout
    )

    # Setup file tree renderer and handlers
    setup_file_tree_renderer(output, input, conv_manager)
    setup_file_selection_handlers(input, session, conv_manager)

    # Setup handlers
    setup_conversation_switch_handler(input, session, conv_manager)
    setup_conversation_delete_handlers(input, session, conv_manager)
    setup_new_chat_handler(input, session, conv_manager)
    setup_conversation_load_handler(input, session, conv_manager)
    setup_conversation_export_handler(input, session, conv_manager)
    setup_send_message_handler(
      input,
      session,
      conv_manager,
      assistant_id,
      api_key,
      timeout
    )
    setup_file_context_handlers(
      input,
      session,
      conv_manager,
      assistant_id,
      api_key,
      timeout
    )
    setup_new_chat_confirm_handler(
      input,
      session,
      conv_manager,
      assistant_id,
      api_key,
      timeout
    )

    # Cleanup - SAVE CONVERSATION
    shiny::onSessionEnded(function() {
      # Get current conversation data outside reactive context
      tryCatch(
        {
          conv <- shiny::isolate(conv_get_current(conv_manager))
          if (!is.null(conv)) {
            cassidy_save_conversation(conv)
          }
          cli::cli_alert_info("Chat session ended - conversation saved")
        },
        error = function(e) {
          cli::cli_alert_warning(
            "Could not save conversation on exit: {e$message}"
          )
        }
      )
    })
  }

  # ---- Launch ----
  if (new_chat) {
    cli::cli_alert_success("Launching Cassidy Chat (new conversation)...")
  } else {
    cli::cli_alert_success("Launching Cassidy Chat (resuming)...")
  }
  shiny::shinyApp(ui = ui, server = server)
}
