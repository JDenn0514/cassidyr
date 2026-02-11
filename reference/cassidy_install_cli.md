# Install Cassidy CLI Tool

Installs the `cassidy` command-line tool to your system PATH, allowing
you to run `cassidy agent` from any directory in your terminal.

## Usage

``` r
cassidy_install_cli()
```

## Value

Invisibly returns the installation path

## Details

The installation process is platform-specific:

- **Mac/Linux**: Installs to `~/.local/bin/cassidy` (Unix executable)

- **Windows**: Installs to `%APPDATA%/cassidy/cassidy.bat` (batch file)

After installation, you may need to add the installation directory to
your PATH if it's not already included.

## Examples

``` r
if (FALSE) { # \dontrun{
# Install CLI tool
cassidy_install_cli()

# After installation, use from terminal:
# $ cassidy agent "List all R files"
# $ cassidy agent              # Interactive mode
# $ cassidy context           # Show project context
# $ cassidy help              # Show help
} # }
```
