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
