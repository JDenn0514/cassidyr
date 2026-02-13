# File Rendering Enhancement Plan
## Improving Markdown/Qmd/Rmd File Handling in cassidy_app()

**Date:** 2026-02-12
**Status:** Planning Phase
**Target Files:** chat-helpers.R, chat-handlers-message.R, agentic-tools.R

---

## Problem Statement

### Current Issues

1. **Nested Markdown Rendering**
   - When the AI creates a `.md`, `.qmd`, or `.Rmd` file in a code block, the content gets rendered as HTML by `commonmark::markdown_html()`
   - This causes nested chunk issues (R code chunks inside qmd files get processed incorrectly)
   - Example: A qmd file containing ` ```{r} ` chunks gets mangled during rendering

2. **No Clear File Boundaries**
   - Files embedded in responses lack visual indicators showing where they begin and end
   - Users can't easily distinguish between "AI explanation" and "file content"

3. **Inconsistent Agentic System Parsing**
   - The `write_file` tool receives content but has no standardized way to extract file content from AI responses
   - No guarantee that file content extracted matches what user sees in UI

4. **Download Button Positioning**
   - Download buttons exist but appear below rendered markdown (not next to raw code)
   - Creates visual disconnect between "this is a file" and "download this file"

---

## Root Cause Analysis

### Current Flow

```
AI Response with .md file
    ↓
.detect_downloadable_files() extracts file (✓ works)
    ↓
commonmark::markdown_html() renders ENTIRE message (✗ problem)
    ↓
Download button added at bottom (✓ works but disconnected)
```

**The Issue:** The file content gets rendered as HTML BEFORE we can prevent it.

### Current Code Locations

- **Detection:** `chat-helpers.R:240-321` - `.detect_downloadable_files()`
- **Rendering:** `chat-handlers-message.R:34-36` - `commonmark::markdown_html()`
- **Preprocessing:** `chat-helpers.R:464-544` - `.preprocess_nested_code_blocks()`
- **Download Links:** `chat-helpers.R:417-452` - `.create_download_link_html()`

---

## Proposed Solution

### 1. Custom Rendering System for File Blocks

**Approach:** Create a two-pass rendering system:
1. **First Pass:** Extract and replace file blocks with placeholders
2. **Second Pass:** Render remaining markdown, then insert file blocks as raw code

#### New Function: `.extract_and_replace_file_blocks()`

```r
#' Extract file blocks and replace with placeholders
#'
#' Scans markdown for code blocks tagged as md/qmd/rmd files,
#' extracts them, and replaces with unique placeholders.
#'
#' @param content Character. Raw markdown content
#' @return List with:
#'   - processed_content: Content with placeholders
#'   - files: List of extracted file info (content, lang, filename, placeholder_id)
#' @keywords internal
.extract_and_replace_file_blocks <- function(content) {
  files <- list()
  processed_content <- content

  # Pattern: ```md or ```qmd or ```rmd (case insensitive)
  # Match entire block including fences

  # For each match:
  #   1. Extract file content
  #   2. Generate unique placeholder: ___FILE_BLOCK_1___
  #   3. Replace block with placeholder
  #   4. Store file info with placeholder_id

  # Return:
  list(
    processed_content = processed_content,
    files = files  # Each with: content, extension, filename, placeholder_id
  )
}
```

#### New Function: `.render_message_with_file_blocks()`

```r
#' Render message preserving file blocks as raw code
#'
#' Two-pass rendering:
#' 1. Extract file blocks → placeholders
#' 2. Render markdown (placeholders preserved)
#' 3. Replace placeholders with styled code blocks + download buttons
#'
#' @param content Character. Raw markdown message
#' @return Character. HTML with proper file rendering
#' @keywords internal
.render_message_with_file_blocks <- function(content) {
  # Pass 1: Extract files
  extracted <- .extract_and_replace_file_blocks(content)

  # Pass 2: Render markdown (without files)
  rendered_html <- commonmark::markdown_html(
    .preprocess_nested_code_blocks(extracted$processed_content)
  )

  # Pass 3: Replace placeholders with styled file blocks
  for (file_info in extracted$files) {
    file_html <- .create_file_display_block(
      content = file_info$content,
      filename = file_info$filename,
      extension = file_info$extension
    )

    rendered_html <- gsub(
      file_info$placeholder_id,
      file_html,
      rendered_html,
      fixed = TRUE
    )
  }

  rendered_html
}
```

#### New Function: `.create_file_display_block()`

```r
#' Create styled HTML block for file content
#'
#' Renders file as:
#' - Header bar with filename + download button
#' - Raw code block (NOT rendered markdown)
#' - Copy button for code
#'
#' @param content Character. File content
#' @param filename Character. Filename for display
#' @param extension Character. File extension (.md, .qmd, .Rmd)
#' @return Character. HTML string
#' @keywords internal
.create_file_display_block <- function(content, filename, extension) {
  # Use base64enc if available, otherwise fallback
  has_base64 <- rlang::is_installed("base64enc")

  # HTML structure:
  # <div class="cassidy-file-block">
  #   <div class="file-header">
  #     <span class="file-icon">📄</span>
  #     <span class="file-name">analysis.qmd</span>
  #     <div class="file-actions">
  #       <button class="copy-file-btn">Copy</button>
  #       <a href="data:..." download="...">Download</a>
  #     </div>
  #   </div>
  #   <pre class="file-content"><code>raw content here</code></pre>
  # </div>

  # Key: Use <pre><code> for raw display, NOT commonmark rendering
}
```

### 2. Updated CSS Styles

Add to `chat-css.R`:

```css
/* ===== FILE DISPLAY BLOCKS ===== */
.cassidy-file-block {
  margin: 1rem 0;
  border: 1px solid #dee2e6;
  border-radius: 6px;
  overflow: hidden;
  background-color: #f8f9fa;
}

