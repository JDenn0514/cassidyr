# Phase 1: Incremental Context Sending
## `cassidyr` Feature Implementation Plan


### Overview

#### Problem Statement

Currently, when clicking "Apply Context" in the Cassidy Chat app, **all selected context is sent every time**, even if it was already sent in the current conversation. This causes issues when:

1. The CassidyAI message length limit (~200K chars) is hit
2. Users want to incrementally add files to an ongoing conversation
3. Users switch between conversations and lose track of what's been sent

Additionally, the UI doesn't accurately reflect conversation state:

- Files sent via "New Conversation" modal aren't checked in the sidebar
- Switching conversations doesn't update checkboxes to reflect that conversation's context
- Reopening the app doesn't restore checkbox state

#### Solution

Track what has been **sent** separately from what is **selected**, and only send the delta when "Apply Context" is clicked.

#### Scope

- ~120 lines of changes across 5 files
- Low risk (additive changes)
- No breaking changes to existing functionality

---

### Implementation Details

#### 1. ConversationManager Changes

**File:** `R/chat-conversation.R`

**Changes (~30 lines):**

Add new reactive properties to track sent state:

```r
ConversationManager <- S7::new_class(
 "ConversationManager",
 properties = list(

   # ... existing properties ...

   # NEW: Track what's actually been sent to Cassidy

   sent_context_files = S7::class_any,
   sent_data_frames = S7::class_any,


   # NEW: Track items queued for refresh (re-send)
   pending_refresh_files = S7::class_any,
   pending_refresh_data = S7::class_any
 ),
 constructor = function() {
   S7::new_object(
     S7::S7_object(),
     # ... existing initializations ...

     # NEW
     sent_context_files = shiny::reactiveVal(character()),
     sent_data_frames = shiny::reactiveVal(character()),
     pending_refresh_files = shiny::reactiveVal(character()),
     pending_refresh_data = shiny::reactiveVal(character())
   )
 }
)
```
Add getter/setter generics and methods for each new property.

Update `conv_switch_to()` to restore tracking state:

```r
S7::method(conv_switch_to, ConversationManager) <- function(x, conv_id, session = NULL) {
 # ... existing code ...

 if (length(idx) > 0) {
   conv <- convs[[idx]]
   # ... existing assignments ...

   # NEW: Restore sent tracking
   x@sent_context_files(conv$sent_context_files %||% character())
   x@sent_data_frames(conv$sent_data_frames %||% character())
   x@pending_refresh_files(character())  # Clear pending on switch
   x@pending_refresh_data(character())

   # NEW: Sync UI checkboxes
   if (!is.null(session)) {
     session$sendCustomMessage("syncFileCheckboxes", conv$sent_context_files %||% character())
   }
 }
}
```

Update `conv_create_new()` to initialize empty tracking:

```r
S7::method(conv_create_new, ConversationManager) <- function(x, session = NULL) {
 # ... existing code ...

 new_conv <- list(
   # ... existing fields ...
   sent_context_files = character(),
   sent_data_frames = character()
 )

 # ... existing code ...

 # NEW: Clear all tracking for new conversation
 x@sent_context_files(character())
 x@sent_data_frames(character())
 x@pending_refresh_files(character())
 x@pending_refresh_data(character())
}
```

---

#### 2. Persistence Changes

**File:** `R/chat-persistence.R`

**Changes (~10 lines):**

Update `cassidy_save_conversation()` to persist sent tracking:

```r
cassidy_save_conversation <- function(conv) {
 # Ensure sent tracking is included
 if (is.null(conv$sent_context_files)) {
   conv$sent_context_files <- character()
 }
 if (is.null(conv$sent_data_frames)) {
   conv$sent_data_frames <- character()
 }

 # ... rest of existing save logic ...
}
```

Update `cassidy_load_conversation()` to restore these fields (should work automatically if saved correctly, but add defaults):

```r
cassidy_load_conversation <- function(conv_id) {
 # ... existing load logic ...

 # Ensure backwards compatibility
 conv$sent_context_files <- conv$sent_context_files %||% character()
 conv$sent_data_frames <- conv$sent_data_frames %||% character()

 conv
}
```

---

#### 3. Context Handler Changes

**File:** `R/chat-context-handlers.R`

**Changes (~50 lines):**
##### Update `gather_selected_context()`

Modify to only gather NEW or REFRESHED items:
```r
gather_selected_context <- function(input, conv_manager, incremental = TRUE) {
 # Get current selections (existing logic)
 selected_files <- conv_context_files(conv_manager)
 # ... existing file selection sync logic ...

 # Get selected data frames (existing logic)
 selected_data <- # ... existing logic ...

 if (incremental)
{
   # NEW: Calculate what actually needs to be sent
   sent_files <- conv_sent_context_files(conv_manager)
   sent_data <- conv_sent_data_frames(conv_manager)
   pending_files <- conv_pending_refresh_files(conv_manager)
   pending_data <- conv_pending_refresh_data(conv_manager)

   # Only gather new + refreshed items
   files_to_send <- union(
     setdiff(selected_files, sent_files),  # Newly selected
     pending_files                           # Marked for refresh
   )

   data_to_send <- union(
     setdiff(selected_data, sent_data),
     pending_data
   )
 } else {
   # Full send (for new conversations)
   files_to_send <- selected_files
   data_to_send <- selected_data
 }

 # ... rest of gather logic, but only for files_to_send and data_to_send ...
}
```

##### Update `setup_apply_context_handler()`

After successful send, update tracking:

