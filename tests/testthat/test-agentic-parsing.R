# ══════════════════════════════════════════════════════════════════════════════
# AGENTIC PARSING TESTS
# Tests for tool decision parsing logic
# ══════════════════════════════════════════════════════════════════════════════

test_that(".parse_tool_decision parses valid structured response", {
  response <- "<TOOL_DECISION>
ACTION: read_file
INPUT: {\"filepath\": \"test.R\"}
REASONING: Need to read the file to understand its contents
STATUS: continue
</TOOL_DECISION>"

  result <- .parse_tool_decision(response, c("read_file", "list_files"))

  expect_equal(result$action, "read_file")
  expect_equal(result$input$filepath, "test.R")
  expect_equal(result$reasoning, "Need to read the file to understand its contents")
  expect_equal(result$status, "continue")
})

test_that(".parse_tool_decision handles TASK COMPLETE", {
  response <- "TASK COMPLETE: I have successfully listed all R files in the directory."

  result <- .parse_tool_decision(response, c("read_file", "list_files"))

  expect_null(result$action)
  expect_equal(result$status, "final")
  expect_match(result$reasoning, "successfully listed")
})

test_that(".parse_tool_decision handles TASK_COMPLETE with underscore", {
  response <- "TASK_COMPLETE: All files have been processed"

  result <- .parse_tool_decision(response, c("read_file"))

  expect_null(result$action)
  expect_equal(result$status, "final")
  expect_match(result$reasoning, "processed")
})

test_that(".parse_tool_decision handles task complete with colon", {
  response <- "TASK COMPLETE: Analysis complete with 5 files found"

  result <- .parse_tool_decision(response, c("read_file"))

  expect_equal(result$status, "final")
  expect_match(result$reasoning, "5 files found")
})

test_that(".parse_tool_decision handles empty completion message", {
  response <- "TASK COMPLETE"

  result <- .parse_tool_decision(response, c("read_file"))

  expect_equal(result$status, "final")
  expect_equal(result$reasoning, "Task completed successfully")
})

test_that(".parse_tool_decision handles multiline structured response", {
  response <- "I'm going to read the file now.

<TOOL_DECISION>
ACTION: read_file
INPUT: {\"filepath\": \"R/utils.R\", \"working_dir\": \"/project\"}
REASONING: Reading the utils file to check for helper functions
STATUS: continue
</TOOL_DECISION>

This will help us understand the code."

  result <- .parse_tool_decision(response, c("read_file", "write_file"))

  expect_equal(result$action, "read_file")
  expect_equal(result$input$filepath, "R/utils.R")
  expect_equal(result$input$working_dir, "/project")
  expect_equal(result$status, "continue")
})

test_that(".parse_tool_decision handles empty INPUT", {
  response <- "<TOOL_DECISION>
ACTION: get_context
INPUT: {}
REASONING: Getting project context
STATUS: continue
</TOOL_DECISION>"

  result <- .parse_tool_decision(response, c("get_context"))

  expect_equal(result$action, "get_context")
  expect_equal(length(result$input), 0)
  expect_equal(result$status, "continue")
})

test_that(".parse_tool_decision defaults to continue status", {
  response <- "<TOOL_DECISION>
ACTION: list_files
INPUT: {\"directory\": \".\"}
REASONING: List all files
STATUS: invalid_status
</TOOL_DECISION>"

  result <- .parse_tool_decision(response, c("list_files"))

  expect_equal(result$status, "continue")
})

test_that(".parse_tool_decision handles missing status field", {
  response <- "<TOOL_DECISION>
ACTION: list_files
INPUT: {\"directory\": \".\"}
REASONING: List all files
</TOOL_DECISION>"

  result <- .parse_tool_decision(response, c("list_files"))

  expect_equal(result$status, "continue")
})

test_that(".parse_tool_decision handles invalid JSON gracefully", {
  response <- "<TOOL_DECISION>
ACTION: read_file
INPUT: {invalid json here}
REASONING: Read a file
STATUS: continue
</TOOL_DECISION>"

  expect_warning(
    result <- .parse_tool_decision(response, c("read_file")),
    "Failed to parse INPUT JSON"
  )

  expect_equal(result$action, "read_file")
  expect_equal(length(result$input), 0)
})

test_that(".parse_tool_decision falls back to inference when no structure", {
  response <- "I will use read_file to read the configuration."

  result <- .parse_tool_decision(response, c("read_file", "write_file"))

  expect_equal(result$action, "read_file")
  expect_equal(result$status, "continue")
  expect_match(result$reasoning, "Inferred")
})

test_that(".extract_field extracts single-line field", {
  text <- "ACTION: read_file
INPUT: {}"

  result <- .extract_field(text, "ACTION")

  expect_equal(result, "read_file")
})

test_that(".extract_field extracts field before next field", {
  text <- "ACTION: read_file
REASONING: This is reasoning text
INPUT: {}"

  result <- .extract_field(text, "REASONING")

  # Should extract reasoning and stop at INPUT
  expect_match(result, "This is reasoning text")
})

test_that(".extract_field returns empty string for missing field", {
  text <- "ACTION: read_file
INPUT: {}"

  result <- .extract_field(text, "MISSING")

  expect_equal(result, "")
})

test_that(".extract_field trims whitespace", {
  text <- "ACTION:    read_file
INPUT: {}"

  result <- .extract_field(text, "ACTION")

  expect_equal(result, "read_file")
})

test_that(".infer_tool_decision returns null when no tool mentioned", {
  response <- "I don't know what to do next."

  result <- .infer_tool_decision(response, c("read_file", "write_file"))

  expect_null(result$action)
  expect_equal(result$status, "continue")
  expect_match(result$reasoning, "No tool decision found")
})

test_that(".infer_tool_decision picks first mentioned tool", {
  response <- "I will use read_file first, then write_file later."

  result <- .infer_tool_decision(response, c("read_file", "write_file"))

  expect_equal(result$action, "read_file")
})

test_that(".infer_tool_decision extracts filepath from quotes", {
  response <- "I will use read_file to read 'R/utils.R' file."

  result <- .infer_tool_decision(response, c("read_file"))

  expect_equal(result$action, "read_file")
  expect_equal(result$input$filepath, "R/utils.R")
})

test_that(".infer_tool_decision extracts filepath from double quotes", {
  response <- "I need to read \"config.json\" using read_file."

  result <- .infer_tool_decision(response, c("read_file"))

  expect_equal(result$input$filepath, "config.json")
})

test_that(".infer_tool_decision only matches available tools", {
  response <- "I will use some_other_tool to process data."

  result <- .infer_tool_decision(response, c("read_file", "write_file"))

  # Should not match unavailable tool
  expect_null(result$action)
})

test_that(".parse_tool_decision handles status=final explicitly", {
  response <- "<TOOL_DECISION>
ACTION: list_files
INPUT: {\"directory\": \".\"}
REASONING: Final check of files
STATUS: final
</TOOL_DECISION>"

  result <- .parse_tool_decision(response, c("list_files"))

  expect_equal(result$status, "final")
  expect_equal(result$action, "list_files")
})

test_that(".parse_tool_decision handles complex nested JSON", {
  response <- "<TOOL_DECISION>
ACTION: write_file
INPUT: {\"filepath\": \"test.json\", \"content\": \"{\\\"nested\\\": \\\"value\\\"}\"}
REASONING: Write nested JSON
STATUS: continue
</TOOL_DECISION>"

  result <- .parse_tool_decision(response, c("write_file"))

  expect_equal(result$action, "write_file")
  expect_equal(result$input$filepath, "test.json")
  expect_type(result$input$content, "character")
})

test_that(".parse_tool_decision is case-insensitive for TASK COMPLETE", {
  response <- "task complete: Done!"

  result <- .parse_tool_decision(response, c("read_file"))

  expect_equal(result$status, "final")
})

test_that(".extract_field handles field at end of text", {
  text <- "ACTION: read_file
INPUT: {}
REASONING: Final reasoning"

  result <- .extract_field(text, "REASONING")

  expect_equal(result, "Final reasoning")
})

test_that(".infer_tool_decision returns empty input for non-file tools", {
  response <- "Let me use list_files to see what we have."

  result <- .infer_tool_decision(response, c("list_files", "read_file"))

  expect_equal(result$action, "list_files")
  expect_equal(length(result$input), 0)
})

test_that(".parse_tool_decision handles Windows-style line endings", {
  response <- "<TOOL_DECISION>\r\nACTION: read_file\r\nINPUT: {\"filepath\": \"test.R\"}\r\nREASONING: Read file\r\nSTATUS: continue\r\n</TOOL_DECISION>"

  result <- .parse_tool_decision(response, c("read_file"))

  expect_equal(result$action, "read_file")
  expect_equal(result$input$filepath, "test.R")
})

test_that(".parse_tool_decision handles extra whitespace in values", {
  response <- "<TOOL_DECISION>
ACTION:   read_file
INPUT: {\"filepath\": \"test.R\"}
REASONING:   Need to read the file
STATUS:   continue
</TOOL_DECISION>"

  result <- .parse_tool_decision(response, c("read_file"))

  expect_equal(result$action, "read_file")
  expect_equal(result$input$filepath, "test.R")
  expect_match(result$reasoning, "Need to read")
})

test_that(".extract_field handles colons in field value", {
  text <- "REASONING: The file path is: /home/user/file.R
ACTION: next"

  result <- .extract_field(text, "REASONING")

  expect_match(result, "file path is: /home/user/file.R")
})
