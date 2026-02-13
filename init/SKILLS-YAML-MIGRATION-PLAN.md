# Skills YAML Frontmatter Migration Plan

## Executive Summary

Update cassidyr's skills system to use YAML frontmatter for metadata instead of markdown bold text, aligning with Claude Code's skill format. This provides better structure, easier parsing, and consistency with modern markdown conventions.

**Note**: No backwards compatibility needed - you are currently the only user, so we can make a clean break to the new format.

## Current Format Analysis

### Current Skill Structure

```markdown
# Skill Title

**Description**: Description text here
**Auto-invoke**: yes
**Requires**: dependency1, dependency2

---

## Content starts here
```

### Current Parsing Logic

**File**: `R/skills-discovery.R`

- `.parse_skill_metadata()` reads first 30 lines
- Uses regex to extract metadata from bold markdown text:
  - `^# ` for title
  - `^\\*\\*Description\\*\\*:` for description
  - `^\\*\\*Auto-invoke\\*\\*:` for auto-invoke flag
  - `^\\*\\*Requires\\*\\*:` for dependencies
- Returns list with: name, description, auto_invoke, requires, file_path

**Limitations**:
- Fragile regex parsing
- Case-sensitive field matching
- No validation of metadata structure
- Can't distinguish between metadata and content bold text
- Limited extensibility for new fields

## Proposed New Format

### YAML Frontmatter Structure

```markdown
---
name: "Skill Title"
description: "Description text here"
auto_invoke: true
requires:
  - dependency1
  - dependency2
---

# Skill Title

## Content starts here
```

### Field Specifications

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `name` | string | No | filename | Display name for skill |
| `description` | string | Yes | - | Brief description for context |
| `auto_invoke` | boolean | No | true | Whether agent can auto-invoke |
| `requires` | array | No | [] | Skill dependencies |

### Optional Future Fields

These can be easily added later:

- `version` (string) - Track skill versions
- `author` (string) - Skill creator
- `tags` (array) - Categorization tags
- `min_version` (string) - Minimum cassidyr version required
- `max_context_lines` (integer) - Limit how much context to send

## Implementation Changes

### 1. Parsing Logic (`skills-discovery.R`)

**Function**: `.parse_skill_metadata()`

**Current approach**: Regex parsing of first 30 lines

**New approach**: YAML parsing only (clean break)

```r
.parse_skill_metadata <- function(file_path) {
  tryCatch({
    # Read file content
    content <- readLines(file_path, warn = FALSE)

    # Expect YAML frontmatter (starts with ---)
    if (length(content) == 0 || content[1] != "---") {
      cli::cli_abort(c(
        "x" = "Invalid skill file format: {.file {basename(file_path)}}",
        "i" = "Skills must start with YAML frontmatter",
        "i" = "Expected first line: {.code ---}"
      ))
    }

    # Find closing ---
    yaml_end <- which(content == "---")[2]

    if (is.na(yaml_end) || yaml_end < 2) {
      cli::cli_abort(c(
        "x" = "Malformed YAML frontmatter in: {.file {basename(file_path)}}",
        "i" = "YAML block must be closed with {.code ---} on its own line"
      ))
    }

    # Extract and parse YAML block
    yaml_lines <- content[2:(yaml_end - 1)]
    yaml_text <- paste(yaml_lines, collapse = "\n")
    metadata <- yaml::yaml.load(yaml_text)

    # Validate required fields
    if (is.null(metadata$description)) {
      cli::cli_abort(c(
        "x" = "Missing required field in: {.file {basename(file_path)}}",
        "i" = "YAML frontmatter must include {.field description}"
      ))
    }

    # Extract fields with defaults
    list(
      name = metadata$name %||% tools::file_path_sans_ext(basename(file_path)),
      description = metadata$description,
      auto_invoke = metadata$auto_invoke %||% TRUE,
      requires = metadata$requires %||% character(0),
      file_path = file_path
    )

  }, error = function(e) {
    # If already a cli error, re-throw it
    if (inherits(e, "rlang_error")) {
      stop(e)
    }
    # Otherwise, wrap in a more helpful error
    cli::cli_abort(c(
      "x" = "Failed to parse skill file: {.file {basename(file_path)}}",
      "i" = "Error: {e$message}"
    ))
  })
}
```

