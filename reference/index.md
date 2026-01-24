# Package index

## Chat Interface

Interactive chat with AI assistants

- [`cassidy_app()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_app.md)
  : Launch Cassidy Interactive Chat Application
- [`cassidy_chat()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_chat.md)
  : Chat with CassidyAI
- [`cassidy_session()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_session.md)
  : Create a stateful chat session
- [`cassidy_continue()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_continue.md)
  : Continue an existing conversation
- [`chat()`](https://jdenn0514.github.io/cassidyr/reference/chat.md) :
  Send a message within a session
- [`chat_text()`](https://jdenn0514.github.io/cassidyr/reference/chat_text.md)
  : Extract text content from a chat result

## API Functions

Low-level API interaction

- [`cassidy_create_thread()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_create_thread.md)
  : Create a new CassidyAI conversation thread
- [`cassidy_send_message()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_send_message.md)
  : Send Message to Cassidy Thread
- [`cassidy_get_thread()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_get_thread.md)
  : Retrieve conversation history from a thread
- [`cassidy_list_threads()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_list_threads.md)
  : List all threads for an assistant

## Context Gathering

Collect project and data context for AI assistance

- [`cassidy_context_project()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_context_project.md)
  : Gather project context
- [`cassidy_context_data()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_context_data.md)
  : Gather context from data frames in environment
- [`cassidy_context_env()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_context_env.md)
  : Get current environment snapshot
- [`cassidy_context_combined()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_context_combined.md)
  : Combine Multiple Contexts
- [`cassidy_context_git()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_context_git.md)
  : Get Git repository status and recent commits

## Data Description

Describe data frames and detect issues

- [`cassidy_describe_df()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_describe_df.md)
  : Describe a data frame for AI context
- [`cassidy_describe_variable()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_describe_variable.md)
  : Describe a single variable in detail
- [`cassidy_detect_issues()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_detect_issues.md)
  : Detect potential data quality issues
- [`cassidy_describe_codebook()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_describe_codebook.md)
  : Format data frame description for LLM context

## File Context

Read and summarize files

- [`cassidy_describe_file()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_describe_file.md)
  : Read File Contents as Context
- [`cassidy_file_summary()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_file_summary.md)
  : Summarize Project Files
- [`cassidy_read_context_file()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_read_context_file.md)
  : Read CASSIDY.md or similar context configuration files

## Environment Info

Gather R session information

- [`cassidy_list_objects()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_list_objects.md)
  : List objects in global environment
- [`cassidy_session_info()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_session_info.md)
  : Get session info formatted for LLM

## Conversation Management

Save, load, and export conversations

- [`cassidy_save_conversation()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_save_conversation.md)
  : Save a conversation to disk
- [`cassidy_load_conversation()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_load_conversation.md)
  : Load a conversation from disk
- [`cassidy_list_conversations()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_list_conversations.md)
  : List all saved conversations
- [`cassidy_delete_conversation()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_delete_conversation.md)
  : Delete a saved conversation
- [`cassidy_export_conversation()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_export_conversation.md)
  : Export a conversation as Markdown

## Code Helpers

Write code and files from chat responses

- [`cassidy_write_code()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_write_code.md)
  : Write Cassidy code to file and show explanation in console
- [`cassidy_write_file()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_write_file.md)
  : Write Cassidy response to a file

## Script Tools

Transform and document R scripts

- [`cassidy_script_to_quarto()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_script_to_quarto.md)
  : Generate a Quarto document skeleton from an R script
- [`cassidy_comment_script()`](https://jdenn0514.github.io/cassidyr/reference/cassidy_comment_script.md)
  : Add explanatory comments to an R script

## Configuration

Setup and configuration

- [`use_cassidy_md()`](https://jdenn0514.github.io/cassidyr/reference/use_cassidy_md.md)
  : Create a CASSIDY.md configuration file
