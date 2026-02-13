# Unified Console Chat Interface Implementation Plan

## Overview

Create a simplified, unified console interface for chatting with Cassidy AI that automatically manages conversation state and context. The new `cassidy_chat()` function will replace the fragmented console chat experience while maintaining backward compatibility.

## Goals

- **Single entry point** - One function for all console chat interactions
- **Smart defaults** - Automatically continue conversations, manage context
- **Natural flow** - Just keep calling `cassidy_chat()` to continue chatting
- **Backward compatible** - Existing functions remain but are superseded

## Function Design

### Main Function: `cassidy_chat()`

```r
cassidy_chat(
  message,
  conversation = NULL,        # NULL = continue current, "new" = start new, conv_id = switch
  assistant_id = Sys.getenv("CASSIDY_ASSISTANT_ID"),
  api_key = Sys.getenv("CASSIDY_API_KEY"),
  context_level = c("standard", "minimal", "comprehensive"),
  include_data = TRUE,
  include_files = NULL,
  timeout = 300
)
```

**Parameters:**

- `message` - Character. The message to send
- `conversation` - Character or NULL. Controls conversation behavior:
  - `NULL` (default) - Continue current conversation
  - `"new"` - Start fresh conversation with new context
  - `conv_id` - Switch to specific conversation (e.g., `"conv_20260131_1234"`)
- `assistant_id` - Character. Assistant ID (from env var)
- `api_key` - Character. API key (from env var)
- `context_level` - Character. Context level for new conversations: `"minimal"`, `"standard"`, `"comprehensive"`
- `include_data` - Logical. Include data frames in context (new conversations only)
- `include_files` - Character vector. File paths to include (new conversations only)
- `timeout` - Numeric. API timeout in seconds

**Behavior:**

- Always prints response to console (user-friendly)
- Returns result invisibly for programmatic use
- Auto-saves conversation after each message
- Manages package-level state for current conversation

**Examples:**

```r
# First call - creates new conversation with standard context
cassidy_chat("What is the tidyverse?")

# Subsequent calls - automatically continues
cassidy_chat("Tell me more")
cassidy_chat("Show an example")

# Start fresh conversation
cassidy_chat("New topic", conversation = "new")

# Switch to previous conversation
convs <- cassidy_conversations()
cassidy_chat("Back to old topic", conversation = convs$id[2])

# Comprehensive context for complex projects
cassidy_chat(
  "Help me refactor this code",
  conversation = "new",
  context_level = "comprehensive",
  include_files = c("R/analysis.R", "R/utils.R")
)
```

### Helper Functions

#### `cassidy_conversations()`

List available conversations with pretty printing.

```r
cassidy_conversations(n = 10)
```

**Returns:** Data frame with conversation metadata (same as `cassidy_list_conversations()` but with better printing)

**Example:**

```r
convs <- cassidy_conversations()
print(convs)
#> # Cassidy Conversations
#> # 
#> # ID                      Title                    Updated              Messages
#> # conv_20260131_143022    Package development      2026-01-31 14:45:33  12
#> # conv_20260131_091544    Data analysis help       2026-01-31 09:23:11  8
#> # conv_20260130_163421    Debugging assistance     2026-01-30 16:52:09  15
```

#### `cassidy_current()`

Show information about the current conversation.

```r
cassidy_current()
```

**Returns:** List with current conversation info, or NULL if no active conversation

**Example:**

```r
cassidy_current()
#> # Current Conversation
#> # 
#> # ID:       conv_20260131_143022
#> # Title:    Package development
#> # Messages: 12
#> # Updated:  2026-01-31 14:45:33
#> # Thread:   thread_abc123xyz
```

#### `cassidy_reset()`