```r
# After successful API response...

# NEW: Update sent tracking
current_sent_files <- conv_sent_context_files(conv_manager)
current_sent_data <- conv_sent_data_frames(conv_manager)

# Add newly sent items
conv_set_sent_context_files(
 conv_manager,
 union(current_sent_files, files_to_send)
)
conv_set_sent_data_frames(
 conv_manager,
 union(current_sent_data, data_to_send)
)

# Clear pending refresh queues
conv_set_pending_refresh_files(conv_manager, character())
conv_set_pending_refresh_data(conv_manager, character())

# Update conversation record for persistence
conv_update_current(conv_manager, list(
 sent_context_files = conv_sent_context_files(conv_manager),
 sent_data_frames = conv_sent_data_frames(conv_manager)
))
```

Add early exit if nothing new to send:

```r
shiny::observeEvent(input$apply_context, {
 # ... gather context ...

 # NEW: Check if there's anything new to send
 if (length(files_to_send) == 0 && length(data_to_send) == 0 && !project_items_changed) {
   shiny::showNotification(
     "No new context to send - everything selected has already been sent",
     type = "message",
     duration = 3
   )
   return()
 }

 # ... rest of send logic ...
})
```

##### Update refresh button handlers

Change from setting boolean to queuing for refresh:

```r
# File refresh handler
shiny::observeEvent(input[[refresh_id]], {
 # OLD: conv_set_context_sent(conv_manager, FALSE)

 # NEW: Add to pending refresh queue
 current_pending <- conv_pending_refresh_files(conv_manager)
 conv_set_pending_refresh_files(
   conv_manager,
   union(current_pending, file_path)
 )

 shiny::showNotification(
   paste(basename(file_path), "queued for refresh - click 'Apply Context' to send"),
   type = "message",
   duration = 3
 )
}, ignoreInit = TRUE)
```

---

#### 4. JavaScript Changes

**File:** `R/chat-js.R`

**Changes (~15 lines):**

Add handler to sync checkbox state from server:

```r
.js_shiny_handlers <- function() {
 "
 // ... existing handlers ...

 // NEW: Sync file checkboxes with conversation state
 Shiny.addCustomMessageHandler('syncFileCheckboxes', function(sentFiles) {
   console.log('Syncing checkboxes for files:', sentFiles);

   // Uncheck all file checkboxes first
   $('.file-checkbox').prop('checked', false);

   // Check boxes for sent files
   sentFiles.forEach(function(filePath) {
     var fileId = filePath.replace(//g, '_');
     $('#ctx_file_' + fileId).prop('checked', true);
   });
 });

 // NEW: Sync data frame checkboxes
 Shiny.addCustomMessageHandler('syncDataCheckboxes', function(sentData) {
   // Uncheck all data checkboxes first
   $('[id^=ctx_data_]').prop('checked', false);

   // Check boxes for sent data frames
   sentData.forEach(function(dfName) {
     var dfId = dfName.replace(//g, '_');
     $('#ctx_data_' + dfId).prop('checked', true);
   });
 });
 "
}
```

---

#### 5. Server Handler Changes

**File:** `R/chat-server-handlers.R`

**Changes (~15 lines):**

Update `setup_conversation_load_handler()` to sync UI:

```r
shiny::observeEvent(input$load_conversation, {
 conv_id <- input$load_conversation
 conv_load_and_set(conv_manager, conv_id, session)

 # NEW: Sync UI with loaded conversation's sent state
 sent_files <- conv_sent_context_files(conv_manager)
 sent_data <- conv_sent_data_frames(conv_manager)

 session$sendCustomMessage("syncFileCheckboxes", sent_files)
 session$sendCustomMessage("syncDataCheckboxes", sent_data)
})
```

---

### Expected Behavior

| Action | Result |
|--------|--------|
| Select new file + Apply | File sent, added to `sent_context_files`, checkbox stays checked |
| Select already-sent file + Apply | Shows "No new context to send" notification |
| Click refresh on sent file + Apply | File re-sent, stays in `sent_context_files` |
| Switch conversation | Checkboxes update to match that conversation's `sent_context_files` |
| Close/reopen app | Checkboxes restore from persisted `sent_context_files` |
| New conversation | All checkboxes cleared, fresh tracking state |

---

### Testing Checklist

- [ ] New conversation: select files, apply context, verify sent
- [ ] Same conversation: select more files, apply, verify only new files sent
- [ ] Refresh button: click refresh on sent file, apply, verify re-sent
- [ ] Switch conversations: verify checkboxes update correctly
- [ ] Close/reopen app: verify checkbox state persists
- [ ] "No new context" notification appears when nothing new selected

---

### Future Enhancements (Not in Phase 1)

1. **Visual feedback for pending items**
 - Green highlight on newly-selected items before "Apply"
 - Badge showing "3 new items pending"

2. **Automatic change detection**
 - Detect when file content has changed since last send
 - Prompt user to refresh

3. **Diff-based updates**
 - Send only changed portions of files
 - Requires more sophisticated tracking

4. **Character count preview**
 - Show estimated size before sending
 - Warn if approaching limit

---

### Files Modified

| File | Lines Changed | Risk |
|------|---------------|------|
| `R/chat-conversation.R` | ~30 | Low |
| `R/chat-persistence.R` | ~10 | Low |
| `R/chat-context-handlers.R` | ~50 | Medium |
| `R/chat-js.R` | ~15 | Low |
| `R/chat-server-handlers.R` | ~15 | Low |
| **Total** | **~120** | **Low** |
