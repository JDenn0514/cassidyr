# ══════════════════════════════════════════════════════════════════════════════
# AGENTIC LIVE TESTS
# Manual tests requiring real API credentials
# Run these manually after setting up environment variables
# ══════════════════════════════════════════════════════════════════════════════

# Prerequisites:
# 1. Set environment variables:
#    CASSIDY_API_KEY=your-api-key
#    CASSIDY_ASSISTANT_ID=your-assistant-id
#    CASSIDY_WORKFLOW_WEBHOOK=your-workflow-webhook-url
# 2. Create Tool Decision Workflow in CassidyAI (see cassidy_setup_workflow())

# Load package
library(cassidyr)

# ══════════════════════════════════════════════════════════════════════════════
# TEST 1: Simple Read-Only Task
# ══════════════════════════════════════════════════════════════════════════════

cat("\n=== Test 1: Simple read-only task ===\n")

result1 <- cassidy_agentic_task(
  "List all R files in the R/ directory and tell me how many there are",
  tools = c("list_files"),  # Read-only tool
  max_iterations = 3,
  verbose = TRUE
)

print(result1)

# ══════════════════════════════════════════════════════════════════════════════
# TEST 2: Task with Safe Mode (will prompt for approval)
# ══════════════════════════════════════════════════════════════════════════════

cat("\n=== Test 2: Task requiring approval ===\n")
cat("This will prompt you to approve writing a file\n\n")

result2 <- cassidy_agentic_task(
  "Create a simple test file called 'test_output.txt' with the text 'Hello from cassidyr agent!'",
  safe_mode = TRUE,  # Default, but explicit here
  max_iterations = 5,
  verbose = TRUE
)

print(result2)

# Clean up test file
if (file.exists("test_output.txt")) {
  cat("\nCleaning up test file...\n")
  file.remove("test_output.txt")
}

# ══════════════════════════════════════════════════════════════════════════════
# TEST 3: Task with Context
# ══════════════════════════════════════════════════════════════════════════════

cat("\n=== Test 3: Task with project context ===\n")

ctx <- cassidy_context_project(level = "minimal")

result3 <- cassidy_agentic_task(
  "Based on the project context, what kind of R package is this?",
  initial_context = ctx$text,
  tools = c("get_context"),
  max_iterations = 2,
  verbose = TRUE
)

print(result3)

# ══════════════════════════════════════════════════════════════════════════════
# TEST 4: Custom Approval Callback
# ══════════════════════════════════════════════════════════════════════════════

cat("\n=== Test 4: Custom approval callback ===\n")
cat("This uses a custom approver that auto-denies writes\n\n")

# Custom approver: deny all writes
strict_approver <- function(action, input, reasoning) {
  cat("\nCustom Approver Called:\n")
  cat("  Action:", action, "\n")
  cat("  Denying write operations automatically\n\n")

  list(
    approved = FALSE,  # Deny everything
    input = input
  )
}

result4 <- cassidy_agentic_task(
  "Try to create a file called 'blocked.txt'",
  safe_mode = TRUE,
  approval_callback = strict_approver,
  max_iterations = 3,
  verbose = TRUE
)

print(result4)

# ══════════════════════════════════════════════════════════════════════════════
# TEST 5: Search and Read Task
# ══════════════════════════════════════════════════════════════════════════════

cat("\n=== Test 5: Search and read task ===\n")

result5 <- cassidy_agentic_task(
  "Search for files containing the word 'cassidy' and tell me which files mention it",
  tools = c("list_files", "search_files", "read_file"),
  max_iterations = 5,
  verbose = TRUE
)

print(result5)

# ══════════════════════════════════════════════════════════════════════════════
# Summary
# ══════════════════════════════════════════════════════════════════════════════

cat("\n")
cat("═══════════════════════════════════════════════════════════════════════\n")
cat("MANUAL TEST SUMMARY\n")
cat("═══════════════════════════════════════════════════════════════════════\n")
cat("Test 1 (Read-only):", if (result1$success) "✓ PASSED" else "✗ FAILED", "\n")
cat("Test 2 (Safe mode):", if (result2$success) "✓ PASSED" else "✗ FAILED", "\n")
cat("Test 3 (Context):  ", if (result3$success) "✓ PASSED" else "✗ FAILED", "\n")
cat("Test 4 (Callback): ", if (!result4$success) "✓ PASSED (expected failure)" else "✗ UNEXPECTED SUCCESS", "\n")
cat("Test 5 (Search):   ", if (result5$success) "✓ PASSED" else "✗ FAILED", "\n")
cat("═══════════════════════════════════════════════════════════════════════\n")
