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

## Conversation Persistence

- Conversations saved to `tools::R_user_dir("cassidyr", "data")/conversations/`
- Auto-save on message and session end
- Functions: `cassidy_list_conversations()`, `cassidy_export_conversation()`,
  `cassidy_delete_conversation()`

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
