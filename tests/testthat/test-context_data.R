# tests/testthat/test-context-data.R

# Test cassidy_context_data ---------------------------------------------------

test_that("cassidy_context_data handles empty environment", {
  # Clear global environment temporarily
  withr::local_envvar(c("TESTTHAT" = "true"))

  # Create a temporary environment
  test_env <- new.env()

  # This will find no data frames in GlobalEnv during package testing
  result <- cassidy_context_data()

  expect_type(result, "character")
  expect_match(result, "Data Context")
})

test_that("cassidy_context_data detects data frames", {
  # Create temporary data frames in global environment
  withr::defer({
    if (exists("test_df1", envir = .GlobalEnv)) {
      rm(test_df1, envir = .GlobalEnv)
    }
    if (exists("test_df2", envir = .GlobalEnv)) rm(test_df2, envir = .GlobalEnv)
  })

  assign("test_df1", data.frame(x = 1:5), envir = .GlobalEnv)
  assign("test_df2", data.frame(y = letters[1:3]), envir = .GlobalEnv)

  result <- cassidy_context_data(detailed = FALSE)

  expect_match(result, "test_df1")
  expect_match(result, "test_df2")
  expect_match(result, "5 obs")
  expect_match(result, "3 obs")
})

test_that("cassidy_context_data detailed parameter works", {
  withr::defer({
    if (exists("test_df", envir = .GlobalEnv)) rm(test_df, envir = .GlobalEnv)
  })

  assign("test_df", data.frame(x = 1:5, y = letters[1:5]), envir = .GlobalEnv)

  basic <- cassidy_context_data(detailed = FALSE)
  detailed <- cassidy_context_data(detailed = TRUE)

  # Detailed should have more content
  expect_gte(nchar(detailed), nchar(basic))
})

# Test cassidy_describe_df ----------------------------------------------------

test_that("cassidy_describe_df requires data frame", {
  expect_error(
    cassidy_describe_df(list(a = 1)),
    "must be a data frame"
  )

  expect_error(
    cassidy_describe_df(1:10),
    "must be a data frame"
  )
})

test_that("cassidy_describe_df basic method works", {
  df <- data.frame(
    x = 1:10,
    y = letters[1:10],
    z = c(TRUE, FALSE)
  )

  result <- cassidy_describe_df(df, method = "basic")

  expect_s3_class(result, "cassidy_df_description")
  expect_type(result$text, "character")
  expect_equal(result$method, "basic")
  expect_match(result$text, "10 observations")
  expect_match(result$text, "3 variables")
})

test_that("cassidy_describe_df handles different variable types", {
  df <- data.frame(
    num = 1:5,
    char = letters[1:5],
    fac = factor(c("a", "b", "a", "b", "c")),
    logi = c(TRUE, TRUE, FALSE, TRUE, FALSE)
  )

  result <- cassidy_describe_df(df, method = "basic")

  expect_match(result$text, "num")
  expect_match(result$text, "char")
  expect_match(result$text, "fac")
  expect_match(result$text, "logi")
  expect_match(result$text, "range") # numeric summary
  expect_match(result$text, "unique values") # character summary
  expect_match(result$text, "levels") # factor summary
  expect_match(result$text, "TRUE") # logical summary
})

test_that("cassidy_describe_df handles missing data", {
  df <- data.frame(
    x = c(1, 2, NA, 4, 5),
    y = c("a", NA, "b", "c", NA)
  )

  result <- cassidy_describe_df(df, method = "basic")

  expect_match(result$text, "Missing Data")
  expect_match(result$text, "NAs")
})

test_that("cassidy_describe_df method fallback works", {
  df <- data.frame(x = 1:5)

  # Basic method should always work
  result_basic <- cassidy_describe_df(df, method = "basic")
  expect_equal(result_basic$method, "basic")

  # Skim and codebook will fall back if packages not available
  result_skim <- cassidy_describe_df(df, method = "skim")
  expect_true(result_skim$method %in% c("skim", "basic"))

  result_codebook <- cassidy_describe_df(df, method = "codebook")
  expect_true(result_codebook$method %in% c("codebook", "skim", "basic"))
})

