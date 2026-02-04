#' @keywords internal
chat_app_css <- function() {
  paste0(
    css_layout(),
    css_sidebars(),
    css_context_sections(),
    css_file_tree(),
    css_chat_area(),
    css_messages(),
    css_conversations(),
    css_responsive(),
    css_downloads(),
    css_context_states(),
    css_loading()
  )
}

#' Layout styles
#' @keywords internal
css_layout <- function() {
  "
/* ===== MAIN LAYOUT ===== */
.main-layout {
  display: flex;
  height: 100vh;
  width: 100%;
  overflow: hidden;
}
"
}

#' Sidebar styles
#' @keywords internal
css_sidebars <- function() {
  "
/* ===== SIDEBARS ===== */
.context-sidebar,
.history-sidebar {
  width: 280px;
  min-width: 200px;
  max-width: 600px;
  flex-shrink: 0;
  background-color: #f8f9fa;
  display: flex;
  flex-direction: column;
  height: 100vh;
  overflow: hidden;
  transition: width 0.1s ease;
  position: relative; /* Important for resize handle */
}

.context-sidebar {
  border-right: 1px solid #dee2e6;
}

.history-sidebar {
  border-left: 1px solid #dee2e6;
}

.context-sidebar.collapsed,
.history-sidebar.collapsed {
  width: 0 !important;
  min-width: 0 !important;
  border: none !important;
  overflow: hidden;
}

/* Resize handle */
.resize-handle {
  position: absolute;
  top: 0;
  right: 0;
  width: 5px;
  height: 100%;
  cursor: ew-resize;
  background: transparent;
  z-index: 10;
}

.resize-handle:hover {
  background: rgba(13, 110, 253, 0.3);
}

.sidebar-header {
  padding: 0.75rem 1rem;
  border-bottom: 1px solid #dee2e6;
  font-weight: 600;
  display: flex;
  justify-content: space-between;
  align-items: center;
  flex-shrink: 0;
  background-color: #f8f9fa;
}

.sidebar-title {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  white-space: nowrap;
}

.sidebar-close {
  background: none;
  border: none;
  font-size: 1.2rem;
  cursor: pointer;
  color: #666;
  padding: 0.25rem;
}

.sidebar-close:hover {
  color: #000;
}

.context-sidebar-content {
  flex: 1;
  overflow-y: auto;
  min-height: 0;
}
"
}

#' Context section styles
#' @keywords internal
css_context_sections <- function() {
  "
/* ===== CONTEXT SECTIONS ===== */
.context-section {
  border-bottom: 1px solid #dee2e6;
}

.context-section-header {
  padding: 0.6rem 1rem;
  font-weight: 500;
  font-size: 0.85rem;
  cursor: pointer;
  display: flex;
  align-items: center;
  gap: 0.5rem;
  background-color: #fff;
  transition: background-color 0.15s ease;
  white-space: nowrap;
}

.context-section-header:hover {
  background-color: #e9ecef;
}

.section-chevron {
  transition: transform 0.2s ease;
  font-size: 0.7rem;
}

.context-section.collapsed .section-chevron {
  transform: rotate(-90deg);
}

.context-section.collapsed .context-section-body {
  display: none;
}

.context-section-body {
  padding: 0.5rem;
  background-color: #fff;
  overflow-y: auto;
}

#context_section_files {
  display: flex;
  flex-direction: column;
  flex: 1;
  min-height: 200px;
  max-height: none;
  overflow: hidden;
}

.context-item {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0.25rem 0.5rem;
  border-radius: 0.25rem;
  margin-bottom: 0.25rem;
}

.context-item:hover {
  background-color: #f8f9fa;
}

.btn-icon-xs {
  padding: 0.1rem 0.3rem;
  font-size: 0.7rem;
  background: none;
  border: none;
  color: #999;
  cursor: pointer;
  opacity: 0;
  transition: opacity 0.15s ease;
}

.context-item:hover .btn-icon-xs {
  opacity: 1;
}

.context-apply-panel {
  padding: 0.75rem;
  border-top: 1px solid #dee2e6;
  background-color: #fff;
  flex-shrink: 0;
}