**Dependencies**: Add `yaml` package to Imports

**Key changes**:
- Require YAML frontmatter (no fallback)
- Clear error messages for missing/malformed YAML
- Validate required fields (description)
- Simpler, more maintainable code

### 2. Template Updates (`skills-functions.R`)

**Function**: `.get_skill_template()`

Update all templates to use YAML frontmatter:

```r
# Example basic template
return(c(
  "---",
  "name: \"", title, "\"",
  "description: \"Brief description of what this skill does\"",
  "auto_invoke: true",
  "requires: []",
  "---",
  "",
  paste0("# ", title),
  "",
  "## When to Use This Skill",
  # ...rest of template...
))
```

### 3. Skill Content Loading (`skills-discovery.R`)

**Function**: `.load_skill()`

**Changes needed**: Strip YAML frontmatter when loading content

```r
.load_skill <- function(skill_name, loaded_skills = character()) {
  # ...existing validation code...

  # Load full skill content
  skill_content <- tryCatch({
    lines <- readLines(skill$file_path, warn = FALSE)

    # Strip YAML frontmatter if present
    if (length(lines) > 0 && lines[1] == "---") {
      yaml_end <- which(lines == "---")[2]
      if (!is.na(yaml_end)) {
        lines <- lines[(yaml_end + 1):length(lines)]
      }
    }

    paste(lines, collapse = "\n")
  }, error = function(e) {
    # ...error handling...
  })

  # ...rest of function...
}
```

### 4. Documentation Updates

**Files to update**:
- `.claude/rules/roadmap.md` - Update Phase 5 description
- `man/cassidy_create_skill.Rd` - Update examples
- README.md - Update skill format examples
- Vignettes (if any) - Update skill creation guides

## Migration Strategy

**Simple approach**: Clean break to YAML format (no backwards compatibility needed)

### Implementation Steps

1. Add `yaml` to DESCRIPTION Imports
2. Replace `.parse_skill_metadata()` with YAML-only version
3. Update `.load_skill()` to strip YAML frontmatter
4. Update all templates in `.get_skill_template()`
5. Convert existing skills in `.cassidy/skills/` to YAML format
6. Add tests for YAML parsing
7. Update all documentation

**Result**: Clean, modern implementation with YAML frontmatter

## Skill Creation Functions

Two complementary approaches for creating skills:

### Approach 1: Traditional Function (Current - Enhanced)

**Function**: `cassidy_create_skill()`

**Purpose**: Quick, programmatic skill creation for users who know what they want

**Enhanced signature**:
```r
cassidy_create_skill <- function(
  name,
  description = NULL,
  location = c("project", "personal"),
  template = c("basic", "analysis", "workflow"),
  auto_invoke = TRUE,
  requires = character(0),
  open = TRUE
)
```

**New parameters**:
- `description` - Optional skill description (if NULL, uses template default)
- `auto_invoke` - Whether skill can be auto-invoked (default: TRUE)
- `requires` - Character vector of skill dependencies
- `open` - Whether to open file after creation (default: TRUE)

**Example usage**:
```r
# Quick creation with template
cassidy_create_skill("my-workflow")

# Full specification
cassidy_create_skill(
  name = "survey-analysis",
  description = "Analyze Likert-scale survey data with reliability analysis",
  location = "project",
  template = "analysis",
  auto_invoke = TRUE,
  requires = c("apa-tables"),
  open = TRUE
)
```

**Benefits**:
- Fast and scriptable
- Follows R conventions
- Good for users who know what they need
- Can be used in automated workflows

