# Context System Details

## Configuration Files

- Supports CASSIDY.md, .cassidy/CASSIDY.md, and CASSIDY.local.md
- `use_cassidy_md()` creates configuration files with templates
- `cassidy_read_context_file()` reads project and user-level configs
- Automatic loading in `cassidy_app()`
- Modular rules supported in `.cassidy/rules/*.md`

## File Context Tiers (automatic based on size)

- **Full tier** (≤2000 lines total): Complete file contents
- **Summary tier** (2001-5000 lines): Summaries with previews
- **Index tier** (>5000 lines): File listings only
- Request specific files with `[REQUEST_FILE:path]` syntax

## Context Management

- Context sent **once at thread creation** (not per message)
- Incremental context updates (only send new/changed items)
- Automatic refresh when resuming saved conversations
- Support for project, session, Git, data, and file context
- Multiple description methods with automatic fallback

## Token Management

### Token Limits

- **API Limit:** 200,000 tokens (conversation + context + new message)
- **Estimation:** ~3:1 character-to-token ratio for mixed content
- **Safety Buffer:** 15% safety margin by default

### Automatic Token Tracking

Token usage tracked across all interfaces:

- **Console Chat:** `cassidy_chat()` shows warnings at 80%
- **Sessions:** `cassidy_session()` tracks tokens per message
- **Shiny App:** Visual display with color-coded alerts

### Automatic Compaction

`cassidy_session()` provides automatic compaction:

```r
# Enabled by default
session <- cassidy_session(
  auto_compact = TRUE,    # Enable auto-compaction (default)
  compact_at = 0.85       # Trigger at 85% (default)
)

# Compaction happens automatically before hitting limit
# Preserves recent messages, summarizes older ones
```

### Manual Compaction

```r
# Compact at any time
session <- cassidy_compact(session)

# Customize preservation
session <- cassidy_compact(
  session,
  preserve_recent = 3,     # Keep last 3 message pairs
  summary_prompt = "..."   # Custom summarization prompt
)
```

### Token Statistics

```r
# Quick overview
print(session)
#> Shows token usage with percentage

# Detailed diagnostics
stats <- cassidy_session_stats(session)
#> Includes: context tokens, message tokens, tool overhead,
#>           compaction count, timestamps
```

### Timeout Management

- **Detection:** Automatic detection of timeout errors (524)
- **Retry:** Automatic retry with chunking guidance
- **Prevention:** Input size validation warns about large messages
- **Complex Tasks:** Auto-detection and incremental delivery guidance

## Conversation Persistence

- Conversations saved to `tools::R_user_dir("cassidyr", "data")/conversations/`
- Auto-save on message and session end
- Functions: `cassidy_list_conversations()`, `cassidy_export_conversation()`,
  `cassidy_delete_conversation()`

## Memory System

### Purpose

Persistent knowledge storage for workflow state and learned insights that survives conversation compaction.

### Storage Location

- **Directory:** `~/.cassidy/memory/`
- **Format:** Plain text files (markdown recommended)
- **Organization:** Supports subdirectories for organization

### Key Distinction

- **Rules** (`~/.cassidy/rules/`) - Static project instructions, always loaded
- **Memory** (`~/.cassidy/memory/`) - Dynamic state, loaded on demand
- **Skills** (`~/.cassidy/skills/`) - Methodology templates, metadata + on-demand
- **Context** - Current session working memory

### Progressive Disclosure

- **In Context:** Lightweight directory listing (~100 tokens) with file sizes and timestamps
- **On Demand:** Full file contents loaded only when requested via memory tool
- **Format:** Human-readable time ago (e.g., "2h ago", "just now")

### Memory Functions

```r
# List all memory files
cassidy_list_memory_files()
#> Returns data frame: path, size, modified, size_human

# Format for context inclusion
cassidy_format_memory_listing()
#> Returns formatted text (~100 tokens)

# Read file contents
cassidy_read_memory_file("workflow_state.md")

# Write/update file (creates subdirectories automatically)
cassidy_write_memory_file("progress.md", "# Status\n\nPhase 3 complete")

# Delete file
cassidy_delete_memory_file("old_notes.md")

# Rename/move file
cassidy_rename_memory_file("draft.md", "final.md")
cassidy_rename_memory_file("file.md", "archive/file.md")
```

### Security

- **Path validation:** Prevents directory traversal attacks
- **Protections:**
  - Rejects `..` sequences
  - Rejects URL-encoded traversal (`%2e%2e`)
  - Canonical path verification
  - All operations restricted to memory directory

### Integration with Context System

```r
# Memory listing included by default
cassidy_context_project(include_memory = TRUE)  # Default

# Exclude if not needed
cassidy_context_project(include_memory = FALSE)
```

### Memory Tool (Agentic)

Available in `cassidy_agentic_task()` as the `memory` tool:

**Commands:**
- `view` - List all memory files
- `read` - Read specific file content
- `write` - Create or update file
- `delete` - Remove file
- `rename` - Rename or move file

**Example:**
```r
# Assistant can use memory tool automatically
cassidy_agentic_task(
  "Analyze the data and save key insights to memory",
  tools = "all"  # Includes memory tool
)
```

### Use Cases

**Good uses:**
- Workflow state tracking ("Currently on Phase 3...")
- Debugging insights ("Bug traced to X, fixed by Y")
- User preferences ("User prefers verbose explanations")
- Cross-session progress ("Completed api-core.R, next: chat-handlers-*.R")
- Learned knowledge that should persist

**Not for:**
- Static project conventions (use rules)
- Current conversation context (automatic)
- Temporary notes (just chat normally)

### Memory + Compaction

Memory enables unlimited conversation length:

1. Save important state to memory during conversation
2. When conversation compacts, memory persists
3. Continue conversation with access to saved state
4. Resume in future sessions with memory intact

**Example workflow:**
```r
session <- cassidy_session()

# Work on phase 1
chat(session, "Let's implement phase 1...")
# ... many messages ...

# Save progress before moving on
chat(session, "Save our progress to memory:workflow_state.md")

# Continue - auto-compaction happens as needed
chat(session, "Now let's do phase 2...")

# Memory persists across compaction
# Can reference it later: "Check memory:workflow_state.md"
```

## CassidyAI API

### Authentication & Base Configuration

- **Base URL:** `https://app.cassidyai.com/api`
- **Authentication:** Bearer token in Authorization header
- **Environment Variables:**
  - `CASSIDY_API_KEY` - API key
  - `CASSIDY_ASSISTANT_ID` - Assistant ID

### Endpoints

- `POST /assistants/thread/create` - Create thread
- `POST /assistants/message/create` - Send message
- `GET /assistants/thread/get` - Get thread history
- `GET /assistants/threads/get` - List threads

### Retry Logic

- Automatic retry on 429 (rate limit) and 503/504 (server errors)
- Max 3 retries
- 120-second timeout (configurable)
