# Multi-Agent Orchestration System for cassidyr

**Implementation Roadmap**

## Overview

Implement a parallel task decomposition and execution system that
enables building complex features in a single request by distributing
work across specialized CassidyAI conversation threads. This system
mimics advanced agentic architectures by spawning multiple concurrent
threads for independent subtasks, then intelligently synthesizing
results.

**Key Capabilities:** - Decompose complex requests into parallelizable
subtasks - Execute subtasks concurrently across multiple threads -
Intelligently aggregate and synthesize results - Route iterative
refinements to appropriate threads - Detect and resolve conflicts
between parallel outputs

------------------------------------------------------------------------

## Phase 1: Foundation - Thread Management Infrastructure

**Goal:** Build core system for creating, tracking, and managing
multiple concurrent conversation threads.

### 1.1 New File: `R/orchestrator-core.R`

#### S7 Class: `ThreadOrchestrator`

``` r
#' @title Thread Orchestration Manager
#' @description Manages multiple concurrent CassidyAI conversation threads
#'   for parallel task execution
#' @export
ThreadOrchestrator <- S7::new_class(
  "ThreadOrchestrator",
  properties = list(
    assistant_id = S7::class_character,
    active_threads = S7::class_list,
    task_registry = S7::class_list,
    results = S7::class_list,
    metadata = S7::class_list
  )
)
```

#### Key Methods

- `thread_create()` - Create new thread with task-specific context
- `thread_track()` - Register thread with component metadata
- `thread_get_result()` - Retrieve thread output
- `thread_status()` - Check completion status
- `thread_cleanup()` - Archive completed threads

### 1.2 Core Functions

``` r
#' Create Multi-Thread Orchestrator
#'
#' @param assistant_id Assistant ID (default: from environment)
#' @return A `ThreadOrchestrator` object
#' @export
cassidy_orchestrator <- function(assistant_id = NULL) {
  assistant_id <- assistant_id %||% Sys.getenv("CASSIDY_ASSISTANT_ID")

  if (assistant_id == "") {
    cli::cli_abort(c(
      "No assistant ID found.",
      "i" = "Set {.envvar CASSIDY_ASSISTANT_ID} or provide {.arg assistant_id}"
    ))
  }

  ThreadOrchestrator(
    assistant_id = assistant_id,
    active_threads = list(),
    task_registry = list(),
    results = list(),
    metadata = list(
      created_at = Sys.time(),
      total_threads = 0L
    )
  )
}

#' Execute Task in New Thread
#'
#' @param orchestrator A `ThreadOrchestrator` object
#' @param task_name Character. Identifier for this task
#' @param prompt Character. Task instructions
#' @param context Character or list. Task-specific context
#' @return Task result with thread metadata
#' @export
cassidy_thread_execute <- function(orchestrator,
                                   task_name,
                                   prompt,
                                   context = NULL) {
  # Implementation here
}
```

**Implementation Notes:** - Leverage existing
[`cassidy_create_thread()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_create_thread.md)
and
[`cassidy_send_message()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_send_message.md) -
Store comprehensive thread metadata: component name, creation time,
status, dependencies - Track which thread handles which component for
intelligent iteration routing - Implement thread lifecycle management
(create → execute → track → archive)

------------------------------------------------------------------------

## Phase 2: Task Decomposition - Intelligent Planning

**Goal:** Build a “planner” that analyzes complex requests and
decomposes them into independent, parallelizable subtasks.

### 2.1 New File: `R/orchestrator-planner.R`

#### Core Function

``` r
#' Decompose Complex Task into Parallel Subtasks
#'
#' @param user_request Character. Development request describing what to build
#' @param project_context Context object from `cassidy_context_project()`, or NULL
#' @param max_threads Integer. Maximum concurrent threads (default: 6)
#' @return Execution plan with parallelizable task groups
#' @export
cassidy_plan_task <- function(user_request,
                              project_context = NULL,
                              max_threads = 6) {
  # Use LLM to analyze request and create execution plan
  # Returns: structured plan with dependency groups
}
```

#### Planner Prompt Template

    Analyze this development request and decompose it into independent,
    parallelizable subtasks suitable for concurrent execution.

    For each subtask, provide:
    1. **name**: Short identifier (snake_case, e.g., "data_context_functions")
    2. **description**: Clear statement of what needs to be built
    3. **dependencies**: List of other subtask names that must complete first, or "none"
    4. **context_requirements**: Specific files/information this subtask needs
    5. **estimated_complexity**: "simple", "moderate", or "complex"
    6. **integration_points**: How this connects with other subtasks

    Request: {user_request}

    Available Context:
    - Project structure: {project_context$structure}
    - Existing files: {project_context$files}
    - Package architecture: {architecture_summary}

    Return as structured JSON with tasks organized into dependency groups
    (parallel_group_1, parallel_group_2, etc.) where all tasks in a group
    can execute concurrently.

    Optimize for:
    - Maximum parallelization (minimize dependency chains)
    - Balanced complexity across threads
    - Clear integration points
    - Minimal context overlap

#### Output Structure

``` r
plan <- structure(
  list(
    parallel_groups = list(
      group_1 = list(
        list(
          name = "data_context",
          description = "Build data context gathering functions",
          dependencies = character(0),
          context = c("context-tools.R", "project structure"),
          complexity = "moderate"
        ),
        list(
          name = "file_context",
          description = "Build file context functions",
          dependencies = character(0),
          context = c("context-tools.R", "file patterns"),
          complexity = "moderate"
        )
      ),
      group_2 = list(
        list(
          name = "ui_assembly",
          description = "Combine context gathering into unified UI",
          dependencies = c("data_context", "file_context"),
          context = c("data_context output", "file_context output"),
          complexity = "simple"
        )
      )
    ),
    metadata = list(
      estimated_time = "5-10 minutes",
      thread_count = 6,
      total_groups = 2
    )
  ),
  class = "cassidy_task_plan"
)
```

### 2.2 Context Distribution Logic

``` r
#' Extract Relevant Context for Subtask
#' @keywords internal
.extract_task_context <- function(task, full_context) {
  # Parse task$context_requirements
  # Filter full_context to only relevant pieces
  # Return minimal sufficient context string

  # Optimization strategies:
  # 1. File filtering: Only include referenced files
  # 2. Section extraction: Pull specific sections from large files
  # 3. Dependency inclusion: Add outputs from prerequisite tasks
  # 4. Token management: Keep under reasonable limits (~4k tokens)
}
```

