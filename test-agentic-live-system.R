#!/usr/bin/env Rscript
# ══════════════════════════════════════════════════════════════════════════════
# AGENTIC SYSTEM END-TO-END TEST
# Tests the full agentic workflow with real API calls
# ══════════════════════════════════════════════════════════════════════════════

library(cassidyr)

cat("╔════════════════════════════════════════════════════════════════╗\n")
cat("║           CASSIDYR AGENTIC SYSTEM TEST SUITE                  ║\n")
cat("╚════════════════════════════════════════════════════════════════╝\n\n")

# Check environment
cat("1. Checking environment variables...\n")
api_key <- Sys.getenv("CASSIDY_API_KEY")
assistant_id <- Sys.getenv("CASSIDY_ASSISTANT_ID")

if (!nzchar(api_key)) {
  stop("❌ CASSIDY_API_KEY not set")
}
if (!nzchar(assistant_id)) {
  stop("❌ CASSIDY_ASSISTANT_ID not set")
}
cat("   ✅ Environment configured\n\n")

# Create temp directory for testing
test_dir <- tempdir()
cat("2. Test directory:", test_dir, "\n\n")

# ══════════════════════════════════════════════════════════════════════════════
# TEST 1: Basic Read-Only Task (Safe, No Approval Needed)
# ══════════════════════════════════════════════════════════════════════════════
cat("╔════════════════════════════════════════════════════════════════╗\n")
cat("║  TEST 1: Read-Only Task (list_files)                          ║\n")
cat("╚════════════════════════════════════════════════════════════════╝\n\n")

cat("Running: List R files in current directory\n")
cat("Expected: Should use list_files tool and complete\n")
cat("Safe mode: ON (but no risky tools used)\n\n")

tryCatch({
  result1 <- cassidy_agentic_task(
    task = "List all R files in the current directory that start with 'agentic'",
    tools = c("list_files"),  # Only read-only tools
    max_iterations = 3,
    safe_mode = TRUE,
    verbose = TRUE
  )

  cat("\n")
  cat("─────────────────────────────────────────────────────────────────\n")
  cat("TEST 1 RESULTS:\n")
  cat("─────────────────────────────────────────────────────────────────\n")
  print(result1)
  cat("\n")

  if (result1$success) {
    cat("✅ TEST 1 PASSED: Task completed successfully\n")
  } else {
    cat("⚠️  TEST 1 WARNING: Task did not complete\n")
  }

}, error = function(e) {
  cat("❌ TEST 1 FAILED:", e$message, "\n")
})

cat("\n")
Sys.sleep(2)  # Brief pause between tests

# ══════════════════════════════════════════════════════════════════════════════
# TEST 2: Multi-Tool Task (Read and Search)
# ══════════════════════════════════════════════════════════════════════════════
cat("╔════════════════════════════════════════════════════════════════╗\n")
cat("║  TEST 2: Multi-Tool Task (list_files + read_file)             ║\n")
cat("╚════════════════════════════════════════════════════════════════╝\n\n")

cat("Running: List and read agentic files\n")
cat("Expected: Should use list_files then read_file\n")
cat("Safe mode: ON (but no risky tools used)\n\n")

tryCatch({
  result2 <- cassidy_agentic_task(
    task = "Find the agentic-tools.R file and tell me how many tools are defined in .cassidy_tools",
    tools = c("list_files", "read_file"),
    max_iterations = 5,
    safe_mode = TRUE,
    verbose = TRUE
  )

  cat("\n")
  cat("─────────────────────────────────────────────────────────────────\n")
  cat("TEST 2 RESULTS:\n")
  cat("─────────────────────────────────────────────────────────────────\n")
  print(result2)
  cat("\n")

  if (result2$success) {
    cat("✅ TEST 2 PASSED: Task completed successfully\n")
  } else {
    cat("⚠️  TEST 2 WARNING: Task did not complete\n")
  }

}, error = function(e) {
  cat("❌ TEST 2 FAILED:", e$message, "\n")
})

cat("\n")
Sys.sleep(2)

# ══════════════════════════════════════════════════════════════════════════════
# TEST 3: Context Gathering
# ══════════════════════════════════════════════════════════════════════════════
cat("╔════════════════════════════════════════════════════════════════╗\n")
cat("║  TEST 3: Context Tool (get_context)                           ║\n")
cat("╚════════════════════════════════════════════════════════════════╝\n\n")

cat("Running: Get project context\n")
cat("Expected: Should use get_context tool\n\n")

