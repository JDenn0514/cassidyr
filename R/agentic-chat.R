# \u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550
# AGENTIC CHAT - Main Agentic Loop
# Orchestrates Assistant \u2194 Workflow \u2194 Tools for autonomous task completion
# \u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550

#' Run an Agentic Task with CassidyAI
#'
#' Execute a task where the AI assistant autonomously uses tools to accomplish
#' complex goals. Uses a hybrid architecture: Assistant for reasoning, Workflow
#' for structured tool decisions, R for execution.
#'
#' **Safe Mode** is enabled by default, requiring user approval for risky
#' operations like writing files or executing code. This protects against
#' unintended changes to your system.
#'
#' @param task Character. The task description
#' @param assistant_id Character. CassidyAI assistant ID (default: env var)
#' @param api_key Character. CassidyAI API key (default: env var)
#' @param tools Character vector. Tools to enable (default: all)
#' @param working_dir Character. Working directory (default: current)
#' @param max_iterations Integer. Max tool calls (default: 10). Use `Inf` for unlimited.
#' @param initial_context Character/list. Optional context to provide
#' @param safe_mode Logical. Require approval for risky tools? (default: TRUE)
#' @param approval_callback Function. Custom approval handler (default: NULL)
#' @param verbose Logical. Show progress? (default: TRUE)
#'
#' @return A `cassidy_agentic_result` object containing:
#'   \describe{
#'     \item{task}{The original task description}
#'     \item{final_response}{Final response or completion message}
#'     \item{iterations}{Number of iterations completed}
#'     \item{actions_taken}{List of all actions performed}
#'     \item{thread_id}{CassidyAI thread ID}
#'     \item{success}{Whether the task completed successfully}
#'   }
#'
#' @details
#' ## How It Works
#'
#' The agentic system uses direct parsing:
#'
#' 1. **Assistant** analyzes the task and chooses a tool in structured format
#' 2. **R parsing** extracts the tool decision from the response
#' 3. **R functions** execute tools with proper error handling
#' 4. **Results** are sent back to the assistant for next steps
#'
#' The assistant responds with structured `<TOOL_DECISION>` blocks that specify
#' which tool to use and what parameters to provide.
#'
#' ## Safe Mode
#'
#' When `safe_mode = TRUE` (default), risky operations require approval:
#'
#' - `write_file`: Writing/modifying files
#' - `execute_code`: Executing R code
#'
#' You'll be prompted to approve, deny, edit parameters, or view details
#' before each risky action. Safe mode can be disabled by setting
#' `safe_mode = FALSE`, but use caution!
#'
#' ## Custom Approval
#'
#' Provide your own approval logic with a callback function:
#'
#' ```r
#' my_approver <- function(action, input, reasoning) {
#'   # Auto-approve read operations, deny writes
#'   list(approved = action == "read_file", input = input)
#' }
#'
#' cassidy_agentic_task("Analyze code", approval_callback = my_approver)
#' ```
#'
#' @family agentic-functions
#' @export
#'
#' @examples
#' \dontrun{
#' # Simple task with safe mode (default)
#' result <- cassidy_agentic_task(
#'   "List all R files and describe what they do"
#' )
#'
#' # Task with limited tools (read-only)
#' result <- cassidy_agentic_task(
#'   "Analyze the package structure",
#'   tools = c("list_files", "read_file", "get_context"),
#'   max_iterations = 5
#' )
#'
#' # Unlimited iterations for complex tasks
#' result <- cassidy_agentic_task(
#'   "Refactor all test files to use modern patterns",
#'   max_iterations = Inf
#' )
#'
#' # Allow risky operations without approval (use with caution!)
#' result <- cassidy_agentic_task(
#'   "Create a helper function in R/helpers.R",
#'   safe_mode = FALSE
#' )
#'
#' # Provide initial context
#' ctx <- cassidy_context_project(level = "standard")
#' result <- cassidy_agentic_task(
#'   "Review my code and suggest improvements",
#'   initial_context = ctx$text
#' )
#' }
cassidy_agentic_task <- function(
  task,
  assistant_id = Sys.getenv("CASSIDY_ASSISTANT_ID"),
  api_key = Sys.getenv("CASSIDY_API_KEY"),
  tools = names(.cassidy_tools),
  working_dir = getwd(),
  max_iterations = 10,
  initial_context = NULL,
  safe_mode = TRUE,  # \u2190 DEFAULT TRUE
  approval_callback = NULL,
  verbose = TRUE
) {

  # Validate inputs
  if (!nzchar(task)) {
    cli::cli_abort("Task cannot be empty")
  }

  if (!nzchar(assistant_id)) {
    cli::cli_abort(c(
      "Assistant ID not found",
      "i" = "Set {.envvar CASSIDY_ASSISTANT_ID} in your {.file .Renviron}",
      "i" = "Run {.run cassidy_setup()} for guided setup"
    ))
  }

  # Warn about unlimited iterations
  if (!is.finite(max_iterations) && verbose) {
    cli::cli_alert_warning(
      "Unlimited iterations enabled. Task will run until completion or manual interrupt."
    )
  }

  # Create thread
  if (verbose) cli::cli_alert_info("Creating conversation thread...")
  thread_id <- cassidy_create_thread(assistant_id, api_key)

  # Build system prompt for assistant
  system_prompt <- .build_agentic_prompt(working_dir, max_iterations, tools)

  # Build initial message
  message <- paste0(
    system_prompt,
    if (!is.null(initial_context)) paste0("\n\nCONTEXT:\n", initial_context),
    "\n\nTASK: ", task
  )

  # Initialize tracking
  iteration <- 0
  actions_taken <- list()

  if (verbose) {
    cli::cli_alert_success("Thread: {.val {thread_id}}")
    cli::cli_rule(left = "Starting Agentic Task")
    cli::cli_text("Task: {.emph {task}}")
    cli::cli_text("Safe mode: {.val {safe_mode}}")
    cli::cli_text(
      "Max iterations: {.val {if (is.finite(max_iterations)) max_iterations else 'unlimited'}}"
    )
    cli::cli_text("")
  }

  # Main loop
  current_message <- message

  repeat {
    if (iteration >= max_iterations) {
      if (verbose) cli::cli_alert_warning("Max iterations reached")
      break
    }

    iteration <- iteration + 1

    if (verbose) {
      iter_label <- if (is.finite(max_iterations)) {
        paste("Iteration", iteration, "/", max_iterations)
      } else {
        paste("Iteration", iteration)
      }
      cli::cli_rule(left = iter_label)
    }

    # Get assistant response with tool decision
    if (verbose) cli::cli_alert_info("Consulting assistant...")
    response <- cassidy_send_message(thread_id, current_message, api_key)

    if (verbose) {
      cli::cli_text("{cli::symbol$pointer} {cli::col_silver(response$content)}")
      cli::cli_text("")
    }

    # Check for skill invocation (before tool execution)
    skill_pattern <- "<USE_SKILL>([^<]+)</USE_SKILL>"
    skill_match <- regmatches(
      response$content,
      regexpr(skill_pattern, response$content, perl = TRUE)
    )

    if (length(skill_match) > 0) {
      # Extract skill name
      skill_name <- gsub("</?USE_SKILL>", "", skill_match)
      skill_name <- trimws(skill_name)

      if (verbose) {
        cli::cli_alert_info("Loading skill: {.field {skill_name}}")
      }

      # Load skill with dependencies
      skill_result <- .load_skill(skill_name)

      if (!skill_result$success) {
        if (verbose) {
          cli::cli_alert_danger("Skill load failed: {skill_result$error}")
          cli::cli_text("")
        }
        current_message <- paste0(
          "ERROR: Failed to load skill '", skill_name, "'\n",
          skill_result$error, "\n\n",
          "Available skills: ", paste(names(.discover_skills()), collapse = ", "),
          "\n\nTry a different approach or use available tools."
        )
        next
      }

      # Show dependencies if loaded
      if (verbose && length(skill_result$dependencies) > 0) {
        cli::cli_alert_info(
          "Loaded dependencies: {.val {skill_result$dependencies}}"
        )
      }

      # Inject skill content into conversation
      if (verbose) {
        cli::cli_alert_success("Skill loaded successfully")
        cli::cli_text("")
      }

      current_message <- paste0(
        "SKILL LOADED: ", skill_name, "\n\n",
        if (length(skill_result$dependencies) > 0) {
          paste0("Dependencies loaded: ",
                 paste(skill_result$dependencies, collapse = ", "), "\n\n")
        },
        skill_result$content, "\n\n",
        strrep("-", 70), "\n\n",
        "The skill workflow has been loaded. Follow the steps above to complete the task.\n",
        "Use the available tools to execute each step."
      )

      # Record action
      actions_taken <- c(actions_taken, list(list(
        iteration = iteration,
        action = paste0("skill:", skill_name),
        input = list(skill = skill_name),
        result = paste0("Loaded skill with ",
                       length(skill_result$dependencies), " dependencies"),
        success = TRUE
      )))

      next
    }

    # Parse tool decision from response
    if (verbose) cli::cli_alert_info("Parsing tool decision...")

    decision <- tryCatch({
      .parse_tool_decision(
        response = response$content,
        available_tools = tools
      )
    }, error = function(e) {
      if (verbose) {
        cli::cli_alert_danger("Parsing error: {e$message}")
      }
      list(
        action = NULL,
        input = list(),
        status = "continue",
        reasoning = paste("Error parsing response:", e$message)
      )
    })

    # Check if done or no action specified
    if (decision$status == "final" || is.null(decision$action)) {
      if (verbose) {
        cli::cli_rule()
        if (decision$status == "final") {
          cli::cli_alert_success("Task completed!")
          cli::cli_text(decision$reasoning)
        } else {
          cli::cli_alert_warning("No tool action specified")
          cli::cli_text(decision$reasoning)
        }
      }

      return(structure(
        list(
          task = task,
          final_response = decision$reasoning,
          iterations = iteration,
          actions_taken = actions_taken,
          thread_id = thread_id,
          success = decision$status == "final"
        ),
        class = "cassidy_agentic_result"
      ))
    }

    # Validate tool is in available list
    if (!decision$action %in% tools) {
      if (verbose) {
        cli::cli_alert_danger("Workflow chose unavailable tool: {.field {decision$action}}")
        cli::cli_text("Available tools: {.field {tools}}")
        cli::cli_text("")
      }
      # Send STRONG error back to assistant
      current_message <- paste0(
        "\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\n",
        "\u274c CRITICAL ERROR \u274c\n",
        "\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\n\n",
        "The tool decision workflow selected '", decision$action, "' but this tool is NOT AVAILABLE.\n\n",
        "AVAILABLE TOOLS (you MUST choose from these):\n",
        paste0("  - ", tools, collapse = "\n"), "\n\n",
        "The tool '", decision$action, "' is NOT in the available tools list.\n",
        "You MUST select from the available tools listed above.\n\n",
        "Please analyze the task and choose the appropriate tool from the AVAILABLE TOOLS list."
      )
      next
    }

    # Handle tool execution
    if (verbose) {
      cli::cli_alert_info("Action: {.field {decision$action}}")
      cli::cli_text("Reasoning: {.emph {decision$reasoning}}")
      cli::cli_text("")
    }

    # Check approval for risky tools
    if (safe_mode && .is_risky_tool(decision$action)) {
      approval <- .request_approval(
        action = decision$action,
        input = decision$input,
        reasoning = decision$reasoning,
        callback = approval_callback
      )

      if (!approval$approved) {
        if (verbose) cli::cli_text("")
        # Send denial back
        current_message <- paste0(
          "DENIED: User did not approve the '", decision$action, "' action.\n",
          "Try a different approach or ask for clarification."
        )
        next
      }

      # Use potentially edited input
      decision$input <- approval$input
      if (verbose) cli::cli_text("")
    }

    # Execute tool
    if (verbose) cli::cli_alert_info("Executing {.field {decision$action}}...")

    result <- .execute_tool(
      tool_name = decision$action,
      input = decision$input,
      working_dir = working_dir
    )

    # Record action
    actions_taken <- c(actions_taken, list(list(
      iteration = iteration,
      action = decision$action,
      input = decision$input,
      result = if (result$success) result$result else result$error,
      success = result$success
    )))

    # Format for next message
    if (result$success) {
      if (verbose) {
        cli::cli_alert_success("Tool executed successfully")
        cli::cli_text("")
      }
      current_message <- paste0(
        "RESULT (", decision$action, "):\n",
        if (is.character(result$result)) {
          result$result
        } else {
          paste(capture.output(print(result$result)), collapse = "\n")
        }
      )
    } else {
      if (verbose) {
        cli::cli_alert_danger("Tool failed: {result$error}")
        cli::cli_text("")
      }
      current_message <- paste0(
        "ERROR (", decision$action, "):\n", result$error,
        "\n\nTry a different approach or adjust parameters."
      )
    }
  }

  # Max iterations reached
  if (verbose) {
    cli::cli_rule()
  }

  structure(
    list(
      task = task,
      final_response = "Task incomplete (max iterations reached)",
      iterations = iteration,
      actions_taken = actions_taken,
      thread_id = thread_id,
      success = FALSE
    ),
    class = "cassidy_agentic_result"
  )
}

