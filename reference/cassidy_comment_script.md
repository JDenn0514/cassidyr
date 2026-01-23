# Add explanatory comments to an R script

Sends an R script to CassidyAI to add detailed comments explaining what
each section of code does. Useful for documenting quickly-written
scripts or preparing code for sharing.

## Usage

``` r
cassidy_comment_script(
  script_path,
  output_path = "auto",
  style = c("detailed", "sections", "minimal"),
  thread_id = NULL
)
```

## Arguments

- script_path:

  Character. Path to the R script file.

- output_path:

  Character or NULL. Where to save the commented script. If NULL,
  overwrites the original (after confirmation). If "auto", creates a new
  file with "\_commented" suffix.

- style:

  Character. Comment style: "detailed" (line-by-line), "sections"
  (chunk-level), or "minimal" (key operations only).

- thread_id:

  Character or NULL. Existing thread to continue.

## Value

A `cassidy_chat` object with the commented script.

## Examples

``` r
if (FALSE) { # \dontrun{
  # Add comments and save to new file
  cassidy_comment_script("analysis/quick_efa.R", output_path = "auto")

  # Section-level comments only
  cassidy_comment_script("scripts/cleaning.R", style = "sections")

  # Preview without saving
  result <- cassidy_comment_script("my_script.R", output_path = NULL)
  cat(chat_text(result))
} # }
```
