# Create a CASSIDY.md configuration file

Creates a project-specific configuration file that provides automatic
context when you start
[`cassidy_app()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_app.md).
Follows similar conventions to Claude Code's CLAUDE.md files, but uses
CASSIDY.md naming.

## Usage

``` r
use_cassidy_md(
  path = ".",
  location = c("root", "hidden", "local"),
  template = c("default", "package", "analysis", "survey"),
  open = interactive()
)
```

## Arguments

- path:

  Directory where to create the file (default: current directory)

- location:

  Where to create the file: "root" (CASSIDY.md), "hidden"
  (.cassidy/CASSIDY.md), or "local" (CASSIDY.local.md for .gitignore)

- template:

  Template to use: "default", "package", "analysis", or "survey"

- open:

  Whether to open the file for editing (default: TRUE in interactive
  sessions)

## Value

Invisibly returns TRUE if file was created, FALSE if cancelled

## Details

You can create project memory files in several locations:

- `CASSIDY.md` - Project-level, checked into git (location = "root")

- `.cassidy/CASSIDY.md` - Project-level in hidden directory (location =
  "hidden")

- `CASSIDY.local.md` - Local-only, auto-gitignored (location = "local")

These files are automatically loaded when you start
[`cassidy_app()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_app.md).
You can also create modular rules in `.cassidy/rules/*.md` files.

## Examples

``` r
if (FALSE) { # \dontrun{
# Create CASSIDY.md in project root
use_cassidy_md()

# Create in .cassidy/ directory (keeps root clean)
use_cassidy_md(location = "hidden")

# Create local-only file (not shared with team)
use_cassidy_md(location = "local")

# Create a package development template
use_cassidy_md(template = "package")
} # }
```