### Approach 2: Interactive LLM-Assisted Creation (New)

**Function**: `cassidy_create_skill_interactive()`

**Purpose**: Guided skill creation with AI assistance

**Signature**:
```r
cassidy_create_skill_interactive <- function(
  location = c("project", "personal"),
  assistant_id = NULL,
  api_key = NULL
)
```

**Workflow**:

1. **Initial prompt**: "What would you like this skill to do?"

2. **LLM conversation**:
   - Clarifies the skill's purpose
   - Asks about when it should be used
   - Suggests appropriate metadata (auto-invoke, dependencies)
   - Helps structure workflow steps
   - Proposes examples and output format

3. **Iterative refinement**:
   - User can request changes
   - LLM adjusts the skill content
   - Shows preview of skill file

4. **Confirmation & creation**:
   - Shows final preview
   - Asks: "Create this skill? (yes/no/edit)"
   - Creates file when confirmed
   - Opens in editor

**Example interaction**:
```r
> cassidy_create_skill_interactive()

What would you like this skill to do?
> Help me analyze EFA results and write up the findings in APA format

Great! I'll help you create a skill for EFA analysis and APA reporting.

A few questions:

1. Should this skill be automatically invoked when users mention
   "EFA" or "factor analysis"? (yes/no)
> yes

2. Will this skill need any other skills? For example, you might
   want the 'apa-tables' skill for formatting. (skill names or 'none')
> apa-tables

3. What should be the main workflow steps? I'm thinking:
   - Run and interpret EFA
   - Format results in APA style
   - Generate tables and write-up

   Does this sound right, or would you like to adjust? (ok/adjust)
> ok

Perfect! I'll create a skill called 'efa-reporting' with:
- Auto-invoke: yes
- Requires: apa-tables
- Workflow steps: [shows outline]

Here's a preview:
[shows YAML frontmatter and key sections]

Create this skill? (yes/no/edit)
> yes

✓ Created skill: .cassidy/skills/efa-reporting.md
✓ Opening in editor...
```

**Implementation approach**:

```r
cassidy_create_skill_interactive <- function(
  location = c("project", "personal"),
  assistant_id = NULL,
  api_key = NULL
) {
  location <- match.arg(location)

  # Setup conversation
  cli::cli_h2("Interactive Skill Creator")
  cli::cli_text("I'll help you create a custom skill through conversation.")
  cli::cli_text("")

  # Initial context for LLM
  initial_context <- paste0(
    "You are helping a user create a cassidyr skill. Skills are markdown files ",
    "with YAML frontmatter that provide workflows and best practices.\n\n",
    "Your task:\n",
    "1. Ask clarifying questions about what the skill should do\n",
    "2. Suggest appropriate metadata (name, description, auto_invoke, requires)\n",
    "3. Help structure the workflow steps\n",
    "4. Generate the complete skill file content\n\n",
    "Skills use this format:\n",
    "---\n",
    "name: \"Skill Name\"\n",
    "description: \"Brief description\"\n",
    "auto_invoke: true\n",
    "requires:\n",
    "  - other-skill\n",
    "---\n\n",
    "# Skill Name\n\n",
    "## When to Use This Skill\n",
    "...\n\n",
    "## Workflow Steps\n",
    "...\n\n",
    "When the user is satisfied, output the final skill content in a code block ",
    "wrapped with ```markdown ... ```"
  )

  # Start chat session
  session <- cassidy_session(initial_context = initial_context)

  # Initial prompt
  cat("\n")
  user_input <- readline("What would you like this skill to do? ")

  skill_content <- NULL
  confirmed <- FALSE

  while (!confirmed) {
    # Send message and get response
    response <- cassidy_chat(user_input, session = session)

    # Check if LLM provided final skill content
    if (grepl("```markdown", response$message, fixed = TRUE)) {
      # Extract skill content from code block
      skill_content <- .extract_markdown_block(response$message)

      # Show preview
      cat("\n")
      cli::cli_h3("Skill Preview:")
      cat(skill_content)
      cat("\n\n")

      # Ask for confirmation
      confirm <- readline("Create this skill? (yes/no/edit): ")
      confirm <- tolower(trimws(confirm))

      if (confirm == "yes") {
        confirmed <- TRUE
      } else if (confirm == "edit") {
        user_input <- readline("What would you like to change? ")
      } else {
        cli::cli_alert_info("Skill creation cancelled")
        return(invisible(NULL))
      }
    } else {
      # Continue conversation
      cat("\n")
      user_input <- readline("> ")
    }
  }

  # Extract skill name from YAML
  skill_name <- .extract_skill_name_from_yaml(skill_content)

  # Create file
  skill_dir <- if (location == "project") {
    file.path(getwd(), ".cassidy/skills")
  } else {
    path.expand("~/.cassidy/skills")
  }

  if (!dir.exists(skill_dir)) {
    dir.create(skill_dir, recursive = TRUE)
  }

  skill_file <- file.path(skill_dir, paste0(skill_name, ".md"))

  # Write file
  writeLines(skill_content, skill_file)

  cli::cli_alert_success("Created skill: {.path {skill_file}}")

  # Open in editor
  if (rlang::is_installed("rstudioapi") && rstudioapi::isAvailable()) {
    rstudioapi::navigateToFile(skill_file)
  } else {
    cli::cli_alert_info("Open to edit: {.path {skill_file}}")
  }

  invisible(skill_file)
}

