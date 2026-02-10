# Development Workflow

## Adding a New Function

1. **Choose the right file** based on function purpose:
   - API functions → `api-core.R`
   - Context functions → `context-*.R`
   - Chat UI → `chat-ui*.R`
   - Chat handlers → `chat-handlers-*.R`
   - Utilities → `utils.R` or `context-tools.R`

2. Write function with roxygen2 documentation
   - Include `@export` for public functions
   - Use `@keywords internal` for internal helpers

3. Update imports if using new packages:
   - Add package::function calls in code
   - Run `source("R/xyz.R")` then `update_package_imports(dry_run = FALSE)`
   - Run `devtools::document()` to update NAMESPACE

4. Write tests in corresponding `tests/testthat/test-*.R`
5. Add example to manual test file if needed
6. Update README/CASSIDY.md if it's a major feature

## Testing Workflow

- Run all tests: `devtools::test()`
- Run specific test file: `devtools::test_active_file()`
- Check package: `devtools::check()`
- Manual testing: `source("tests/manual/test-context-live.R")`
- Live chat testing: `cassidy_app()` with your own API key

## Working with Modular Structure

### Chat Handlers
When adding new Shiny handlers, add them to the appropriate file:
- Message sending logic → `chat-handlers-message.R`
- Conversation management → `chat-handlers-conversation.R`
- Context application → `chat-handlers-context-apply.R`
- Data frame handlers → `chat-handlers-context-data.R`
- File handlers → `chat-handlers-context-files.R`

### Context System
When extending context capabilities:
- New context sources → Create new `context-*.R` file
- Parsing/formatting → `context-file-parse.R` or `context-tools.R`
- Context gathering logic → `chat-context-gather.R`

## Code Review Checklist

Before finalizing any new code:

- [ ] Function follows naming conventions (`cassidy_*` prefix)
- [ ] All parameters documented with @param
- [ ] @return value described
- [ ] @examples provided (with `\dontrun{}` for API calls)
- [ ] Tests pass with `devtools::test()`
- [ ] No hardcoded credentials or sensitive data
- [ ] Error handling implemented with helpful messages
- [ ] Works without optional dependencies (graceful fallbacks)
- [ ] Documentation renders correctly with `devtools::document()`
- [ ] Package passes `devtools::check()` with no errors or warnings
