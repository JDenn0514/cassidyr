#!/usr/bin/env Rscript
# Cleanup Old Conversations
# ==========================
# Deletes all saved conversations to start fresh

devtools::load_all()

cat("\n")
cat("╔══════════════════════════════════════════════════════╗\n")
cat("║     Cleanup Cassidy App Conversations                ║\n")
cat("╚══════════════════════════════════════════════════════╝\n")
cat("\n")

# List current conversations
convs <- cassidy_list_conversations()

if (nrow(convs) == 0) {
  cat("✓ No conversations to clean up\n\n")
} else {
  cat("Found", nrow(convs), "conversation(s):\n")
  print(convs[, c("id", "title", "created_at")])

  cat("\n")
  response <- readline("Delete all conversations? (yes/no): ")

  if (tolower(response) %in% c("yes", "y")) {
    for (id in convs$id) {
      cassidy_delete_conversation(id)
      cat("✓ Deleted:", id, "\n")
    }
    cat("\n✅ All conversations deleted!\n\n")
  } else {
    cat("\n❌ Cleanup cancelled\n\n")
  }
}

cat("Now you can run cassidy_app() with a clean slate\n\n")