# Helper: Extract markdown from code block
.extract_markdown_block <- function(text) {
  # Find ```markdown ... ``` block
  pattern <- "```markdown\\s*\\n(.*?)\\n```"
  match <- regmatches(text, regexec(pattern, text, dotall = TRUE))
  if (length(match[[1]]) > 1) {
    return(match[[1]][2])
  }
  return(NULL)
}

# Helper: Extract skill name from YAML frontmatter
.extract_skill_name_from_yaml <- function(content) {
  lines <- strsplit(content, "\n")[[1]]

  # Find YAML block
  if (lines[1] != "---") return("unnamed-skill")
  yaml_end <- which(lines == "---")[2]
  if (is.na(yaml_end)) return("unnamed-skill")

  # Parse YAML
  yaml_lines <- lines[2:(yaml_end - 1)]
  yaml_text <- paste(yaml_lines, collapse = "\n")
  metadata <- yaml::yaml.load(yaml_text)

  # Convert name to filename format
  name <- metadata$name %||% "unnamed-skill"
  name <- tolower(gsub("[^a-z0-9]+", "-", name))
  name <- gsub("^-|-$", "", name)  # Remove leading/trailing hyphens

  return(name)
}
```

**Benefits**:
- Guided experience for new users
- AI helps with structure and best practices
- Iterative refinement
- Learns user's needs through conversation
- Reduces cognitive load

### Comparison

| Feature | Traditional | Interactive |
|---------|-------------|-------------|
| Speed | Fast | Slower |
| Guidance | Minimal | Extensive |
| Flexibility | High | High |
| Learning curve | Steeper | Gentle |
| API required | No | Yes |
| Scriptable | Yes | No |
| Use case | Power users | All users |

**Recommendation**: Implement both
- Traditional function for quick/programmatic creation
- Interactive function for guided creation and learning
- Users choose based on their needs and preferences

## Testing Implications

### New Test Coverage Needed

**File**: `tests/testthat/test-skills.R`

1. **YAML Parsing Tests**
   ```r
   test_that("YAML frontmatter parsing works", {
     # Test valid YAML with all fields
     # Test minimal YAML (only required fields)
     # Test with default values
   })
   ```

2. **Error Handling Tests**
   ```r
   test_that("Invalid YAML generates helpful errors", {
     # Test missing frontmatter
     # Test malformed YAML
     # Test missing required field (description)
     # Test unclosed YAML block
   })
   ```

3. **Content Loading Tests**
   ```r
   test_that("YAML frontmatter stripped from content", {
     # Ensure --- blocks don't appear in loaded content
     # Verify content starts after frontmatter
   })
   ```

4. **Template Tests**
   ```r
   test_that("Templates generate valid YAML", {
     # Test each template type (basic, analysis, workflow)
     # Validate YAML structure
     # Ensure all required fields present
   })
   ```

5. **Field Validation Tests**
   ```r
   test_that("Field parsing handles edge cases", {
     # Test empty requires array
     # Test single vs multiple dependencies
     # Test boolean auto_invoke values
     # Test name fallback to filename
   })
   ```

6. **Interactive Creation Tests** (if implemented)
   ```r
   test_that("cassidy_create_skill() with arguments works", {
     # Test with description argument
     # Test with auto_invoke = FALSE
     # Test with requires dependencies
   })
   ```

### Test Files to Create

```r
# tests/testthat/fixtures/skills/
# - skill-yaml-valid.md         (well-formed YAML, all fields)
# - skill-yaml-minimal.md       (only required: description)
# - skill-yaml-malformed.md     (invalid YAML syntax)
# - skill-no-frontmatter.md     (missing YAML, should error)
# - skill-missing-description.md (missing required field)
# - skill-with-dependencies.md  (has requires array)
```

## Package Dependencies

### New Dependency: yaml

**Add to DESCRIPTION**:
```
Imports:
    ...existing imports...,
    yaml (>= 2.3.0)
