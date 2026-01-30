# Implementation Plan: File Download Feature

### Overview

Add a download link that appears below assistant messages when a downloadable file (md/qmd/Rmd) is detected. The link downloads the raw file content to the project root.

---

### Step 1: Create file detection helper

**File:** `R/chat-helpers.R`

**New function:** `.detect_downloadable_files()`

- Input: raw message content (string)
- Scans for code blocks with language identifiers: `md`, `markdown`, `qmd`, `rmd`, `Rmd`
- Also detects unlabeled code blocks starting with YAML front matter (`---\n`)
- Returns a list of detected files, each with:
    - `content` - the raw file content (inside the fences)
    - `extension` - detected file type (`.md`, `.qmd`, `.Rmd`)
    - `filename` - auto-detected from content or `untitled.{ext}`
    - `start_pos` / `end_pos` - position in original text (for UI placement)

**Filename detection logic:**

1. Check for YAML `title:` field → sanitize to filename
2. Check if assistant mentioned a filename before the code block (regex for `filename.md` patterns)
3. Fallback to `untitled.{ext}`

---

### Step 2: Create download link generator

**File:** `R/chat-helpers.R`

**New function:** `.create_download_link_html()`

- Input: file info from Step 1
- Returns HTML for the download link: `📄 **Download:** [filename.md]()`
- Uses a unique ID for each download link to handle multiple files

---

### Step 3: Store raw content for downloads

**File:** `R/chat-conversation.R`

**Modify:** `conv_add_message()`

- When adding an assistant message, also run `.detect_downloadable_files()`
- Store detected files in the message object: `msg$downloadable_files`
- This preserves raw content before rendering mangles it

---

### Step 4: Modify message renderer to show download links

**File:** `R/chat-server-handlers.R`

**Modify:** `setup_message_renderer()`

- After rendering message HTML, check if `msg$downloadable_files` exists
- If yes, append download link HTML below the message
- Each link gets a unique input ID like `download_file_{msg_index}_{file_index}`

---

### Step 5: Add download handler

**File:** `R/chat-server-handlers.R`

**New function:** `setup_file_download_handlers()`

- Uses `shiny::observeEvent()` to listen for download link clicks
- On click:
    1. Get the file content from stored message data
    2. Write to project root with detected filename
    3. Show notification: “Downloaded {filename} to project root”
    4. If file exists, append number: `untitled_1.md`, `untitled_2.md`

---

### Step 6: Add CSS for download link styling

**File:** `R/chat-css.R`

- Style the download link to look clickable (blue, underlined)
- Add file icon (📄 or Font Awesome equivalent)
- Hover state

---

### Step 7: Wire up in main server

**File:** `R/chat-ui.R`

- Call `setup_file_download_handlers()` in server function

---

### Files Modified

|File|Changes|
|---|---|
|`R/chat-helpers.R`|Add `.detect_downloadable_files()`, `.create_download_link_html()`|
|`R/chat-conversation.R`|Modify `conv_add_message()` to detect/store files|
|`R/chat-server-handlers.R`|Modify renderer, add `setup_file_download_handlers()`|
|`R/chat-css.R`|Add download link styles|
|`R/chat-ui.R`|Wire up new handler|

---

### Testing Plan

1. **Manual test:** Ask Cassidy to generate a README.md with R code examples
2. **Verify:** Download link appears below message
3. **Verify:** Clicking downloads correct content to project root
4. **Verify:** Multiple files in one message each get their own link
5. **Verify:** Duplicate filenames get numbered

---

### Future Enhancements (not in this iteration)

- Switch to `commonmark` for better rendering
- Modal to choose save location
- Preview content before download
- “Download all” for multiple files
