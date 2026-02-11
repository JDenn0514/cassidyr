# Manual Test: Skills Context Window
# =====================================
# This script helps you test the skills context window feature in cassidy_app()

# Setup ----
devtools::load_all()
library(cassidyr)

# Check current skills
cat("=== Current Skills ===\n")
cassidy_list_skills()

# Create a test skill if needed
test_skill_path <- file.path(getwd(), ".cassidy/skills/test-skill.md")
if (!file.exists(test_skill_path)) {
  cat("\n=== Creating Test Skill ===\n")
  cassidy_create_skill("test-skill", location = "project", template = "basic")
}

# Verify skills are discoverable
cat("\n=== Skills Context ===\n")
ctx <- cassidy_context_skills()
print(ctx)

# Show what skills will look like in the app
cat("\n=== Skills Available for Testing ===\n")
all_skills <- cassidy_context_skills(format = "list")
for (skill_name in names(all_skills)) {
  skill <- all_skills[[skill_name]]
  cat(sprintf(
    "\n%s\n  Description: %s\n  Auto-invoke: %s\n  Location: %s\n  Dependencies: %s\n",
    skill_name,
    skill$description,
    skill$auto_invoke,
    basename(dirname(skill$file_path)),
    if (length(skill$requires) > 0) paste(skill$requires, collapse = ", ") else "none"
  ))
}

cat("\n\n=== Ready to Launch ===\n")
cat("The app will open with the following features:\n")
cat("  ✓ Skills section in left sidebar\n")
cat("  ✓", length(all_skills), "skill(s) available\n")
cat("  ✓ Context summary shows skills count\n")
cat("  ✓ Skills persist across conversations\n")

cat("\n=== TESTING CHECKLIST ===\n")
cat("\nWhen the app opens, test:\n\n")

cat("1. SKILLS SECTION VISIBILITY\n")
cat("   [ ] Skills section appears in left sidebar\n")
cat("   [ ] Section has magic wand icon and count\n")
cat("   [ ] Section is collapsible\n\n")

cat("2. SKILLS DISPLAY\n")
cat("   [ ] Skills grouped by Project/Personal\n")
cat("   [ ] Each skill shows description\n")
cat("   [ ] Auto-invoke badge appears for auto skills\n")
cat("   [ ] Dependencies shown (if any)\n\n")

cat("3. SKILLS SELECTION\n")
cat("   [ ] Can check/uncheck skill checkboxes\n")
cat("   [ ] Skills count updates in section header\n")
cat("   [ ] Selected skills appear in bottom summary panel\n\n")

cat("4. CONTEXT APPLICATION\n")
cat("   [ ] Click 'Apply Context' with skills selected\n")
cat("   [ ] Success notification shows skill count\n")
cat("   [ ] Skills marked as sent (blue indicator)\n")
cat("   [ ] Refresh button appears for sent skills\n\n")

cat("5. INCREMENTAL CONTEXT\n")
cat("   [ ] Select additional skill\n")
cat("   [ ] Click 'Apply Context'\n")
cat("   [ ] Only new skill is sent (check notification)\n\n")

cat("6. SKILL REFRESH\n")
cat("   [ ] Click refresh button on a sent skill\n")
cat("   [ ] Skill queued for refresh\n")
cat("   [ ] Click 'Apply Context'\n")
cat("   [ ] Skill re-sent to assistant\n\n")

cat("7. CONVERSATION PERSISTENCE\n")
cat("   [ ] Select some skills\n")
cat("   [ ] Send context\n")
cat("   [ ] Create new conversation\n")
cat("   [ ] Switch back to previous conversation\n")
cat("   [ ] Skills still selected and marked as sent\n\n")

cat("8. SKILLS IN MESSAGES\n")
cat("   [ ] Send a message asking about a skill workflow\n")
cat("   [ ] Assistant has access to skill content\n")
cat("   [ ] Assistant can reference skill steps/guidelines\n\n")

cat("\n=== Launch App ===\n")
cat("Run: cassidy_app(new_chat = TRUE)\n\n")

# Uncomment to launch automatically:
# cassidy_app(new_chat = TRUE)
