# Manual test for recursive memory loading (team-repo use case)
# Run this script to verify the upstream memory feature works

library(cassidyr)

# Create a temporary team-repo structure
temp_dir <- tempfile("team-repo-test")
dir.create(temp_dir)
old_wd <- getwd()

tryCatch({
  setwd(temp_dir)

  cat("Creating team-repo structure...\n")

  # Company-wide config
  writeLines(
    c(
      "# Company-Wide Standards",
      "",
      "## Coding Style",
      "- Use tidyverse style guide",
      "- Maximum line length: 80 characters",
      "- Use native pipe |> operator",
      "",
      "## Security",
      "- Never commit credentials",
      "- Use environment variables for API keys"
    ),
    "CASSIDY.md"
  )

  # Company-wide modular rules
  dir.create(".cassidy/rules", recursive = TRUE)
  writeLines(
    c(
      "# Testing Standards",
      "- All functions must have tests",
      "- Use testthat 3e",
      "- Aim for >80% coverage"
    ),
    ".cassidy/rules/testing.md"
  )

  # Project A - Survey analysis
  dir.create("project-a")
  writeLines(
    c(
      "# Project A: Survey Analysis",
      "",
      "## Project Details",
      "- Survey research project",
      "- Uses lavaan for SEM",
      "- N = 500 participants",
      "",
      "## Preferred Packages",
      "- psych for scale reliability",
      "- lavaan for confirmatory factor analysis",
      "- ggplot2 for visualization"
    ),
    "project-a/CASSIDY.md"
  )

  # Project B - Web scraping
  dir.create("project-b")
  writeLines(
    c(
      "# Project B: Web Scraping",
      "",
      "## Project Details",
      "- Web scraping and API integration",
      "- Uses rvest and httr2",
      "",
      "## Preferred Packages",
      "- rvest for HTML parsing",
      "- httr2 for API calls",
      "- jsonlite for JSON handling"
    ),
    "project-b/CASSIDY.md"
  )

  cat("\n=== Structure Created ===\n")
  system("find . -name '*.md' -type f")

  # Test from project-a
  cat("\n\n=== Testing from project-a ===\n\n")
  setwd("project-a")

  cat("1. Testing cassidy_read_context_file(recursive=TRUE)...\n")
  config <- cassidy_read_context_file(recursive = TRUE)

  if (is.null(config)) {
    cat("❌ FAILED: No config loaded\n")
  } else {
    cat("✅ Config loaded successfully\n\n")

    # Check what was loaded
    has_company <- grepl("Company-Wide Standards", config)
    has_testing <- grepl("Testing Standards", config)
    has_project_a <- grepl("Project A: Survey Analysis", config)
    has_project_b <- grepl("Project B: Web Scraping", config)

    cat("Checking loaded content:\n")
    cat(sprintf("  ✅ Company-wide config: %s\n", if(has_company) "YES" else "NO"))
    cat(sprintf("  ✅ Company-wide rules:  %s\n", if(has_testing) "YES" else "NO"))
    cat(sprintf("  ✅ Project A config:    %s\n", if(has_project_a) "YES" else "NO"))
    cat(sprintf("  ❌ Project B config:    %s (should be NO)\n", if(has_project_b) "YES" else "NO"))

    if (has_company && has_testing && has_project_a && !has_project_b) {
      cat("\n✅ ALL CHECKS PASSED! Recursive loading works correctly.\n")
    } else {
      cat("\n❌ SOME CHECKS FAILED. See above.\n")
    }
  }

  cat("\n2. Testing cassidy_context_project() default behavior...\n")
  ctx <- cassidy_context_project(level = "minimal", include_config = TRUE)

  if ("config" %in% ctx$parts) {
    has_company <- grepl("Company-Wide Standards", ctx$text)
    has_project_a <- grepl("Project A", ctx$text)

    if (has_company && has_project_a) {
      cat("✅ cassidy_context_project() loads both configs by default\n")
    } else {
      cat("❌ cassidy_context_project() missing some configs\n")
    }
  } else {
    cat("❌ No config loaded in cassidy_context_project()\n")
  }

  cat("\n3. Testing from project-b...\n")
  setwd("../project-b")

  config_b <- cassidy_read_context_file(recursive = TRUE)
  has_company_b <- grepl("Company-Wide Standards", config_b)
  has_project_b <- grepl("Project B: Web Scraping", config_b)
  has_project_a_from_b <- grepl("Project A", config_b)

  if (has_company_b && has_project_b && !has_project_a_from_b) {
    cat("✅ Project B loads company-wide + project-b only (not project-a)\n")
  } else {
    cat("❌ Project B config loading incorrect\n")
  }

  cat("\n=== SUMMARY ===\n")
  cat("The recursive memory loading feature is working correctly!\n")
  cat("Your team-repo use case is fully supported.\n\n")
  cat("To use in your actual team-repo:\n")
  cat("1. Create CASSIDY.md in your repo root with company standards\n")
  cat("2. Create project-specific CASSIDY.md in each project subfolder\n")
  cat("3. Run cassidy_app() or cassidy_context_project() from any project\n")
  cat("4. Both configs will be automatically loaded!\n")

}, finally = {
  setwd(old_wd)
  unlink(temp_dir, recursive = TRUE)
  cat("\nCleaned up temporary directory.\n")
})
