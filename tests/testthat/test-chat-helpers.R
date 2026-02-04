# ========================================================================
# .detect_downloadable_files ---------------------------------------------
# ========================================================================

test_that(".detect_downloadable_files finds md code blocks", {
  content <- "Here's your file:\n\n```md\n# Hello\n\nSome content\n```\n\nLet me know!"

  result <- .detect_downloadable_files(content)

  expect_length(result, 1)
  expect_equal(result[[1]]$extension, ".md")
  expect_equal(result[[1]]$filename, "untitled.md")
  expect_true(grepl("# Hello", result[[1]]$content))
})

test_that(".detect_downloadable_files finds markdown code blocks", {
  content <- "```markdown\n# Title\n```"

  result <- .detect_downloadable_files(content)

  expect_length(result, 1)
  expect_equal(result[[1]]$extension, ".md")
})

test_that(".detect_downloadable_files finds qmd code blocks", {
  content <- "```qmd\n---\ntitle: My Doc\nformat: html\n---\n\n# Content\n```"

  result <- .detect_downloadable_files(content)

  expect_length(result, 1)
  expect_equal(result[[1]]$extension, ".qmd")
})

test_that(".detect_downloadable_files finds Rmd code blocks", {
  content <- "```rmd\n---\ntitle: Analysis\noutput: html_document\n---\n\n# Intro\n```"

  result <- .detect_downloadable_files(content)

  expect_length(result, 1)
  expect_equal(result[[1]]$extension, ".Rmd")
})

test_that(".detect_downloadable_files extracts content correctly", {
  file_content <- "# My README\n\nThis is content.\n\n```r\nlibrary(tidyverse)\n```"
  content <- paste0("Here's your file:\n\n```md\n", file_content, "\n```")

  result <- .detect_downloadable_files(content)

  expect_equal(result[[1]]$content, file_content)
})

test_that(".detect_downloadable_files detects YAML title as filename", {
  content <- "```qmd\n---\ntitle: My Analysis Report\nformat: html\n---\n\n# Content\n```"

  result <- .detect_downloadable_files(content)

  expect_equal(result[[1]]$filename, "My_Analysis_Report.qmd")
})

test_that(".detect_downloadable_files returns empty list when no files", {
  content <- "Here's some R code:\n\n```r\nx <- 1\n```\n\nThat's it!"

  result <- .detect_downloadable_files(content)

  expect_length(result, 0)
})

test_that(".detect_downloadable_files returns empty list for NULL input", {
  expect_length(.detect_downloadable_files(NULL), 0)
  expect_length(.detect_downloadable_files(""), 0)
})

test_that(".detect_downloadable_files handles multiple files", {
  content <- "First file:\n\n```md\n# One\n```\n\nSecond:\n\n```qmd\n# Two\n```"

  result <- .detect_downloadable_files(content)

  expect_length(result, 2)
  expect_equal(result[[1]]$extension, ".md")
  expect_equal(result[[2]]$extension, ".qmd")
})

# ========================================================================
# .sanitize_filename -----------------------------------------------------
# ========================================================================

test_that(".sanitize_filename handles special characters", {
  expect_equal(.sanitize_filename("My Report: 2024"), "My_Report_2024")
  expect_equal(.sanitize_filename("file<>name"), "filename")
  expect_equal(.sanitize_filename("  spaces  "), "spaces")
})

test_that(".sanitize_filename limits length", {
  long_title <- paste(rep("a", 100), collapse = "")
  result <- .sanitize_filename(long_title)
  expect_equal(nchar(result), 50)
})

test_that(".sanitize_filename handles empty input", {
  expect_equal(.sanitize_filename(""), "untitled")
  expect_equal(.sanitize_filename("   "), "untitled")
})


# ========================================================================
# ---- .create_download_link_html tests ----------------------------------
# ========================================================================

test_that(".create_download_link_html creates valid HTML", {
  skip_if_not_installed("base64enc")
  skip_if_not_installed("htmltools")

  content <- "# Test\n\nHello world"
  result <- .create_download_link_html(content, "test.md", 1)

  expect_type(result, "character")
  expect_match(result, "file-download-container")
  expect_match(result, 'download="test.md"')
  expect_match(result, "data:text/markdown;base64,")
  expect_match(result, "fa-download")
})

