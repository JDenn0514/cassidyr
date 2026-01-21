# tests/testthat/test-context-project.R

# Test cassidy_context_project ------------------------------------------------

test_that("cassidy_context_project returns valid structure", {
  ctx <- cassidy_context_project(level = "minimal")

  expect_s3_class(ctx, "cassidy_context")
  expect_type(ctx$text, "character")
  expect_type(ctx$level, "character")
  expect_type(ctx$parts, "character")
  expect_equal(ctx$level, "minimal")
})

test_that("cassidy_context_project respects level parameter", {
  minimal <- cassidy_context_project(level = "minimal")
  standard <- cassidy_context_project(level = "standard")
  comprehensive <- cassidy_context_project(level = "comprehensive")

  expect_equal(minimal$level, "minimal")
  expect_equal(standard$level, "standard")
  expect_equal(comprehensive$level, "comprehensive")

  # Comprehensive should have more content
  expect_gte(nchar(comprehensive$text), nchar(minimal$text))
})

test_that("cassidy_context_project respects max_size", {
  ctx <- cassidy_context_project(max_size = 100)

  # Should be at or near max_size (with some margin for truncation message)
  expect_lte(nchar(ctx$text), 150)
})

test_that("cassidy_context_project include_config works", {
  # Create a temporary config file
  withr::with_tempdir({
    writeLines(c("# Test Config", "Test content"), "cassidy.md")

    ctx_with <- cassidy_context_project(include_config = TRUE)
    ctx_without <- cassidy_context_project(include_config = FALSE)

    # Config should be in parts when included
    expect_true("config" %in% ctx_with$parts)
    expect_false("config" %in% ctx_without$parts)
  })
})

test_that("print.cassidy_context works and returns invisibly", {
  ctx <- cassidy_context_project(level = "minimal")

  # Test structure
  expect_s3_class(ctx, "cassidy_context")
  expect_true(all(c("text", "level", "parts") %in% names(ctx)))

  # Test that it prints something (the actual context text)
  expect_output(print(ctx), "R Session Information")

  # Test that print returns invisibly
  expect_invisible(print(ctx))
})

# Test cassidy_describe_files --------------------------------------------------

test_that("cassidy_describe_files handles empty directory", {
  withr::with_tempdir({
    result <- cassidy_describe_files()

    expect_type(result, "character")
    expect_match(result, "No files found|R scripts: 0")
  })
})

test_that("cassidy_describe_files counts file types correctly", {
  withr::with_tempdir({
    # Create test files
    writeLines("# R code", "test1.R")
    writeLines("# R code", "test2.R")
    writeLines("# Rmd", "analysis.Rmd")
    writeLines("data", "data.csv")

    result <- cassidy_describe_files()

    expect_match(result, "R scripts: 2")
    expect_match(result, "R Markdown files: 1")
    expect_match(result, "Data files: 1")
  })
})

test_that("cassidy_describe_files detects directories", {
  withr::with_tempdir({
    dir.create("R")
    dir.create("data")
    dir.create("tests")
    writeLines("# code", "R/utils.R")

    result <- cassidy_describe_files()

    expect_match(result, "Key directories:")
    expect_match(result, "R")
    expect_match(result, "data")
    expect_match(result, "tests")
  })
})

test_that("cassidy_describe_files detects package structure", {
  withr::with_tempdir({
    # Create minimal DESCRIPTION file
    desc <- c(
      "Package: testpkg",
      "Title: Test Package",
      "Version: 0.1.0"
    )
    writeLines(desc, "DESCRIPTION")

    result <- cassidy_describe_files()

    expect_match(result, "Package name: testpkg")
  })
})

test_that("cassidy_describe_files detailed parameter works", {
  withr::with_tempdir({
    writeLines("# R code", "test.R")

    basic <- cassidy_describe_files(detailed = FALSE)
    detailed <- cassidy_describe_files(detailed = TRUE)

    # Detailed should have more content
    expect_gte(nchar(detailed), nchar(basic))
  })
})

# Test cassidy_context_git ----------------------------------------------------

test_that("cassidy_context_git returns NULL when no git repo", {
  withr::with_tempdir({
    result <- cassidy_context_git()
    expect_null(result)
  })
})

test_that("cassidy_context_git handles git repo gracefully", {
  # Skip if git not available
  skip_if(Sys.which("git") == "", "Git not available")

  withr::with_tempdir({
    # Initialize git repo
    system("git init", ignore.stdout = TRUE, ignore.stderr = TRUE)
    system(
      "git config user.email 'test@example.com'",
      ignore.stdout = TRUE,
      ignore.stderr = TRUE
    )
    system(
      "git config user.name 'Test User'",
      ignore.stdout = TRUE,
      ignore.stderr = TRUE
    )

    result <- cassidy_context_git()

    # Should return something (or NULL if git commands fail)
    expect_true(is.null(result) || is.character(result))

    if (!is.null(result)) {
      expect_match(result, "Git Status")
    }
  })
})

