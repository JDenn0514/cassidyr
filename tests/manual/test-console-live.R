# Manual tests for unified console chat interface
# These tests use real API calls and should be run manually

library(cassidyr)

# ===========================================================================
# SETUP
# ===========================================================================

# Ensure you have API credentials set
if (Sys.getenv("CASSIDY_API_KEY") == "" || Sys.getenv("CASSIDY_ASSISTANT_ID") == "") {
  stop("Please set CASSIDY_API_KEY and CASSIDY_ASSISTANT_ID environment variables")
}

# Clear any existing state
cassidy_reset()

# ===========================================================================
# TEST 1: Basic conversation flow
# ===========================================================================

cat("\n=== TEST 1: Basic Conversation Flow ===\n\n")

# First message - should create new conversation
result1 <- cassidy_chat("What is R?")
print(result1)

# Second message - should auto-continue
result2 <- cassidy_chat("Tell me more about its history")
print(result2)

# Check they're in same conversation
stopifnot(result1$conversation_id == result2$conversation_id)
stopifnot(result1$thread_id == result2$thread_id)

cat("\n\u2713 Basic conversation flow works!\n")

# ===========================================================================
# TEST 2: Check current conversation
# ===========================================================================

cat("\n=== TEST 2: Current Conversation ===\n\n")

current <- cassidy_current()
print(current)

stopifnot(!is.null(current))
stopifnot(current$id == result2$conversation_id)
stopifnot(length(current$messages) == 4) # 2 user + 2 assistant

cat("\n\u2713 Current conversation tracking works!\n")

# ===========================================================================
# TEST 3: List conversations
# ===========================================================================

cat("\n=== TEST 3: List Conversations ===\n\n")

convs <- cassidy_conversations()
print(convs)

stopifnot(nrow(convs) >= 1)
stopifnot(result1$conversation_id %in% convs$id)

cat("\n\u2713 Conversation listing works!\n")

# ===========================================================================
# TEST 4: Start new conversation explicitly
# ===========================================================================

cat("\n=== TEST 4: New Conversation ===\n\n")

result3 <- cassidy_chat("New topic: What is Python?", conversation = "new")
print(result3)

# Should be different conversation
stopifnot(result3$conversation_id != result1$conversation_id)
stopifnot(result3$thread_id != result1$thread_id)

cat("\n\u2713 New conversation creation works!\n")

# ===========================================================================
# TEST 5: Switch between conversations
# ===========================================================================

cat("\n=== TEST 5: Switch Conversations ===\n\n")

# Get first conversation ID
first_conv_id <- result1$conversation_id

# Switch back to first conversation
result4 <- cassidy_chat("Back to R topic", conversation = first_conv_id)
print(result4)

stopifnot(result4$conversation_id == first_conv_id)
stopifnot(result4$thread_id == result1$thread_id)

cat("\n\u2713 Conversation switching works!\n")

# ===========================================================================
# TEST 6: Reset and verify clean state
# ===========================================================================

cat("\n=== TEST 6: Reset State ===\n\n")

cassidy_reset()

# Current should be NULL
current_after_reset <- cassidy_current()
stopifnot(is.null(current_after_reset))

# But saved conversations should still exist
convs_after_reset <- cassidy_conversations()
stopifnot(nrow(convs_after_reset) >= 2) # At least the 2 we created

cat("\n\u2713 Reset works (clears state but keeps saved conversations)!\n")

# ===========================================================================
# TEST 7: Context levels
# ===========================================================================

cat("\n=== TEST 7: Context Levels ===\n\n")

# Minimal context
result5 <- cassidy_chat(
  "Test with minimal context",
  conversation = "new",
  context_level = "minimal"
)
stopifnot(result5$context_level == "minimal")

# Standard context (default)
result6 <- cassidy_chat(
  "Test with standard context",
  conversation = "new",
  context_level = "standard"
)
stopifnot(result6$context_level == "standard")

# Comprehensive context
result7 <- cassidy_chat(
  "Test with comprehensive context",
  conversation = "new",
  context_level = "comprehensive"
)
stopifnot(result7$context_level == "comprehensive")

cat("\n\u2713 Context levels work!\n")

# ===========================================================================
# TEST 8: Include specific files
# ===========================================================================

cat("\n=== TEST 8: Include Files ===\n\n")

# Find an R file to include
test_files <- list.files("R", pattern = "\\.R$", full.names = TRUE)
if (length(test_files) > 0) {
  result8 <- cassidy_chat(
    "Review this code",
    conversation = "new",
    include_files = test_files[1]
  )
  print(result8)
  cat("\n\u2713 File inclusion works!\n")
} else {
  cat("\n(Skipped - no R files found)\n")
}

# ===========================================================================
# TEST 9: Include data frames
# ===========================================================================

cat("\n=== TEST 9: Include Data ===\n\n")

# Create a test data frame
test_df <- data.frame(
  x = 1:10,
  y = rnorm(10),
  z = letters[1:10]
)

result9 <- cassidy_chat(
  "Describe this data",
  conversation = "new",
  include_data = TRUE,
  context_level = "standard"
)
print(result9)

# Clean up
rm(test_df)

cat("\n\u2713 Data inclusion works!\n")

# ===========================================================================
# TEST 10: Backward compatibility (thread_id parameter)
# ===========================================================================

cat("\n=== TEST 10: Backward Compatibility ===\n\n")

# Create a thread the old way
old_thread <- cassidy_create_thread()

# Use old interface
result10 <- cassidy_chat("Legacy mode test", thread_id = old_thread)
print(result10)

# Should work but not affect package state
stopifnot(result10$thread_id == old_thread)
stopifnot(is.null(result10$conversation_id))

# State should still be NULL from previous reset
current_after_legacy <- cassidy_current()
stopifnot(is.null(current_after_legacy))

cat("\n\u2713 Backward compatibility works!\n")

# ===========================================================================
# SUMMARY
# ===========================================================================

cat("\n" , rep("=", 60), "\n", sep = "")
cat("ALL MANUAL TESTS PASSED!\n")
cat(rep("=", 60), "\n\n", sep = "")

# Show final conversation list
cat("Final conversation list:\n\n")
print(cassidy_conversations(n = 20))

cat("\n")
cat("You can now:\n")
cat("- Resume any conversation: cassidy_chat('message', conversation = 'conv_id')\n")
cat("- Export a conversation: cassidy_export_conversation('conv_id')\n")
cat("- Delete a conversation: cassidy_delete_conversation('conv_id')\n")
cat("- Reset state: cassidy_reset()\n")
