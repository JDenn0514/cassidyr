# File: tests/manual/test-live-api.R (NOT run automatically)

# Only run this manually when you want to verify API still works
if (interactive()) {
  library(cassidyr)

  # Test basic workflow
  thread_id <- cassidy_create_thread()
  response <- cassidy_send_message(thread_id, "Hello!")
  thread <- cassidy_get_thread(thread_id)

  print("✓ All API calls working")
}