```

**Why yaml package**:
- Standard R YAML parser
- Well-maintained (last update 2023)
- Used by rmarkdown, blogdown, etc.
- Minimal additional dependencies
- ~100KB installed size

**Alternatives considered**:
- **Write custom parser**: Too fragile, reinventing wheel
- **rmarkdown's YAML functions**: Unnecessary heavy dependency
- **Regular expressions**: Insufficient for proper YAML parsing

## Potential Risks & Implications

### Risk Assessment

| Risk | Severity | Likelihood | Mitigation |
|------|----------|------------|------------|
| Breaking existing skills | Low | High | You'll manually update 3 skill files |
| YAML parsing errors | Medium | Low | Clear error messages with line numbers |
| Malformed user-created YAML | Medium | Medium | Validation in creation functions |
| Dependency bloat | Low | Low | yaml is lightweight and standard |
| Performance impact | Low | Low | Parsing only on discovery (cached) |
| Interactive function complexity | Medium | Low | Keep it simple, well-tested |

### Specific Concerns

**1. Malformed YAML**

**Issue**: Users create invalid YAML
**Impact**: Skill won't load
**Solution**:
- Clear error messages pointing to the problem
- Pre-validate YAML in `cassidy_create_skill()`
- Interactive function helps avoid errors
- Include examples in docs

**2. Quote Escaping**

**Issue**: Descriptions with quotes break YAML
**Example**: `description: He said "hello"` (invalid)
**Solution**:
- Document proper quoting
- Use validation in skill creation
- Show examples:
  ```yaml
  description: 'He said "hello"'
  # or
  description: "He said \"hello\""
  ```

**3. Field Name Changes**

**Current**: `auto_invoke` (snake_case)
**YAML option**: Could use `auto-invoke` (kebab-case) or `autoInvoke` (camelCase)
**Decision**: Keep `auto_invoke` for R consistency

**4. Array Formatting**

**YAML allows multiple formats**:
```yaml
# Flow style
requires: [dep1, dep2]

# Block style
requires:
  - dep1
  - dep2
