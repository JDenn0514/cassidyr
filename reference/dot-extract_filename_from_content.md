# Extract filename from file content

Attempts to detect a filename from YAML front matter title field. Falls
back to "untitled" with appropriate extension.

## Usage

``` r
.extract_filename_from_content(content, extension)
```

## Arguments

- content:

  Character. File content.

- extension:

  Character. File extension (e.g., ".md").

## Value

Character. Detected or default filename.
