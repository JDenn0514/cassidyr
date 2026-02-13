# ══════════════════════════════════════════════════════════════════════════════
# YAML Parsing Tests
# ══════════════════════════════════════════════════════════════════════════════

test_that("YAML frontmatter parsing works with all fields", {
  fixture_path <- test_path("fixtures/skills/test-valid.md")
  metadata <- .parse_skill_metadata(fixture_path)

  expect_equal(metadata$name, "Test Valid Skill")
  expect_equal(metadata$description, "A valid test skill for testing YAML parsing")
  expect_true(metadata$auto_invoke)
  expect_equal(metadata$requires, c("dependency1", "dependency2"))
  expect_equal(metadata$file_path, fixture_path)
})

test_that("YAML parsing works with minimal required fields", {
  fixture_path <- test_path("fixtures/skills/test-minimal.md")
  metadata <- .parse_skill_metadata(fixture_path)

  # Description is required
  expect_equal(metadata$description, "Minimal skill with only required fields")

  # Name should default to filename
  expect_equal(metadata$name, "test-minimal")

  # auto_invoke should default to TRUE
  expect_true(metadata$auto_invoke)

  # requires should default to empty
  expect_equal(metadata$requires, character(0))
})

test_that("YAML parsing fails gracefully without frontmatter", {
  fixture_path <- test_path("fixtures/skills/test-no-frontmatter.md")

  expect_error(
    .parse_skill_metadata(fixture_path),
    "Invalid skill file format"
  )
})

test_that("YAML parsing fails gracefully with malformed YAML", {
  fixture_path <- test_path("fixtures/skills/test-malformed.md")

  expect_error(
    .parse_skill_metadata(fixture_path),
    "Failed to parse skill file"
  )
})

test_that("YAML parsing fails when description is missing", {
  fixture_path <- test_path("fixtures/skills/test-missing-description.md")

  expect_error(
    .parse_skill_metadata(fixture_path),
    "Missing required field"
  )
})

# ══════════════════════════════════════════════════════════════════════════════
# Skill Discovery Tests
# ══════════════════════════════════════════════════════════════════════════════

test_that("skill discovery works", {
  # Create temp directory with test skill
  withr::with_tempdir({
    dir.create(".cassidy/skills", recursive = TRUE)

    writeLines(c(
      "---",
      "name: \"Test Skill\"",
      "description: \"A test skill\"",
      "auto_invoke: true",
      "---",
      "",
      "# Test Skill",
      "Content"
    ), ".cassidy/skills/test-skill.md")

    skills <- .discover_skills()

    expect_type(skills, "list")
    expect_true("test-skill" %in% names(skills))
    expect_equal(skills[["test-skill"]]$description, "A test skill")
    expect_true(skills[["test-skill"]]$auto_invoke)
  })
})

test_that("skill metadata parsing works with YAML", {
  withr::with_tempdir({
    skill_content <- c(
      "---",
      "name: \"My Analysis Skill\"",
      "description: \"Performs custom analysis workflow\"",
      "auto_invoke: false",
      "requires:",
      "  - apa-tables",
      "  - reliability-analysis",
      "---",
      "",
      "# My Analysis Skill",
      "",
      "## Workflow",
      "Step 1: Do something"
    )

    writeLines(skill_content, "test.md")

    metadata <- .parse_skill_metadata("test.md")

    expect_equal(metadata$name, "My Analysis Skill")
    expect_equal(metadata$description, "Performs custom analysis workflow")
    expect_false(metadata$auto_invoke)
    expect_equal(metadata$requires, c("apa-tables", "reliability-analysis"))
  })
})

# ══════════════════════════════════════════════════════════════════════════════
# Content Loading Tests
# ══════════════════════════════════════════════════════════════════════════════

test_that("YAML frontmatter is stripped from loaded content", {
  withr::with_tempdir({
    dir.create(".cassidy/skills", recursive = TRUE)

    writeLines(c(
      "---",
      "name: \"Test Skill\"",
      "description: \"A test skill\"",
      "---",
      "",
      "# Test Skill",
      "",
      "Content starts here"
    ), ".cassidy/skills/test-skill.md")

    result <- .load_skill("test-skill")

    expect_true(result$success)
    # YAML block should not appear in content
    expect_false(grepl("^---", result$content))
    expect_false(grepl("name: \"Test Skill\"", result$content, fixed = TRUE))
    # Content should be present
    expect_true(grepl("Content starts here", result$content))
  })
})