```
**Solution**: Document block style as preferred, but accept both

**5. Empty Fields**

**Current**: `requires` can be empty string
**YAML**: Should be empty array `[]` or null
**Solution**: Handle both in parsing logic

### Impact Summary

**Breaking changes**: Yes - existing skills need manual conversion
- Only 3 skill files to update (efa-workflow, apa-tables, test-skill)
- Straightforward conversion process
- Can be done in ~15 minutes

**Documentation updates**:
- Update README with YAML format examples
- Update roxygen2 docs
- Add new interactive function docs
- Show YAML format as standard

## Implementation Checklist

### Code Changes

**Core parsing (`skills-discovery.R`)**:
- [ ] Add `yaml` to DESCRIPTION Imports
- [ ] Replace `.parse_skill_metadata()` with YAML-only version
  - [ ] Require YAML frontmatter
  - [ ] Validate required fields
  - [ ] Add helpful error messages
- [ ] Update `.load_skill()` to strip YAML frontmatter from content

**Templates (`skills-functions.R`)**:
- [ ] Update `.get_skill_template()` for YAML format
  - [ ] Update "basic" template
  - [ ] Update "analysis" template
  - [ ] Update "workflow" template

**Enhanced creation function (`skills-functions.R`)**:
- [ ] Add parameters to `cassidy_create_skill()`:
  - [ ] `description` argument
  - [ ] `auto_invoke` argument (default: TRUE)
  - [ ] `requires` argument (default: character(0))
  - [ ] `open` argument (default: TRUE)
- [ ] Update function to use new parameters in template generation
- [ ] Add YAML validation before writing file

**Interactive creation (new file: `skills-interactive.R`)**:
- [ ] Create `cassidy_create_skill_interactive()` function
- [ ] Implement conversation loop with LLM
- [ ] Add `.extract_markdown_block()` helper
- [ ] Add `.extract_skill_name_from_yaml()` helper
- [ ] Handle user confirmation/editing workflow
- [ ] Integrate with `cassidy_session()`

**Package maintenance**:
- [ ] Run `update_package_imports()` to update NAMESPACE
- [ ] Export new functions

### Testing

**Test fixtures**:
- [ ] Create `tests/testthat/fixtures/skills/` directory
- [ ] Create skill-yaml-valid.md (all fields)
- [ ] Create skill-yaml-minimal.md (required only)
- [ ] Create skill-yaml-malformed.md (invalid syntax)
- [ ] Create skill-no-frontmatter.md (should error)
- [ ] Create skill-missing-description.md (should error)
- [ ] Create skill-with-dependencies.md (has requires)

**Test cases**:
- [ ] Write tests for YAML parsing (valid cases)
- [ ] Write tests for error handling (invalid cases)
- [ ] Write tests for content loading (frontmatter stripping)
- [ ] Write tests for template generation (all 3 templates)
- [ ] Write tests for field validation (edge cases)
- [ ] Write tests for enhanced `cassidy_create_skill()` arguments
- [ ] Write tests for interactive function (if implemented)

**Package checks**:
- [ ] Run `devtools::test()` and ensure all pass
- [ ] Run `devtools::check()` for package check
- [ ] Verify no warnings or errors

### Documentation

- [ ] Update function documentation with roxygen2
- [ ] Update `.claude/rules/roadmap.md`
- [ ] Update README.md with new format examples
- [ ] Add migration notes to NEWS.md
- [ ] Update any vignettes
- [ ] Create migration guide section
- [ ] Document YAML requirements and gotchas

### Migration

- [ ] Update `.cassidy/skills/efa-workflow.md` to YAML
- [ ] Update `.cassidy/skills/apa-tables.md` to YAML
- [ ] Update `.cassidy/skills/test-skill.md` to YAML (if exists)
- [ ] Test all updated skills load correctly
- [ ] Verify dependency resolution still works

### Quality Assurance

**Functional testing**:
- [ ] Test skill discovery with YAML skills
- [ ] Test skill loading and dependency resolution
- [ ] Test `cassidy_list_skills()` output format
- [ ] Test `cassidy_use_skill()` with converted skills
- [ ] Test `cassidy_create_skill()` with new arguments
- [ ] Test `cassidy_create_skill_interactive()` (if implemented)
- [ ] Verify error messages are clear and helpful

**Integration testing**:
- [ ] Test skills in Shiny app (`cassidy_app()`)
- [ ] Test skills in agentic system (`cassidy_agentic_task()`)
- [ ] Test skill dependencies still resolve correctly
- [ ] Test skill context integration (`cassidy_context_skills()`)

**Manual testing**:
- [ ] Create a new skill with traditional function
- [ ] Create a new skill with interactive function (if implemented)
- [ ] Use skill in actual workflow
- [ ] Verify all existing skills work after conversion

### Release

- [ ] Update version number in DESCRIPTION
- [ ] Update NEWS.md with changes
- [ ] Run final `devtools::check()`
- [ ] Commit changes
- [ ] Create git tag for release
- [ ] Build and test package installation
- [ ] Update documentation website (pkgdown)

## Timeline Estimate

**Core YAML Migration**: 3-4 hours
- Update parsing logic: 1 hour
- Update templates: 30 minutes
- Convert 3 existing skills: 15 minutes
- Testing: 1-1.5 hours
- Documentation updates: 30 minutes

**Enhanced Traditional Function**: 1-2 hours
- Add new parameters: 30 minutes
- Update template generation logic: 30 minutes
- Testing: 30-60 minutes

**Interactive Function** (optional): 3-4 hours
- Core conversation loop: 1.5 hours
- Helper functions: 1 hour
- Testing and refinement: 1-1.5 hours

**Total estimates**:
- **Core migration only**: 3-4 hours
- **With enhanced function**: 4-6 hours
- **With interactive function**: 7-10 hours

**Recommendation**: Implement in phases
1. Core YAML migration first (clean, stable foundation)
2. Enhanced traditional function (quick win)
3. Interactive function as separate PR (larger feature)

## Example Conversion

### Before (Current Format)

```markdown
# EFA Workflow

