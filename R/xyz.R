#' Detect and update package imports
#'
#' @param pkg_path Path to your package root directory
#' @param package_file Name of your package documentation file (default: "cassidyr-package.R")
#' @param dry_run If TRUE, shows what would be changed without writing (default: TRUE)
#' @noRd
update_package_imports <- function(
  pkg_path = ".",
  package_file = "cassidyr-package.R",
  dry_run = TRUE
) {
  # Step 1: Detect all imports from your R files
  cat("Scanning R files for imports...\n")
  r_files <- list.files(
    file.path(pkg_path, "R"),
    pattern = "\\.R$",
    full.names = TRUE
  )

  # Exclude the package file itself from scanning
  r_files <- r_files[!grepl(package_file, r_files)]

  imports <- list()

  for (file in r_files) {
    content <- readLines(file, warn = FALSE)
    # Find package::function patterns
    matches <- gregexpr("([a-zA-Z0-9.]+)::([a-zA-Z0-9._]+)", content)

    for (i in seq_along(content)) {
      # Skip lines that are roxygen comments
      if (grepl("^\\s*#'", content[i])) {
        next
      }

      if (matches[[i]][1] != -1) {
        text <- content[i]
        start <- matches[[i]]
        len <- attr(matches[[i]], "match.length")

        for (j in seq_along(start)) {
          full_call <- substr(text, start[j], start[j] + len[j] - 1)
          parts <- strsplit(full_call, "::")[[1]]
          pkg <- parts[1]
          func <- parts[2]

          if (!pkg %in% names(imports)) {
            imports[[pkg]] <- character()
          }
          imports[[pkg]] <- unique(c(imports[[pkg]], func))
        }
      }
    }
  }

  # Sort packages and functions alphabetically
  imports <- imports[order(names(imports))]
  imports <- lapply(imports, sort)

  cat("\nDetected imports:\n")
  for (pkg in names(imports)) {
    cat(sprintf("  %s: %s\n", pkg, paste(imports[[pkg]], collapse = ", ")))
  }

  # Step 2: Read current package file
  package_file_path <- file.path(pkg_path, "R", package_file)

  if (file.exists(package_file_path)) {
    current_content <- readLines(package_file_path, warn = FALSE)
    cat(sprintf("\nCurrent %s file found.\n", package_file))
  } else {
    current_content <- character()
    cat(sprintf("\n%s file not found. Will create new file.\n", package_file))
  }

  # Step 3: Generate new content
  new_content <- generate_package_file(imports)

  # Step 4: Show comparison
  cat("\n", rep("=", 60), "\n", sep = "")
  cat("PROPOSED NEW CONTENT:\n")
  cat(rep("=", 60), "\n", sep = "")
  cat(paste(new_content, collapse = "\n"))
  cat("\n", rep("=", 60), "\n\n", sep = "")

  # Step 5: Write file if not dry run
  if (!dry_run) {
    writeLines(new_content, package_file_path)
    cat(sprintf("✓ Updated %s\n", package_file_path))
    cat("Don't forget to run devtools::document() to update NAMESPACE!\n")
  } else {
    cat("DRY RUN MODE - No files were changed.\n")
    cat(sprintf("Set dry_run = FALSE to update %s\n", package_file))
  }

  invisible(imports)
}


#' Generate package documentation file content
#' @noRd
generate_package_file <- function(imports, max_line_length = 80) {
  lines <- character()

  # Header
  lines <- c(
    lines,
    "#' @keywords internal",
    "#' @aliases cassidyr-package NULL",
    '"_PACKAGE"',
    ""
  )

  # Add importFrom statements
  if (length(imports) > 0) {
    lines <- c(lines, "## usethis namespace: start")

    for (pkg in names(imports)) {
      funcs <- imports[[pkg]]

      # Start with the @importFrom line
      first_line <- sprintf("#' @importFrom %s", pkg)
      current_line <- first_line
      remaining_funcs <- funcs
      func_lines <- character()

      # Add functions to the line until we exceed max_line_length
      for (i in seq_along(funcs)) {
        test_line <- paste(current_line, funcs[i])

        if (nchar(test_line) <= max_line_length || current_line == first_line) {
          # Add to current line
          current_line <- test_line
        } else {
          # Save current line and start a new continuation line
          func_lines <- c(func_lines, current_line)
          current_line <- paste0("#'   ", funcs[i])
        }
      }

      # Add the last line
      func_lines <- c(func_lines, current_line)

      # Add all lines for this package
      lines <- c(lines, func_lines)
    }

    lines <- c(lines, "## usethis namespace: end")
    lines <- c(lines, "NULL")
  }

  lines
}