#' Build system prompt for agentic assistant
#'
#' Creates the initial instructions for the assistant explaining its role
#' in the agentic workflow.
#'
#' @param working_dir Character. Working directory path
#' @param max_iterations Integer. Maximum iterations allowed
#'
#' @return Character. System prompt
#' @keywords internal
#' @noRd
.build_agentic_prompt <- function(working_dir, max_iterations, available_tools) {
  # Build detailed tool documentation with parameters
  tools_doc <- sapply(available_tools, function(tool_name) {
    tool <- .cassidy_tools[[tool_name]]
    if (is.null(tool)) return(paste0("  - ", tool_name))

    # Get parameter names from the handler function
    params <- names(formals(tool$handler))
    # Remove working_dir as it's added automatically
    params <- setdiff(params, "working_dir")

    param_str <- if (length(params) > 0) {
      paste0("(", paste(params, collapse = ", "), ")")
    } else {
      "()"
    }

    paste0("  - ", tool_name, param_str, ": ", tool$description)
  })

  tools_list <- paste0(tools_doc, collapse = "\n")

  # Build skills documentation
  skills <- .discover_skills()
  auto_invoke_skills <- Filter(function(s) s$auto_invoke, skills)

  skills_doc <- if (length(auto_invoke_skills) > 0) {
    skill_lines <- sapply(names(auto_invoke_skills), function(name) {
      skill <- auto_invoke_skills[[name]]
      deps <- if (length(skill$requires) > 0) {
        paste0(" [requires: ", paste(skill$requires, collapse = ", "), "]")
      } else {
        ""
      }
      paste0("  - ", name, ": ", skill$description, deps)
    })

    paste0(
      "\n\n## Available Skills (Workflows)\n",
      "You can use these pre-defined workflows when they match the task:\n",
      paste0(skill_lines, collapse = "\n"), "\n\n",
      "To use a skill, respond with:\n",
      "<USE_SKILL>skill-name</USE_SKILL>\n\n",
      "Skills provide multi-step workflows and best practices. ",
      "Use them when the task matches a skill's description."
    )
  } else {
    ""
  }

  paste0(
    "You are an expert R programming assistant working in: ", working_dir, "\n\n",
    "## Your Role\n",
    "You execute tasks by choosing and using tools OR skills. Each iteration:\n",
    "1. You analyze the current situation\n",
    "2. You choose ONE tool OR skill to use\n",
    "3. The tool/skill executes and returns results\n",
    "4. You analyze results and repeat until task is complete\n\n",
    "## Available Tools\n",
    "You can ONLY use these tools (with their exact parameter names):\n",
    tools_list, "\n\n",
    skills_doc,
    "IMPORTANT: Use the EXACT parameter names shown above. For example:\n",
    "  read_file uses: {\"filepath\": \"path/to/file.R\"}\n",
    "  write_file uses: {\"filepath\": \"path/to/file.R\", \"content\": \"text\"}\n",
    "  list_files uses: {\"directory\": \".\", \"pattern\": \"*.R\"}\n\n",
    "## Response Format\n\n",
    "For TOOLS, use this EXACT format:\n\n",
    "<TOOL_DECISION>\n",
    "ACTION: tool_name\n",
    "INPUT: {\"param1\": \"value1\", \"param2\": \"value2\"}\n",
    "REASONING: Explain why you chose this tool and these parameters\n",
    "STATUS: continue\n",
    "</TOOL_DECISION>\n\n",
    "For SKILLS, use this format:\n\n",
    "<USE_SKILL>skill-name</USE_SKILL>\n\n",
    "## Important Rules\n",
    "- Choose either a TOOL or a SKILL, not both at once\n",
    "- Skills provide workflows; tools perform actions\n",
    "- ACTION must be ONE of the available tools listed above\n",
    "- INPUT must be valid JSON with the tool's required parameters\n",
    "- STATUS is 'continue' (unless task is complete, then see below)\n",
    "- DO NOT make up or predict tool results - wait for actual execution\n",
    "- Use ONLY tools/skills from the available lists\n\n",
    "## Task Completion\n",
    "When you receive tool results that fully satisfy the task, respond with:\n\n",
    "TASK COMPLETE: [summary of what was accomplished with actual results]\n\n",
    if (is.finite(max_iterations)) {
      paste0("You have ", max_iterations, " iterations to complete this task.")
    } else {
      "You have unlimited iterations to complete this task."
    }
  )
}

