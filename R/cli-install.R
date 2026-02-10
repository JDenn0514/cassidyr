# ══════════════════════════════════════════════════════════════════════════════
# CLI INSTALLATION - Install Cassidy CLI Tool
# Provides system-wide command-line access to cassidy agent
# ══════════════════════════════════════════════════════════════════════════════

#' Install Cassidy CLI Tool
#'
#' Installs the `cassidy` command-line tool to your system PATH, allowing you
#' to run `cassidy agent` from any directory in your terminal.
#'
#' The installation process is platform-specific:
#'
#' - **Mac/Linux**: Installs to `~/.local/bin/cassidy` (Unix executable)
#' - **Windows**: Installs to `%APPDATA%/cassidy/cassidy.bat` (batch file)
#'
#' After installation, you may need to add the installation directory to your
#' PATH if it's not already included.
#'
#' @return Invisibly returns the installation path
#' @export
#'
#' @examples
#' \dontrun{
#' # Install CLI tool
#' cassidy_install_cli()
#'
#' # After installation, use from terminal:
#' # $ cassidy agent "List all R files"
#' # $ cassidy agent              # Interactive mode
#' # $ cassidy context           # Show project context
#' # $ cassidy help              # Show help
#' }
cassidy_install_cli <- function() {
  # Find CLI script in package
  cli_script <- system.file("cli", "cassidy.R", package = "cassidyr")

  if (!file.exists(cli_script)) {
    cli::cli_abort(c(
      "CLI script not found in package",
      "x" = "Expected location: {.file {cli_script}}",
      "i" = "Reinstall cassidyr package if this persists"
    ))
  }

  if (.Platform$OS.type == "unix") {
    # ══════════════════════════════════════════════════════════════════════════
    # Mac/Linux Installation
    # ══════════════════════════════════════════════════════════════════════════

    dest <- path.expand("~/.local/bin/cassidy")
    dest_dir <- dirname(dest)

    # Create directory if needed
    if (!dir.exists(dest_dir)) {
      dir.create(dest_dir, showWarnings = FALSE, recursive = TRUE)
    }

    # Copy script
    success <- file.copy(cli_script, dest, overwrite = TRUE)

    if (!success) {
      cli::cli_abort(c(
        "Failed to copy CLI script",
        "x" = "Could not write to {.file {dest}}",
        "i" = "Check directory permissions"
      ))
    }

    # Make executable
    Sys.chmod(dest, mode = "0755")

    # Check if directory is in PATH
    path_dirs <- strsplit(Sys.getenv("PATH"), ":", fixed = TRUE)[[1]]
    in_path <- dest_dir %in% path_dirs

    cli::cli_alert_success("Installed to {.file {dest}}")

    if (!in_path) {
      cli::cli_alert_warning("{.file {dest_dir}} is not in your PATH")
      cli::cli_text("")
      cli::cli_text("Add this line to your shell profile (~/.bashrc, ~/.zshrc, etc.):")
      cli::cli_code(paste0('export PATH="$HOME/.local/bin:$PATH"'))
      cli::cli_text("")
      cli::cli_text("Then restart your terminal or run:")
      cli::cli_code(paste0('source ~/.bashrc  # or ~/.zshrc'))
    } else {
      cli::cli_alert_info("Directory is already in PATH")
      cli::cli_text("")
      cli::cli_text("Test installation with:")
      cli::cli_code("cassidy help")
    }

    invisible(dest)

  } else {
    # ══════════════════════════════════════════════════════════════════════════
    # Windows Installation
    # ══════════════════════════════════════════════════════════════════════════

    dest_dir <- file.path(Sys.getenv("APPDATA"), "cassidy")
    dest <- file.path(dest_dir, "cassidy.bat")

    # Create directory if needed
    if (!dir.exists(dest_dir)) {
      dir.create(dest_dir, showWarnings = FALSE, recursive = TRUE)
    }

    # Create batch file that calls Rscript
    batch_content <- c(
      "@echo off",
      paste0('Rscript "', cli_script, '" %*')
    )

    success <- tryCatch({
      writeLines(batch_content, dest)
      TRUE
    }, error = function(e) {
      FALSE
    })

    if (!success) {
      cli::cli_abort(c(
        "Failed to create batch file",
        "x" = "Could not write to {.file {dest}}",
        "i" = "Check directory permissions"
      ))
    }

    # Check if directory is in PATH
    path_dirs <- strsplit(Sys.getenv("PATH"), ";", fixed = TRUE)[[1]]
    in_path <- dest_dir %in% path_dirs

    cli::cli_alert_success("Installed to {.file {dest}}")

    if (!in_path) {
      cli::cli_alert_warning("{.file {dest_dir}} is not in your PATH")
      cli::cli_text("")
      cli::cli_text("To add to PATH:")
      cli::cli_ol(c(
        "Press Windows + R, type 'sysdm.cpl', press Enter",
        "Go to 'Advanced' tab, click 'Environment Variables'",
        "Under 'User variables', select 'Path', click 'Edit'",
        "Click 'New', add: {.file {dest_dir}}",
        "Click OK on all dialogs",
        "Restart your terminal"
      ))
    } else {
      cli::cli_alert_info("Directory is already in PATH")
      cli::cli_text("")
      cli::cli_text("Test installation with:")
      cli::cli_code("cassidy help")
    }

    invisible(dest)
  }
}

#' Uninstall Cassidy CLI Tool
#'
#' Removes the `cassidy` command-line tool from your system.
#'
#' @return Invisibly returns TRUE if successful, FALSE otherwise
#' @export
#'
#' @examples
#' \dontrun{
#' # Uninstall CLI tool
#' cassidy_uninstall_cli()
#' }
cassidy_uninstall_cli <- function() {
  if (.Platform$OS.type == "unix") {
    dest <- path.expand("~/.local/bin/cassidy")
  } else {
    dest <- file.path(Sys.getenv("APPDATA"), "cassidy", "cassidy.bat")
  }

  if (!file.exists(dest)) {
    cli::cli_alert_info("CLI tool is not installed at {.file {dest}}")
    return(invisible(FALSE))
  }

  success <- file.remove(dest)

  if (success) {
    cli::cli_alert_success("CLI tool uninstalled from {.file {dest}}")
  } else {
    cli::cli_alert_danger("Failed to remove {.file {dest}}")
  }

  invisible(success)
}