test_that(".create_download_link_html escapes filename", {
  skip_if_not_installed("base64enc")
  skip_if_not_installed("htmltools")

  content <- "test"
  # Filename with special chars
  result <- .create_download_link_html(
    content,
    'file<with>"special.md',
    1
  )

  # Should be escaped
  expect_false(grepl('download="file<', result, fixed = TRUE))
  expect_match(result, "file&lt;with&gt;")
})

test_that(".create_download_link_html handles different extensions", {
  skip_if_not_installed("base64enc")
  skip_if_not_installed("htmltools")

  content <- "test"

  # QMD
  result_qmd <- .create_download_link_html(content, "doc.qmd", 1)
  expect_match(result_qmd, "text/plain")

  # RMD
  result_rmd <- .create_download_link_html(content, "doc.Rmd", 1)
  expect_match(result_rmd, "text/plain")

  # MD
  result_md <- .create_download_link_html(content, "doc.md", 1)
  expect_match(result_md, "text/markdown")
})


# =========================================================================
# .preprocess_nested_code_blocks
# =========================================================================

# tests/testthat/test-chat-helpers.R

test_that(".preprocess_nested_code_blocks handles NULL and empty input", {
  expect_null(.preprocess_nested_code_blocks(NULL))
  expect_equal(.preprocess_nested_code_blocks(""), "")
})

test_that(".preprocess_nested_code_blocks passes through simple content", {
  simple <- "Just some text\nwith multiple lines"
  expect_equal(.preprocess_nested_code_blocks(simple), simple)
})

test_that(".preprocess_nested_code_blocks handles simple code blocks", {
  content <- "Some text\n```r\nx <- 1\n```\nMore text"
  result <- .preprocess_nested_code_blocks(content)
  expect_equal(result, content)
})

# test_that(".preprocess_nested_code_blocks increases fence for nested blocks", {
#   # Markdown block containing R code block
#   content <- paste(
#     "Here's a file:",
#     "```markdown",
#     "# Title",
#     "```r",
#     "x <- 1",
#     "```",
#     "More content",
#     "```",
#     "Done",
#     sep = "\n"
#   )

#   result <- .preprocess_nested_code_blocks(content)

#   # Outer fence should now be ```` (4 backticks)
#   expect_true(grepl("````markdown", result))
#   expect_true(grepl("````\\s*$", result))

#   # Inner fence should remain unchanged
#   expect_true(grepl("```r", result))
# })

test_that(".preprocess_nested_code_blocks handles multiple nested levels", {
  content <- paste(
    "```markdown",
    "# Doc",
    "````r",
    "code",
    "````",
    "```",
    sep = "\n"
  )

  result <- .preprocess_nested_code_blocks(content)

  # Outer should be ````` (5 backticks) to exceed inner ````
  expect_true(grepl("^`{5}markdown", result))
})

test_that(".preprocess_nested_code_blocks handles tilde fences", {
  content <- paste(
    "~~~markdown",
    "# Title",
    "~~~r",
    "x <- 1",
    "~~~",
    "~~~",
    sep = "\n"
  )

  result <- .preprocess_nested_code_blocks(content)

  # Outer fence should be ~~~~ (4 tildes)
  expect_true(grepl("~~~~markdown", result))
})

test_that(".preprocess_nested_code_blocks renders correctly with commonmark", {
  content <- paste(
    "Here's a markdown file:",
    "```markdown",
    "# My Doc",
    "```r",
    "x <- 1",
    "```",
    "End of doc",
    "```",
    "That's it!",
    sep = "\n"
  )

  processed <- .preprocess_nested_code_blocks(content)

  # Should not error
  expect_no_error({
    html <- commonmark::markdown_html(processed)
  })

  # The nested content should appear in a single code block
  html <- commonmark::markdown_html(processed)

  # Should have exactly one <pre> block for the markdown content
  # (not multiple broken blocks)
  pre_count <- length(gregexpr("<pre>", html)[[1]])
  expect_equal(pre_count, 1)
})

test_that(".preprocess_nested_code_blocks preserves non-nested blocks", {
  content <- paste(
    "```r",
    "x <- 1",
    "```",
    "",
    "```python",
    "y = 2",
    "```",
    sep = "\n"
  )

  result <- .preprocess_nested_code_blocks(content)

  # Should be unchanged - no nesting
  expect_equal(result, content)
})