.file-header {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.5rem 0.75rem;
  background-color: #e9ecef;
  border-bottom: 1px solid #dee2e6;
}

.file-icon {
  font-size: 1.2rem;
}

.file-name {
  font-weight: 600;
  font-family: 'Courier New', monospace;
  color: #0d6efd;
  flex: 1;
}

.file-actions {
  display: flex;
  gap: 0.5rem;
}

.copy-file-btn,
.download-file-btn {
  padding: 0.25rem 0.75rem;
  font-size: 0.85rem;
  border-radius: 4px;
  cursor: pointer;
}

.file-content {
  margin: 0;
  padding: 1rem;
  background-color: #fff;
  border: none;
  overflow-x: auto;
  max-height: 500px;  /* Prevent huge files from dominating UI */
  overflow-y: auto;
}

.file-content code {
  font-family: 'Monaco', 'Menlo', 'Courier New', monospace;
  font-size: 0.9rem;
  color: #333;
  white-space: pre;
  display: block;
}
```

### 3. Enhanced Agentic System Integration

#### Update `.parse_tool_decision()` in `agentic-workflow.R`

Currently, the agentic system parses `<TOOL_DECISION>` blocks but doesn't have a standard way to extract file content.

**Add New Function:** `.extract_file_content_from_response()`

```r
#' Extract file content from AI response for write_file tool
#'
#' Looks for file blocks in the same format as chat UI:
#' - ```md, ```qmd, ```rmd code blocks
#' - Extracts raw content (not rendered)
#' - Returns content ready for write_file tool
#'
#' @param response Character. AI response text
#' @param filepath Character. Intended file path (for validation)
#' @return Character. Extracted file content, or NULL if not found
#' @keywords internal
.extract_file_content_from_response <- function(response, filepath) {
  # Use same detection logic as .extract_and_replace_file_blocks()
  # But instead of creating placeholders, just return raw content

  # This ensures consistency between:
  # 1. What user sees in chat UI
  # 2. What gets written to disk via agentic write_file
}
```

#### Update `write_file` Tool Handler

```r
write_file = list(
  description = "Write content to a file",
  risky = TRUE,
  parameters = list(
    filepath = "Path to the file to write",
    content = "Content to write (or 'extract_from_response')",
    working_dir = "Working directory (optional)"
  ),
  handler = function(filepath, content, working_dir = getwd(),
                     .full_response = NULL) {  # NEW: pass full response

    # If content is sentinel value, extract from response
    if (content == "extract_from_response" && !is.null(.full_response)) {
      extracted <- .extract_file_content_from_response(.full_response, filepath)
      if (!is.null(extracted)) {
        content <- extracted
      } else {
        stop("Could not extract file content from response")
      }
    }

    # ... rest of existing write_file logic ...
  }
)
```

### 4. Prompt Engineering Guidance

Update the system prompt in `cassidy_agentic_task()` to encourage consistent file formatting:

```
When creating markdown (.md), Quarto (.qmd), or R Markdown (.Rmd) files:

