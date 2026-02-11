# Direct Parsing Migration Guide

## What Changed?

The agentic system now uses **direct parsing** instead of CassidyAI Workflows. This means:

✅ **No workflow setup needed**
✅ **No webhook configuration**
✅ **Simpler, more reliable**
✅ **Works out of the box**

## Before (Workflow Approach)

```r
# Required setup:
# 1. Create CassidyAI Workflow
# 2. Configure structured outputs
# 3. Set CASSIDY_WORKFLOW_WEBHOOK env var
# 4. Debug workflow template variables
# 5. Fight with platform limitations

result <- cassidy_agentic_task(
  "List R files",
  workflow_webhook = Sys.getenv("CASSIDY_WORKFLOW_WEBHOOK")
)
```

## After (Direct Parsing)

```r
# Required setup:
# 1. Set CASSIDY_ASSISTANT_ID
# 2. Set CASSIDY_API_KEY
# That's it!

result <- cassidy_agentic_task(
  "List R files"
)
```

## How It Works

### 1. Assistant Response Format

The assistant now responds with structured text:

```
<TOOL_DECISION>
ACTION: list_files
INPUT: {"directory": ".", "pattern": "*.R"}
REASONING: Need to find all R files in current directory
STATUS: continue
</TOOL_DECISION>
```

### 2. Direct Parsing

R code extracts the tool decision directly from the response:
- No webhook calls
- No workflow delays
- Immediate execution

### 3. Tool Execution

Same as before - tools execute with proper error handling and safe mode.

## Breaking Changes

### Function Signature

**Removed parameter:**
- ~~`workflow_webhook`~~ - No longer needed

**Everything else stays the same:**
- `task`
- `assistant_id`
- `api_key`
- `tools`
- `max_iterations`
- `safe_mode`
- `approval_callback`
- etc.

### Environment Variables

**No longer needed:**
- ~~`CASSIDY_WORKFLOW_WEBHOOK`~~ - Can delete from .Renviron

**Still required:**
- `CASSIDY_ASSISTANT_ID`
- `CASSIDY_API_KEY`

## Migration Steps

1. **Update your code** - Remove `workflow_webhook` parameter
2. **Update .Renviron** - Remove `CASSIDY_WORKFLOW_WEBHOOK` line
3. **Test it** - Run your existing tasks

That's it!

## Example Usage

```r
library(cassidyr)

# Simple task
result <- cassidy_agentic_task(
  "List all R files in this directory"
)

# With tool restrictions
result <- cassidy_agentic_task(
  "Analyze the package structure",
  tools = c("list_files", "read_file", "get_context")
)

# With safe mode disabled (be careful!)
result <- cassidy_agentic_task(
  "Create a new helper function",
  safe_mode = FALSE
)

# With custom approval
my_approver <- function(action, input, reasoning) {
  # Auto-approve reads, ask about writes
  list(
    approved = action %in% c("read_file", "list_files"),
    input = input
  )
}

result <- cassidy_agentic_task(
  "Read and analyze code",
  approval_callback = my_approver
)
```

## Troubleshooting

### "No tool decision found in response"

The assistant didn't use the structured format. The parser will try to infer
the tool from the text, or ask the assistant to use proper format.

**Solution:** Give clearer task instructions or increase max_iterations.

### "Tool [X] is not available"

The assistant chose a tool not in your `tools` parameter.

**Solution:** Either add the tool to your `tools` list, or be more specific
about what tools to use in your task description.

### Assistant makes up results

The assistant predicts results instead of waiting for tool execution.

**Solution:** This should be fixed by the updated system prompt. If it persists,
report it as a bug.

## Benefits of Direct Parsing

1. **Simpler Setup** - No workflow configuration
2. **More Reliable** - No webhook/platform dependencies
3. **Easier Debugging** - Everything happens in R
4. **Faster** - No network overhead for tool decisions
5. **More Transparent** - Can see exactly what's being parsed
6. **Better Error Messages** - Parse errors caught and explained

## Questions?

If you encounter issues:
1. Check that your assistant is updated (may need to re-create)
2. Use `verbose = TRUE` to see what's happening
3. Set `options(cassidy.debug = TRUE)` for detailed output
4. Check the examples in `tests/manual/test-agentic-direct-parsing.R`
