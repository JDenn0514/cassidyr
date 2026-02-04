#' Get Git repository status and recent commits
#'
#' @param repo Path to Git repository (default: current directory)
#' @param include_commits Whether to include recent commit history
#' @param n_commits Number of recent commits to include (default: 5)
#'
#' @return Character string with formatted Git information, or NULL if no Git repo
#' @export
#'
#' @examples
#' \dontrun{
#' # Basic Git status
#' cassidy_context_git()
#'
#' # Include recent commits
#' cassidy_context_git(include_commits = TRUE)
#'
#' # More commits
#' cassidy_context_git(include_commits = TRUE, n_commits = 10)
#' }
cassidy_context_git <- function(
  repo = ".",
  include_commits = FALSE,
  n_commits = 5
) {
  if (!.has_git()) {
    return(NULL)
  }

  # Try using gert package if available
  if (requireNamespace("gert", quietly = TRUE)) {
    return(.git_status_gert(repo, include_commits, n_commits))
  }

  # Fall back to system git commands
  .git_status_system(repo, include_commits, n_commits)
}

# Helper: Get Git status using gert package
.git_status_gert <- function(repo, include_commits, n_commits) {
  tryCatch(
    {
      # Get basic info
      info <- gert::git_info(repo = repo)
      status <- gert::git_status(repo = repo)

      git_text <- "## Git Status\n"
      git_text <- paste0(git_text, "Branch: ", info$shorthand, "\n")

      # Check for uncommitted changes
      n_changed <- nrow(status)
      if (n_changed > 0) {
        git_text <- paste0(
          git_text,
          "Status: ",
          n_changed,
          " uncommitted changes\n"
        )

        # Show what's changed
        staged <- status[status$staged, ]
        unstaged <- status[!status$staged, ]

        if (nrow(staged) > 0) {
          git_text <- paste0(git_text, "Staged files: ", nrow(staged), "\n")
        }
        if (nrow(unstaged) > 0) {
          git_text <- paste0(git_text, "Unstaged files: ", nrow(unstaged), "\n")
        }
      } else {
        git_text <- paste0(git_text, "Status: clean\n")
      }

      # Add commit history if requested
      if (include_commits) {
        commits <- gert::git_log(max = n_commits, repo = repo)

        if (nrow(commits) > 0) {
          git_text <- paste0(git_text, "\n### Recent Commits:\n")
          for (i in 1:nrow(commits)) {
            commit_date <- format(commits$time[i], "%Y-%m-%d")
            git_text <- paste0(
              git_text,
              "- ",
              commit_date,
              ": ",
              commits$message[i],
              " (",
              commits$author[i],
              ")\n"
            )
          }
        }
      }

      git_text
    },
    error = function(e) {
      cli::cli_alert_warning("Error reading Git status with gert")
      .git_status_system(repo, include_commits, n_commits)
    }
  )
}

# Helper: Get Git status using system commands
.git_status_system <- function(repo, include_commits, n_commits) {
  tryCatch(
    {
      if (Sys.which("git") == "") {
        return(NULL)
      }

      old_wd <- getwd()
      on.exit(setwd(old_wd))
      setwd(repo)

      branch <- system(
        "git branch --show-current",
        intern = TRUE,
        ignore.stderr = TRUE
      )
      status <- system(
        "git status --porcelain",
        intern = TRUE,
        ignore.stderr = TRUE
      )
      clean <- length(status) == 0

      git_text <- "## Git Status\n"
      git_text <- paste0(git_text, "Branch: ", branch, "\n")
      git_text <- paste0(
        git_text,
        "Status: ",
        if (clean) "clean" else paste(length(status), "uncommitted changes"),
        "\n"
      )

      # Add commit history if requested
      if (include_commits) {
        # Use simpler format that works cross-platform
        log_cmd <- paste0(
          'git log -n ',
          n_commits,
          ' --pretty=format:"%h|%an|%ad|%s" --date=short'
        )
        commits <- suppressWarnings(
          system(log_cmd, intern = TRUE, ignore.stderr = TRUE)
        )

        if (length(commits) > 0 && !any(grepl("^fatal:", commits))) {
          git_text <- paste0(git_text, "\n### Recent Commits:\n")
          for (commit in commits) {
            # Split by | but handle cases where message might contain |
            parts <- strsplit(commit, "\\|", fixed = FALSE)[[1]]
            if (length(parts) >= 4) {
              # Rejoin message parts if split
              msg <- paste(parts[4:length(parts)], collapse = "|")
              git_text <- paste0(
                git_text,
                "- ",
                parts[3],
                ": ",
                msg,
                " (",
                parts[2],
                ")\n"
              )
            }
          }
        }
      }

      git_text
    },
    error = function(e) {
      NULL
    }
  )
}


# Check for Git repository
.has_git <- function() {
  dir.exists(".git")
}
