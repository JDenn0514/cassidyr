#' @keywords internal
chat_app_css <- function() {
  "
/* ===== MAIN LAYOUT ===== */
.main-layout {
  display: flex;
  height: 100vh;
  width: 100%;
  overflow: hidden;
}

/* ===== SIDEBARS ===== */
.context-sidebar,
.history-sidebar {
  width: 280px;
  min-width: 0;
  flex-shrink: 0;
  background-color: #f8f9fa;
  display: flex;
  flex-direction: column;
  height: 100vh;
  overflow: hidden;
  transition: width 0.3s ease;
}

.context-sidebar {
  border-right: 1px solid #dee2e6;
}

.history-sidebar {
  border-left: 1px solid #dee2e6;
}

/* Sidebar collapsed state for all screen sizes */
.context-sidebar.collapsed,
.history-sidebar.collapsed {
  width: 0 !important;
  min-width: 0 !important;
  border: none !important;
  overflow: hidden;
}

/* ===== SIDEBAR HEADER ===== */
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

/* ===== CONTEXT SIDEBAR CONTENT ===== */
.context-sidebar-content {
  flex: 1;
  overflow-y: auto;
  min-height: 0;
}

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
}

/* ===== CONTEXT ITEMS ===== */
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

.context-item-main {
  flex: 1;
  min-width: 0;
}

