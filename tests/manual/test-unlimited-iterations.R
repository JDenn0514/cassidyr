# Manual Test: Unlimited Iterations
#
# This test demonstrates using max_iterations = Inf for complex tasks
# that may require many steps.

library(cassidyr)

cat("\n=== Test: Unlimited Iterations ===\n")
cat("This task can take as many iterations as needed to complete.\n\n")

# Example 1: Simple task with unlimited iterations
result <- cassidy_agentic_task(
  "List all R files in this directory and count them",
  tools = c("list_files"),
  max_iterations = Inf, # ← Unlimited!
  verbose = TRUE
)

print(result)
cat("\nTotal iterations used:", result$iterations, "\n")

# Example 2: Complex task that might need many steps
# (uncomment to test)
result <- cassidy_agentic_task(
  "Analyze all R files in the R/ directory and summarize their purpose",
  tools = c("list_files", "read_file", "get_context"),
  max_iterations = Inf,
  verbose = TRUE
)

cat("\n=== Tips for Unlimited Iterations ===\n")
cat("• Use Ctrl+C to interrupt if needed\n")
cat("• Monitor progress with verbose = TRUE\n")
cat("• Consider safe_mode = TRUE for risky operations\n")
cat("• The assistant should say 'TASK COMPLETE' when done\n")
