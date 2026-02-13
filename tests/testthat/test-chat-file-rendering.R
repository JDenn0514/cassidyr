test_that("extract_and_replace_file_blocks detects md files", {
  content <- '
Here is your file:

```md
# My Document
Hello world
```

That was the file.
'

  result <- cassidyr:::.extract_and_replace_file_blocks(content)

  expect_length(result$files, 1)
  expect_equal(result$files[[1]]$extension, ".md")
  expect_match(result$files[[1]]$content, "# My Document")
  expect_match(result$processed_content, "\\{\\{CASSIDY_FILE_BLOCK_")
})

test_that("extract_and_replace_file_blocks handles qmd files", {
  content <- '
```qmd
---
title: "Test"
---

Content here
```
'

  result <- cassidyr:::.extract_and_replace_file_blocks(content)

  expect_length(result$files, 1)
  expect_equal(result$files[[1]]$extension, ".qmd")
  expect_match(result$files[[1]]$content, "title:")
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

  result <- cassidyr:::.extract_and_replace_file_blocks(content)
  file_content <- result$files[[1]]$content

  # Should contain raw chunk markers
  expect_match(file_content, "```\\{r\\}", fixed = FALSE)
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

  result <- cassidyr:::.extract_and_replace_file_blocks(content)
  expect_length(result$files, 2)
  expect_equal(result$files[[1]]$extension, ".md")
  expect_equal(result$files[[2]]$extension, ".qmd")
})

test_that("extract_and_replace_file_blocks handles empty content", {
  result <- cassidyr:::.extract_and_replace_file_blocks("")
  expect_equal(result$processed_content, "")
  expect_length(result$files, 0)

  result2 <- cassidyr:::.extract_and_replace_file_blocks(NULL)
  expect_null(result2$processed_content)
  expect_length(result2$files, 0)
})

test_that("create_file_display_block generates valid HTML", {
  skip_if_not_installed("base64enc")
  skip_if_not_installed("htmltools")

  content <- "# Test\nHello world"
  filename <- "test.md"
  extension <- ".md"

  html <- cassidyr:::.create_file_display_block(content, filename, extension)

  # Check for key HTML elements
  expect_match(html, "cassidy-file-block")
  expect_match(html, "file-header")
  expect_match(html, "file-content")
  expect_match(html, filename)
  expect_match(html, "copy-file-btn")
  expect_match(html, "download-file-btn")
})

test_that("render_message_with_file_blocks preserves non-file content", {
  content <- '
This is regular markdown text.

## Heading

Some code:

```r
x <- 1
```

More text.
'

  result <- cassidyr:::.render_message_with_file_blocks(content)

  # Should render as normal markdown
  expect_match(result, "<h2>")
  expect_match(result, "regular markdown")
  expect_match(result, "language-r")  # Code block should have language class
})

test_that("render_message_with_file_blocks transforms file blocks", {
  skip_if_not_installed("base64enc")
  skip_if_not_installed("htmltools")

  content <- '
Here is a file:

```md
# My File
Content
```

Done!
'

  result <- cassidyr:::.render_message_with_file_blocks(content)

  # Should contain file block HTML
  expect_match(result, "cassidy-file-block")
  expect_match(result, "file-header")
  # Should NOT contain the placeholder text
  expect_false(grepl("CASSIDY_FILE_BLOCK_", result, fixed = TRUE))
  # Should contain the actual content in raw form
  expect_match(result, "# My File")
})

test_that("render_message_with_file_blocks handles mixed content", {
  skip_if_not_installed("base64enc")
  skip_if_not_installed("htmltools")

  content <- '
Some text before.

```md
# File 1
Content 1
```

Text between files.

```qmd
# File 2
Content 2
```

Text after.
'

  result <- cassidyr:::.render_message_with_file_blocks(content)

  # Should have two file blocks
  expect_equal(
    length(gregexpr("cassidy-file-block", result, fixed = TRUE)[[1]]),
    2
  )

  # Should have regular text rendered
  expect_match(result, "Some text before")
  expect_match(result, "Text between")
  expect_match(result, "Text after")
})

test_that("file blocks use correct icons", {
  skip_if_not_installed("base64enc")
  skip_if_not_installed("htmltools")

  md_html <- cassidyr:::.create_file_display_block("test", "test.md", ".md")
  qmd_html <- cassidyr:::.create_file_display_block("test", "test.qmd", ".qmd")
  rmd_html <- cassidyr:::.create_file_display_block("test", "test.Rmd", ".Rmd")

  # All should have file icons (emojis)
  expect_match(md_html, "file-icon")
  expect_match(qmd_html, "file-icon")
  expect_match(rmd_html, "file-icon")
})