.context-item-main .form-check {
  margin-bottom: 0;
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

.context-item:hover .btn-icon-xs,
.context-data-item:hover .btn-icon-xs {
  opacity: 1;
}

.btn-icon-xs:hover {
  color: #0d6efd;
}

/* ===== CONTEXT DATA ===== */
.context-data-options {
  margin-bottom: 0.5rem;
}

.context-data-options .form-select {
  font-size: 0.8rem;
  padding: 0.25rem 0.5rem;
}

.context-data-list {
  max-height: 200px;
  overflow-y: auto;
}

.context-data-item {
  display: flex;
  align-items: center;
  padding: 0.4rem 0.5rem;
  background-color: #fff;
  border-radius: 0.25rem;
  margin-bottom: 0.25rem;
  border: 1px solid #e9ecef;
}

.context-data-item:hover {
  background-color: #f8f9fa;
  border-color: #dee2e6;
}

.context-data-item .form-check {
  margin-bottom: 0;
  flex: 1;
  min-width: 0;
}

.context-data-item .form-check-label {
  font-size: 0.8rem;
  display: flex;
  align-items: center;
  gap: 0.5rem;
  cursor: pointer;
  width: 100%;
}

.data-info {
  display: flex;
  align-items: center;
  justify-content: space-between;
  flex: 1;
  min-width: 0;
}

.data-name {
  font-weight: 500;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.data-dims {
  font-size: 0.7rem;
  color: #6c757d;
  white-space: nowrap;
  margin-left: 0.5rem;
}

.no-data-message {
  font-size: 0.8rem;
  color: #6c757d;
  text-align: center;
  padding: 1rem 0.5rem;
}

/* ===== CONTEXT FILES ===== */
.context-files-actions {
  margin-bottom: 0.5rem;
}

.context-files-list {
  max-height: 200px;
  overflow-y: auto;
}

/* ===== FILE TREE ===== */
.context-files-tree {
  max-height: 300px;
  overflow-y: auto;
  font-size: 0.8rem;
}

.file-tree-folder {
  margin-bottom: 0.25rem;
}

.file-tree-folder-header {
  display: flex;
  align-items: center;
  padding: 0.2rem 0.4rem;  /* Was 0.3rem 0.5rem */
  cursor: pointer;
  border-radius: 0.25rem;
  gap: 0.35rem;  /* Was 0.5rem */
}

.file-tree-folder-header:hover {
  background-color: #e9ecef;
}

.file-tree-folder-header .folder-icon {
  color: #f0ad4e;
}

.file-tree-folder-header .folder-name {
  flex: 1;
  font-weight: 500;
}

.file-tree-folder-header .folder-count {
  font-size: 0.7rem;
  color: #6c757d;
}

.file-tree-folder.collapsed .file-tree-folder-contents {
  display: none;
}

.file-tree-folder.collapsed .folder-chevron {
  transform: rotate(-90deg);
}

.folder-chevron {
  font-size: 0.6rem;
  transition: transform 0.2s ease;
}

.file-tree-folder-contents {
  padding-left: 0.75rem;  /* Was 1rem */
  border-left: 1px solid #dee2e6;
  margin-left: 0.25rem;  /* Was 0.5rem */
}
/* ====== FILE TREE ITEMS ====== */
.file-tree-item {
  display: flex;
  align-items: center;
  padding: 0.15rem 0.25rem;
  border-radius: 0.25rem;
  margin-bottom: 0.1rem;
  gap: 0.35rem;
}

.file-tree-item:hover {
  background-color: #f8f9fa;
}

.file-tree-item.selected {
  background-color: #e3f2fd;
  border: 1px solid #0d6efd;
}

.file-tree-item .form-check {
  margin-bottom: 0;
  flex: 1;
  min-width: 0;
}

.file-tree-item .form-check-label {
  display: flex;
  align-items: center;
  gap: 0.1rem;
  cursor: pointer;
  font-size: 0.8rem;
}

.file-tree-item .file-icon {
  color: #6c757d;
}

.file-tree-item .file-icon.r-file {
  color: #276dc3;
}

.file-tree-item .file-icon.md-file {
  color: #083fa1;
}

.file-tree-item .file-icon.qmd-file {
  color: #75aadb;
}

.file-tree-item .file-name {
  flex: 1;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.file-tree-item .file-actions {
  display: flex;
  gap: 0.25rem;
  opacity: 1;
  transition: opacity 0.15s ease;
}

.file-tree-item:hover .file-actions {
  opacity: 1;
}

.file-tree-item:hover .file-refresh-btn {
  opacity: 1;
}

.file-tree-item .file-checkbox {
  margin: 0;
  flex-shrink: 0;
}

.file-tree-label {
  display: flex;
  align-items: center;
  gap: 0.35rem;
  cursor: pointer;
  flex: 1;
  min-width: 0;
  font-size: 0.8rem;
}

.file-tree-label .file-name {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.file-tree-label .file-icon {
  flex-shrink: 0;
  color: #6c757d;
}

.file-tree-label .file-icon.r-file {
  color: #276dc3;
}

.file-tree-label .file-icon.md-file {
  color: #083fa1;
}

.file-tree-label .file-icon.qmd-file {
  color: #75aadb;
}

.file-tree-empty {
  text-align: center;
  padding: 1rem;
  color: #6c757d;
  font-size: 0.85rem;
}

.file-tree-empty .empty-icon {
  font-size: 2rem;
  margin-bottom: 0.5rem;
  opacity: 0.5;
}

.file-refresh-btn {
  flex-shrink: 0;
  opacity: 0;
  transition: opacity 0.15s ease;
}

/* ===== CONTEXT APPLY PANEL ===== */
.context-apply-panel {
  padding: 0.75rem;
  border-top: 1px solid #dee2e6;
  background-color: #fff;
  flex-shrink: 0;
}

.context-apply-summary {
  margin-bottom: 0.5rem;
  font-size: 0.8rem;
  color: #495057;
}

.summary-title {
  font-weight: 600;
  margin-bottom: 0.25rem;
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.summary-items {
  font-size: 0.75rem;
  color: #6c757d;
}

.summary-item {
  display: flex;
  align-items: center;
  gap: 0.25rem;
  margin-bottom: 0.1rem;
}

.summary-item.has-items {
  color: #198754;
}

.summary-item.no-items {
  color: #6c757d;
}

.context-applied-badge {
  display: inline-flex;
  align-items: center;
  gap: 0.25rem;
  padding: 0.15rem 0.4rem;
  background-color: #d1e7dd;
  color: #0f5132;
  border-radius: 0.25rem;
  font-size: 0.7rem;
  margin-left: 0.5rem;
}

/* ===== CHAT MAIN AREA ===== */
.chat-main {
  flex: 1;
  display: flex;
  flex-direction: column;
  min-width: 0;
  height: 100vh;
  overflow: hidden;
}

/* ===== HEADER ===== */
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

.header-left,
.header-right {
  display: flex;
  align-items: center;
}

.header-left h4 {
  white-space: nowrap;
}

#context_status {
  font-size: 0.8rem;
}

/* ===== CHAT CONTAINER ===== */
.chat-container {
  flex: 1;
  display: flex;
  flex-direction: column;
  min-height: 0;
  overflow: hidden;
}

/* ===== CHAT MESSAGES ===== */
.chat-messages {
  flex: 1;
  overflow-y: auto;
  padding: 1rem;
  min-height: 0;
}

.chat-messages::-webkit-scrollbar {
  width: 8px;
}

.chat-messages::-webkit-scrollbar-track {
  background: #f1f1f1;
  border-radius: 4px;
}

.chat-messages::-webkit-scrollbar-thumb {
  background: #c1c1c1;
  border-radius: 4px;
}

.chat-messages::-webkit-scrollbar-thumb:hover {
  background: #a1a1a1;
}

/* ===== CHAT INPUT ===== */
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

.message-loading {
  background-color: #f5f5f5;
  margin-right: 15%;
  border: 2px solid #0d6efd;
}

.message-role {
  font-weight: 600;
  margin-bottom: 0.25rem;
  font-size: 0.8rem;
  text-transform: uppercase;
  color: #666;
}

.message pre {
  overflow-x: auto;
  max-width: 100%;
}

.message code {
  word-break: break-word;
}

/* ===== LOADING INDICATOR ===== */
.loading-indicator {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.5rem;
  padding: 0.5rem 0;
}

.loading-dots {
  display: flex;
  gap: 0.5rem;
}

.loading-dots .dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  background-color: #0d6efd;
  animation: bounce 1.4s infinite ease-in-out both;
}

.loading-dots .dot:nth-child(1) { animation-delay: -0.32s; }
.loading-dots .dot:nth-child(2) { animation-delay: -0.16s; }

@keyframes bounce {
  0%, 80%, 100% { transform: scale(0); opacity: 0.5; }
  40% { transform: scale(1); opacity: 1; }
}

.loading-text {
  font-size: 0.85rem;
  color: #666;
  font-style: italic;
}

/* ===== CONVERSATION LIST ===== */
.conversation-list {
  flex: 1;
  overflow-y: auto;
  padding: 0.5rem;
}

.conversation-list-header {
  font-size: 0.7rem;
  text-transform: uppercase;
  font-weight: 600;
  color: #6c757d;
  margin: 0.75rem 0 0.5rem 0.5rem;
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
  border-color: #0d6efd;
}

.conversation-item.active .conversation-preview,
.conversation-item.active .conversation-time {
  color: rgba(255, 255, 255, 0.8);
}

.conversation-title {
  font-weight: 500;
  font-size: 0.85rem;
  margin-bottom: 0.2rem;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  padding-right: 50px;
}

.conversation-preview {
  font-size: 0.75rem;
  color: #666;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.conversation-time {
  font-size: 0.7rem;
  color: #999;
  margin-top: 0.2rem;
}

.conversation-actions {
  position: absolute;
  top: 0.4rem;
  right: 0.4rem;
  display: flex;
  gap: 0.2rem;
  opacity: 0;
  transition: opacity 0.15s ease;
}

.conversation-item:hover .conversation-actions,
.conversation-item.active .conversation-actions {
  opacity: 1;
}

.conversation-actions .btn {
  padding: 0.15rem 0.3rem;
  font-size: 0.7rem;
}

.delete-btn {
  color: #dc3545;
}

.delete-btn:hover {
  background-color: #dc3545;
  color: white;
}

.export-btn {
  color: #0d6efd;
}

.export-btn:hover {
  background-color: #0d6efd;
  color: white;
}

.no-conversations {
  text-align: center;
  padding: 2rem 1rem;
  color: #666;
}

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

  .context-sidebar {
    left: 0;
    transform: translateX(0);
  }

  .history-sidebar {
    right: 0;
    transform: translateX(0);
  }

  .context-sidebar.collapsed {
    transform: translateX(-100%);
  }

  .history-sidebar.collapsed {
    transform: translateX(100%);
  }

  .message-user { margin-left: 5%; }
  .message-assistant { margin-right: 5%; }
}

/* ===== COPY CODE BUTTON ===== */
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

.copy-code-btn:hover {
  background-color: #e9ecef;
}
"
}
