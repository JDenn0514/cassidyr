# Testing Standards & Style Guide

## Testing Approach

- **testthat 3e** for all tests
- **Simplified testing approach** (not httptest2):
  - Unit tests validate R code logic without API calls
  - Mocking used sparingly (only when needed)
  - Manual tests verify real API integration
  - CRAN-compatible (no required API credentials)

## Test Structure

- Use `withr::with_tempdir()` for file operations
- Use `skip_if()` for environment-dependent tests
- Use `skip_on_cran()` for system command tests
- Test error handling and edge cases

## Important Testing Rules

- **Don't test cli output text directly**
  - cli functions write to stderr, not stdout
  - Use `expect_no_error()` instead of `expect_output()` for cli messages
  - Test structure and behavior, not exact formatting

## Code Style

- Follow tidyverse style guide
- Use `paste0()` for string concatenation (not `sprintf()`)
- Prefer `|>` pipe for R >= 4.1 examples
- Maximum line length: 80 characters
- Use meaningful variable names
- Comment complex logic

## Dependencies

- **Minimize dependencies** where reasonable
- Current imports:
  - httr2 (>= 1.0.0) - HTTP requests
  - cli (>= 3.6.0) - User interface
  - rlang (>= 1.1.0) - Programming tools
  - shiny - Chat UI
  - bslib - Modern theming
  - S7 - OOP for ConversationManager
  - commonmark - Render chat messages
  - skimr (for data summaries)
  - fs - For file system operations
  - gert (for Git operations)
- Suggested packages:
  - testthat (>= 3.0.0)
  - withr
  - rstudioapi
- Prefer base R for simple operations

## Common Pitfalls to Avoid

1. **Don't use `sprintf()`** - use paste0() instead
2. **Don't test cli output directly** - test structure/behavior instead
3. **Don't use `.format_num()` inside cli strings** - format values first
4. **Don't forget `skip_on_cran()`** for system commands
5. **Don't make git tests strict** - git behavior varies by environment
6. **Always use `suppressMessages()`** around `use_cassidy_md()` in tests
7. **Don't forget to update imports** - run `update_package_imports()` after adding package:: calls
8. **Keep handlers modular** - put new Shiny handlers in appropriate chat-handlers-*.R file
9. **Test file tree rendering** - ensure file paths are preserved correctly through nested folders
10. **Watch context size** - tiered file context prevents API limits from being exceeded

## Documentation Standards

- **roxygen2 with markdown** (@md in DESCRIPTION)
- All exported functions must have:
  - Complete parameter documentation
  - @return descriptions
  - @examples (with `\dontrun{}` for API calls)
  - @export tag for public functions
- Use markdown formatting in documentation
- Link related functions with @seealso
- Include usage examples that are realistic
