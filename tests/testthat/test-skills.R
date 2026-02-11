test_that("skill discovery works", {
  # Create temp directory with test skill
  withr::with_tempdir({
    dir.create(".cassidy/skills", recursive = TRUE)

    writeLines(c(
      "# Test Skill",
      "**Description**: A test skill",
      "**Auto-invoke**: yes"
    ), ".cassidy/skills/test-skill.md")

    skills <- .discover_skills()

    expect_type(skills, "list")
    expect_true("test-skill" %in% names(skills))
    expect_equal(skills[["test-skill"]]$description, "A test skill")
    expect_true(skills[["test-skill"]]$auto_invoke)
  })
})

test_that("skill metadata parsing works", {
  withr::with_tempdir({
    skill_content <- c(
      "# My Analysis Skill",
      "**Description**: Performs custom analysis workflow",
      "**Auto-invoke**: no",
      "**Requires**: apa-tables, reliability-analysis",
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

test_that("skill loading with dependencies works", {
  withr::with_tempdir({
    dir.create(".cassidy/skills", recursive = TRUE)

    # Create base skill (no dependencies)
    writeLines(c(
      "# Base Skill",
      "**Description**: Base functionality",
      "",
      "Content of base skill"
    ), ".cassidy/skills/base-skill.md")

    # Create dependent skill
    writeLines(c(
      "# Dependent Skill",
      "**Description**: Uses base skill",
      "**Requires**: base-skill",
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
      "# Skill A",
      "**Requires**: skill-b"
    ), ".cassidy/skills/skill-a.md")

    writeLines(c(
      "# Skill B",
      "**Requires**: skill-a"
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

test_that("cassidy_context_skills returns proper format", {
  withr::with_tempdir({
    dir.create(".cassidy/skills", recursive = TRUE)

    writeLines(c(
      "# Test Skill",
      "**Description**: Test description"
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
      "# Skill 1",
      "**Description**: First skill"
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
      "# Test Workflow",
      "**Description**: Test workflow",
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

test_that("cassidy_create_skill creates valid skill file", {
  withr::with_tempdir({
    suppressMessages({
      skill_path <- cassidy_create_skill("my-test-skill")
    })

    expect_true(file.exists(skill_path))

    content <- readLines(skill_path)
    expect_true(any(grepl("^# ", content)))
    expect_true(any(grepl("\\*\\*Description\\*\\*:", content)))
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
      basic_path <- cassidy_create_skill("basic-skill", template = "basic")
    })
    basic_content <- paste(readLines(basic_path), collapse = "\n")
    expect_true(grepl("Workflow Steps", basic_content))

    # Analysis template
    suppressMessages({
      analysis_path <- cassidy_create_skill("analysis-skill", template = "analysis")
    })
    analysis_content <- paste(readLines(analysis_path), collapse = "\n")
    expect_true(grepl("Analysis Steps", analysis_content))

    # Workflow template
    suppressMessages({
      workflow_path <- cassidy_create_skill("workflow-skill", template = "workflow")
    })
    workflow_content <- paste(readLines(workflow_path), collapse = "\n")
    expect_true(grepl("Workflow Phases", workflow_content))
  })
})

test_that("skills integrate with project context", {
  withr::with_tempdir({
    dir.create(".cassidy/skills", recursive = TRUE)

    writeLines(c(
      "# Project Skill",
      "**Description**: A project-specific skill"
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
      "# Project Skill",
      "**Description**: A project-specific skill"
    ), ".cassidy/skills/project-skill.md")

    # Get project context without skills
    ctx <- cassidy_context_project(level = "minimal", include_skills = FALSE)

    expect_false(grepl("Available Skills", ctx$text))
  })
})
