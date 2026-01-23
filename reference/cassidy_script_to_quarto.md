# Generate a Quarto document skeleton from an R script

Reads an R script and asks CassidyAI to create a Quarto document that
organizes the analysis with narrative sections, code chunks, and
placeholders for results interpretation.

## Usage

``` r
cassidy_script_to_quarto(
  script_path,
  output_path = NULL,
  doc_type = c("report", "methods", "presentation"),
  thread_id = NULL
)
```

## Arguments

- script_path:

  Character. Path to the R script file.

- output_path:

  Character or NULL. Where to save the .qmd file. If NULL, just returns
  the content.

- doc_type:

  Character. Type of document: "report", "methods", or "presentation".

- thread_id:

  Character or NULL. Existing thread to continue.

## Value

A list with thread_id and the Quarto document content.

## Examples

``` r
if (FALSE) { # \dontrun{
  result <- cassidy_script_to_quarto(
    "analysis/efa_analysis.R",
    output_path = "reports/efa_report.qmd",
    doc_type = "report"
  )
} # }
```
