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
  rlang::check_installed("shinychat", reason = "to use cassidy_app()")
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
          # Resume previous conversation
          cli::cli_alert_info("Resuming conversation: {resume_id}")
          conv_load_and_set(conv_manager, resume_id, session)
        } else {
          # Create new conversation and set initial context
          conv_create_new(conv_manager, session)
          if (!is.null(context_text)) {
            conv_set_context(conv_manager, context_text)
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


#' Build the Cassidy Shiny app object
#' @keywords internal
.build_cassidy_shiny_app <- function(
  theme,
  context_level,
  context_text,
  assistant_id,
  api_key,
  timeout
) {
  # ---- UI ----
  ui <- chat_build_ui(theme, context_level)

  # ---- Server ----
  server <- function(input, output, session) {
    # Initialize conversation manager
    conv_manager <- ConversationManager()

    # Setup renderers
    setup_message_renderer(output, conv_manager)
    setup_conversation_list_renderer(output, conv_manager)
    setup_file_context_renderer(output, conv_manager)

    # Setup handlers
    setup_conversation_switch_handler(input, session, conv_manager)
    setup_conversation_delete_handlers(input, session, conv_manager)
    setup_new_chat_handler(input, session, conv_manager)
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

    # Cleanup
    shiny::onSessionEnded(function() {
      cli::cli_alert_info("Chat session ended")
    })
  }

  # Return app object
  shiny::shinyApp(ui = ui, server = server)
}
