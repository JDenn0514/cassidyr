#' Create app header UI
#' @keywords internal
chat_header_ui <- function(context_level) {
  shiny::div(
    class = "app-header",
    shiny::div(
      class = "header-content",
      shiny::div(
        class = "header-left",
        shiny::actionButton(
          "context_sidebar_toggle",
          shiny::icon("sliders-h"),
          class = "btn btn-outline-secondary btn-sm",
          title = "Toggle context panel"
        ),
        shiny::h4("Cassidy Chat", class = "mb-0 ms-2 d-inline-block")
      ),
      shiny::div(
        class = "header-right",
        shiny::tags$small(
          class = "text-muted me-3",
          id = "context_status",
          shiny::icon("circle-check", class = "text-success"),
          " Context ready"
        ),
        shiny::actionButton(
          "history_sidebar_toggle",
          shiny::icon("history"),
          class = "btn btn-outline-secondary btn-sm",
          title = "Toggle conversation history"
        )
      )
    )
  )
}


#' Create chat messages area UI
#' @keywords internal
chat_messages_ui <- function() {
  shiny::div(
    class = "chat-messages",
    id = "chat_messages",
    shiny::uiOutput("messages"),
    shiny::uiOutput("loading_indicator")
  )
}

#' Create chat input area UI
#' @keywords internal
chat_input_ui <- function() {
  shiny::div(
    class = "chat-input-area",
    shiny::div(
      class = "input-row",
      shiny::tags$textarea(
        id = "user_input",
        class = "form-control",
        placeholder = "Type your message... (Enter to send, Shift+Enter for new line)",
        rows = 1
      ),
      shiny::actionButton(
        "send",
        shiny::icon("paper-plane"),
        class = "btn-primary send-btn",
        title = "Send message"
      )
    )
  )
}