1. Use code fences with language tag:
   ```md
   # Your Markdown Here
   ```

2. Place complete file in single code block
3. Include YAML front matter if applicable
4. Use {r} chunks for Quarto/Rmd (will be preserved as raw text)

Example:
```qmd
---
title: "Analysis Report"
format: html
---

# Introduction

This report analyzes...

```{r}
#| label: setup
library(tidyverse)
```

# Results

...
```
```

---

## Implementation Phases

### Phase 1: Core Rendering (High Priority)

**Files to Modify:**
- `R/chat-helpers.R` - Add 3 new functions
- `R/chat-handlers-message.R` - Replace `commonmark::markdown_html()` call
- `R/chat-css.R` - Add new CSS for file blocks

**Testing:**
- Manual test: Ask AI to create sample .qmd file
- Verify raw content displayed (not rendered)
- Verify download button works
- Test nested chunks render correctly

### Phase 2: Agentic Integration (Medium Priority)

**Files to Modify:**
- `R/agentic-tools.R` - Update `write_file` handler
- `R/agentic-workflow.R` - Add extraction helper

**Testing:**
- Test agentic task: "Create analysis.qmd file"
- Verify file written matches UI display
- Test with nested R chunks

### Phase 3: Enhanced UX (Low Priority)

**Potential Enhancements:**
- Syntax highlighting for file content (using Shiny's built-in highlighter)
- Collapsible file blocks for long files
- "Open in RStudio" button (if rstudioapi available)
- File type icons based on extension

---

## Alternative Approaches Considered

### Option A: Custom Markdown Processor (REJECTED)
- Write own markdown → HTML converter
- **Pros:** Full control over rendering
- **Cons:** Reinventing wheel, maintenance burden, missing commonmark features

### Option B: Post-Processing HTML (REJECTED)
- Let commonmark render everything, then parse HTML to extract file blocks
- **Pros:** Uses existing renderer
- **Cons:** Fragile (HTML structure may vary), harder to reverse render

### Option C: Two-Pass with Placeholders (RECOMMENDED ✓)
- Extract files before rendering, insert after
- **Pros:** Clean separation, preserves raw content, extensible
- **Cons:** Slightly more complex, but manageable

**Decision:** Option C provides best balance of maintainability and functionality.

---

## Testing Strategy

### Unit Tests (testthat)

**File:** `tests/testthat/test-chat-file-rendering.R`

```r
test_that("extract_and_replace_file_blocks detects md files", {
  content <- '
Here is your file:

```md
# My Document
Hello world
```

That was the file.
'

  result <- .extract_and_replace_file_blocks(content)

  expect_length(result$files, 1)
  expect_equal(result$files[[1]]$extension, ".md")
  expect_match(result$files[[1]]$content, "# My Document")
  expect_match(result$processed_content, "___FILE_BLOCK_")
})

test_that("nested chunks preserved in qmd files", {
  content <- '
```qmd
---
title: "Test"
---

```{r}
x <- 1
```
```

'

  result <- .extract_and_replace_file_blocks(content)
  file_content <- result$files[[1]]$content

  # Should contain raw chunk markers
  expect_match(file_content, "```\\{r\\}")
  expect_match(file_content, "x <- 1")
})

test_that("multiple files handled correctly", {
  content <- '
First file:
```md
# Doc 1
```

Second file:
```qmd
# Doc 2
```
'

  result <- .extract_and_replace_file_blocks(content)
  expect_length(result$files, 2)
})
```

### Integration Tests (manual)

**File:** `tests/manual/test-file-rendering-live.R`

```r
# Test file rendering in cassidy_app()

