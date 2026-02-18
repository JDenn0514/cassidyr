# Manual test for compaction (requires API key)
#
# This file tests the compaction functionality with a real API.
# Run this manually when you have API credentials configured.
#
# Usage:
#   source("tests/manual/test-compaction-live.R")

library(cassidyr)

test_compaction_live <- function() {
  cli::cli_h1("Manual Compaction Test")

  # Check for API key
  if (Sys.getenv("CASSIDY_API_KEY") == "" || Sys.getenv("CASSIDY_ASSISTANT_ID") == "") {
    cli::cli_alert_danger("CASSIDY_API_KEY and CASSIDY_ASSISTANT_ID must be set")
    cli::cli_alert_info("Run cassidy_setup() or set them in .Renviron")
    return(invisible(NULL))
  }

  # Create session with auto_compact = FALSE for manual testing
  cli::cli_alert_info("Creating new session...")
  session <- cassidy_session(auto_compact = FALSE)

  cli::cli_alert_success("Session created: {session$thread_id}")

  # Send several messages to build up history
  cli::cli_h2("Building conversation history")

  messages <- c(
    "Hello! I'm testing the compaction feature.",
    "Can you tell me about R programming?",
    "What are some best practices for R package development?",
    "How do I write good documentation?",
    "What testing frameworks are available in R?",
    "Tell me about the tidyverse style guide."
  )

  for (i in seq_along(messages)) {
    cli::cli_alert_info("Message {i}/{length(messages)}: {substr(messages[i], 1, 50)}...")

    session <- chat(session, messages[i])

    # Brief pause to avoid rate limits
    Sys.sleep(2)
  }

  # Check token estimate
  cli::cli_h2("Before Compaction")
  stats_before <- cassidy_session_stats(session)
  print(stats_before)

  # Manual compact
  cli::cli_h2("Performing Compaction")
  session <- cassidy_compact(session, preserve_recent = 2)

  # Check stats again
  cli::cli_h2("After Compaction")
  stats_after <- cassidy_session_stats(session)
  print(stats_after)

  # Verify compaction worked
  cli::cli_h2("Verification")
  cli::cli_alert_info("Compaction count: {session$compaction_count}")
  cli::cli_alert_info("Messages before: {stats_before$total_messages}")
  cli::cli_alert_info("Messages after: {stats_after$total_messages}")
  cli::cli_alert_info("Tokens before: {stats_before$token_estimate}")
  cli::cli_alert_info("Tokens after: {stats_after$token_estimate}")

  # Continue conversation to verify context is preserved
  cli::cli_h2("Testing Continuation")
  cli::cli_alert_info("Sending follow-up message...")

  session <- chat(session, "What were the main topics we discussed?")

  # Final stats
  cli::cli_h2("Final State")
  stats_final <- cassidy_session_stats(session)
  print(stats_final)

  cli::cli_alert_success("Compaction test complete!")

  invisible(session)
}

# Run the test
test_compaction_live()
