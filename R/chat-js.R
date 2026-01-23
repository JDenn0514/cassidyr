#' @keywords internal
chat_app_js <- function() {
  paste0(
    .js_sidebar_toggles(),
    .js_copy_buttons(),
    .js_shiny_handlers(),
    .js_textarea_behavior(),
    .js_init(),
    .js_helper_functions()
  )
}

.js_sidebar_toggles <- function() {
  "
  $(document).ready(function() {
    // Context sidebar toggle (LEFT)
    $('#context_sidebar_toggle').on('click', function() {
      $('#context_sidebar').toggleClass('collapsed');
    });

    // History sidebar toggle (RIGHT)
    $('#history_sidebar_toggle').on('click', function() {
      $('#history_sidebar').toggleClass('collapsed');
    });

    // Close buttons inside sidebars
    $('#close_context_sidebar').on('click', function() {
      $('#context_sidebar').addClass('collapsed');
    });

    $('#close_history_sidebar').on('click', function() {
      $('#history_sidebar').addClass('collapsed');
    });
  "
}

.js_copy_buttons <- function() {
  clipboard <- stringi::stri_unescape_unicode("\\U0001F4CB")
  checkmark <- stringi::stri_unescape_unicode("\\u2713")

  paste0(
    "
    // Add copy buttons to code blocks
    function addCopyButtons() {
      $('.chat-messages pre').each(function() {
        var $pre = $(this);

        // Skip if already has button
        if ($pre.parent().hasClass('code-block-wrapper')) return;

        // Wrap pre in relative container
        $pre.wrap('<div class=\"code-block-wrapper\"></div>');

        // Add copy button
        var $btn = $('<button class=\"copy-code-btn\" title=\"Copy code\">",
    clipboard,
    "</button>');
        $pre.parent().append($btn);

        $btn.on('click', function(e) {
          e.stopPropagation();
          var text = $pre.text();
          navigator.clipboard.writeText(text).then(function() {
            $btn.text('",
    checkmark,
    "');
            setTimeout(function() { $btn.text('",
    clipboard,
    "'); }, 1500);
          });
        });
      });
    }
  "
  )
}

.js_shiny_handlers <- function() {
  "
    // Auto-scroll to bottom when new messages arrive
    Shiny.addCustomMessageHandler('scrollToBottom', function(message) {
      setTimeout(function() {
        var container = $('.chat-messages');
        if (container.length && container[0]) {
          container.scrollTop(container[0].scrollHeight);
        }
        addCopyButtons();
      }, 150);
    });

    // Also add copy buttons when messages output changes
    $(document).on('shiny:value', function(event) {
      if (event.name === 'messages') {
        setTimeout(addCopyButtons, 150);
      }
    });

    // Clear input
    Shiny.addCustomMessageHandler('clearInput', function(message) {
      $('#user_input').val('');
      var textarea = document.getElementById('user_input');
      if (textarea) {
        textarea.style.height = 'auto';
      }
    });

    // Set loading state
    Shiny.addCustomMessageHandler('setLoading', function(isLoading) {
      if (isLoading) {
        $('#send').prop('disabled', true);
        $('#user_input').prop('disabled', true);
      } else {
        $('#send').prop('disabled', false);
        $('#user_input').prop('disabled', false);
        $('#user_input').focus();
      }
    });
  "
}

.js_textarea_behavior <- function() {
  "
    // Auto-resize textarea
    $('#user_input').on('input', function() {
      this.style.height = 'auto';
      this.style.height = Math.min(this.scrollHeight, 150) + 'px';
    });

    // Handle Enter key (send) vs Shift+Enter (new line)
    $('#user_input').on('keydown', function(e) {
      if (e.key === 'Enter' && !e.shiftKey) {
        e.preventDefault();
        $('#send').click();
      }
    });
  "
}

.js_init <- function() {
  "
    // Initial scroll to bottom and add copy buttons
    setTimeout(function() {
      var container = $('.chat-messages');
      if (container.length && container[0]) {
        container.scrollTop(container[0].scrollHeight);
      }
      addCopyButtons();
    }, 300);
  });
  "
}

.js_helper_functions <- function() {
  "
  // Toggle context sections (collapsible)
  function toggleContextSection(sectionName) {
    var section = $('#context_section_' + sectionName).closest('.context-section');
    section.toggleClass('collapsed');
  }

  // Toggle file tree folders
  function toggleFileFolder(folderId) {
    var folder = document.getElementById('folder_' + folderId);
    if (folder) {
      folder.classList.toggle('collapsed');
    }
  }

  // Bind file checkboxes to Shiny
  $(document).on('change', '.file-checkbox', function() {
    var id = $(this).attr('id');
    var checked = $(this).is(':checked');
    Shiny.setInputValue(id, checked, {priority: 'event'});
  });
  "
}
