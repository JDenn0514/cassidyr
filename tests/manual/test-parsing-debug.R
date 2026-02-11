# Manual Test: Debug Parsing Issues
#
# This test helps diagnose parsing problems with debug output enabled

library(cassidyr)

# Enable debug mode
options(cassidy.debug = TRUE)

cat("\n=== Test: List R Files (Debug Mode) ===\n\n")

result <- cassidy_agentic_task(
  "List all R files in this directory and count them",
  tools = c("list_files"),
  max_iterations = 5,
  verbose = TRUE
)

cat("\n=== Result ===\n")
print(result)

cat("\n=== Summary ===\n")
cat("Success:", result$success, "\n")
cat("Iterations:", result$iterations, "\n")
cat("Actions:", length(result$actions_taken), "\n")

if (result$success) {
  cat("\n✓ TEST PASSED\n")
} else {
  cat("\n✗ TEST FAILED\n")
  cat("Final response:", result$final_response, "\n")
}

# Disable debug mode
options(cassidy.debug = FALSE)