tryCatch({
  result3 <- cassidy_agentic_task(
    task = "Get the minimal project context and tell me the package name",
    tools = c("get_context"),
    max_iterations = 2,
    safe_mode = TRUE,
    verbose = TRUE
  )

  cat("\n")
  cat("─────────────────────────────────────────────────────────────────\n")
  cat("TEST 3 RESULTS:\n")
  cat("─────────────────────────────────────────────────────────────────\n")
  print(result3)
  cat("\n")

  if (result3$success) {
    cat("✅ TEST 3 PASSED: Task completed successfully\n")
  } else {
    cat("⚠️  TEST 3 WARNING: Task did not complete\n")
  }

}, error = function(e) {
  cat("❌ TEST 3 FAILED:", e$message, "\n")
})

cat("\n")

# ══════════════════════════════════════════════════════════════════════════════
# TEST 4: Safe Mode with Risky Operation (Will Require Approval)
# ══════════════════════════════════════════════════════════════════════════════
cat("╔════════════════════════════════════════════════════════════════╗\n")
cat("║  TEST 4: Safe Mode Test (SKIPPED - requires interaction)      ║\n")
cat("╚════════════════════════════════════════════════════════════════╝\n\n")

cat("This test would require user approval for write_file.\n")
cat("To test manually, run:\n\n")
cat("  result <- cassidy_agentic_task(\n")
cat("    'Create a test file called hello.txt with Hello World',\n")
cat("    tools = c('write_file'),\n")
cat("    safe_mode = TRUE\n")
cat("  )\n\n")
cat("⏭️  SKIPPED: Interactive approval required\n\n")

# ══════════════════════════════════════════════════════════════════════════════
# TEST 5: Safe Mode Disabled (Automatic Execution)
# ══════════════════════════════════════════════════════════════════════════════
cat("╔════════════════════════════════════════════════════════════════╗\n")
cat("║  TEST 5: Safe Mode OFF (write_file, automatic)                ║\n")
cat("╚════════════════════════════════════════════════════════════════╝\n\n")

cat("Running: Write a test file (automatic, no approval)\n")
cat("Expected: Should create file without prompting\n")
cat("Safe mode: OFF\n\n")

# Change to temp directory for write test
setwd(test_dir)

tryCatch({
  result5 <- cassidy_agentic_task(
    task = "Create a file called agentic-test-output.txt with the text 'Agentic system test successful!'",
    tools = c("write_file"),
    working_dir = test_dir,
    max_iterations = 3,
    safe_mode = FALSE,  # ⚠️  Safe mode OFF
    verbose = TRUE
  )

  cat("\n")
  cat("─────────────────────────────────────────────────────────────────\n")
  cat("TEST 5 RESULTS:\n")
  cat("─────────────────────────────────────────────────────────────────\n")
  print(result5)
  cat("\n")

  # Check if file was created
  test_file <- file.path(test_dir, "agentic-test-output.txt")
  if (file.exists(test_file)) {
    content <- readLines(test_file)
    cat("✅ File created successfully!\n")
    cat("   Content:", content, "\n")
    cat("✅ TEST 5 PASSED: Write operation completed\n")
  } else {
    cat("⚠️  TEST 5 WARNING: File not created\n")
  }

}, error = function(e) {
  cat("❌ TEST 5 FAILED:", e$message, "\n")
})

cat("\n")

# ══════════════════════════════════════════════════════════════════════════════
# SUMMARY
# ══════════════════════════════════════════════════════════════════════════════
cat("\n")
cat("╔════════════════════════════════════════════════════════════════╗\n")
cat("║                    TEST SUITE SUMMARY                          ║\n")
cat("╚════════════════════════════════════════════════════════════════╝\n\n")

cat("Tests completed. The agentic system is working if:\n")
cat("  ✅ TEST 1: Successfully listed files\n")
cat("  ✅ TEST 2: Successfully used multiple tools\n")
cat("  ✅ TEST 3: Successfully gathered context\n")
cat("  ⏭️  TEST 4: Skipped (interactive)\n")
cat("  ✅ TEST 5: Successfully wrote file with safe mode off\n\n")

cat("Next steps:\n")
cat("  1. Test CLI: cassidy agent 'List all R files'\n")
cat("  2. Test interactive: cassidy agent\n")
cat("  3. Test with approval: Run TEST 4 manually\n\n")

cat("╔════════════════════════════════════════════════════════════════╗\n")
cat("║              AGENTIC SYSTEM TEST COMPLETE                      ║\n")
cat("╚════════════════════════════════════════════════════════════════╝\n")