test_that("skill loading with dependencies works", {
  withr::with_tempdir({
    dir.create(".cassidy/skills", recursive = TRUE)

    # Create base skill (no dependencies)
    writeLines(c(
      "---",
      "description: \"Base functionality\"",
      "---",
      "",
      "# Base Skill",
      "",
      "Content of base skill"
    ), ".cassidy/skills/base-skill.md")

    # Create dependent skill
    writeLines(c(
      "---",
      "description: \"Uses base skill\"",
      "requires:",
      "  - base-skill",
      "---",
      "",
      "# Dependent Skill",
      "",
      "Content of dependent skill"
    ), ".cassidy/skills/dependent-skill.md")

    result <- .load_skill("dependent-skill")

    expect_true(result$success)
    expect_true(grepl("base-skill", result$content))
    expect_true(grepl("dependent-skill", result$content))
    expect_equal(result$dependencies, "base-skill")
  })
})

test_that("circular dependency detection works", {
  withr::with_tempdir({
    dir.create(".cassidy/skills", recursive = TRUE)

    # Create circular dependency
    writeLines(c(
      "---",
      "description: \"Skill A\"",
      "requires:",
      "  - skill-b",
      "---",
      "",
      "# Skill A"
    ), ".cassidy/skills/skill-a.md")

    writeLines(c(
      "---",
      "description: \"Skill B\"",
      "requires:",
      "  - skill-a",
      "---",
      "",
      "# Skill B"
    ), ".cassidy/skills/skill-b.md")

    # Should not infinite loop and should load successfully
    result <- .load_skill("skill-a")
    expect_true(result$success)
    expect_false(isTRUE(result$circular))  # Main skill not circular
    # Both skills should be present in content
    expect_true(grepl("skill-a", result$content))
    expect_true(grepl("skill-b", result$content))
    # Verify dependency structure is present
    expect_true(grepl("Referenced Skills", result$content))
    expect_true(grepl("DEPENDENCY: skill-b", result$content))
  })
})

# ══════════════════════════════════════════════════════════════════════════════
# User-Facing Function Tests
# ══════════════════════════════════════════════════════════════════════════════

test_that("cassidy_context_skills returns proper format", {
  withr::with_tempdir({
    dir.create(".cassidy/skills", recursive = TRUE)

    writeLines(c(
      "---",
      "description: \"Test description\"",
      "---",
      "",
      "# Test Skill"
    ), ".cassidy/skills/test-skill.md")

    ctx <- cassidy_context_skills()

    expect_s3_class(ctx, "cassidy_context")
    expect_type(ctx$text, "character")
    expect_type(ctx$skills, "list")
    expect_true(grepl("Available Skills", ctx$text))
  })
})

test_that("cassidy_list_skills shows available skills", {
  withr::with_tempdir({
    dir.create(".cassidy/skills", recursive = TRUE)

    writeLines(c(
      "---",
      "description: \"First skill\"",
      "---",
      "",
      "# Skill 1"
    ), ".cassidy/skills/skill-1.md")

    expect_no_error({
      skills <- suppressMessages(cassidy_list_skills())
    })

    expect_type(skills, "character")
    expect_true("skill-1" %in% skills)
  })
})

test_that("cassidy_use_skill loads and displays skill", {
  withr::with_tempdir({
    dir.create(".cassidy/skills", recursive = TRUE)

    writeLines(c(
      "---",
      "description: \"Test workflow\"",
      "---",
      "",
      "# Test Workflow",
      "",
      "## Steps",
      "1. First step",
      "2. Second step"
    ), ".cassidy/skills/test-workflow.md")

    # Preview skill (no task)
    expect_output(
      result <- cassidy_use_skill("test-workflow"),
      "Steps"
    )

    expect_true(result$success)
  })
})

# ══════════════════════════════════════════════════════════════════════════════
# Skill Creation Tests
# ══════════════════════════════════════════════════════════════════════════════

test_that("cassidy_create_skill creates valid YAML skill file", {
  withr::with_tempdir({
    suppressMessages({
      skill_path <- cassidy_create_skill("my-test-skill", open = FALSE)
    })

    expect_true(file.exists(skill_path))

    content <- readLines(skill_path)

    # Should start with YAML frontmatter
    expect_equal(content[1], "---")

    # Should have required YAML fields
    expect_true(any(grepl("^name:", content)))
    expect_true(any(grepl("^description:", content)))
    expect_true(any(grepl("^auto_invoke:", content)))
    expect_true(any(grepl("^requires:", content)))

    # Should have heading
    expect_true(any(grepl("^# ", content)))
  })
})

