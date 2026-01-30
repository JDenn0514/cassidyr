# Create HTML for file download link

Generates an HTML download button/link for a file. Uses data URI
encoding to embed content directly in the href.

## Usage

``` r
.create_download_link_html(content, filename, index = 1)
```

## Arguments

- content:

  Character. File content to download.

- filename:

  Character. Suggested filename for download.

- index:

  Integer. Unique index for multiple downloads in same message.

## Value

Character. HTML string for download link.