# 1. Start app
cassidy_app()

# 2. Test cases:
# - "Create a simple markdown document about data analysis"
# - "Create a Quarto document with R chunks for analyzing mtcars"
# - "Create an R Markdown report with multiple code chunks"

# 3. Verify:
# - Files display as raw code (not rendered HTML)
# - Download buttons work
# - Copy buttons work
# - Nested chunks visible and correct
```

---

## Risk Assessment

### Low Risk
- ✅ Modifying rendering logic (well-isolated code)
- ✅ Adding CSS (non-breaking)
- ✅ Unit testable functions

### Medium Risk
- ⚠️ Regex patterns for file detection (edge cases)
  - **Mitigation:** Comprehensive unit tests, fallback to current behavior
- ⚠️ Large file content (performance/memory)
  - **Mitigation:** Max height CSS, lazy rendering for large files

### High Risk
- ❌ Breaking existing message rendering
  - **Mitigation:** Extensive testing, gradual rollout, feature flag option

---

## Success Criteria

**Must Have:**
1. ✅ `.md`, `.qmd`, `.Rmd` files display as raw code (not rendered HTML)
2. ✅ Download buttons appear with file header
3. ✅ Nested R chunks in qmd/Rmd preserved correctly
4. ✅ No breaking changes to existing message rendering

**Nice to Have:**
5. ⭐ Copy button for file content
6. ⭐ Syntax highlighting (if feasible)
7. ⭐ Agentic system uses same extraction logic

**Future Enhancements:**
8. 🔮 Multiple file formats (HTML, JSON, CSV preview)
9. 🔮 Collapsible file blocks
10. 🔮 IDE integration (open in RStudio)

---

## Open Questions

1. **Should we support other file types?**
   - Currently targeting .md/.qmd/.Rmd
   - Could extend to .R, .html, .css, .json, etc.
   - Decision: Start with markdown variants, add others if requested

2. **How to handle very large files (>1000 lines)?**
   - Option A: Truncate with "show more" button
   - Option B: Max height with scroll
   - Option C: Collapse by default
   - Decision: Max height (500px) with scroll (simple, CSS-only)

3. **Should files be syntax highlighted?**
   - Pros: Better UX, easier to read
   - Cons: Adds dependency, complexity
   - Decision: Phase 3 enhancement (not MVP)

4. **What if AI creates file without proper fences?**
   - Fallback to current behavior (render as markdown)
   - Add warning message: "File detected but not in proper format"
   - Decision: Implement fallback + warning

---

## References

**Current Implementation:**
- `.detect_downloadable_files()` - chat-helpers.R:240-321
- `.preprocess_nested_code_blocks()` - chat-helpers.R:464-544
- `setup_message_renderer()` - chat-handlers-message.R:3-79

**Related Issues:**
- Commonmark nested code block handling
- Base64 encoding for download links (chat-helpers.R:419)
- File tree rendering (chat-utils.R) - similar pattern

**Testing Patterns:**
- ellmer testing approach (mentioned in roadmap.md)
- Manual testing for API calls (tests/manual/)

---

## Next Steps

1. **Review Plan** - Get feedback on approach
2. **Prototype Phase 1** - Implement core rendering functions
3. **Manual Test** - Verify with real AI-generated files
4. **Unit Tests** - Add comprehensive test coverage
5. **Phase 2 & 3** - If Phase 1 successful, proceed with agentic integration

---

## Notes for Implementation

### Key Design Principles
- **Fail Gracefully** - If file detection fails, fall back to current rendering
- **Preserve Raw Content** - Never modify user's file content during display
- **Visual Clarity** - Make it obvious what is a file vs. AI explanation
- **Consistency** - Same extraction logic for UI and agentic system

### Code Style Reminders
- Use `paste0()` not `sprintf()`
- Follow tidyverse naming (snake_case)
- Internal helpers use `.` prefix
- Add `@keywords internal` and `@noRd` for unexported functions
- Run `update_package_imports()` after adding dependencies