#' Create context sidebar UI (LEFT)
#' @keywords internal
chat_context_sidebar_ui <- function() {
  shiny::div(
    class = "context-sidebar",
    id = "context_sidebar",

    # Header with close button
    shiny::div(
      class = "sidebar-header",
      shiny::div(
        class = "sidebar-title",
        shiny::icon("sliders-h"),
        " Context"
      ),
      shiny::div(
        shiny::actionButton(
          "refresh_all_context",
          shiny::icon("sync"),
          class = "btn btn-sm btn-outline-secondary me-1",
          title = "Refresh all context"
        ),
        shiny::tags$button(
          class = "sidebar-close",
          id = "close_context_sidebar",
          shiny::icon("times")
        )
      )
    ),

    # Scrollable content area
    shiny::div(
      class = "context-sidebar-content",

      # Project section
      shiny::div(
        class = "context-section",
        shiny::div(
          class = "context-section-header",
          onclick = "toggleContextSection('project')",
          shiny::icon("chevron-down", class = "section-chevron"),
          shiny::icon("folder-open"),
          " Project"
        ),
        shiny::div(
          class = "context-section-body",
          id = "context_section_project",
          shiny::div(
            class = "context-item",
            shiny::div(
              class = "context-item-main",
              shiny::checkboxInput(
                "ctx_config",
                shiny::tagList(
                  shiny::icon("file-alt"),
                  " cassidy.md"
                ),
                value = TRUE
              )
            ),
            shiny::actionButton(
              "refresh_config",
              shiny::icon("sync"),
              class = "btn-icon-xs",
              title = "Refresh cassidy.md"
            )
          ),
          shiny::div(
            class = "context-item",
            shiny::div(
              class = "context-item-main",
              shiny::checkboxInput(
                "ctx_session",
                shiny::tagList(
                  shiny::icon("r-project"),
                  " R session info"
                ),
                value = TRUE
              )
            ),
            shiny::actionButton(
              "refresh_session",
              shiny::icon("sync"),
              class = "btn-icon-xs",
              title = "Refresh session info"
            )
          ),
          shiny::div(
            class = "context-item",
            shiny::div(
              class = "context-item-main",
              shiny::checkboxInput(
                "ctx_git",
                shiny::tagList(
                  shiny::icon("code-branch"),
                  " Git status"
                ),
                value = FALSE
              )
            ),
            shiny::actionButton(
              "refresh_git",
              shiny::icon("sync"),
              class = "btn-icon-xs",
              title = "Refresh git status"
            )
          )
        )
      ),

      # Data section
      shiny::div(
        class = "context-section",
        shiny::div(
          class = "context-section-header",
          onclick = "toggleContextSection('data')",
          shiny::icon("chevron-down", class = "section-chevron"),
          shiny::icon("table"),
          " Data",
          shiny::tags$small(
            class = "text-muted ms-1",
            id = "data_count",
            shiny::uiOutput("data_count_ui", inline = TRUE)
          )
        ),
        shiny::div(
          class = "context-section-body",
          id = "context_section_data",
          # Data description method selector
          shiny::div(
            class = "context-data-options",
            shiny::selectInput(
              "data_description_method",
              label = NULL,
              choices = c(
                "Basic summary" = "basic",
                "Codebook (adlgraphs)" = "codebook",
                "Skim (skimr)" = "skim"
              ),
              selected = "basic",
              width = "100%"
            )
          ),
          shiny::div(
            class = "context-data-list",
            id = "context_data_list",
            shiny::uiOutput("context_data_ui")
          )
        )
      ),

      # Files section
      shiny::div(
        class = "context-section",
        shiny::div(
          class = "context-section-header",
          onclick = "toggleContextSection('files')",
          shiny::icon("chevron-down", class = "section-chevron"),
          shiny::icon("file-code"),
          " Files",
          shiny::tags$small(
            class = "text-muted ms-1",
            shiny::uiOutput("files_count_ui", inline = TRUE)
          )
        ),
        shiny::div(
          class = "context-section-body",
          id = "context_section_files",
          shiny::div(
            class = "context-files-actions",
            shiny::div(
              class = "btn-group w-100 mb-2",
              shiny::actionButton(
                "add_files",
                shiny::tagList(shiny::icon("plus"), " Add"),
                class = "btn btn-sm btn-outline-primary"
              ),
              shiny::actionButton(
                "refresh_all_files",
                shiny::tagList(shiny::icon("sync")),
                class = "btn btn-sm btn-outline-secondary",
                title = "Refresh all files"
              )
            )
          ),
          shiny::div(
            class = "context-files-tree",
            id = "context_files_tree",
            shiny::uiOutput("context_files_tree_ui")
          )
        )
      ),

      # Skills section
      shiny::div(
        class = "context-section",
        shiny::div(
          class = "context-section-header",
          onclick = "toggleContextSection('skills')",
          shiny::icon("chevron-down", class = "section-chevron"),
          shiny::icon("wand-magic-sparkles"),
          " Skills",
          shiny::tags$small(
            class = "text-muted ms-1",
            shiny::uiOutput("skills_count_ui", inline = TRUE)
          )
        ),
        shiny::div(
          class = "context-section-body",
          id = "context_section_skills",
          shiny::div(
            class = "context-skills-list",
            id = "context_skills_list",
            shiny::uiOutput("context_skills_ui")
          )
        )
      )
    ),

    # Fixed bottom panel for context confirmation
    shiny::div(
      class = "context-apply-panel",
      shiny::div(
        class = "context-apply-summary",
        shiny::uiOutput("context_summary")
      ),
      shiny::actionButton(
        "apply_context",
        shiny::tagList(shiny::icon("check"), " Apply Context"),
        class = "btn btn-primary w-100"
      )
    )
  )
}

#' Create conversation history sidebar UI (RIGHT)
#' @keywords internal
chat_history_sidebar_ui <- function() {
  shiny::div(
    class = "history-sidebar",
    id = "history_sidebar",
    shiny::div(
      class = "sidebar-header",
      shiny::div(
        class = "sidebar-title",
        shiny::icon("history"),
        " History"
      ),
      shiny::tags$button(
        class = "sidebar-close",
        id = "close_history_sidebar",
        shiny::icon("times")
      )
    ),
    shiny::div(
      class = "conversation-list",
      shiny::actionButton(
        "new_chat",
        shiny::tagList(shiny::icon("plus"), " New Chat"),
        class = "btn btn-primary w-100 mb-2"
      ),
      shiny::div(
        class = "conversation-list-header",
        "Recent"
      ),
      shiny::uiOutput("conversation_list")
    )
  )
}


#' Build complete chat UI
#' @keywords internal
chat_build_ui <- function(theme, context_level) {
  bslib::page_fillable(
    theme = theme,
    title = "Cassidy Chat",
    shiny::tags$style(shiny::HTML(chat_app_css())),
    shiny::tags$script(shiny::HTML(chat_app_js())),
    # shiny::uiOutput("loading_overlay"),
    shiny::div(
      class = "main-layout",
      chat_context_sidebar_ui(),
      shiny::div(
        class = "chat-main",
        chat_header_ui(context_level),
        shiny::div(
          class = "chat-container",
          chat_messages_ui(),
          chat_input_ui()
        )
      ),
      chat_history_sidebar_ui()
    )
  )
}
