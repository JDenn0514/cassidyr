#!/usr/bin/env Rscript
# Interactive Skills Context Window Test
# ========================================
# Launch the cassidy_app() with skills context window for testing

# Load package
devtools::load_all()

# Show pre-launch info
cat("\n")
cat("╔════════════════════════════════════════════════════════════╗\n")
cat("║        Skills Context Window - Interactive Test           ║\n")
cat("╚════════════════════════════════════════════════════════════╝\n")
cat("\n")

# Check environment
if (!nzchar(Sys.getenv("CASSIDY_API_KEY"))) {
  cat("⚠️  WARNING: CASSIDY_API_KEY not set\n")
  cat("   Set it in your .Renviron file or the app will error\n\n")
}

if (!nzchar(Sys.getenv("CASSIDY_ASSISTANT_ID"))) {
  cat("⚠️  WARNING: CASSIDY_ASSISTANT_ID not set\n")
  cat("   Set it in your .Renviron file or the app will error\n\n")
}

# Show available skills
cat("📚 Available Skills for Testing:\n")
skills <- cassidy_context_skills(format = "list")
for (name in names(skills)) {
  skill <- skills[[name]]
  auto_badge <- if (skill$auto_invoke) "✓ auto" else "○ manual"
  deps <- if (length(skill$requires) > 0) {
    paste0(" → requires: ", paste(skill$requires, collapse = ", "))
  } else {
    ""
  }
  cat(sprintf("   • %s (%s)%s\n", name, auto_badge, deps))
  cat(sprintf("     %s\n", skill$description))
}

cat("\n")
cat("🎯 What to Test:\n")
cat("   1. Skills section in left sidebar (magic wand icon)\n")
cat("   2. Select skills with checkboxes\n")
cat("   3. View selected skills in bottom summary\n")
cat("   4. Click 'Apply Context' to send skills\n")
cat("   5. Skills marked as sent (blue indicator)\n")
cat("   6. Refresh button appears for sent skills\n")
cat("   7. Send a message asking about a skill\n")
cat("   8. Switch conversations - skills persist\n")
cat("\n")

cat("🚀 Launching cassidy_app()...\n\n")

# Launch the app
cassidy_app(new_chat = TRUE, context_level = "standard")
