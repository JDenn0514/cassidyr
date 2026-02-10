# Manual Test: Direct Parsing Agentic System
#
# This test demonstrates the new direct parsing approach (no workflow needed!)
#
# Setup:
# 1. Set CASSIDY_ASSISTANT_ID in .Renviron
# 2. Set CASSIDY_API_KEY in .Renviron
# 3. No workflow setup needed!

library(cassidyr)

# Test 1: Simple file listing
cat("\n=== Test 1: List R Files ===\n")
result1 <- cassidy_agentic_task(
  "List all R files in this directory",
  tools = c("list_files"),
  max_iterations = 5,
  verbose = TRUE
)

print(result1)

if (result1$success) {
  cat("\n✓ Test 1 PASSED\n")
} else {
  cat("\n✗ Test 1 FAILED\n")
}

# Test 2: Read a file
cat("\n=== Test 2: Read File ===\n")
result2 <- cassidy_agentic_task(
  "Read the contents of R/utils.R",
  tools = c("read_file"),
  max_iterations = 5,
  verbose = TRUE
)

print(result2)

if (result2$success) {
  cat("\n✓ Test 2 PASSED\n")
} else {
  cat("\n✗ Test 2 FAILED\n")
}

# Test 3: Get project context
cat("\n=== Test 3: Get Context ===\n")
result3 <- cassidy_agentic_task(
  "Get a summary of this R package",
  tools = c("get_context", "list_files"),
  max_iterations = 5,
  verbose = TRUE
)

print(result3)

if (result3$success) {
  cat("\n✓ Test 3 PASSED\n")
} else {
  cat("\n✗ Test 3 FAILED\n")
}

cat("\n=== All Tests Complete ===\n")