**Description**: Run exploratory factor analysis following psychometric best practices
**Auto-invoke**: yes
**Requires**: apa-tables

---

## When to Use This Skill
...
```

### After (YAML Format)

```markdown
---
name: "EFA Workflow"
description: "Run exploratory factor analysis following psychometric best practices"
auto_invoke: true
requires:
  - apa-tables
---

# EFA Workflow

## When to Use This Skill
...
```

## Benefits of This Change

1. **Structured Metadata**: YAML provides formal structure vs. regex parsing
2. **Extensibility**: Easy to add new fields without breaking parsing
3. **Validation**: YAML parsers provide built-in validation
4. **Standards Compliance**: Aligns with Claude Code and common markdown conventions
5. **Tool Support**: Many editors provide YAML syntax highlighting and validation
6. **Robustness**: Less fragile than regex-based parsing
7. **Developer Experience**: Easier to work with structured data
8. **Future-Proofing**: Standard format supports evolution

## Conclusion

This migration provides significant long-term benefits with minimal disruption since you're the only current user. The clean break to YAML format eliminates technical debt and establishes a robust foundation for future development.

**Recommendations**:

1. **Phase 1: Core YAML migration** (Priority: High)
   - Clean, simple implementation
   - Convert 3 existing skills
   - Establishes modern standard
   - Estimated: 3-4 hours

2. **Phase 2: Enhanced traditional function** (Priority: Medium)
   - Quick improvement to existing function
   - Better UX without much complexity
   - Estimated: 1-2 hours

3. **Phase 3: Interactive function** (Priority: Low-Medium)
   - Significant new feature
   - Consider user demand first
   - Can be separate PR/release
   - Estimated: 3-4 hours

**Overall**: This is a solid foundation upgrade. The phased approach allows you to get the core benefits quickly while leaving room for enhancement based on real usage patterns.
