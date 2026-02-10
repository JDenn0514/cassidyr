# CassidyAI Tool Decision Workflow Setup

This directory contains configuration files for setting up the Tool Decision Workflow required by `cassidy_agentic_task()`.

## Quick Setup

### Option 1: Manual Setup (Recommended)

Follow these steps to create the workflow in CassidyAI:

1. **Login to CassidyAI** at https://app.cassidyai.com

2. **Navigate to Workflows** in the left sidebar

3. **Create New Workflow** and configure:

#### Trigger Configuration
- **Type**: Webhook
- **Settings**:
  - ✅ Enable "Return results from webhook"
  - (Optional) Add API key authentication for security

#### Action: Generate Text with Cassidy Agent
Add this prompt:

```
You are a tool selection expert for an R programming assistant.

Based on the reasoning provided, choose the most appropriate tool and parameters.

## Available Tools
{{available_tools}}

## Current Reasoning
{{reasoning}}

## Context
{{context}}

## Instructions

Choose ONE tool and provide exact parameters needed.

- If the task is complete, set status to "final"
- Otherwise set status to "continue"
- Be precise with parameters - use exact file paths

## Tool Descriptions

**read_file**: Read file contents
- Parameters: {"filepath": "path/to/file"}

**write_file**: Write content to file (RISKY)
- Parameters: {"filepath": "path/to/file", "content": "content here"}

**execute_code**: Execute R code (RISKY)
- Parameters: {"code": "R code"}

**list_files**: List files in directory
- Parameters: {"directory": ".", "pattern": "*.R"}

**search_files**: Search for text
- Parameters: {"pattern": "text", "directory": ".", "file_pattern": "*.R"}

**get_context**: Get project context
- Parameters: {"level": "minimal|standard|comprehensive"}

**describe_data**: Describe data frame
- Parameters: {"name": "df_name", "method": "basic|skim|codebook"}

## Response Format

You MUST respond with exactly these fields:

- **action**: Tool name
- **input**: Object with tool parameters
- **reasoning**: Why you chose this (10-500 chars)
- **status**: Either "continue" or "final"

Example:
{
  "action": "list_files",
  "input": {"directory": "R", "pattern": "\\.R$"},
  "reasoning": "Need to see all R files first",
  "status": "continue"
}
```

#### Structured Output Fields

Configure these exact fields:

1. **action** (Dropdown)
   - Type: String (dropdown)
   - Options: `read_file`, `write_file`, `execute_code`, `list_files`, `search_files`, `get_context`, `describe_data`
   - Description: "The tool to execute"
   - Required: Yes

2. **input** (Object)
   - Type: Object
   - Description: "Tool parameters as key-value pairs"
   - Required: Yes

3. **reasoning** (Text)
   - Type: String (text)
   - Description: "Why this action was chosen"
   - Min length: 10
   - Max length: 500
   - Required: Yes

4. **status** (Dropdown)
   - Type: String (dropdown)
   - Options: `continue`, `final`
   - Description: "Whether to continue or task is complete"
   - Required: Yes

4. **Save the Workflow**

5. **Copy the Webhook URL** from the workflow settings

6. **Add to .Renviron**:
```r
# In R console
usethis::edit_r_environ()

# Add this line:
CASSIDY_WORKFLOW_WEBHOOK=https://webhook.cassidyai.com/your-webhook-id

# Save, close, restart R
```

### Option 2: JSON Import (If Supported)

If CassidyAI supports JSON import:

1. Navigate to Workflows
2. Look for "Import" or "Upload" option
3. Upload `tool-decision-workflow.json` from this directory
4. Verify structured output fields
5. Copy webhook URL to `.Renviron`

## Testing Your Setup

After configuration, test it:

```r
library(cassidyr)

# Test with a simple read-only task
result <- cassidy_agentic_task(
  "List all R files in the current directory",
  tools = c("list_files"),
  max_iterations = 2,
  verbose = TRUE
)

print(result)
```

Expected output:
- Agent should call `list_files` tool
- Should complete in 1-2 iterations
- Result should show files found

## Troubleshooting

### Webhook URL Not Found
```
Error: Workflow webhook URL not found
```
**Solution**: Set `CASSIDY_WORKFLOW_WEBHOOK` in `.Renviron`

### Invalid Structure Error
```
Error: Workflow returned invalid structure
Missing fields: action, input, reasoning, status
```
**Solution**: Check structured output fields are configured exactly as specified above

### Wrong Status Value
```
Warning: Unexpected status value
```
**Solution**: Ensure status dropdown only has "continue" and "final" options

### Tool Not Found
```
Error: Unknown tool: tool_name
```
**Solution**: Verify action dropdown has all 7 tools listed correctly

## Advanced Configuration

### Custom Temperature
Adjust the temperature in the Generate Text action:
- Lower (0.1-0.3): More deterministic, better for structured tasks
- Higher (0.7-1.0): More creative, may be less reliable

### Custom Max Tokens
Increase if getting truncated responses:
- Default: 500 tokens
- Recommended: 500-1000 tokens
- Maximum: Depends on your CassidyAI plan

### Authentication
Add API key to webhook trigger for security:
1. Enable API key authentication in webhook settings
2. Generate and copy API key
3. Store securely (not in code!)

## Support

If you encounter issues:

1. Check workflow logs in CassidyAI platform
2. Run `cassidy_setup_workflow()` for detailed instructions
3. Verify all 4 structured output fields exist and are required
4. Test webhook with a simple curl request first

## References

- CassidyAI Docs: https://docs.cassidyai.com/en/collections/9119782-workflows
- Package Documentation: https://github.com/JDenn0514/cassidyr
- Issue Tracker: https://github.com/JDenn0514/cassidyr/issues