#' Print method for agentic results
#'
#' @param x A `cassidy_agentic_result` object
#' @param ... Additional arguments (unused)
#'
#' @return Invisibly returns x
#' @export
print.cassidy_agentic_result <- function(x, ...) {
  cli::cli_rule(left = "Agentic Task Result")
  cli::cli_text("Task: {.emph {x$task}}")
  cli::cli_text("Success: {.val {x$success}}")
  cli::cli_text("Iterations: {.val {x$iterations}}")
  cli::cli_text("Actions taken: {.val {length(x$actions_taken)}}")
  cli::cli_text("")

  if (x$success) {
    cli::cli_h2("Result")
    cli::cli_text(x$final_response)
  } else {
    cli::cli_alert_warning(x$final_response)
  }

  if (length(x$actions_taken) > 0) {
    cli::cli_text("")
    cli::cli_h2("Actions Taken")
    for (i in seq_along(x$actions_taken)) {
      action <- x$actions_taken[[i]]
      status_symbol <- if (action$success) {
        cli::col_green(cli::symbol$tick)
      } else {
        cli::col_red(cli::symbol$cross)
      }
      cli::cli_text(
        "{status_symbol} {i}. {.field {action$action}} (iteration {action$iteration})"
      )
    }
  }

  cli::cli_rule()

  invisible(x)
}
