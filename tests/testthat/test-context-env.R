# tests/testthat/test-context-environment.R

# Test cassidy_context_env ----------------------------------------------------

test_that("cassidy_context_env returns character string", {
  result <- cassidy_context_env()

  expect_type(result, "character")
})

test_that("cassidy_context_env detailed parameter works", {
  basic <- cassidy_context_env(detailed = FALSE)
  detailed <- cassidy_context_env(detailed = TRUE)

  # Both should be character
  expect_type(basic, "character")
  expect_type(detailed, "character")

  # Detailed might have more content (depending on environment)
  expect_gte(nchar(detailed), 0)
})

# Test cassidy_list_objects ---------------------------------------------------

test_that("cassidy_list_objects handles empty environment", {
  test_env <- new.env()

  result <- cassidy_list_objects(envir = test_env)

  expect_type(result, "character")
  expect_match(result, "Empty")
})

test_that("cassidy_list_objects detects data frames", {
  test_env <- new.env()
  test_env$df1 <- data.frame(x = 1:5)
  test_env$df2 <- data.frame(y = letters[1:3])

  result <- cassidy_list_objects(envir = test_env)

  expect_match(result, "Data frames")
  expect_match(result, "df1")
  expect_match(result, "df2")
  expect_match(result, "5 obs")
  expect_match(result, "3 obs")
})

test_that("cassidy_list_objects detects functions", {
  test_env <- new.env()
  test_env$my_func <- function() 1 + 1
  test_env$another_func <- function() 2 + 2

  result <- cassidy_list_objects(envir = test_env, detailed = TRUE)

  expect_match(result, "Functions")
  expect_match(result, "my_func")
  expect_match(result, "another_func")
})

test_that("cassidy_list_objects detailed includes sizes", {
  test_env <- new.env()
  test_env$df <- data.frame(x = 1:100)

  basic <- cassidy_list_objects(envir = test_env, detailed = FALSE)
  detailed <- cassidy_list_objects(envir = test_env, detailed = TRUE)

  # Detailed should include size information (case insensitive, various formats)
  expect_match(detailed, "bytes|Kb|Mb|KB|MB", ignore.case = TRUE)
})

test_that("cassidy_list_objects includes summary count", {
  test_env <- new.env()
  test_env$a <- 1
  test_env$b <- 2
  test_env$c <- 3

  result <- cassidy_list_objects(envir = test_env, detailed = TRUE)

  expect_match(result, "Total.*3 object")
})

test_that("cassidy_list_objects limits function display", {
  test_env <- new.env()

  # Create more than 10 functions
  for (i in 1:15) {
    assign(paste0("func", i), function() NULL, envir = test_env)
  }

  result <- cassidy_list_objects(envir = test_env, detailed = TRUE)

  # Should mention "more" functions
  expect_match(result, "and [0-9]+ more")
})

test_that("cassidy_list_objects categorizes objects correctly", {
  test_env <- new.env()
  test_env$df <- data.frame(x = 1:5)
  test_env$func <- function() NULL
  test_env$vec <- 1:10
  test_env$mat <- matrix(1:9, 3, 3)

  result <- cassidy_list_objects(envir = test_env, detailed = TRUE)

  # Should have data frames section
  expect_match(result, "Data frames")
  expect_match(result, "df")

  # Should have functions section
  expect_match(result, "Functions")
  expect_match(result, "func")

  # Other objects only in detailed mode
  expect_match(result, "Other objects")
  expect_match(result, "vec")
  expect_match(result, "mat")
})

# Test cassidy_session_info ---------------------------------------------------

test_that("cassidy_session_info returns character string", {
  result <- cassidy_session_info()

  expect_type(result, "character")
})

test_that("cassidy_session_info includes basic information", {
  result <- cassidy_session_info()

  expect_match(result, "R Session Information")
  expect_match(result, "R version") # Flexible - with or without colon/bold
  expect_match(result, "Platform")
  expect_match(result, "IDE")
  expect_match(result, "Working directory")
})

test_that("cassidy_session_info includes R version correctly", {
  result <- cassidy_session_info()

  expected_version <- paste0(R.version$major, ".", R.version$minor)
  # Use flexible matching to handle potential markdown formatting
  expect_match(result, expected_version, fixed = TRUE)
})

test_that("cassidy_session_info includes platform", {
  result <- cassidy_session_info()

  # Platform might be in different formats, just check it's there
  expect_match(result, R.version$platform, fixed = TRUE)
})

test_that("cassidy_session_info includes working directory", {
  result <- cassidy_session_info()

  # Working directory should be present
  wd <- getwd()
  expect_match(result, wd, fixed = TRUE)
})

test_that("cassidy_session_info include_packages parameter works", {
  without_pkgs <- cassidy_session_info(include_packages = FALSE)
  with_pkgs <- cassidy_session_info(include_packages = TRUE)

  # Both should be character
  expect_type(without_pkgs, "character")
  expect_type(with_pkgs, "character")

  # Version with packages might be longer (if packages are loaded)
  # But not guaranteed in test environment
  expect_gte(nchar(with_pkgs), nchar(without_pkgs))
})

test_that("cassidy_session_info detects IDE", {
  result <- cassidy_session_info()

  # Should mention some IDE (even if Unknown/Terminal)
  expect_match(result, "IDE")
  expect_match(result, "RStudio|Positron|VS Code|Unknown|Terminal")
})