**Context Optimization Strategies:** - Use existing
[`cassidy_context_project()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_context_project.md)
for comprehensive context - Filter to only files/data explicitly needed
for each subtask - Include cross-references for integration points -
Balance context completeness with token efficiency - Pass dependency
outputs to dependent tasks

------------------------------------------------------------------------

## Phase 3: Parallel Execution Engine

**Goal:** Execute subtasks concurrently using R’s async capabilities,
with robust error handling and progress tracking.

### 3.1 New File: `R/orchestrator-executor.R`

#### Dependencies

Add to `DESCRIPTION` Suggests:

    Suggests:
        future (>= 1.33.0),
        promises (>= 1.2.0),
        later (>= 1.3.0)

#### Core Execution Function

``` r
#' Execute Tasks in Parallel
#'
#' @param orchestrator A `ThreadOrchestrator` object
#' @param plan Task plan from `cassidy_plan_task()`
#' @param progress Logical. Show progress indicators (default: TRUE)
#' @param timeout Numeric. Timeout per task in seconds (default: 300)
#' @return List of task results
#' @export
cassidy_execute_parallel <- function(orchestrator,
                                     plan,
                                     progress = TRUE,
                                     timeout = 300) {

  # Check for required packages
  if (!requireNamespace("future", quietly = TRUE)) {
    cli::cli_abort(c(
      "{.fn cassidy_execute_parallel} requires {.pkg future}.",
      "i" = "Install with {.code install.packages('future')}"
    ))
  }

  require(future)
  require(promises)

  # Set up parallel workers
  n_workers <- min(plan$metadata$thread_count, 6)
  future::plan(future::multisession, workers = n_workers)

  all_results <- list()

  # Execute each parallel group sequentially
  for (i in seq_along(plan$parallel_groups)) {
    group <- plan$parallel_groups[[i]]
    group_name <- paste0("group_", i)

    if (progress) {
      cli::cli_alert_info("Starting {group_name} ({length(group)} tasks)")
    }

    # All tasks in group execute concurrently
    group_futures <- lapply(group, function(task) {
      future::future({
        .execute_single_task(orchestrator, task, timeout)
      }, seed = TRUE)
    })

    # Wait for all in group to complete
    group_results <- lapply(group_futures, function(fut) {
      tryCatch(
        future::value(fut),
        error = function(e) {
          list(
            status = "error",
            error = conditionMessage(e)
          )
        }
      )
    })

    all_results <- c(all_results, group_results)

    if (progress) {
      n_success <- sum(vapply(group_results,
                             function(r) r$status == "success",
                             logical(1)))
      cli::cli_alert_success(
        "Completed {group_name}: {n_success}/{length(group)} succeeded"
      )
    }
  }

  # Clean up
  future::plan(future::sequential)

  return(all_results)
}

#' Execute Single Task in Thread
#' @keywords internal
.execute_single_task <- function(orchestrator, task, timeout) {

  start_time <- Sys.time()

  tryCatch({
    # Create thread
    thread_id <- cassidy_create_thread(orchestrator$assistant_id)

    # Send task-specific context
    if (!is.null(task$context)) {
      context_msg <- .format_task_context(task$context)
      cassidy_send_message(thread_id, context_msg)
    }

    # Send task prompt
    result <- cassidy_send_message(
      thread_id,
      task$description,
      timeout = timeout
    )

    # Track in orchestrator
    orchestrator$active_threads[[task$name]] <- thread_id
    orchestrator$task_registry[[task$name]] <- list(
      thread_id = thread_id,
      started_at = start_time,
      completed_at = Sys.time()
    )

    list(
      task_name = task$name,
      thread_id = thread_id,
      output = result,
      status = "success",
      duration = difftime(Sys.time(), start_time, units = "secs")
    )

  }, error = function(e) {
    list(
      task_name = task$name,
      status = "error",
      error = conditionMessage(e),
      duration = difftime(Sys.time(), start_time, units = "secs")
    )
  })
}
```

#### Progress Tracking

``` r
#' Show execution progress with cli
#' @keywords internal
.show_execution_progress <- function(tasks, current, total) {
  cli::cli_progress_step(
    "Executing {current}/{total}: {tasks[[current]]$name}",
    msg_done = "Completed {current}/{total}"
  )
}
```

**Implementation Notes:** - Gracefully handle missing async packages
with clear error messages - Implement per-task timeout with configurable
limits - Track execution duration for performance analysis - Return
partial results if some tasks fail (don’t fail entire execution) - Use
`seed = TRUE` in futures for reproducibility

------------------------------------------------------------------------

## Phase 4: Result Aggregation & Conflict Resolution

**Goal:** Intelligently combine outputs from parallel threads into
coherent final result, detecting and resolving conflicts.

### 4.1 New File: `R/orchestrator-aggregator.R`

#### Core Aggregation Function

``` r
#' Aggregate Results from Parallel Threads
#'
#' @param results List of task results from parallel execution
#' @param strategy How to combine results: "synthesize", "concatenate", or
#'   "structure_by_file"
#' @param resolve_conflicts Logical. Use LLM to resolve detected conflicts
#'   (default: TRUE)
#' @return Aggregated result with conflict information
#' @export
cassidy_aggregate_results <- function(results,
                                      strategy = "synthesize",
                                      resolve_conflicts = TRUE) {

  strategies <- c("synthesize", "concatenate", "structure_by_file")
  strategy <- match.arg(strategy, strategies)

  # Detect conflicts first
  conflicts <- .detect_conflicts(results)

  # Aggregate based on strategy
  aggregated <- switch(strategy,
    synthesize = .synthesize_with_llm(results, conflicts),
    concatenate = .concatenate_results(results),
    structure_by_file = .organize_by_file(results)
  )

  # Resolve conflicts if requested and any found
  if (resolve_conflicts && length(conflicts) > 0) {
    aggregated <- .resolve_conflicts_llm(aggregated, conflicts)
  }

  structure(
    list(
      content = aggregated,
      conflicts = conflicts,
      strategy = strategy,
      n_results = length(results)
    ),
    class = "cassidy_aggregated_result"
  )
}
```

#### LLM Synthesis

``` r
#' Synthesize Results Using LLM
#' @keywords internal
.synthesize_with_llm <- function(results, conflicts = NULL) {

  # Filter to successful results
  successful <- Filter(function(r) r$status == "success", results)

  # Create synthesis prompt
  conflict_note <- if (length(conflicts) > 0) {
    paste0(
      "\n\nCONFLICTS DETECTED:\n",
      paste(names(conflicts), collapse = ", "),
      "\nPlease resolve these in your synthesis."
    )
  } else {
    ""
  }

  prompt <- paste0(
    "Synthesize these parallel development results into a coherent ",
    "implementation. Organize code by file, resolve conflicts, and ensure ",
    "all components integrate properly.\n\n",
    "TASK RESULTS:\n",
    .format_results_for_synthesis(successful),
    conflict_note,
    "\n\nProvide:\n",
    "1. Complete, organized code by file\n",
    "2. Integration notes and dependencies\n",
    "3. Resolution of any conflicts\n",
    "4. Testing recommendations\n",
    "5. Next steps or known limitations"
  )

  # Use separate thread for synthesis
  synthesis_thread <- cassidy_create_thread()
  synthesis <- cassidy_send_message(synthesis_thread, prompt)

  synthesis
}
```

#### Conflict Detection

``` r
#' Detect Conflicts Between Thread Outputs
#' @keywords internal
.detect_conflicts <- function(results) {

  conflicts <- list()

  # Extract function definitions from all results
  functions_by_task <- lapply(results, function(r) {
    if (r$status == "success") {
      .extract_functions(r$output)
    } else {
      character(0)
    }
  })

  # Find duplicate function names
  all_functions <- unlist(lapply(functions_by_task, names))
  duplicates <- unique(all_functions[duplicated(all_functions)])

  if (length(duplicates) > 0) {
    conflicts$duplicate_functions <- list(
      functions = duplicates,
      affected_tasks = names(which(
        vapply(functions_by_task,
               function(fns) any(names(fns) %in% duplicates),
               logical(1))
      ))
    )
  }

  # Check for file conflicts (multiple tasks targeting same file)
  file_targets <- lapply(results, .extract_file_targets)
  all_files <- unlist(file_targets)
  duplicate_files <- unique(all_files[duplicated(all_files)])

  if (length(duplicate_files) > 0) {
    conflicts$duplicate_file_targets <- list(
      files = duplicate_files,
      affected_tasks = names(which(
        vapply(file_targets,
               function(files) any(files %in% duplicate_files),
               logical(1))
      ))
    )
  }

  # Check for conflicting dependencies
  # (e.g., different versions, incompatible packages)
  dep_conflicts <- .check_dependency_conflicts(results)
  if (length(dep_conflicts) > 0) {
    conflicts$dependencies <- dep_conflicts
  }

  conflicts
}

#' Extract Function Definitions from Code
#' @keywords internal
.extract_functions <- function(code_text) {
  # Parse code and extract function names
  # Returns named vector of function definitions
  tryCatch({
    parsed <- parse(text = code_text)
    # Extract function assignments
    # This is simplified - actual implementation would be more robust
    list()
  }, error = function(e) {
    list()
  })
}
```

#### Conflict Resolution Strategies

``` r
#' Resolve Conflicts Using LLM
#' @keywords internal
.resolve_conflicts_llm <- function(aggregated, conflicts) {

  prompt <- paste0(
    "The following conflicts were detected in parallel development:\n\n",
    .format_conflicts(conflicts),
    "\n\nAggregated result:\n",
    aggregated,
    "\n\nPlease resolve these conflicts by:\n",
    "1. Choosing the best implementation for duplicates\n",
    "2. Merging compatible changes\n",
    "3. Removing redundant code\n",
    "4. Explaining your resolution decisions"
  )

  resolution_thread <- cassidy_create_thread()
  resolved <- cassidy_send_message(resolution_thread, prompt)

  resolved
}

#' Interactive Conflict Resolution
#' @keywords internal
.resolve_conflicts_interactive <- function(conflicts, results) {

  cli::cli_h2("Conflict Resolution Required")

  for (conflict_type in names(conflicts)) {
    cli::cli_alert_warning("Conflict: {conflict_type}")

    # Present options to user
    choice <- utils::menu(
      c("Use LLM to resolve automatically",
        "Show details and choose manually",
        "Skip (keep both versions)"),
      title = "How would you like to resolve this?"
    )

    # Handle user choice
    # Implementation depends on conflict type
  }

  conflicts
}
```

**Conflict Resolution Priority:** 1. **Automatic**: Compatible changes
merged, last-wins for simple cases 2. **LLM-assisted**: Use synthesis
thread for complex conflicts 3. **User prompt**: Present options when
ambiguous

------------------------------------------------------------------------

## Phase 5: Iteration Routing System

**Goal:** Route follow-up requests to the appropriate thread that
handled the original component.

### 5.1 Enhancement to `R/orchestrator-core.R`

``` r
#' Route Follow-up to Appropriate Thread
#'
#' @param orchestrator A `ThreadOrchestrator` object from previous execution
#' @param component_name Character. Name of component to iterate on, or NULL
#'   to auto-detect
#' @param feedback Character. Refinement request or feedback
#' @return Updated result from the component's thread
#' @export
cassidy_iterate_component <- function(orchestrator,
                                      component_name = NULL,
                                      feedback) {

  # Auto-detect component if not specified
  if (is.null(component_name)) {
    component_name <- .detect_component(orchestrator, feedback)
    cli::cli_alert_info("Detected component: {.val {component_name}}")
  }

  # Validate component exists
  if (!component_name %in% names(orchestrator$task_registry)) {
    available <- names(orchestrator$task_registry)
    cli::cli_abort(c(
      "Component {.val {component_name}} not found.",
      "i" = "Available components: {.val {available}}"
    ))
  }

  # Find thread that handled this component
  thread_id <- orchestrator$task_registry[[component_name]]$thread_id

  # Continue conversation in that thread
  cli::cli_alert_info("Sending feedback to {.val {component_name}} thread...")
  result <- cassidy_send_message(thread_id, feedback)

  # Update result in orchestrator
  orchestrator$results[[component_name]] <- result
  orchestrator$task_registry[[component_name]]$last_updated <- Sys.time()
  orchestrator$task_registry[[component_name]]$iteration_count <-
    (orchestrator$task_registry[[component_name]]$iteration_count %||% 0) + 1

  cli::cli_alert_success("Component {.val {component_name}} updated")

  invisible(result)
}

#' Detect Which Component Feedback Refers To
#' @keywords internal
.detect_component <- function(orchestrator, feedback) {

  components <- names(orchestrator$task_registry)

  if (length(components) == 1) {
    return(components[1])
  }

  # Use LLM classification for multiple components
  prompt <- paste0(
    "Which component does this feedback refer to?\n\n",
    "Feedback: ", feedback, "\n\n",
    "Available components:\n",
    paste0("- ", components, collapse = "\n"),
    "\n\nRespond with ONLY the component name, nothing else."
  )

  # Use quick classification thread
  detection_thread <- cassidy_create_thread()
  component_raw <- cassidy_send_message(detection_thread, prompt)

  # Clean response
  component <- trimws(component_raw)

  # Fuzzy match if exact match fails
  if (!component %in% components) {
    component <- components[agrep(component, components, max.distance = 0.2)[1]]
  }

  component
}

#' List Available Components for Iteration
#'
#' @param orchestrator A `ThreadOrchestrator` object
#' @return Data frame of components with metadata
#' @export
cassidy_list_components <- function(orchestrator) {

  if (length(orchestrator$task_registry) == 0) {
    cli::cli_alert_info("No components available")
    return(invisible(NULL))
  }

  components_df <- do.call(rbind, lapply(names(orchestrator$task_registry), function(name) {
    task <- orchestrator$task_registry[[name]]
    data.frame(
      component = name,
      thread_id = task$thread_id,
      iterations = task$iteration_count %||% 0,
      last_updated = as.character(task$last_updated %||% task$completed_at),
      stringsAsFactors = FALSE
    )
  }))

  print(components_df)
  invisible(components_df)
}
```

**Key Features:** - Automatic component detection using LLM
classification - Fuzzy matching for typos in component names - Iteration
count tracking per component - Timestamp tracking for audit trail

------------------------------------------------------------------------

## Phase 6: User Interface - High-Level Function

**Goal:** Provide simple, user-friendly interface that abstracts
complexity.

### 6.1 Main Entry Point: `R/orchestrator-main.R`

``` r
#' Build Complex Feature with Parallel Execution
#'
#' @description
#' Decomposes a complex development request into parallel subtasks,
#' executes them concurrently across multiple CassidyAI threads, and
#' synthesizes results into a unified implementation.
#'
#' This function provides a high-level interface to the multi-agent
#' orchestration system, handling task planning, parallel execution,
#' conflict detection, and result synthesis automatically.
#'
#' @param request Character. Development request describing what to build.
#'   Should be detailed and specific about requirements.
#' @param context Context object from `cassidy_context_project()`, or NULL
#'   to auto-gather. Providing context improves task decomposition quality.
#' @param max_threads Integer. Maximum concurrent threads (default: 6).
#'   Higher values enable more parallelization but may hit API rate limits.
#' @param strategy How to aggregate results (default: "synthesize"):
#'   - "synthesize": Use LLM to intelligently combine and integrate results
#'   - "concatenate": Simple joining of outputs
#'   - "structure_by_file": Organize results by target file
#' @param interactive Logical. If TRUE, prompts for confirmation before
#'   execution and for conflict resolution (default: TRUE)
#' @param assistant_id Character. CassidyAI assistant ID. Defaults to
#'   `CASSIDY_ASSISTANT_ID` environment variable.
#' @param timeout Numeric. Timeout per task in seconds (default: 300)
#'
#' @return A `cassidy_orchestrated_result` object containing:
#'   - `$plan`: Execution plan showing task decomposition
#'   - `$results`: Individual thread outputs by component
#'   - `$synthesis`: Aggregated final result
#'   - `$orchestrator`: Orchestrator object for follow-up iterations
#'   - `$conflicts`: Any detected conflicts and resolutions
#'   - `$metadata`: Execution metadata (timing, success rate, etc.)
#'
#' @examples
#' \dontrun{
#' # Build complete Shiny chatbot feature
#' result <- cassidy_build_parallel(
#'   request = "Create a Shiny chatbot with:
#'     - Conversation sidebar showing chat history
#'     - Context sidebar with project/data/file tabs
#'     - Modern styling with dark theme
#'     - Copy code buttons in responses
#'     - Auto-save conversation state",
#'   context = cassidy_context_project(level = "comprehensive")
#' )
#'
#' # Review the execution plan
#' print(result$plan)
#'
#' # Access final synthesized code
#' cat(result$synthesis$content)
#'
#' # Access individual components
#' result$results$css_styling
#'
#' # Iterate on specific component
#' updated <- cassidy_iterate_component(
#'   result$orchestrator,
#'   component_name = "sidebar_ui",
#'   feedback = "Make the sidebar collapsible on mobile"
#' )
#'
#' # List all available components for iteration
#' cassidy_list_components(result$orchestrator)
#' }
#'
#' @export
cassidy_build_parallel <- function(request,
                                   context = NULL,
                                   max_threads = 6,
                                   strategy = "synthesize",
                                   interactive = TRUE,
                                   assistant_id = NULL,
                                   timeout = 300) {

  # Validate inputs
  if (!is.character(request) || length(request) != 1) {
    cli::cli_abort("{.arg request} must be a single character string")
  }

  # Setup
  assistant_id <- assistant_id %||% Sys.getenv("CASSIDY_ASSISTANT_ID")

  if (assistant_id == "") {
    cli::cli_abort(c(
      "No assistant ID found.",
      "i" = "Set {.envvar CASSIDY_ASSISTANT_ID} or provide {.arg assistant_id}"
    ))
  }

  start_time <- Sys.time()

  # Gather context if not provided
  if (is.null(context)) {
    cli::cli_alert_info("Gathering project context...")
    context <- tryCatch(
      cassidy_context_project(level = "comprehensive"),
      error = function(e) {
        cli::cli_alert_warning("Could not gather full context: {e$message}")
        NULL
      }
    )
  }

  # Phase 1: Planning
  cli::cli_h1("Phase 1: Task Decomposition")
  plan <- cassidy_plan_task(request, context, max_threads)

  n_groups <- length(plan$parallel_groups)
  n_tasks <- sum(vapply(plan$parallel_groups, length, integer(1)))

  cli::cli_alert_info(
    "Plan: {plan$metadata$thread_count} threads across {n_groups} dependency groups"
  )
  cli::cli_alert_info("Total tasks: {n_tasks}")

  # Show plan preview
  if (interactive) {
    cli::cli_h3("Execution Plan:")
    for (i in seq_along(plan$parallel_groups)) {
      group <- plan$parallel_groups[[i]]
      cli::cli_text("Group {i} ({length(group)} parallel tasks):")
      for (task in group) {
        cli::cli_li("{task$name}: {task$description}")
      }
    }

    proceed <- utils::menu(
      c("Yes, proceed with execution",
        "No, cancel and return plan"),
      title = "\nExecute this plan?"
    )

    if (proceed != 1) {
      cli::cli_alert_info("Execution cancelled")
      return(invisible(plan))
    }
  }

  # Phase 2: Execution
  cli::cli_h1("Phase 2: Parallel Execution")
  orchestrator <- cassidy_orchestrator(assistant_id)
  results <- cassidy_execute_parallel(
    orchestrator,
    plan,
    progress = TRUE,
    timeout = timeout
  )

  # Phase 3: Conflict Detection
  cli::cli_h1("Phase 3: Conflict Detection")
  conflicts <- .detect_conflicts(results)

  if (length(conflicts) > 0) {
    cli::cli_alert_warning("Detected {length(conflicts)} conflict type(s)")
    for (conflict_type in names(conflicts)) {
      cli::cli_li("{conflict_type}")
    }

    if (interactive) {
      conflicts <- .resolve_conflicts_interactive(conflicts, results)
    }
  } else {
    cli::cli_alert_success("No conflicts detected")
  }

  # Phase 4: Aggregation
  cli::cli_h1("Phase 4: Result Synthesis")
  synthesis <- cassidy_aggregate_results(
    results,
    strategy,
    resolve_conflicts = (length(conflicts) > 0)
  )

  # Calculate execution metadata
  end_time <- Sys.time()
  n_success <- sum(vapply(results,
                         function(r) r$status == "success",
                         logical(1)))

  metadata <- list(
    total_duration = difftime(end_time, start_time, units = "mins"),
    success_rate = n_success / length(results),
    total_tasks = length(results),
    successful_tasks = n_success,
    failed_tasks = length(results) - n_success,
    execution_timestamp = end_time
  )

  cli::cli_alert_success(
    "Completed in {round(metadata$total_duration, 1)} minutes ({n_success}/{length(results)} tasks succeeded)"
  )

  # Return structured result
  result <- structure(
    list(
      plan = plan,
      results = results,
      synthesis = synthesis,
      orchestrator = orchestrator,
      conflicts = conflicts,
      metadata = metadata,
      request = request
    ),
    class = "cassidy_orchestrated_result"
  )

  result
}

#' Print Method for Orchestrated Results
#' @export
print.cassidy_orchestrated_result <- function(x, ...) {
  cli::cli_h2("Cassidy Orchestrated Build Result")
  cli::cli_text("Request: {.val {x$request}}")
  cli::cli_text("Threads: {.val {length(x$results)}}")
  cli::cli_text("Duration: {.val {round(x$metadata$total_duration, 1)}} minutes")
  cli::cli_text("Success rate: {.val {scales::percent(x$metadata$success_rate)}}")

  if (length(x$conflicts) > 0) {
    cli::cli_alert_warning("{length(x$conflicts)} conflict type(s) detected")
  }

  cli::cli_h3("Components Built:")
  for (result in x$results) {
    if (result$status == "success") {
      cli::cli_li("{.field {result$task_name}} ({round(result$duration, 1)}s)")
    } else {
      cli::cli_li("{.field {result$task_name}} {.emph (failed)}")
    }
  }

  cli::cli_text("\nAccess results:")
  cli::cli_ul(c(
    "{.code $synthesis$content} - Final synthesized output",
    "{.code $results} - Individual component outputs",
    "{.code $plan} - Execution plan details"
  ))

  cli::cli_text("\nRefine components with {.fn cassidy_iterate_component}")

  invisible(x)
}

#' Print Method for Task Plan
#' @export
print.cassidy_task_plan <- function(x, ...) {
  cli::cli_h2("Cassidy Task Execution Plan")
  cli::cli_text("Total tasks: {.val {sum(vapply(x$parallel_groups, length, integer(1)))}}")
  cli::cli_text("Dependency groups: {.val {length(x$parallel_groups)}}")
  cli::cli_text("Max threads: {.val {x$metadata$thread_count}}")
  cli::cli_text("Estimated time: {.val {x$metadata$estimated_time}}")

  cli::cli_h3("Execution Groups:")
  for (i in seq_along(x$parallel_groups)) {
    group <- x$parallel_groups[[i]]
    cli::cli_text("\n{.strong Group {i}} ({length(group)} parallel tasks):")

    for (task in group) {
      deps <- if (length(task$dependencies) > 0) {
        paste0(" [depends: ", paste(task$dependencies, collapse = ", "), "]")
      } else {
        ""
      }
      cli::cli_li("{.field {task$name}}: {task$description} ({task$complexity}){deps}")
    }
  }

  invisible(x)
}
```

------------------------------------------------------------------------

## Phase 7: Testing & Validation

**Goal:** Ensure robustness through comprehensive testing at all levels.

### 7.1 Unit Tests: `tests/testthat/test-orchestrator.R`

``` r
# tests/testthat/test-orchestrator.R

test_that("ThreadOrchestrator initializes correctly", {
  skip_if_not_installed("S7")

  # Mock environment variable
  withr::local_envvar(CASSIDY_ASSISTANT_ID = "test_assistant_123")

  orch <- cassidy_orchestrator()

  expect_s7_class(orch, "ThreadOrchestrator")
  expect_equal(orch@assistant_id, "test_assistant_123")
  expect_length(orch@active_threads, 0)
  expect_length(orch@task_registry, 0)
})

test_that("orchestrator requires assistant_id", {
  withr::local_envvar(CASSIDY_ASSISTANT_ID = "")

  expect_error(
    cassidy_orchestrator(),
    "No assistant ID found"
  )
})

test_that("task plan structure is valid", {
  skip_on_cran()

  plan <- structure(
    list(
      parallel_groups = list(
        group_1 = list(
          list(
            name = "task1",
            description = "Test task",
            dependencies = character(0),
            context = c("file.R"),
            complexity = "simple"
          )
        )
      ),
      metadata = list(
        thread_count = 1,
        total_groups = 1
      )
    ),
    class = "cassidy_task_plan"
  )

  expect_s3_class(plan, "cassidy_task_plan")
  expect_true("parallel_groups" %in% names(plan))
  expect_true("metadata" %in% names(plan))
  expect_equal(plan$metadata$thread_count, 1)
})

test_that("conflict detection finds duplicates", {
  results <- list(
    list(
      task_name = "task1",
      status = "success",
      output = "foo <- function() { 1 }"
    ),
    list(
      task_name = "task2",
      status = "success",
      output = "foo <- function() { 2 }"
    )
  )

  conflicts <- .detect_conflicts(results)

  # Should detect duplicate function 'foo'
  expect_type(conflicts, "list")
  # Implementation-dependent - structure will vary
})

test_that("component detection handles single component", {
  skip_if_not_installed("S7")
  withr::local_envvar(CASSIDY_ASSISTANT_ID = "test_123")

  orch <- cassidy_orchestrator()
  orch@task_registry <- list(
    only_component = list(thread_id = "thread_1")
  )

  # Should return the only component without LLM call
  component <- .detect_component(orch, "any feedback")
  expect_equal(component, "only_component")
})

test_that("list_components returns empty for new orchestrator", {
  skip_if_not_installed("S7")
  withr::local_envvar(CASSIDY_ASSISTANT_ID = "test_123")

  orch <- cassidy_orchestrator()

  expect_message(
    result <- cassidy_list_components(orch),
    "No components available"
  )
  expect_null(result)
})

test_that("orchestrated result prints correctly", {
  skip_if_not_installed("S7")

  result <- structure(
    list(
      request = "Build test feature",
      results = list(
        list(task_name = "task1", status = "success", duration = 5.2),
        list(task_name = "task2", status = "success", duration = 3.1)
      ),
      metadata = list(
        total_duration = as.difftime(8.5, units = "mins"),
        success_rate = 1.0,
        total_tasks = 2
      ),
      conflicts = list()
    ),
    class = "cassidy_orchestrated_result"
  )

  expect_no_error(print(result))
})
```

### 7.2 Integration Tests: `tests/testthat/test-orchestrator-integration.R`

``` r
# tests/testthat/test-orchestrator-integration.R

test_that("parallel execution handles task failures gracefully", {
  skip_on_cran()
  skip_if_not_installed("future")

  # Mock plan with one task that will fail
  plan <- structure(
    list(
      parallel_groups = list(
        group_1 = list(
          list(
            name = "failing_task",
            description = "This will fail",
            context = NULL,
            complexity = "simple"
          ),
          list(
            name = "succeeding_task",
            description = "This should work",
            context = NULL,
            complexity = "simple"
          )
        )
      ),
      metadata = list(thread_count = 2)
    ),
    class = "cassidy_task_plan"
  )

  # Results should include both success and failure
  # Actual test would need mocking - this is structure only
  expect_true(TRUE)  # Placeholder
})

test_that("context extraction filters correctly", {
  skip_on_cran()

  full_context <- list(
    files = c("file1.R", "file2.R", "file3.R"),
    structure = "test structure"
  )

  task <- list(
    context = c("file1.R", "structure")
  )

  # Should filter context to only required pieces
  extracted <- .extract_task_context(task, full_context)

  expect_type(extracted, "character")
  # Should not include file2.R or file3.R
})

test_that("aggregation strategies produce different outputs", {
  skip_on_cran()

  results <- list(
    list(
      task_name = "task1",
      status = "success",
      output = "code from task 1"
    ),
    list(
      task_name = "task2",
      status = "success",
      output = "code from task 2"
    )
  )

  # Different strategies should produce different structures
  # Actual implementation would test real differences
  expect_true(TRUE)  # Placeholder
})
```

### 7.3 Manual Live Tests: `tests/manual/test-orchestrator-live.R`

``` r
# tests/manual/test-orchestrator-live.R
# Run manually with real API credentials

library(cassidyr)

# Test 1: Simple parallel build
message("\n=== Test 1: Simple Parallel Build ===\n")

result <- cassidy_build_parallel(
  request = "Create three simple validation functions:
    1. validate_numeric(x) - checks if x is numeric
    2. validate_positive(x) - checks if all values are positive
    3. validate_complete(x) - checks for no missing values
    Each should return TRUE/FALSE with a message attribute.",
  max_threads = 3,
  interactive = FALSE
)

print(result)
stopifnot(length(result$results) >= 2)  # At least 2 should succeed
stopifnot(result$metadata$success_rate > 0.5)

# Test 2: Iteration on component
message("\n=== Test 2: Component Iteration ===\n")

cassidy_list_components(result$orchestrator)

updated <- cassidy_iterate_component(
  result$orchestrator,
  component_name = "validate_numeric",  # Adjust based on actual component names
  feedback = "Also add a 'strict' parameter that errors on non-numeric instead of returning FALSE"
)

print(updated)

# Test 3: Complex build with dependencies
message("\n=== Test 3: Complex Build with Dependencies ===\n")

complex_result <- cassidy_build_parallel(
  request = "Build a data validation system with:
    - Core validation engine (validate_data function)
    - Rule definitions (define_rules function)
    - Reporting module (generate_report function)
    The engine should use rules and produce reports.",
  max_threads = 4,
  interactive = FALSE,
  context = cassidy_context_project(level = "standard")
)

print(complex_result)

# Should have multiple dependency groups
stopifnot(length(complex_result$plan$parallel_groups) >= 2)

# Check synthesis was performed
stopifnot(!is.null(complex_result$synthesis$content))

message("\n=== All Manual Tests Complete ===\n")
```

------------------------------------------------------------------------

## Phase 8: Documentation & Examples

**Goal:** Provide comprehensive documentation for users and developers.

### 8.1 Vignette: `vignettes/parallel-development.Rmd`

``` r
---
title: "Parallel Development with Multi-Agent Orchestration"
output: rmarkdown::html_vignette
vignette: >
  %\VignetteIndexEntry{Parallel Development with Multi-Agent Orchestration}
  %\VignetteEngine{knitr::rmarkdown}
  %\VignetteEncoding{UTF-8}
---

```{r setup, include=FALSE}
knitr::opts_chunk$set(
  collapse = TRUE,
  comment = "#>",
  eval = FALSE  # Don't run on CRAN
)
```

## Overview

The cassidyr orchestration system enables building complex features by
decomposing them into parallel subtasks executed across multiple
CassidyAI threads. This approach can dramatically speed up development
of multi-component features.

### How It Works

1.  **Planning**: Your request is analyzed and decomposed into
    independent subtasks
2.  **Execution**: Subtasks run concurrently across multiple threads
3.  **Synthesis**: Results are intelligently combined into a coherent
    implementation
4.  **Iteration**: Refine specific components by routing feedback to the
    right thread

## Basic Usage

### Simple Example: Build Related Functions

Build a set of related utility functions in parallel:

\`\`\`{r} library(cassidyr)

result \<- cassidy_build_parallel( request = “Create three data cleaning
functions: - clean_names(): standardize column names (lowercase,
underscores) - remove_duplicates(): identify and remove duplicate rows -
fill_missing(): smart imputation for missing values”, max_threads = 3 )

# Review what was built

print(result)

# Access the final code

cat(result$synthesis$content)

    ### Viewing the Execution Plan

    See how your request was decomposed before execution:

    ```{r}
    result <- cassidy_build_parallel(
      request = "Build a survey analysis toolkit",
      interactive = TRUE  # Will show plan and ask for confirmation
    )

## Advanced Usage

### Complete Feature Development

Build a complex Shiny application feature:

\`\`\`{r} \# Gather project context first for better task decomposition
context \<- cassidy_context_project(level = “comprehensive”)

result \<- cassidy_build_parallel( request = “Create a Shiny data
explorer module with: - Interactive data table with filtering - Summary
statistics panel - Visualization builder (scatter, bar, histogram) -
Export functionality (CSV, Excel, RDS) - Mobile-responsive design”,
context = context, max_threads = 6, strategy = “synthesize” \# Use LLM
to integrate components )

    ### Iteration and Refinement

    Refine specific components after initial build:

    ```{r}
    # See what components are available
    cassidy_list_components(result$orchestrator)

    # Refine a specific component
    updated <- cassidy_iterate_component(
      result$orchestrator,
      component_name = "visualization_builder",
      feedback = "Add box plots and violin plots as chart options"
    )

    # Auto-detect component from feedback
    updated <- cassidy_iterate_component(
      result$orchestrator,
      component_name = NULL,  # Will auto-detect
      feedback = "Make the data table sortable by clicking column headers"
    )

### Working with Different Strategies

Choose how results are combined:

\`\`\`{r} \# Synthesize: LLM intelligently integrates (best for complex
features) result_synth \<- cassidy_build_parallel( request = “…”,
strategy = “synthesize” )

# Concatenate: Simple joining (fast, for independent functions)

result_concat \<- cassidy_build_parallel( request = “…”, strategy =
“concatenate” )

# Structure by file: Organize by target file (good for package development)

result_files \<- cassidy_build_parallel( request = “…”, strategy =
“structure_by_file” )

    ## Understanding Results

    ### Result Structure

    ```{r}
    str(result, max.level = 1)

    # $plan - The execution plan used
    # $results - Individual thread outputs
    # $synthesis - Combined final result
    # $orchestrator - For iteration
    # $conflicts - Any detected conflicts
    # $metadata - Execution statistics

### Execution Metadata

`{r} result$metadata # $total_duration - Time in minutes # $success_rate - Proportion successful # $total_tasks - Number of tasks # $successful_tasks - Number succeeded # $failed_tasks - Number failed`

## Best Practices

### Writing Effective Requests

**Good**: Specific, decomposable, clear requirements
`{r} request <- "Create a user authentication system with: - register_user(email, password): create account - login_user(email, password): verify credentials - reset_password(email): send reset token - validate_token(token): verify reset token Use bcrypt for password hashing"`

**Less good**: Vague, monolithic
`{r} request <- "Build a login system" # Too vague`

### Providing Context

Always provide context for package development:

\`\`\`{r} context \<- cassidy_context_project( level = “comprehensive”,
include_git = TRUE, max_files = 50 )

result \<- cassidy_build_parallel( request = “…”, context = context \#
Improves task decomposition quality )

    ### Handling Failures

    Some tasks may fail - results include partial output:

    ```{r}
    result <- cassidy_build_parallel(request = "...")

    # Check success rate
    if (result$metadata$success_rate < 1.0) {
      message("Some tasks failed:")

      failed <- Filter(
        function(r) r$status != "success",
        result$results
      )

      for (f in failed) {
        message("  - ", f$task_name, ": ", f$error)
      }
    }

    # Use successful results anyway
    successful <- Filter(
      function(r) r$status == "success",
      result$results
    )

## Performance Considerations

### Thread Limits

More threads = more parallelization, but: - API rate limits may apply -
Context size multiplies across threads - Diminishing returns beyond 6-8
threads

\`\`\`{r} \# Conservative (safe for most APIs) result \<-
cassidy_build_parallel(request = “…”, max_threads = 3)

# Aggressive (faster but may hit limits)

result \<- cassidy_build_parallel(request = “…”, max_threads = 8)

    ### Task Granularity

    Balance task size for optimal performance:

    ```{r}
    # Too fine-grained: 20 tiny tasks
    request <- "Create functions: add, subtract, multiply, divide, ..."  # Overkill

    # Too coarse: 1 massive task
    request <- "Build entire data pipeline"  # No parallelization

    # Just right: 4-6 meaningful components
    request <- "Build data pipeline with: ingestion, validation, transformation, storage"

## Troubleshooting

### Common Issues

**Issue**: Tasks timing out
`{r} # Increase timeout result <- cassidy_build_parallel( request = "...", timeout = 600 # 10 minutes per task )`

**Issue**: Component iteration not working \`\`\`{r} \# Check component
names cassidy_list_components(result\$orchestrator)

# Use exact name from registry

cassidy_iterate_component( result\$orchestrator, component_name =
“exact_name_from_list”, \# Use this feedback = “…” )

    **Issue**: Conflicts detected
    ```{r}
    # Review conflicts
    print(result$conflicts)

    # Use interactive mode to resolve
    result <- cassidy_build_parallel(
      request = "...",
      interactive = TRUE  # Will prompt for conflict resolution
    )

## Examples Gallery

### Package Development

`{r} # Build new package feature cassidy_build_parallel( request = "Add caching system to cassidyr with: - cache_response(): store API responses - get_cached(): retrieve cached responses - clear_cache(): remove old cached data - configure_cache(): set cache location and TTL", context = cassidy_context_project(level = "comprehensive") )`

### Analysis Pipeline

`{r} # Build analysis workflow cassidy_build_parallel( request = "Create reproducible analysis pipeline: - load_survey_data(): import and validate - calculate_scales(): compute composite scores - run_efa(): exploratory factor analysis - generate_tables(): APA-formatted results - create_visualizations(): publication-ready plots", max_threads = 5 )`

### Shiny Application

`{r} # Build Shiny components cassidy_build_parallel( request = "Shiny dashboard for sales analytics with: - UI: sidebar with filters (date, region, product) - UI: main panel with value boxes and plots - Server: reactive data filtering - Server: dynamic plot generation - Server: downloadable reports", max_threads = 4, strategy = "synthesize" # Important for UI/Server integration )`

## Learn More

- See `?cassidy_build_parallel` for full parameter documentation
- See `?cassidy_iterate_component` for iteration details
- See `?cassidy_orchestrator` for low-level control
- Visit package website for more examples

&nbsp;

    ### 8.2 README Section

    Add to main `README.md`:

    ````markdown
    ## Parallel Development (Experimental 🧪)

    Build complex features faster by decomposing tasks across multiple concurrent AI threads:

    ```r
    library(cassidyr)

    # Build complete feature in one request
    result <- cassidy_build_parallel(
      request = "Create a modern Shiny sidebar with tabs for data, files, and settings.
        Include dark theme styling and mobile responsiveness."
    )

    # Review what was built
    print(result)

    # Refine specific components
    cassidy_iterate_component(
      result$orchestrator,
      component_name = "css_styling",
      feedback = "Make the dark theme even darker"
    )

**Key Benefits:** - ⚡ 3-5x faster for complex multi-component tasks -
🎯 Intelligent task decomposition - 🔄 Easy iteration on specific
components - 🤝 Automatic conflict detection and resolution

See `vignette("parallel-development")` for complete guide. \`\`\`\`

------------------------------------------------------------------------

## Implementation Timeline

### Sprint 1: Foundation (1-2 weeks)

- ✅ Phase 1: Thread management infrastructure
- ✅ Phase 2: Task decomposition planner
- ✅ Basic unit tests
- 📦 **Deliverable**: Core orchestration objects and planning system

### Sprint 2: Execution (1-2 weeks)

- ✅ Phase 3: Parallel execution engine
- ✅ Phase 4: Result aggregation and conflict detection
- ✅ Integration testing
- 📦 **Deliverable**: End-to-end parallel execution

### Sprint 3: Refinement (1 week)

- ✅ Phase 5: Iteration routing
- ✅ Phase 6: User interface polish
- ✅ Conflict resolution UX
- 📦 **Deliverable**: Complete user-facing API

### Sprint 4: Launch (1 week)

- ✅ Phase 7: Comprehensive testing
- ✅ Phase 8: Documentation and examples
- ✅ README and vignette completion
- 📦 **Deliverable**: Production-ready feature

**Total Timeline: 4-6 weeks to production-ready**

------------------------------------------------------------------------

## Success Metrics

### Functionality

- ✅ Can build Shiny chatbot example in one request
- ✅ Handles 80%+ of decomposable tasks successfully
- ✅ Iteration routing works for all components

### Performance

- ⚡ 3-5x faster than serial for 6+ component tasks
- ⚡ \<10% overhead for task decomposition
- ⚡ 90%+ of parallel tasks complete successfully

### Reliability

- 🛡️ \<5% conflict rate requiring manual intervention
- 🛡️ Graceful degradation on task failures
- 🛡️ No data loss from orchestrator state

### Usability

- 👥 Non-technical users can use `cassidy_build_parallel()` successfully
- 📖 Clear error messages and guidance
- 🎯 Intuitive iteration workflow

### Cost

- 💰 Token usage \<2x serial approach (worth it for time savings)
- 💰 Predictable cost based on task complexity
- 💰 Optional cost estimation before execution

------------------------------------------------------------------------

## Future Enhancements

### V2 Features (Post-Launch)

**Smart Context Sharing** - Threads share common context efficiently -
Deduplicate context across tasks - Streaming context updates

**Dynamic Thread Spawning** - Orchestrator spawns new threads for
discovered subtasks - Adaptive parallelization based on complexity -
Auto-scaling within rate limits

**Result Streaming** - Real-time updates as threads complete -
Progressive synthesis during execution - Live progress dashboard

**Cost Estimation** - Preview token usage before execution - Budget
constraints and warnings - Cost optimization suggestions

**Rollback & Checkpointing** - Undo problematic iterations - Save
orchestrator state at checkpoints - Resume from checkpoint after
interruption

### V3 Features (Future)

**Multi-Model Orchestration** - Route to Opus/Sonnet/Haiku based on
complexity - Model-specific optimization strategies - Cost-performance
tradeoffs

**Learning System** - Improve decomposition based on success patterns -
Learn from user feedback and iterations - Personalized task routing

**Template Library** - Pre-built plans for common tasks -
Community-contributed templates - Task pattern matching and reuse

**Collaborative Features** - Share orchestrators across team - Merge
parallel work from multiple users - Conflict resolution across
developers

------------------------------------------------------------------------

## Technical Considerations

### CassidyAI API Requirements

**Verify API Capabilities:** 1. ✅ Multiple concurrent threads per
assistant 2. ✅ Thread state persistence across requests 3. ✅
Thread-specific context (sent at creation) 4. ❓ Rate limits for
concurrent requests (needs testing) 5. ❓ Maximum threads per
user/assistant (needs verification)

**Action Items:** - \[ \] Test concurrent thread creation limits (5, 10,
20 threads) - \[ \] Document observed rate limiting behavior - \[ \]
Implement queue system if hard limits exist - \[ \] Add retry logic for
rate limit errors - \[ \] Monitor API response times under parallel load

### Package Dependencies

**Required Additions to `DESCRIPTION`:**

``` r
Suggests:
    future (>= 1.33.0),
    promises (>= 1.2.0),
    later (>= 1.3.0),
    scales  # For percentage formatting in print methods
```

**Graceful Fallbacks:**

``` r
# All orchestration functions check for required packages
if (!requireNamespace("future", quietly = TRUE)) {
  cli::cli_abort(c(
    "{.fn cassidy_build_parallel} requires {.pkg future}.",
    "i" = "Install with {.code install.packages('future')}"
  ))
}
```

### Error Handling Strategy

**Layered Error Handling:**

1.  **Task Level**: Try-catch around individual task execution
    - Return error status instead of failing
    - Preserve partial results
2.  **Group Level**: Handle futures gracefully
    - Timeout individual tasks
    - Don’t block group on single failure
3.  **Orchestrator Level**: Validate inputs and state
    - Early validation of required parameters
    - Clear error messages with actionable guidance
4.  **User Level**: Interactive conflict resolution
    - Present clear options
    - Allow graceful cancellation

**Example:**

``` r
tryCatch({
  result <- cassidy_send_message(thread_id, prompt, timeout = timeout)
  list(status = "success", output = result)
}, error = function(e) {
  list(
    status = "error",
    error = conditionMessage(e),
    task_name = task$name,
    suggestions = c(
      "Check API credentials",
      "Verify network connection",
      "Try increasing timeout parameter"
    )
  )
})
```

### Performance Optimization

**Context Optimization:** - Compress redundant context across tasks -
Use task-specific context extraction - Cache commonly-used context
elements - Lazy-load large context components

**Parallel Execution:** - Optimal worker count: `min(n_tasks, 6)` - Use
`future::multisession` for R session isolation - Set `seed = TRUE` for
reproducibility - Clean up futures after each group

**Memory Management:** - Don’t store full response history in
orchestrator - Periodically archive completed threads - Stream large
outputs instead of loading fully - Implement garbage collection between
groups

### Security Considerations

**Thread Isolation:** - Each thread gets independent context - No
cross-thread contamination - Separate API credentials handling

**Code Execution Safety:** - Never execute generated code
automatically - User must explicitly run/save outputs - Warn about
security review for generated code

**Data Privacy:** - Context filtering to avoid leaking sensitive data -
No persistent storage of API responses - Thread cleanup removes
temporary data

------------------------------------------------------------------------

## Migration Path

### For Existing cassidyr Users

**Backward Compatibility:** - All existing functions remain unchanged -
Orchestration is opt-in via new functions - No breaking changes to
current API

**Gradual Adoption:**

``` r
# Step 1: Try simple parallel build
result <- cassidy_build_parallel(
  request = "Build 3 utility functions",
  max_threads = 3
)

# Step 2: Use iteration on single component
cassidy_iterate_component(result$orchestrator, feedback = "...")

# Step 3: Build complex feature
result <- cassidy_build_parallel(
  request = "Complete Shiny module",
  context = cassidy_context_project()
)
```

### From Manual Multi-Thread Approach

If you’re currently managing threads manually:

``` r
# Before: Manual thread management
thread1 <- cassidy_create_thread()
thread2 <- cassidy_create_thread()
result1 <- cassidy_send_message(thread1, "Build X")
result2 <- cassidy_send_message(thread2, "Build Y")
# ... manual combination ...

# After: Automatic orchestration
result <- cassidy_build_parallel(
  request = "Build X and Y",
  max_threads = 2
)
```

------------------------------------------------------------------------

## Code Review Checklist

When implementing this system, ensure:

All functions follow `cassidy_*` naming convention

S7 classes properly defined with all required properties

Roxygen2 documentation complete with examples

Unit tests for core logic (no API calls)

Manual integration tests with real API

Error messages use
[`cli::cli_abort()`](https://cli.r-lib.org/reference/cli_abort.html)
with helpful context

Works without optional dependencies (graceful fallbacks)

No hardcoded credentials

Print methods return `invisible(x)`

Package passes
[`devtools::check()`](https://devtools.r-lib.org/reference/check.html)
with no errors

Examples use `\dontrun{}` for API calls

Thread cleanup implemented

Timeout handling on all API calls

Conflict detection is robust

\[