.summary-title {
  font-weight: 600;
  margin-bottom: 0.25rem;
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.summary-item {
  display: flex;
  align-items: center;
  gap: 0.25rem;
  margin-bottom: 0.1rem;
  font-size: 0.75rem;
}

.summary-item.has-items { color: #198754; }
.summary-item.no-items { color: #6c757d; }
"
}

css_file_tree <- function() {
  checkmark <- stringi::stri_unescape_unicode("\\u2713")
  paste0(
    "
    /* ===== FILE TREE ===== */
    .context-files-tree {
      flex: 1;
      overflow-y: auto;
      font-size: 0.8rem;
      min-height: 150px;
    }

    .file-tree-controls {
      padding: 10px;
      border-bottom: 1px solid #dee2e6;
      display: flex;
      gap: 8px;
    }

    .file-tree-folder {
      margin: 2px 0;
    }

    .file-tree-folder-header {
      padding: 6px 8px;
      cursor: pointer;
      border-radius: 4px;
      display: flex;
      align-items: center;
      gap: 6px;
      transition: background-color 0.2s;
      user-select: none;
    }

    .file-tree-folder-header:hover {
      background-color: #f0f0f0;
    }

    .folder-toggle-icon {
      font-size: 10px;
      width: 12px;
      display: inline-block;
      transition: transform 0.2s;
    }

    .folder-icon {
      color: #ffc107;
      font-size: 14px;
    }

    .folder-name {
      font-size: 13px;
      color: #333;
    }

    .folder-count {
      font-size: 11px;
      color: #6c757d;
      margin-left: auto;
    }

    .file-tree-item {
      display: flex;
      align-items: center;
      padding: 4px 8px;
      border-radius: 4px;
      transition: background-color 0.2s;
      gap: 8px;
    }

    .file-tree-item:hover {
      background-color: #f8f9fa;
    }

    /* Sent files (blue) - files that have been sent to AI */
    .file-tree-item.sent {
      background-color: #e7f3ff !important;
      border: 1px solid #0d6efd !important;
    }

    .file-tree-item.sent .file-checkbox {
      accent-color: #0d6efd !important;
    }

    .file-tree-item.sent .file-name::after {
      content: '",
    checkmark,
    "';
      color: #0d6efd;
      font-size: 0.7rem;
      font-weight: bold;
    }

    /* Pending files (green) - selected but not yet sent */
    .file-tree-item.pending {
      background-color: #d4edda !important;
      border: 1px solid #28a745 !important;
    }

    .file-tree-item.pending .file-checkbox {
      accent-color: #28a745 !important;
    }

    .file-tree-item.pending .file-name::after {
      content: ' (pending)';
      color: #28a745;
      font-size: 0.65rem;
      font-style: italic;
    }

    .file-tree-label {
      display: flex;
      align-items: center;
      gap: 6px;
      cursor: pointer;
      flex: 1;
      margin: 0;
      font-size: 13px;
      min-width: 0;
    }

    .file-checkbox {
      cursor: pointer;
      margin: 0;
      flex-shrink: 0;
    }

    .file-icon {
      font-size: 14px;
      width: 16px;
      flex-shrink: 0;
    }

    .file-icon.r-file { color: #276DC3; }
    .file-icon.rmd-file { color: #75AADB; }
    .file-icon.qmd-file { color: #75AADB; }
    .file-icon.md-file { color: #6c757d; }

    .file-name {
      color: #333;
      font-weight: 500;
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
    }

    .file-refresh-btn {
      flex-shrink: 0;
      opacity: 0;
      transition: opacity 0.15s ease;
    }

    .file-tree-item:hover .file-refresh-btn {
      opacity: 1;
    }

    /* File checkbox wrapper - remove default shiny styling */
    .file-checkbox-wrapper .form-group {
      margin-bottom: 0;
      display: inline-block;
    }

    .file-checkbox-wrapper .checkbox {
      margin: 0;
      padding: 0;
    }

    .file-checkbox-wrapper .checkbox label {
      padding: 0;
      margin: 0;
      font-weight: normal;
    }

    .file-checkbox-wrapper input[type='checkbox'] {
      margin: 0;
      cursor: pointer;
    }
    "
  )
}


#' Chat area styles
#' @keywords internal
css_chat_area <- function() {
  "
/* ===== CHAT AREA ===== */
.chat-main {
  flex: 1;
  display: flex;
  flex-direction: column;
  min-width: 0;
  height: 100vh;
  overflow: hidden;
}

.app-header {
  padding: 0.75rem 1rem;
  border-bottom: 1px solid #dee2e6;
  flex-shrink: 0;
  background-color: #fff;
}

.header-content {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.chat-container {
  flex: 1;
  display: flex;
  flex-direction: column;
  min-height: 0;
  overflow: hidden;
}

.chat-messages {
  flex: 1;
  overflow-y: auto;
  padding: 1rem;
  min-height: 0;
}

.chat-input-area {
  padding: 0.75rem 1rem;
  border-top: 1px solid #dee2e6;
  flex-shrink: 0;
  background-color: #fff;
}

.input-row {
  display: flex;
  gap: 0.5rem;
  align-items: flex-end;
}

.input-row textarea {
  flex: 1;
  resize: none;
  overflow-y: auto;
  min-height: 38px;
  max-height: 150px;
  line-height: 1.5;
}

.send-btn {
  height: 38px;
  width: 50px;
  flex-shrink: 0;
}
"
}

#' Message styles
#' @keywords internal
css_messages <- function() {
  "
/* ===== MESSAGES ===== */
.message {
  margin-bottom: 1rem;
  padding: 0.75rem;
  border-radius: 0.5rem;
  animation: fadeIn 0.3s ease-in;
  word-wrap: break-word;
  overflow-wrap: break-word;
}

@keyframes fadeIn {
  from { opacity: 0; transform: translateY(10px); }
  to { opacity: 1; transform: translateY(0); }
}

.message-user {
  background-color: #e3f2fd;
  margin-left: 15%;
}

.message-assistant {
  background-color: #f5f5f5;
  margin-right: 15%;
}

.message-system {
  background-color: #fff3cd;
  margin-left: 10%;
  margin-right: 10%;
  font-size: 0.9rem;
}

.code-block-wrapper {
  position: relative;
}

.copy-code-btn {
  position: absolute;
  top: 0.5rem;
  right: 0.5rem;
  padding: 0.25rem 0.5rem;
  font-size: 0.8rem;
  background-color: #f8f9fa;
  border: 1px solid #dee2e6;
  border-radius: 0.25rem;
  cursor: pointer;
  opacity: 0;
  transition: opacity 0.15s ease;
}

.code-block-wrapper:hover .copy-code-btn {
  opacity: 1;
}
"
}

#' Conversation list styles
#' @keywords internal
css_conversations <- function() {
  "
/* ===== CONVERSATIONS ===== */
.conversation-list {
  flex: 1;
  overflow-y: auto;
  padding: 0.5rem;
}

.conversation-item {
  padding: 0.6rem;
  margin-bottom: 0.4rem;
  border-radius: 0.4rem;
  cursor: pointer;
  background-color: #fff;
  border: 1px solid #dee2e6;
  transition: all 0.15s ease;
  position: relative;
}

.conversation-item:hover {
  background-color: #e3f2fd;
  border-color: #0d6efd;
}

.conversation-item.active {
  background-color: #0d6efd;
  color: white;
}

.conversation-title {
  font-weight: 500;
  font-size: 0.85rem;
  margin-bottom: 0.2rem;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
"
}

#' Responsive styles
#' @keywords internal
css_responsive <- function() {
  "
/* ===== RESPONSIVE ===== */
@media (max-width: 768px) {
  .context-sidebar,
  .history-sidebar {
    position: absolute;
    z-index: 100;
    height: 100vh;
    width: 280px;
    box-shadow: 2px 0 15px rgba(0,0,0,0.15);
  }

  .message-user { margin-left: 5%; }
  .message-assistant { margin-right: 5%; }
}
"
}

#' Download button styles
#' @keywords internal
css_downloads <- function() {
  "
/* ===== FILE DOWNLOADS ===== */
.file-download-container {
  margin: 0.5rem 0;
}

.file-download-btn {
  display: inline-flex;
  align-items: center;
  gap: 0.5rem;
  font-size: 0.85rem;
  padding: 0.4rem 0.8rem;
  border-radius: 4px;
  text-decoration: none;
  transition: all 0.2s ease;
}

.file-download-btn:hover {
  background-color: var(--bs-primary);
  color: white;
  text-decoration: none;
}

.message-downloads {
  margin-top: 1rem;
  padding-top: 0.75rem;
  border-top: 1px solid rgba(0, 0, 0, 0.1);
}

.message-assistant .message-downloads {
  border-top-color: rgba(0, 0, 0, 0.08);
}
"
}


#' Context item state styles
#' @keywords internal
css_context_states <- function() {
  checkmark <- stringi::stri_unescape_unicode("\\u2713")
  refresh <- stringi::stri_unescape_unicode("\\u21bb")

  paste0(
    "
  /* ===== CONTEXT ITEM STATES ===== */
  /* General context items (not file tree) */
  .context-item-sent .context-item-main::after {
    content: '",
    checkmark,
    "';
    color: #198754;
    font-size: 0.7rem;
    margin-left: 0.5rem;
  }

  .context-item-pending {
    background-color: #fff3cd;
    border-left: 3px solid #ffc107;
  }

  .context-item-pending .context-item-main::after {
    content: '",
    refresh,
    " pending';
    color: #856404;
    font-size: 0.65rem;
    margin-left: 0.5rem;
    font-style: italic;
  }

  /* Data frame items */
  .data-item.sent::after {
    content: '",
    checkmark,
    "';
    color: #198754;
    font-size: 0.7rem;
  }

  .data-item.pending {
    background-color: #fff3cd;
    border-left: 3px solid #ffc107;
  }
  "
  )
}

#' Loading indicator styles
#' @keywords internal
css_loading <- function() {
  "
  /* ===== LOADING OVERLAY ===== */
  .loading-overlay {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background-color: rgba(255, 255, 255, 0.8);
    display: flex;
    flex-direction: column;
    justify-content: center;
    align-items: center;
    z-index: 9999;
  }

  .loading-spinner {
    width: 50px;
    height: 50px;
    border: 4px solid #e9ecef;
    border-top-color: #0d6efd;
    border-radius: 50%;
    animation: spin 0.8s linear infinite;
  }

  .loading-text {
    margin-top: 16px;
    color: #6c757d;
    font-size: 1rem;
    font-weight: 500;
  }

  @keyframes spin {
    to { transform: rotate(360deg); }
  }
  "
}