test_that("print.cassidy_df_description works", {
  df <- data.frame(x = 1:5)
  desc <- cassidy_describe_df(df, method = "basic")

  # Test the actual content that gets printed via cat()
  expect_output(print(desc), "Data Frame: df")
  expect_output(print(desc), "observations")
  expect_output(print(desc), "variables")

  # Should return invisibly
  expect_invisible(print(desc))
})


# Test cassidy_describe_variable ----------------------------------------------
test_that("cassidy_describe_variable requires data frame", {
  expect_error(
    cassidy_describe_variable(list(a = 1), "x"),
    "must be a data frame"
  )

  expect_error(
    cassidy_describe_variable(1:10, "x"),
    "must be a data frame"
  )
})

test_that("cassidy_describe_variable works with variable name", {
  df <- data.frame(x = 1:10, y = letters[1:10])

  result <- cassidy_describe_variable(df, "x")

  expect_type(result, "character")
  expect_match(result, "Variable: x")
  expect_match(result, "Type.*integer")
  expect_match(result, "Length.*10")
})

test_that("cassidy_describe_variable works with variable position", {
  df <- data.frame(x = 1:10, y = letters[1:10])

  result <- cassidy_describe_variable(df, 1)

  expect_type(result, "character")
  expect_match(result, "Variable: x")
})

test_that("cassidy_describe_variable handles numeric variables", {
  df <- data.frame(x = c(1, 2, 3, 4, 5))

  result <- cassidy_describe_variable(df, "x")

  expect_match(result, "Summary Statistics")
  expect_match(result, "Min:")
  expect_match(result, "Max:")
  expect_match(result, "Mean:")
  expect_match(result, "Median:")
})

test_that("cassidy_describe_variable handles categorical variables", {
  df <- data.frame(x = factor(c("a", "b", "a", "c", "b", "a")))

  result <- cassidy_describe_variable(df, "x")

  expect_match(result, "Unique values")
  expect_match(result, "Value Counts")
})

test_that("cassidy_describe_variable handles logical variables", {
  df <- data.frame(x = c(TRUE, TRUE, FALSE, TRUE, FALSE))

  result <- cassidy_describe_variable(df, "x")

  expect_match(result, "Values")
  expect_match(result, "TRUE")
  expect_match(result, "FALSE")
})

test_that("cassidy_describe_variable handles missing data", {
  df <- data.frame(x = c(1, 2, NA, 4, NA))

  result <- cassidy_describe_variable(df, "x")

  expect_match(result, "Missing.*2")
})

test_that("cassidy_describe_variable validates variable exists", {
  df <- data.frame(x = 1:5)

  expect_error(
    cassidy_describe_variable(df, "nonexistent"),
    "not found"
  )

  expect_error(
    cassidy_describe_variable(df, 10),
    "out of range"
  )
})

# Test cassidy_detect_issues --------------------------------------------------

test_that("cassidy_detect_issues requires data frame", {
  expect_error(
    cassidy_detect_issues(1:10),
    "must be a data frame"
  )
})

test_that("cassidy_detect_issues returns correct structure", {
  df <- data.frame(x = 1:5, y = letters[1:5])

  result <- cassidy_detect_issues(df)

  expect_s3_class(result, "cassidy_data_issues")
  expect_type(result$missing_data, "list")
  expect_type(result$constant_columns, "character")
  expect_type(result$high_cardinality, "list")
  expect_type(result$outliers, "list")
})

test_that("cassidy_detect_issues finds missing data", {
  df <- data.frame(
    x = c(rep(NA, 8), 1, 2), # 80% missing
    y = 1:10
  )

  result <- cassidy_detect_issues(df, missing_threshold = 50)

  expect_true("x" %in% names(result$missing_data))
  expect_false("y" %in% names(result$missing_data))
})

