# ══════════════════════════════════════════════════════════════════════════════
# AGENTIC HELPERS TESTS
# Tests for helper functions (cassidy_list_tools, cassidy_tool_preset)
# ══════════════════════════════════════════════════════════════════════════════

test_that("cassidy_list_tools returns all tool names", {
  # Capture invisibly returned value
  tools <- suppressMessages(cassidy_list_tools())

  # Should be character vector
  expect_type(tools, "character")

  # Should have all 7 tools
  expect_length(tools, 7)

  # Should contain expected tools
  expected_tools <- c(
    "read_file", "write_file", "execute_code",
    "list_files", "search_files", "get_context", "describe_data"
  )
  expect_true(all(expected_tools %in% tools))
})

test_that("cassidy_list_tools displays tool information", {
  # Just test it runs without error
  expect_no_error(cassidy_list_tools())
})

test_that("cassidy_tool_preset returns correct tools for 'all'", {
  tools <- cassidy_tool_preset("all")

  expect_type(tools, "character")
  expect_length(tools, 7)

  # Should have all tools
  expected_tools <- c(
    "read_file", "write_file", "execute_code",
    "list_files", "search_files", "get_context", "describe_data"
  )
  expect_setequal(tools, expected_tools)
})

test_that("cassidy_tool_preset returns correct tools for 'read_only'", {
  tools <- cassidy_tool_preset("read_only")

  expect_type(tools, "character")
  expect_length(tools, 5)

  # Should have read-only tools
  expected_tools <- c(
    "read_file", "list_files", "search_files",
    "get_context", "describe_data"
  )
  expect_setequal(tools, expected_tools)

  # Should NOT have risky tools
  expect_false("write_file" %in% tools)
  expect_false("execute_code" %in% tools)
})

test_that("cassidy_tool_preset returns correct tools for 'code_analysis'", {
  tools <- cassidy_tool_preset("code_analysis")

  expect_type(tools, "character")
  expect_length(tools, 4)

  # Should have code analysis tools
  expected_tools <- c(
    "read_file", "list_files", "search_files", "get_context"
  )
  expect_setequal(tools, expected_tools)

  # Should NOT have data or write tools
  expect_false("write_file" %in% tools)
  expect_false("execute_code" %in% tools)
  expect_false("describe_data" %in% tools)
})

test_that("cassidy_tool_preset returns correct tools for 'data_analysis'", {
  tools <- cassidy_tool_preset("data_analysis")

  expect_type(tools, "character")
  expect_length(tools, 3)

  # Should have data analysis tools
  expected_tools <- c("describe_data", "execute_code", "get_context")
  expect_setequal(tools, expected_tools)

  # Should NOT have file tools
  expect_false("read_file" %in% tools)
  expect_false("write_file" %in% tools)
  expect_false("list_files" %in% tools)
  expect_false("search_files" %in% tools)
})

test_that("cassidy_tool_preset returns correct tools for 'code_generation'", {
  tools <- cassidy_tool_preset("code_generation")

  expect_type(tools, "character")
  expect_length(tools, 4)

  # Should have code generation tools
  expected_tools <- c("read_file", "list_files", "write_file", "get_context")
  expect_setequal(tools, expected_tools)

  # Should NOT have data or search tools
  expect_false("execute_code" %in% tools)
  expect_false("search_files" %in% tools)
  expect_false("describe_data" %in% tools)
})

test_that("cassidy_tool_preset validates input", {
  # Invalid preset should error
  expect_error(
    cassidy_tool_preset("invalid_preset"),
    "should be one of"
  )
})

test_that("cassidy_tool_preset defaults to 'all'", {
  # Without argument should default to 'all'
  tools <- cassidy_tool_preset()

  expect_length(tools, 7)
  expect_setequal(
    tools,
    c("read_file", "write_file", "execute_code", "list_files",
      "search_files", "get_context", "describe_data")
  )
})

test_that("cassidy_tool_preset shows info message for non-all presets", {
  # Should show info when using a specific preset
  expect_no_error(cassidy_tool_preset("read_only"))
  expect_no_error(cassidy_tool_preset("code_analysis"))
  expect_no_error(cassidy_tool_preset("data_analysis"))
  expect_no_error(cassidy_tool_preset("code_generation"))
})

test_that("all preset tools exist in .cassidy_tools", {
  presets <- c("all", "read_only", "code_analysis", "data_analysis", "code_generation")

  for (preset in presets) {
    tools <- cassidy_tool_preset(preset)

    # Every tool in preset should exist in .cassidy_tools
    for (tool in tools) {
      expect_true(
        tool %in% names(.cassidy_tools),
        info = paste("Tool", tool, "from preset", preset, "not found in .cassidy_tools")
      )
    }
  }
})

test_that("preset tools can be used with cassidy_agentic_task", {
  # Just verify the tools argument accepts preset output
  # (doesn't actually call API)
  tools <- cassidy_tool_preset("read_only")

  expect_type(tools, "character")
  expect_gt(length(tools), 0)

  # Tools should be valid names
  expect_true(all(nzchar(tools)))
  expect_false(any(is.na(tools)))
})

test_that("cassidy_list_tools and cassidy_tool_preset are consistent", {
  # All tools from list_tools should match all preset
  all_tools <- cassidy_list_tools()
  all_preset <- cassidy_tool_preset("all")

  expect_setequal(all_tools, all_preset)
})

test_that("read_only preset excludes risky tools", {
  read_only <- cassidy_tool_preset("read_only")

  # Check that no risky tools are included
  risky_tools <- c("write_file", "execute_code")

  for (risky in risky_tools) {
    expect_false(
      risky %in% read_only,
      info = paste("Risky tool", risky, "should not be in read_only preset")
    )
  }
})

test_that("code_generation preset includes write_file", {
  code_gen <- cassidy_tool_preset("code_generation")

  # Code generation should include write_file
  expect_true("write_file" %in% code_gen)
})

test_that("data_analysis preset includes execute_code", {
  data_analysis <- cassidy_tool_preset("data_analysis")

  # Data analysis should include execute_code for calculations
  expect_true("execute_code" %in% data_analysis)
})

test_that("presets don't have duplicate tools", {
  presets <- c("all", "read_only", "code_analysis", "data_analysis", "code_generation")

  for (preset in presets) {
    tools <- cassidy_tool_preset(preset)

    # No duplicates
    expect_equal(
      length(tools),
      length(unique(tools)),
      info = paste("Preset", preset, "has duplicate tools")
    )
  }
})