test_that("cassidy_create_skill accepts custom description", {
  withr::with_tempdir({
    suppressMessages({
      skill_path <- cassidy_create_skill(
        "custom-skill",
        description = "My custom description",
        open = FALSE
      )
    })

    content <- paste(readLines(skill_path), collapse = "\n")
    expect_true(grepl("My custom description", content))
  })
})

test_that("cassidy_create_skill accepts custom auto_invoke", {
  withr::with_tempdir({
    suppressMessages({
      skill_path <- cassidy_create_skill(
        "manual-skill",
        auto_invoke = FALSE,
        open = FALSE
      )
    })

    content <- paste(readLines(skill_path), collapse = "\n")
    expect_true(grepl("auto_invoke: false", content))
  })
})

test_that("cassidy_create_skill accepts requires dependencies", {
  withr::with_tempdir({
    suppressMessages({
      skill_path <- cassidy_create_skill(
        "dependent-skill",
        requires = c("skill-a", "skill-b"),
        open = FALSE
      )
    })

    content <- paste(readLines(skill_path), collapse = "\n")
    expect_true(grepl("skill-a", content))
    expect_true(grepl("skill-b", content))
  })
})

test_that("cassidy_create_skill validates name format", {
  withr::with_tempdir({
    # Invalid names
    expect_error(
      cassidy_create_skill("My Skill"),  # Spaces
      "Invalid skill name"
    )

    expect_error(
      cassidy_create_skill("MySkill"),  # Capital letters
      "Invalid skill name"
    )

    expect_error(
      cassidy_create_skill("my_skill"),  # Underscores
      "Invalid skill name"
    )

    # Valid name
    expect_no_error({
      suppressMessages(cassidy_create_skill("my-skill"))
    })
  })
})

test_that("cassidy_create_skill handles different templates", {
  withr::with_tempdir({
    # Basic template
    suppressMessages({
      basic_path <- cassidy_create_skill("basic-skill", template = "basic", open = FALSE)
    })
    basic_content <- paste(readLines(basic_path), collapse = "\n")
    expect_true(grepl("Workflow Steps", basic_content))
    expect_true(grepl("auto_invoke: true", basic_content))

    # Analysis template
    suppressMessages({
      analysis_path <- cassidy_create_skill("analysis-skill", template = "analysis", open = FALSE)
    })
    analysis_content <- paste(readLines(analysis_path), collapse = "\n")
    expect_true(grepl("Analysis Steps", analysis_content))
    expect_true(grepl("auto_invoke: true", analysis_content))

    # Workflow template
    suppressMessages({
      workflow_path <- cassidy_create_skill("workflow-skill", template = "workflow", open = FALSE)
    })
    workflow_content <- paste(readLines(workflow_path), collapse = "\n")
    expect_true(grepl("Workflow Phases", workflow_content))
    expect_true(grepl("auto_invoke: false", workflow_content))
  })
})

# ══════════════════════════════════════════════════════════════════════════════
# Integration Tests
# ══════════════════════════════════════════════════════════════════════════════

test_that("skills integrate with project context", {
  withr::with_tempdir({
    dir.create(".cassidy/skills", recursive = TRUE)

    writeLines(c(
      "---",
      "description: \"A project-specific skill\"",
      "---",
      "",
      "# Project Skill"
    ), ".cassidy/skills/project-skill.md")

    # Get project context with skills
    ctx <- cassidy_context_project(level = "minimal", include_skills = TRUE)

    expect_true(grepl("Available Skills", ctx$text))
    expect_true(grepl("project-skill", ctx$text))
  })
})

test_that("skills can be excluded from project context", {
  withr::with_tempdir({
    dir.create(".cassidy/skills", recursive = TRUE)

    writeLines(c(
      "---",
      "description: \"A project-specific skill\"",
      "---",
      "",
      "# Project Skill"
    ), ".cassidy/skills/project-skill.md")

    # Get project context without skills
    ctx <- cassidy_context_project(level = "minimal", include_skills = FALSE)

    expect_false(grepl("Available Skills", ctx$text))
  })
})