test_that("cassidy_detect_issues finds constant columns", {
  df <- data.frame(
    x = rep(1, 10),
    y = 1:10
  )

  result <- cassidy_detect_issues(df)

  expect_true("x" %in% result$constant_columns)
  expect_false("y" %in% result$constant_columns)
})

test_that("cassidy_detect_issues finds high cardinality", {
  df <- data.frame(
    x = as.character(1:100), # 100% unique
    y = rep(c("a", "b"), 50)
  )

  result <- cassidy_detect_issues(df)

  expect_true("x" %in% names(result$high_cardinality))
  expect_false("y" %in% names(result$high_cardinality))
})

test_that("cassidy_detect_issues finds outliers with IQR method", {
  df <- data.frame(x = c(1:10, 100)) # 100 is outlier

  result <- cassidy_detect_issues(df, outlier_method = "iqr")

  expect_true("x" %in% names(result$outliers))
  expect_gt(result$outliers$x, 0)
})

test_that("cassidy_detect_issues finds outliers with zscore method", {
  df <- data.frame(x = c(rep(0, 20), 10)) # 10 is outlier

  result <- cassidy_detect_issues(
    df,
    outlier_method = "zscore",
    outlier_threshold = 2
  )

  expect_true("x" %in% names(result$outliers))
  expect_gt(result$outliers$x, 0)
})

test_that("cassidy_detect_issues finds duplicate rows", {
  df <- data.frame(
    x = c(1, 2, 1, 3),
    y = c("a", "b", "a", "c")
  )

  result <- cassidy_detect_issues(df)

  expect_equal(result$duplicates, 1)
})

test_that("cassidy_detect_issues handles clean numeric data", {
  df <- data.frame(
    x = 1:10,
    y = 11:20
  )

  result <- cassidy_detect_issues(df)

  expect_length(result$missing_data, 0)
  expect_length(result$constant_columns, 0)
  expect_length(result$high_cardinality, 0)
  expect_length(result$outliers, 0)
  expect_true(is.null(result$duplicates) || result$duplicates == 0)
})

test_that("cassidy_detect_issues handles clean mixed data", {
  df <- data.frame(
    id = 1:20,
    category = rep(c("A", "B", "C", "D"), 5), # Low cardinality
    value = rnorm(20, mean = 50, sd = 5) # No outliers
  )

  result <- cassidy_detect_issues(df)

  expect_length(result$missing_data, 0)
  expect_length(result$constant_columns, 0)
  expect_length(result$high_cardinality, 0)
  expect_length(result$outliers, 0)
  expect_true(is.null(result$duplicates) || result$duplicates == 0)
})

test_that("cassidy_detect_issues correctly identifies high cardinality", {
  df <- data.frame(
    id = 1:10,
    unique_values = letters[1:10] # 100% unique - should be flagged
  )

  result <- cassidy_detect_issues(df)

  # High cardinality should be detected
  expect_true("unique_values" %in% names(result$high_cardinality))
})


test_that("print.cassidy_data_issues works", {
  df <- data.frame(
    x = c(rep(NA, 8), 1, 2), # High missing
    y = rep(1, 10) # Constant
  )

  result <- cassidy_detect_issues(df, missing_threshold = 50)

  # Test structure
  expect_s3_class(result, "cassidy_data_issues")

  # Test that print works without error (don't test for output since cli writes to stderr)
  expect_no_error(print(result))

  # Should return invisibly
  expect_invisible(print(result))
})

test_that("print.cassidy_data_issues shows output for clean data", {
  df <- data.frame(x = 1:5, y = letters[1:5])
  result <- cassidy_detect_issues(df)

  # Just verify it prints without error
  expect_no_error(print(result))

  # Should return invisibly
  expect_invisible(print(result))
})