test_that("cassidy_context_git include_commits parameter works", {
  skip_if(Sys.which("git") == "", "Git not available")

  withr::with_tempdir({
    # Initialize git repo with a commit
    init_result <- system(
      "git init",
      ignore.stdout = TRUE,
      ignore.stderr = TRUE
    )
    skip_if(init_result != 0, "Git init failed")

    system(
      "git config user.email 'test@example.com'",
      ignore.stdout = TRUE,
      ignore.stderr = TRUE
    )
    system(
      "git config user.name 'Test User'",
      ignore.stdout = TRUE,
      ignore.stderr = TRUE
    )

    writeLines("test", "test.txt")
    system("git add .", ignore.stdout = TRUE, ignore.stderr = TRUE)
    commit_result <- system(
      "git commit -m 'Initial commit'",
      ignore.stdout = TRUE,
      ignore.stderr = TRUE
    )
    skip_if(commit_result != 0, "Git commit failed")

    # Test that functions don't error with both parameter values
    expect_no_error(
      result_no_commits <- cassidy_context_git(include_commits = FALSE)
    )
    expect_no_error(
      result_with_commits <- cassidy_context_git(include_commits = TRUE)
    )

    # Both should either be NULL or character
    expect_true(is.null(result_no_commits) || is.character(result_no_commits))
    expect_true(
      is.null(result_with_commits) || is.character(result_with_commits)
    )
  })
})


# Test cassidy_read_context_file ----------------------------------------------

test_that("cassidy_read_context_file returns NULL when no file exists", {
  withr::with_tempdir({
    result <- cassidy_read_context_file()
    expect_null(result)
  })
})

test_that("cassidy_read_context_file finds cassidy.md", {
  withr::with_tempdir({
    content <- c("# Project Context", "Test content")
    writeLines(content, "cassidy.md")

    result <- cassidy_read_context_file()

    expect_type(result, "character")
    expect_match(result, "Project Configuration")
    expect_match(result, "Test content")
  })
})

test_that("cassidy_read_context_file finds alternative file names", {
  withr::with_tempdir({
    writeLines("Content 1", ".cassidy.md")

    result <- cassidy_read_context_file()

    expect_type(result, "character")
    expect_match(result, "Content 1")
  })
})

test_that("cassidy_read_context_file handles multiple config files", {
  withr::with_tempdir({
    writeLines("Config 1", "cassidy.md")
    writeLines("Config 2", "ai-context.md")

    result <- cassidy_read_context_file()

    expect_type(result, "character")
    expect_match(result, "Config 1")
    expect_match(result, "Config 2")
  })
})

# Test use_cassidy_md ---------------------------------------------------------

test_that("use_cassidy_md creates file", {
  withr::with_tempdir({
    # Suppress cli output
    suppressMessages({
      result <- use_cassidy_md(open = FALSE)
    })

    expect_true(result)
    expect_true(file.exists("cassidy.md"))
  })
})

test_that("use_cassidy_md creates correct template", {
  withr::with_tempdir({
    suppressMessages({
      use_cassidy_md(template = "package", open = FALSE)
    })

    content <- readLines("cassidy.md")
    expect_true(any(grepl("Package Development", content)))
  })

  withr::with_tempdir({
    suppressMessages({
      use_cassidy_md(template = "analysis", open = FALSE)
    })

    content <- readLines("cassidy.md")
    expect_true(any(grepl("Data Analysis", content)))
  })

  withr::with_tempdir({
    suppressMessages({
      use_cassidy_md(template = "survey", open = FALSE)
    })

    content <- readLines("cassidy.md")
    expect_true(any(grepl("Survey Research", content)))
  })
})

test_that("use_cassidy_md doesn't overwrite without confirmation in non-interactive", {
  withr::with_tempdir({
    # Create initial file
    writeLines("Original", "cassidy.md")

    # Try to create again (suppress warnings)
    suppressMessages({
      result <- use_cassidy_md(open = FALSE)
    })

    # Should return FALSE (not overwritten)
    expect_false(result)

    # Original should still be there
    content <- readLines("cassidy.md")
    expect_equal(content, "Original")
  })
})

test_that("use_cassidy_md templates are well-formed", {
  templates <- c("default", "package", "analysis", "survey")

  for (template in templates) {
    withr::with_tempdir({
      suppressMessages({
        use_cassidy_md(template = template, open = FALSE)
      })

      content <- readLines("cassidy.md")

      # Should have content
      expect_gt(length(content), 0)

      # Should start with a heading
      expect_match(content[1], "^#")
    })
  }
})
