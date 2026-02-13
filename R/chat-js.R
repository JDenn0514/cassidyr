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
  });
  "
}

.js_copy_buttons <- function() {
  clipboard <- "\U0001F4CB"
  checkmark <- "\u2713"

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
      });
    }

    // Use event delegation for copy button clicks
    $(document).on('click', '.copy-code-btn', function(e) {
      e.preventDefault();
      e.stopPropagation();

      var $btn = $(this);
      var $pre = $btn.siblings('pre');
      var text = $pre.text();

      // Try modern clipboard API first, fallback to execCommand
      if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(text).then(function() {
          $btn.text('",
    checkmark,
    "');
          setTimeout(function() { $btn.text('",
    clipboard,
    "'); }, 1500);
        }).catch(function(err) {
          fallbackCopy(text, $btn);
        });
      } else {
        fallbackCopy(text, $btn);
      }
    });

    // Fallback copy method for older browsers or non-HTTPS
    function fallbackCopy(text, $btn) {
      var textarea = document.createElement('textarea');
      textarea.value = text;
      textarea.style.position = 'fixed';
      textarea.style.opacity = '0';
      document.body.appendChild(textarea);
      textarea.select();
      try {
        document.execCommand('copy');
        $btn.text('",
    checkmark,
    "');
        setTimeout(function() { $btn.text('",
    clipboard,
    "'); }, 1500);
      } catch (err) {
        console.error('Copy failed:', err);
        $btn.text('Error');
        setTimeout(function() { $btn.text('",
    clipboard,
    "'); }, 1500);
      }
      document.body.removeChild(textarea);
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

    // Trigger file tree refresh
    Shiny.addCustomMessageHandler('triggerFileTreeRefresh', function(message) {
      Shiny.setInputValue('force_file_tree_refresh', Math.random(), {priority: 'event'});
    });

    Shiny.addCustomMessageHandler('syncFileCheckboxes', function(data) {
      var sent = (data && data.sent) ? data.sent : [];
      var selected = (data && data.selected) ? data.selected : [];

      // Only update classes, don't touch checkbox state
      $('.file-tree-item').each(function() {
        var item = $(this);
        var checkbox = item.find('.file-checkbox');
        var filePath = checkbox.attr('data-filepath') || '';

        item.removeClass('sent pending');

        if (sent.indexOf(filePath) !== -1) {
          item.addClass('sent');
        } else if (checkbox.is(':checked')) {
          item.addClass('pending');
        }
      });
    });

    // Sync data frame checkboxes
    Shiny.addCustomMessageHandler('syncDataCheckboxes', function(data) {
      var sent, selected;
      if (data && typeof data === 'object' && !Array.isArray(data)) {
        sent = Array.isArray(data.sent) ? data.sent : [];
        selected = Array.isArray(data.selected) ? data.selected : sent;
      } else {
        sent = Array.isArray(data) ? data : [];
        selected = sent;
      }

      $('[id^=\"ctx_data_\"]').prop('checked', false);
      selected.forEach(function(dfName) {
        // Convert data frame name to valid ID
        var dfId = dfName.replace(/[^a-zA-Z0-9]/g, '_');
        var checkbox = $('#ctx_data_' + dfId);Fre
        if (checkbox.length) {
          checkbox.prop('checked', true);
        }
      });
    });

    // Mark file as pending for refresh
    Shiny.addCustomMessageHandler('markFileAsPending', function(data) {
      if (data && data.fileId) {
        var checkbox = $('#ctx_file_' + data.fileId);
        var item = checkbox.closest('.file-tree-item');
        if (item.length && item.hasClass('sent')) {
          // Change from blue (sent) to green (pending refresh)
          item.removeClass('sent').addClass('pending');
        }
      }
    });

    // Copy buttons on message change
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
      var overlay = document.getElementById('loading_overlay_div');

      if (isLoading) {
        $('#send').prop('disabled', true);
        $('#user_input').prop('disabled', true);

        // Create and show overlay
        if (!overlay) {
          overlay = document.createElement('div');
          overlay.id = 'loading_overlay_div';
          overlay.className = 'loading-overlay';
          overlay.innerHTML = '<div class=\"loading-spinner\"></div><div class=\"loading-text\">Waiting for response...</div>';
          document.body.appendChild(overlay);
        }
        overlay.style.display = 'flex';
      } else {
        $('#send').prop('disabled', false);
        $('#user_input').prop('disabled', false);
        $('#user_input').focus();

        // Hide overlay
        if (overlay) {
          overlay.style.display = 'none';
        }
      }
    });

  "
}

.js_textarea_behavior <- function() {
  "
  $(document).ready(function() {
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
  });
  "
}

.js_init <- function() {
  "
  $(document).ready(function() {
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
  right_arrow <- "\u25B6"
  down_arrow <- "\u25BC"
  checkmark <- "\u2713"

  paste0(
    "
  // Copy file content from file blocks
  window.copyFileContent = function(btn) {
    var $btn = $(btn);
    var $fileBlock = $btn.closest('.cassidy-file-block');
    var $code = $fileBlock.find('.file-content code');
    var text = $code.text();

    // Try modern clipboard API first, fallback to execCommand
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(text).then(function() {
        var originalHTML = $btn.html();
        $btn.html('", checkmark, " Copied!');
        setTimeout(function() { $btn.html(originalHTML); }, 1500);
      }).catch(function(err) {
        copyFileFallback(text, $btn);
      });
    } else {
      copyFileFallback(text, $btn);
    }
  };

  // Fallback copy method for file content
  function copyFileFallback(text, $btn) {
    var textarea = document.createElement('textarea');
    textarea.value = text;
    textarea.style.position = 'fixed';
    textarea.style.opacity = '0';
    document.body.appendChild(textarea);
    textarea.select();
    try {
      document.execCommand('copy');
      var originalHTML = $btn.html();
      $btn.html('", checkmark, " Copied!');
      setTimeout(function() { $btn.html(originalHTML); }, 1500);
    } catch (err) {
      console.error('Copy failed:', err);
      $btn.text('Error');
      setTimeout(function() { $btn.html(originalHTML); }, 1500);
    }
    document.body.removeChild(textarea);
  }

  $(document).ready(function() {
    // Toggle context sections (collapsible)
    window.toggleContextSection = function(sectionName) {
      var section = $('#context_section_' + sectionName).closest('.context-section');
      section.toggleClass('collapsed');
    };

    // Toggle file tree folders
    window.toggleFolder = function(folderId) {
      var contents = $('#folder_contents_' + folderId);
      var icon = $('#toggle_icon_' + folderId);

      if (contents.is(':visible')) {
        contents.hide();
        icon.html('",
    right_arrow,
    "');
      } else {
        contents.show();
        icon.html('",
    down_arrow,
    "');
      }
    };

    // Expand all folders
    $(document).on('click', '#expand_all_folders', function() {
      $('.file-tree-folder-contents').show();
      $('.folder-toggle-icon').html('",
    down_arrow,
    "');
    });

    // Collapse all folders
    $(document).on('click', '#collapse_all_folders', function() {
      $('.file-tree-folder-contents').hide();
      $('.folder-toggle-icon').html('",
    right_arrow,
    "');
    });

    // Handle file checkbox changes and update classes
    $(document).on('change', '.file-checkbox', function() {
      var checkbox = $(this);
      var id = checkbox.attr('id');
      var checked = checkbox.is(':checked');
      var item = checkbox.closest('.file-tree-item');

      // *** NEW: Get the original file path from data attribute ***
      var filePath = checkbox.attr('data-filepath') || checkbox.data('filepath');

      // Send to Shiny (keep existing for backwards compatibility)
      Shiny.setInputValue(id, checked, {priority: 'event'});

      // *** NEW: Also send consolidated update with the file path ***
      if (filePath) {
        Shiny.setInputValue('file_checkbox_changed', {
          filePath: filePath,
          checked: checked,
          timestamp: Date.now()
        }, {priority: 'event'});
      }

      // Update visual state immediately (UNCHANGED)
      // If checked, mark as pending (green) unless already sent
      if (checked) {
        // Don't change class if already sent - let Apply Context handle the state
        if (!item.hasClass('sent')) {
          item.addClass('pending');
        }
      } else {
        item.removeClass('pending sent');
      }

    });

    // Make context sidebar resizable
    var isResizing = false;
    var sidebar = $('#context_sidebar');
    var minWidth = 200;
    var maxWidth = 600;

    // Add resize handle to sidebar
    if (sidebar.find('.resize-handle').length === 0) {
      sidebar.append('<div class=\"resize-handle\"></div>');
    }

    $(document).on('mousedown', '.resize-handle', function(e) {
      isResizing = true;
      $('body').css('cursor', 'ew-resize').css('user-select', 'none');
      e.preventDefault();
    });

    $(document).on('mousemove', function(e) {
      if (!isResizing) return;

      var newWidth = e.clientX;
      newWidth = Math.max(minWidth, Math.min(newWidth, maxWidth));
      sidebar.css('width', newWidth + 'px');
    });

    $(document).on('mouseup', function() {
      if (isResizing) {
        isResizing = false;
        $('body').css('cursor', '').css('user-select', '');
      }
    });
  });
  "
  )
}
