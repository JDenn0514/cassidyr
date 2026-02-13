# Manual Test: File Rendering in cassidy_app()
#
# This file contains test scenarios for the new file rendering enhancement.
# Run these tests interactively with the actual Shiny app to verify the UI.

library(cassidyr)

# ------------------------------------------------------------------------------
# Test Setup
# ------------------------------------------------------------------------------

# Ensure you have API credentials set up
if (!nzchar(Sys.getenv("CASSIDY_API_KEY"))) {
  stop("Please set CASSIDY_API_KEY environment variable")
}

if (!nzchar(Sys.getenv("CASSIDY_ASSISTANT_ID"))) {
  stop("Please set CASSIDY_ASSISTANT_ID environment variable")
}

# ------------------------------------------------------------------------------
# Test 1: Simple Markdown File
# ------------------------------------------------------------------------------

# Launch the app
cassidy_app()

# In the chat, send this message:
# "Create a simple markdown document about data analysis best practices"

# Expected behavior:
# 1. File content displayed in a styled block with header
# 2. File icon (📄) visible in header
# 3. Filename shown in blue monospace font
# 4. Copy and Download buttons in header
# 5. Content shown as raw text (not rendered HTML)
# 6. Max height 500px with scroll if content is long

# ------------------------------------------------------------------------------
# Test 2: Quarto Document with R Chunks
# ------------------------------------------------------------------------------

# In the chat, send this message:
# "Create a Quarto document analyzing the mtcars dataset with multiple R chunks"

# Expected behavior:
# 1. File displays with appropriate icon (📊)
# 2. R code chunks (```{r}) are visible as raw text, not executed
# 3. YAML front matter preserved
# 4. Copy button copies entire file content
# 5. Download button downloads the .qmd file

# ------------------------------------------------------------------------------
# Test 3: R Markdown with Nested Chunks
# ------------------------------------------------------------------------------

# In the chat, send this message:
# "Create an R Markdown report with setup chunk, data loading, and plots"

# Expected behavior:
# 1. File displays with chart icon (📈)
# 2. All R chunks preserved as ```{r} blocks
# 3. Chunk options (e.g., #| label:) visible
# 4. No rendering of nested markdown inside chunks
# 5. File can be downloaded and opened in RStudio

# ------------------------------------------------------------------------------
# Test 4: Multiple Files in One Response
# ------------------------------------------------------------------------------

# In the chat, send this message:
# "Create both a README.md and a simple analysis.qmd file for a new project"

# Expected behavior:
# 1. Two separate file blocks displayed
# 2. Each with its own header and buttons
# 3. Correct icons for each file type
# 4. Both files can be downloaded independently
# 5. Copy works correctly for each file

# ------------------------------------------------------------------------------
# Test 5: Mixed Content (Text + File)
# ------------------------------------------------------------------------------

# In the chat, send this message:
# "Explain the importance of reproducible research, then create a template.qmd"

# Expected behavior:
# 1. Regular text rendered normally (with formatting)
# 2. File block clearly separated from text
# 3. Visual distinction between explanation and file
# 4. Both parts visible and properly formatted

# ------------------------------------------------------------------------------
# Test 6: Large File (>500px content)
# ------------------------------------------------------------------------------

# In the chat, send this message:
# "Create a comprehensive R Markdown tutorial with 10+ sections and code examples"

# Expected behavior:
# 1. File block has scroll bar (max-height: 500px)
# 2. Content is scrollable within the block
# 3. Header stays visible while scrolling content
# 4. Copy button copies entire content (even scrolled parts)

# ------------------------------------------------------------------------------
# Test 7: Copy Button Functionality
# ------------------------------------------------------------------------------

# Steps:
# 1. Ask AI to create any .md/.qmd/.Rmd file
# 2. Click the Copy button
# 3. Button should show checkmark and "Copied!" briefly
# 4. Paste into a text editor
# 5. Verify pasted content matches displayed content exactly

# ------------------------------------------------------------------------------
# Test 8: Download Button Functionality
# ------------------------------------------------------------------------------

# Steps:
# 1. Ask AI to create a file with specific filename in YAML (e.g., "my-analysis")
# 2. Click the Download button
# 3. File should download with correct name and extension
# 4. Open downloaded file in text editor
# 5. Verify content matches displayed content

# ------------------------------------------------------------------------------
# Test 9: File Block Styling
# ------------------------------------------------------------------------------

# Visual checks:
# 1. File block has distinct border and background
# 2. Header bar has gray background
# 3. Content area has white background
# 4. Buttons are properly styled and hover effects work
# 5. File name is in blue monospace font
# 6. Icons display correctly

# ------------------------------------------------------------------------------
# Test 10: Backwards Compatibility
# ------------------------------------------------------------------------------

# Test that old conversations still work:
# 1. Load an existing conversation (if you have one saved)
# 2. Verify old messages render correctly
# 3. Send a new message requesting a file
# 4. Verify new file rendering works in old conversation

# ------------------------------------------------------------------------------
# Test 11: Edge Cases
# ------------------------------------------------------------------------------

# Test edge cases:
# 1. Empty file content
# 2. File with only whitespace
# 3. File with special characters in content
# 4. File with very long lines (>200 characters)
# 5. File with emojis or Unicode characters

# Example messages:
# "Create an empty markdown file"
# "Create a file with a very long line of text without any breaks"
# "Create a markdown file with emojis and special characters"

# ------------------------------------------------------------------------------
# Test 12: Regular Code Blocks (Not Files)
# ------------------------------------------------------------------------------

# Send this message:
# "Show me an example R function for calculating mean"

# Expected behavior:
# 1. Regular code block (without filename) renders normally
# 2. Code block has copy button (existing functionality)
# 3. NOT rendered as a file block
# 4. No download button

# ------------------------------------------------------------------------------
# Validation Checklist
# ------------------------------------------------------------------------------

# After running tests, verify:
# ✓ All file types (.md, .qmd, .Rmd) display correctly
# ✓ File content is raw (not rendered as HTML)
# ✓ Nested R chunks are preserved
# ✓ Copy button works
# ✓ Download button works
# ✓ File icons display correctly
# ✓ Multiple files in one message work
# ✓ Mixed content (text + file) displays properly
# ✓ Large files are scrollable
# ✓ Regular code blocks still work normally
# ✓ No errors in browser console
# ✓ Mobile responsive (if applicable)

# ------------------------------------------------------------------------------
# Cleanup
# ------------------------------------------------------------------------------

# After testing:
# - Close the Shiny app
# - Review browser console for any JavaScript errors
# - Check that downloaded files are valid
# - Verify copied content pastes correctly
