#' Generate a Quarto document skeleton from an R script
#'
#' @description
#' Reads an R script and asks CassidyAI to create a Quarto document that
#' organizes the analysis with narrative sections, code chunks, and
#' placeholders for results interpretation.
#'
#' @param script_path Character. Path to the R script file.
#' @param output_path Character or NULL. Where to save the .qmd file.
#'   If NULL, just returns the content.
#' @param doc_type Character. Type of document: "report", "methods", or
#'   "presentation".
#' @param thread_id Character or NULL. Existing thread to continue.
#'
#' @return A list with thread_id and the Quarto document content.
#'
#' @examples
#'
#' \dontrun{
#'   result <- cassidy_script_to_quarto(
#'     "analysis/efa_analysis.R",
#'     output_path = "reports/efa_report.qmd",
#'     doc_type = "report"
#'   )
#' }
#'
#' @export
cassidy_script_to_quarto <- function(
  script_path,
  output_path = NULL,
  doc_type = c("report", "methods", "presentation"),
  thread_id = NULL
) {
  doc_type <- match.arg(doc_type)

  # Validate script exists
  if (!file.exists(script_path)) {
    cli::cli_abort(c(
      "Script file not found",
      "x" = "Path: {.file {script_path}}"
    ))
  }

  # Read the script
  script_content <- paste(readLines(script_path, warn = FALSE), collapse = "\n")

  doc_instruction <- switch(
    doc_type,
    report = "Create a full analysis report with Introduction, Methods, Results, and Discussion sections.",
    methods = "Create a methods-focused document suitable for an academic paper's methods section.",
    presentation = "Create a presentation-style document with concise slides/sections."
  )

  prompt <- paste0(
    "Convert this R script into a Quarto document (.qmd).\n\n",
    doc_instruction,
    "\n\n",
    "Guidelines:\n",
    "- Add a YAML header with title, author (leave blank), and format: html\n",
    "- Break the code into logical chunks with {r} blocks\n",
    "- Add narrative text explaining what each analysis does and why\n",
    "- Add placeholder text like [INTERPRET RESULTS HERE] where I should add interpretation\n",
    "- Add placeholder text like [DESCRIBE SAMPLE HERE] where I should add descriptions\n",
    "- Use headers (##, ###) to organize sections\n",
    "- Include any necessary library() calls at the top\n\n",
    "Here's the R script:\n\n",
    "r\n",
    script_content,
    "\n```"
  )

  result <- cassidy_chat(prompt, thread_id = thread_id)

  # Save if output path provided
  if (!is.null(output_path)) {
    # Create directory if needed
    dir.create(
      dirname(output_path),
      recursive = TRUE,
      showWarnings = TRUE
    )

    # Extract content using package helper
    content <- chat_text(result)

    # Remove any markdown code fences if present
    content <- gsub("^```[a-z]*\\n?", "", content)
    content <- gsub("\\n?```$", "", content)

    writeLines(content, output_path)
    cli::cli_alert_success("Saved Quarto document to: {.file {output_path}}")
  }

  result
}


#' Add explanatory comments to an R script
#'
#' Sends an R script to CassidyAI to add detailed comments explaining
#' what each section of code does. Useful for documenting quickly-written
#' scripts or preparing code for sharing.
#'
#' @param script_path Character. Path to the R script file.
#' @param output_path Character or NULL. Where to save the commented script.
#'   If NULL, overwrites the original (after confirmation). If "auto", creates
#'   a new file with "_commented" suffix.
#' @param style Character. Comment style: "detailed" (line-by-line),
#'   "sections" (chunk-level), or "minimal" (key operations only).
#' @param thread_id Character or NULL. Existing thread to continue.
#'
#' @return A `cassidy_chat` object with the commented script.
#'
#' @examples
#' \dontrun{
#'   # Add comments and save to new file
#'   cassidy_comment_script("analysis/quick_efa.R", output_path = "auto")
#'
#'   # Section-level comments only
#'   cassidy_comment_script("scripts/cleaning.R", style = "sections")
#'
#'   # Preview without saving
#'   result <- cassidy_comment_script("my_script.R", output_path = NULL)
#'   cat(chat_text(result))
#' }
#'
#' @export
cassidy_comment_script <- function(
  script_path,
  output_path = "auto",
  style = c("detailed", "sections", "minimal"),
  thread_id = NULL
) {
  style <- match.arg(style)

  # Validate script exists

  if (!file.exists(script_path)) {
    cli::cli_abort(c(
      "Script file not found",
      "x" = "Path: {.file {script_path}}"
    ))
  }

  # Read the script
  script_content <- paste(readLines(script_path, warn = FALSE), collapse = "\n")

  # Build style-specific instructions

  style_instruction <- switch(
    style,
    detailed = paste0(
      "Add detailed comments explaining what each line or small group of lines does. ",
      "Include comments about:\n",
      "- What each variable represents\n",
      "- Why specific functions or parameters are used\n",
      "- Any assumptions or edge cases"
    ),
    sections = paste0(
      "Add section-level comments using comment blocks. ",
      "Group related code into logical sections with headers like:\n",
      "# ---- Section Name ----\n",
      "Explain what each section accomplishes without commenting every line."
    ),
    minimal = paste0(
      "Add minimal comments only for key operations, complex logic, ",
      "or non-obvious code. Keep the script clean and readable."
    )
  )

  prompt <- paste0(
    "Add explanatory comments to this R script. ",
    "Return ONLY the commented R code with no markdown formatting or explanation.\n\n",
    style_instruction,
    "\n\n",
    "Guidelines:\n",
    "- Preserve all existing code exactly as-is\n",
    "- Keep any existing comments\n",
    "- Use standard R comment style (#)\n",
    "- Be concise but informative\n",
    "- Explain the 'why' not just the 'what' where relevant\n\n",
    "Here's the script:\n\n",
    script_content
  )

  result <- cassidy_chat(prompt, thread_id = thread_id)

  # Extract the commented code
  content <- chat_text(result)

  # Clean up any markdown code fences if present

  content <- gsub("^```[a-z]*\\n?", "", content)
  content <- gsub("\\n?```$", "", content)

  # Handle output
  if (!is.null(output_path)) {
    if (output_path == "auto") {
      # Create _commented version
      ext <- tools::file_ext(script_path)
      base <- tools::file_path_sans_ext(script_path)
      output_path <- paste0(base, "_commented.", ext)
    }

    # Check if overwriting original
    if (
      normalizePath(output_path, mustWork = FALSE) ==
        normalizePath(script_path, mustWork = FALSE)
    ) {
      if (interactive()) {
        confirm <- readline("Overwrite original file? (y/n): ")
        if (!tolower(confirm) %in% c("y", "yes")) {
          cli::cli_alert_info(
            "Cancelled. Use output_path = 'auto' to save as new file."
          )
          return(result)
        }
      }
    }

    writeLines(content, output_path)
    cli::cli_alert_success("Saved commented script to: {.file {output_path}}")
  }

  result
}