Clear current conversation state (doesn't delete saved conversations).

```r
cassidy_reset()
```

**Returns:** NULL (invisibly), called for side effects

**Example:**

```r
cassidy_reset()
#> ✔ Cleared current conversation state
#> ℹ Use cassidy_chat() to start a new conversation
```

## State Management

### Package Environment

Create a package-level environment to track state:

```r
# In R/chat-console.R
.cassidy_state <- new.env(parent = emptyenv())

# State variables:
# - current_conv_id: Character or NULL
# - current_thread_id: Character or NULL
# - context_sent: Logical
# - last_response: cassidy_response object
```

### State Functions (Internal)

- `.get_current_conv_id()`
- `.set_current_conv_id(conv_id)`
- `.get_current_thread_id()`
- `.set_current_thread_id(thread_id)`
- `.get_context_sent()`
- `.set_context_sent(sent)`
- `.get_last_response()`
- `.set_last_response(response)`
- `.clear_state()`

## Implementation Details

### Conversation Flow Logic

```r
cassidy_chat <- function(message, conversation = NULL, ...) {
  # 1. Determine conversation mode
  if (is.null(conversation)) {
    # Continue current conversation
    conv_id <- .get_current_conv_id()
    if (is.null(conv_id)) {
      # No current conversation, start new
      mode <- "new"
    } else {
      mode <- "continue"
    }
  } else if (conversation == "new") {
    mode <- "new"
  } else {
    # Switch to specific conversation
    mode <- "switch"
    target_conv_id <- conversation
  }
  
  # 2. Handle each mode
  if (mode == "new") {
    # Gather context, create conversation, send context
  } else if (mode == "switch") {
    # Load conversation, update state
  } else {
    # Continue current conversation
  }
  
  # 3. Send message
  # 4. Update state
  # 5. Save conversation
  # 6. Print and return
}
```

### Context Management

- **New conversations:** Auto-gather context based on `context_level`
- **Switched conversations:** Load existing context from saved conversation
- **Continued conversations:** Use existing context (already sent)

### Conversation Switching

When switching conversations:

1. Load conversation from disk using `cassidy_load_conversation(conv_id)`
2. Update package state with new `conv_id` and `thread_id`
3. Optionally refresh context (if conversation was saved a while ago)
4. Continue chatting in that conversation

### Error Handling

- Validate conversation ID exists before switching
- Handle API errors gracefully with helpful messages
- Auto-create new conversation if current one is invalid
- Warn if trying to switch to conversation without `thread_id`

## Migration Strategy

### Supersede Existing Functions

Mark these functions as superseded (not deprecated yet):

- `cassidy_chat()` (old version) → New unified `cassidy_chat()`
- `cassidy_session()` → Use new `cassidy_chat()`
- `cassidy_continue()` → Use new `cassidy_chat()` (auto-continues)
- `chat()` generic → Use new `cassidy_chat()`

Documentation updates:

```r
#' @description
#' `r lifecycle::badge("superseded")`
#' 
#' This function has been superseded by the new unified [cassidy_chat()] 
#' interface, which automatically manages conversation state and provides
#' a simpler console experience. The old function still works but is no
#' longer recommended for new code.
#' 
#' @seealso [cassidy_chat()] for the recommended console interface
```

### Keep These Functions

These remain as-is (different use cases):

- `cassidy_app()` - Shiny interface (different paradigm)
- `cassidy_create_thread()` - Low-level API function
- `cassidy_send_message()` - Low-level API function
- `cassidy_get_thread()` - API function
- `cassidy_list_threads()` - API function
- `cassidy_list_conversations()` - Persistence function (but add `cassidy_conversations()` wrapper)
- `cassidy_export_conversation()` - Persistence function
- `cassidy_delete_conversation()` - Persistence function

## File Structure

### New Files

**R/chat-console.R** - Unified console interface

- Package state environment
- `cassidy_chat()` - Main function
- `cassidy_conversations()` - List with pretty printing
- `cassidy_current()` - Show current conversation
- `cassidy_reset()` - Clear state
- Internal state management functions
- Print method for `cassidy_conversations`

**tests/testthat/test-chat-console.R** - Tests

- Test state management
- Test conversation modes (new/continue/switch)
- Test context gathering
- Test error handling
- Test helper functions

### Modified Files

**R/chat-core.R** - Add lifecycle badges

- Add superseded badges to old functions
- Add seealso links to new `cassidy_chat()`

**_pkgdown.yml** - Update reference

- Add new section for "Console Chat Interface"
- Move superseded functions to "Superseded Functions" section

**NEWS.md** - Document changes

```markdown
# cassidyr (development version)

## New features

* New unified `cassidy_chat()` function provides a simplified console chat
  experience with automatic conversation management and context handling.
  
* Added `cassidy_conversations()`, `cassidy_current()`, and `cassidy_reset()`
  helper functions for managing console chat state.

## Lifecycle changes

* `cassidy_chat()` (old version), `cassidy_session()`, `cassidy_continue()`,
  and `chat()` are now superseded in favor of the new unified `cassidy_chat()`
  interface. The old functions still work but are no longer recommended.
```

## Testing Strategy

### Unit Tests

**State management**

- Test state initialization
- Test state updates
- Test state clearing
- Test state persistence across calls

**Conversation modes**

- Test new conversation creation
- Test continuing conversation
- Test switching conversations
- Test auto-creating when no current conversation

**Context handling**

- Test context gathering for new conversations
- Test context levels (minimal/standard/comprehensive)
- Test `include_data` and `include_files`
- Test context reuse in continued conversations

**Error handling**

- Test invalid conversation ID
- Test missing API credentials
- Test API errors
- Test conversation without `thread_id`

**Helper functions**

- Test `cassidy_conversations()` output
- Test `cassidy_current()` with/without active conversation
- Test `cassidy_reset()`

### Manual Tests

Create `tests/manual/test-console-live.R`:

```r
# Test unified console interface with real API

# Test 1: New conversation
cassidy_chat("What is R?", conversation = "new")

# Test 2: Continue conversation
cassidy_chat("Tell me more")
cassidy_chat("Show an example")

# Test 3: Check current conversation
cassidy_current()

# Test 4: List conversations
convs <- cassidy_conversations()
print(convs)

# Test 5: Start new conversation
cassidy_chat("Different topic", conversation = "new")

# Test 6: Switch back to first conversation
cassidy_chat("Back to R discussion", conversation = convs$id[1])

# Test 7: Reset state
cassidy_reset()
cassidy_current()  # Should be NULL

# Test 8: Context levels
cassidy_chat("Help with package", conversation = "new", context_level = "comprehensive")

# Test 9: Include specific files
cassidy_chat(
  "Review this code",
  conversation = "new",
  include_files = c("R/chat-console.R")
)
```

## Implementation Checklist

- [ ] Create R/chat-console.R with unified interface
- [ ] Implement package state environment
- [ ] Implement `cassidy_chat()` main function
- [ ] Implement `cassidy_conversations()` helper
- [ ] Implement `cassidy_current()` helper
- [ ] Implement `cassidy_reset()` helper
- [ ] Add print method for conversations
- [ ] Create tests/testthat/test-chat-console.R
- [ ] Add lifecycle badges to old functions in R/chat-core.R
- [ ] Update _pkgdown.yml reference structure
- [ ] Update NEWS.md with changes
- [ ] Create tests/manual/test-console-live.R
- [ ] Run `devtools::document()`
- [ ] Run `devtools::test()`
- [ ] Run `devtools::check()`
- [ ] Update README with new examples

## Benefits

### For Users

- **Simpler mental model** - One function does everything
- **Natural conversation flow** - Just keep calling `cassidy_chat()`
- **Automatic state management** - No objects to track
- **Easy conversation switching** - Switch between topics seamlessly
- **Better for console use** - Designed for interactive R sessions

### For Package

- **Cleaner API** - Reduces function proliferation
- **Consistent with app** - Similar parameters to `cassidy_app()`
- **Better discoverability** - One main function to learn
- **Easier to document** - Focused documentation
- **Future-proof** - Can extend without breaking changes

## Future Enhancements

Potential additions after initial implementation:

- **Auto-save intervals** - Save conversation every N messages
- **Conversation search** - Find conversations by content
- **Context refresh** - Automatically refresh context for old conversations
- **Conversation merging** - Combine related conversations
- **Export on exit** - Auto-export conversations when R session ends
- **Conversation tags** - Tag conversations for organization
- **Smart context** - Learn which context is most useful over time

---

**Status:** Ready for implementation  
**Priority:** High - Significantly improves user experience  
**Breaking Changes:** None (backward compatible)  
**Dependencies:** Uses existing infrastructure