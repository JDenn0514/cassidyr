# Detect downloadable files in message content

Scans a message for code blocks that represent downloadable files
(markdown, Quarto, R Markdown). Extracts content and metadata.

## Usage

``` r
.detect_downloadable_files(content)
```

## Arguments

- content:

  Character. Raw message content from assistant.

## Value

List of detected files, each with: content, extension, filename. Returns
empty list if no downloadable files found.
