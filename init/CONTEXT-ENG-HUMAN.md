# Understanding Context Management in cassidyr

**A Human-Oriented Guide to Token Management and Long Conversations**

---

## The Problem We're Solving

Imagine you're having a conversation with someone who has a **fixed-size notebook** where they write down everything you say. At first, there's plenty of space. But after an hour of conversation, the notebook fills up. When they try to write your next message, there's no room left, and the conversation **suddenly crashes**.

This is what happens with CassidyAI's API (and most LLM APIs). The "notebook" is called **context**, and its size is measured in **tokens** (roughly words or word pieces). CassidyAI has a hard limit of **200,000 tokens** per request.

Here's the catch: CassidyAI doesn't have a "forget old stuff" feature. It sends your **entire conversation history** to Claude every single time you send a message. So as your conversation grows, each message gets closer to filling up that 200K token notebook.

When you finally exceed the limit, the API returns a 500 error and your conversation dies. No warning, no graceful degradation—just a crash.

**Our context management system prevents this from happening.**

---

## Key Concepts

### What Are Tokens?

Think of tokens as **pieces of text** that the AI model processes. They're usually:
- Individual words ("hello" = 1 token)
- Parts of words ("understanding" might be 2-3 tokens: "under", "stand", "ing")
- Punctuation and spaces (also count as tokens)

A rough rule of thumb: **1 token ≈ 0.75 English words** or **1 token ≈ 3-4 characters**.

For example:
- "Hello, world!" ≈ 4 tokens
- A paragraph (100 words) ≈ 130 tokens
- A full R script (500 lines) ≈ 5,000-10,000 tokens

### Why 200,000 Tokens Is Both Big and Small

**It sounds like a lot:**
- 200K tokens ≈ 150,000 words
- A typical novel is 80,000-100,000 words
- You can fit a small book in the context window

**But it fills up fast in real use:**
- Your first message includes **project context** (files, data, git status) = 10,000-20,000 tokens
- A back-and-forth conversation of 50 messages = 30,000-50,000 tokens
- Tool calls and results (code execution, file reading) = 5,000-10,000 tokens per operation
- After an hour of work, you're approaching the limit

### The Core Problem: No Server-Side Management

Here's what makes this especially tricky with CassidyAI:

1. **No auto-compaction:** The API doesn't automatically summarize or drop old messages. It sends your raw, complete thread history every time.

2. **No token counting API:** You can't ask "how many tokens is my thread?" before sending. You have to estimate.

3. **Hard failure:** When you exceed the limit, you get a 500 error. There's no "you're at 95% capacity" warning.

This is why we need a **client-side context management system** built into cassidyr.

---

## Our Solution: Transparent Token Tracking + Automatic Compaction

The context management system has three layers of defense:

### 1. **Awareness** - You can always see token usage

Every time you interact with cassidyr, you'll see how much of your token budget you're using:

```r
session <- cassidy_session()
chat(session, "Hello!")
print(session)
#> Cassidy Session
#> Thread ID: thread_abc123
#> Messages: 2
#> Tokens: 1,250 / 200,000 (0.6%)
```

In the Shiny app, there's a visual progress bar:
```
[████░░░░░░░░░░░░░░] 25%
50,000 / 200,000 tokens
```

**Why this matters:** You're never surprised. You know when you're approaching limits.

### 2. **Warnings** - Proactive alerts before trouble

At **80% capacity** (160K tokens), you'll get warnings:

```r
chat(session, "Another question...")
#> ⚠ Token usage is high: 162,000/200,000 (81%)
#> ℹ Consider running cassidy_compact() or the conversation may fail soon
```

In the Shiny app, the token display turns **yellow** at 60%, **red** at 80%.

**Why this matters:** You have time to act before hitting the limit.

### 3. **Auto-Compaction** - Automatic conversation summarization

At **85% capacity** (170K tokens), the system automatically compacts your conversation:

```r
chat(session, "Yet another message...")
#> ⚠ Approaching token limit (172,000 tokens, threshold: 170,000)
#> ℹ Auto-compacting conversation history...
#> ✔ Compaction complete. Continuing with your message...
```

**Why this matters:** Your conversation doesn't crash. It keeps going seamlessly.

---

## How Compaction Works (The Magic Behind the Scenes)

When your conversation gets too long, cassidyr performs a **three-step compaction**:

### Step 1: Ask Claude to Summarize

The system takes your conversation history and asks Claude (via CassidyAI) to create a concise summary. The prompt is carefully designed to preserve:

- **Key decisions** you made and why
- **Unresolved issues** or open questions
- **Important outputs** (code, insights, data findings)
- **Next steps** or action items
- **Critical context** needed to continue productively

And to discard:
- Redundant information
- Intermediate work steps
- Old tool outputs that are no longer relevant
- Conversational fluff

This is based on [Anthropic's context engineering guidelines](https://docs.anthropic.com/en/docs/build-with-claude/prompt-engineering/long-context-tips).

### Step 2: Create a New Thread

Since CassidyAI doesn't let you edit old thread history, we create a **brand new thread** and send the summary as the first message, framed like this:

> "This is a continuation of our previous conversation. Here is a summary of what we discussed: [summary]. We will continue our conversation from here."

Claude acknowledges the context and you're ready to continue.

### Step 3: Preserve Recent Messages

The **most recent messages** (default: last 2 exchanges) are kept verbatim, not summarized. This ensures immediate context is fresh and accurate.

**The Result:**
- Your 50-message conversation (100K tokens) becomes a 5-message conversation (20K tokens)
- You have 80% of your token budget back
- Claude remembers the important parts of your conversation
- You can keep working without interruption

---

## Token Estimation: How We Count Without Counting

Since CassidyAI doesn't provide token counts, we **estimate** using a simple heuristic:

**~3 characters = 1 token** (with a 15% safety buffer)

We arrived at this through empirical testing:
- Sent messages with known character counts
- Recorded when we hit the 200K token limit
- Calculated the average ratio
- Added a safety factor

This works well because:
- It's fast (just character counting)
- It's conservative (we overestimate slightly)
- It's consistent (same method everywhere)

The system offers three estimation modes:
- **Fast** (default): 3:1 ratio - balanced
- **Conservative**: 2.5:1 ratio - more cautious, earlier warnings
- **Optimistic**: 3.5:1 ratio - for prose-heavy conversations

You can adjust if you find estimates are off:
```r
session <- cassidy_session()
cassidy_estimate_tokens("Some text", method = "conservative")
```

---

## Understanding Token Budget with Tools

When you use the **agentic system** with tools, tokens are consumed by three things:

1. **Tool definitions** - Each tool adds ~150 tokens for its schema and instructions
2. **Tool calls** - When Claude decides to use a tool, that's a message (~200-500 tokens)
3. **Tool results** - The output from executing the tool (varies widely: 1K-10K tokens)

For example, if you have 5 tools active:
- Base overhead: 500 tokens (instructions)
- Per-tool overhead: 5 × 150 = 750 tokens
- **Total reserved: 1,250 tokens**

The system automatically reserves this from your budget:
```
Effective limit = 200,000 - 1,250 = 198,750 tokens
```

When checking if compaction is needed, it uses the effective limit, not the raw limit.

### Why Tool Results Are Heavy

When Claude executes a tool like `read_file`, the result includes:
- The file path
- The full file contents
- Possibly thousands of lines of code

A single file read can consume 5,000-10,000 tokens. After 10-15 tool operations, you've used a significant chunk of your budget.

**Lightweight compaction idea (future):**
After a tool succeeds and its output is used, we could **clear that tool result** from history after a few turns, keeping only a summary. This is cheaper than full compaction.

---

## Practical Examples

### Example 1: A Normal Conversation (No Compaction Needed)

```r
session <- cassidy_session()

chat(session, "Help me analyze this dataset")
#> Tokens: 5,200 / 200,000 (3%)

chat(session, "What patterns do you see?")
#> Tokens: 8,400 / 200,000 (4%)

chat(session, "Create a visualization")
#> Tokens: 12,100 / 200,000 (6%)

# ... 20 more messages ...

print(session)
#> Tokens: 42,000 / 200,000 (21%)
#> ℹ Plenty of room remaining
```

**What happens:** Nothing special. Token tracking happens silently in the background.

---

### Example 2: A Long Debugging Session (Manual Compaction)

```r
session <- cassidy_session(auto_compact = FALSE)  # Disable auto

# ... 100 messages of back-and-forth debugging ...

print(session)
#> ⚠ Token usage is high: 175,000/200,000 (88%)

# Manually compact before continuing
session <- cassidy_compact(session)
#> ℹ Requesting conversation summary from assistant...
#> ℹ Creating new compacted thread...
#> ✔ Compaction complete: 100 messages reduced to 8 messages
#> ℹ Token estimate: 38,000 (19%)

chat(session, "Okay, let's try a different approach")
#> Tokens: 41,200 / 200,000 (21%)
```

**What happens:** You notice you're approaching the limit, manually compact, then continue with a fresh budget.

---

### Example 3: Automatic Compaction (Hands-Off)

```r
session <- cassidy_session(auto_compact = TRUE)  # Default

# ... many messages ...

chat(session, "Continue with the analysis")
#> ⚠ Approaching token limit (172,000 tokens, threshold: 170,000)
#> ℹ Auto-compacting conversation history...
#> ℹ Requesting conversation summary from assistant...
#> ℹ Creating new compacted thread...
#> ✔ Compaction complete. Continuing with your message...
#> [Claude's response to your original message]

# Your message was sent AFTER compaction, automatically
```

**What happens:** The system detects the upcoming limit, compacts, then sends your message. You don't have to do anything.

---

### Example 4: Checking Session Stats

```r
session <- cassidy_session()
# ... long conversation ...

stats <- cassidy_session_stats(session)
print(stats)
#> Session Statistics
#> Session ID: thread_xyz789
#> Created: 2026-02-17 14:32:10
#> Messages: 64 (32 user, 32 assistant)
#>
#> Token Usage
#> [████████████████████░░░░░░░░░░░] 67%
#> 134,000 / 200,000 tokens
#> Remaining: 66,000 tokens
#>
#> Breakdown
#> Context: 12,000 tokens
#> Messages: 122,000 tokens
#>
#> Settings
#> Auto-Compact: Enabled
#> Compact Threshold: 170,000 tokens
```

**What happens:** You get a detailed breakdown of where your tokens are going.

---

## Design Philosophy: Why We Made These Choices

### Default: Auto-Compact Enabled

**Decision:** Auto-compaction is **ON by default** in `cassidy_session()`.

**Why:**
- Without it, users will hit hard failures (500 errors)
- The API provides no graceful degradation
- Most users don't want to think about token management
- It's better to auto-compact than to crash

**Opt-out available:**
```r
session <- cassidy_session(auto_compact = FALSE)
```

### Threshold: 85% Before Compaction

**Decision:** Auto-compact at **170K tokens** (85% of 200K limit).

**Why:**
- Gives room for a large message + response after compaction
- Avoids compacting too eagerly (which disrupts flow)
- Ensures we don't hit the limit even with token estimation errors
- Users get a warning at 80%, compaction at 85%

**Adjustable:**
```r
session <- cassidy_session(compact_at = 0.90)  # More aggressive (wait longer)
session <- cassidy_session(compact_at = 0.75)  # More cautious (compact earlier)
```

### Preserve Recent Messages

**Decision:** Keep the last **2 message pairs** (4 messages total) verbatim during compaction.

**Why:**
- Immediate context is most important
- Recent messages haven't had time to "settle" into the conversation
- Summarizing your last exchange feels jarring
- You might reference "what we just discussed"

**Adjustable:**
```r
session <- cassidy_compact(session, preserve_recent = 5)  # Keep last 5 pairs
```

### Estimation, Not Counting

**Decision:** Use **character-based estimation** instead of trying to get exact token counts.

**Why:**
- CassidyAI doesn't provide a token counting endpoint
- Client-side tokenization libraries are heavy dependencies
- Estimation is fast and good enough with a safety buffer
- We optimize for simplicity and speed

### Immutable Sessions

**Decision:** `chat()` returns an updated session object; you must capture it.

```r
session <- chat(session, "message")  # CORRECT
chat(session, "message")             # WRONG - session not updated
```

**Why:**
- This is idiomatic R (same pattern as `dplyr`, `purrr`, etc.)
- Avoids hidden state mutation (easier to reason about)
- Makes it clear when state changes
- Users familiar with tidyverse expect this pattern

**Trade-off:** Requires discipline to capture return values. We document this clearly.

---

## Mental Models

### The Notebook Analogy (Again)

Think of your conversation as a **notebook**:
- Each message you send is written on a new page
- Claude reads the entire notebook every time to understand context
- The notebook has exactly **200,000 lines** (tokens)
- When full, you can't write anymore

**Compaction** is like:
- Tearing out the old pages
- Writing a summary of them on a single new page
- Stapling that summary to the front
- Continuing with fresh pages

You now have room for thousands more lines, but you haven't lost the important information from the old pages.

### The Conversation Highway Analogy

Imagine tokens as **cars on a highway** (context window):
- The highway has a **200,000 car capacity**
- Every message you send is a convoy of cars entering the highway
- The highway never clears—old cars stay forever (no API compaction)
- Eventually, the highway is at capacity and you can't add more cars

**Token tracking** = Highway signs showing "85% full"

**Auto-compaction** = Opening an express lane that compresses 100 cars into 10 cars (summarization), clearing space

---

## Common Questions

### "What if compaction loses important context?"

We preserve:
- Key decisions and reasoning
- Unresolved issues
- Important outputs
- Recent messages (verbatim)

What we discard:
- Redundant information (you asked the same thing twice)
- Superseded work (you fixed a bug three times before getting it right)
- Intermediate steps (the journey to the solution, not the solution itself)

If you're worried, you can:
- Increase `preserve_recent` to keep more messages
- Use a custom `summary_prompt` to control what's preserved
- Keep `auto_compact = FALSE` and compact manually when YOU decide

### "Can I see the old thread after compaction?"

Yes! The old `thread_id` is preserved and logged:
```
✔ Compaction complete
ℹ Old thread: thread_abc123
ℹ New thread: thread_xyz789
```

You can retrieve the old thread with:
```r
old_thread <- cassidy_get_thread("thread_abc123")
```

### "What if I want to control when compaction happens?"

Turn off auto-compaction and do it manually:
```r
session <- cassidy_session(auto_compact = FALSE)

# ... later, when YOU decide ...
session <- cassidy_compact(session)
```

### "Do I need to think about tokens for normal use?"

**No.** The system handles it automatically. Token tracking and compaction happen in the background. You'll only notice if:
- You have a very long conversation (many hours)
- You're using lots of tools with large outputs
- You approach the limits (you'll get warnings)

For typical use (< 50 messages, moderate tool use), you won't hit limits.

### "What about the Shiny app?"

Same system, but:
- Token usage is displayed visually (progress bar)
- You can manually trigger compaction with a button
- Warnings appear as notifications
- Auto-compaction happens transparently (you just see "compacting..." briefly)

### "How is memory different from just using ~/.cassidy/rules/?"

**Rules** = Static project instructions (always loaded in full)
- "This project uses snake_case"
- "Test files go here"
- "Use this package structure"

**Memory** = Dynamic workflow state (listing shown, content on-demand)
- "Currently on step 5 of this refactoring"
- "Tried approach X, didn't work because Y"
- "User prefers detailed explanations"

Rules tell Claude **how** to work. Memory tells Claude **what** you're working on and what you've learned.

### "Won't memory bloat my context if I have lots of files?"

No! Memory uses **progressive disclosure**:
- Only the directory listing (~100 tokens) is auto-included
- Claude reads specific files only when relevant
- Unlike rules (always full content), memory is on-demand

Example:
```
# In context automatically (~50 tokens):
Memory files: refactoring.md (2.3K), prefs.md (0.8K), debug.md (1.5K)

# Claude reads on demand when needed:
User: "Continue refactoring"
Claude: [reads refactoring.md]
```

### "Can I disable all of this?"

For `cassidy_session()`: You can disable auto-compact but token tracking always happens (it's lightweight).

For `cassidy_chat()` (console): Token tracking is **opt-in** by default for simplicity:
```r
cassidy_chat("message", track_tokens = TRUE)
```

---

## When Things Go Wrong

### "I got a 500 error about too many tokens"

This means:
- Auto-compaction was disabled, or
- Token estimation was off, or
- You sent a massive single message

**Fix:**
1. Check if you have `auto_compact = FALSE` - turn it on
2. Try `method = "conservative"` for token estimation
3. If you're sending huge context (like a 50,000 line file), reduce it

### "Compaction failed mid-conversation"

This can happen if:
- The API is down during compaction
- The summarization request times out

**Fix:**
1. The system catches errors and returns your original session
2. You can retry manually: `session <- cassidy_compact(session)`
3. If it keeps failing, you may need to start a new conversation

### "Token estimates seem way off"

**Possible causes:**
- Your content is very code-heavy (code tokenizes differently than prose)
- You're using lots of special characters or non-English text

**Fix:**
```r
session <- cassidy_session()
# Use conservative estimation
cassidy_estimate_tokens(text, method = "conservative", safety_factor = 1.25)
```

### "Auto-compaction is too aggressive / not aggressive enough"

**Fix:**
```r
# Compact later (more aggressive)
session <- cassidy_session(compact_at = 0.90)

# Compact earlier (more cautious)
session <- cassidy_session(compact_at = 0.75)
```

---

## Advanced: Custom Summary Prompts

If you're doing specialized work and want to control what's preserved during compaction:

```r
my_prompt <- "
Create a summary of our conversation focusing on:
1. All data transformations we performed
2. Statistical analysis results
3. Visualization decisions
4. Unresolved data quality issues

You can omit:
- Exploratory dead ends
- Debugging steps
- Tool output details
"

session <- cassidy_compact(session, summary_prompt = my_prompt)
```

This gives you fine-grained control over compaction for domain-specific use cases (data science, code review, writing, etc.).

---

## Memory Tool: Persistent Knowledge Across Sessions

**What It Is:**

The Memory Tool is a persistent storage system that lets cassidyr remember things **across conversations and compactions**. Think of it as Claude's long-term memory notebook.

### The Three-Layer Knowledge System

cassidyr has three complementary systems for managing knowledge:

| System | What It's For | When It's Loaded | Lifetime |
|--------|---------------|------------------|----------|
| **Rules** (`~/.cassidy/rules/`) | Project structure & conventions | Always (full content) | Permanent |
| **Memory** (`~/.cassidy/memory/`) | Workflow state & learned insights | Listing always, content on-demand | Persistent until deleted |
| **Context** | Current session working data | Per-message | Single conversation |

### Why Memory Is Different from Rules

**Rules** are like the instruction manual:
- "This project uses snake_case"
- "Test files go in tests/testthat/"
- "Always update NEWS.md"

**Memory** is like your lab notebook:
- "Currently on Phase 3 of the refactoring"
- "Tried approach X, didn't work because Y"
- "User prefers verbose statistical explanations"

### How Memory Avoids Context Bloat

**The Problem:** If memory auto-loaded all files, you could start with 20K-50K tokens before even sending a message!

**The Solution:** Progressive disclosure (like skills):

1. **Directory listing only** (~100 tokens) shows up in context automatically:
   ```
   Memory files:
   - refactoring_progress.md (2.3K, updated 2h ago)
   - user_preferences.md (0.8K)
   - debugging_insights.md (1.5K)
   ```

2. **Claude reads specific files on demand** when relevant:
   ```
   User: "Let's continue the refactoring"
   Claude: [reads refactoring_progress.md]
   "I see we left off after completing api-core.R..."
   ```

3. **Content is NOT auto-injected** - keeps context lean

### What Memory Is Good For

#### ✅ **Long-Running Workflow State**

```
~/.cassidy/memory/context_implementation.md

# Context Management Implementation

Status: Phase 3 (Manual Compaction)

Completed:
- ✓ Phase 1: Token estimation
- ✓ Phase 2: Session tracking

In Progress:
- cassidy_compact() function - core logic done, need live API testing

Next Steps:
- Test compaction with real thread
- Handle edge case: summarization failures

Notes:
- 3:1 char-to-token ratio validated empirically
- 85% threshold feels right based on testing
```

**Why this works:** You can stop working Friday, pick up Monday, and Claude knows exactly where you left off.

#### ✅ **Discovered Debugging Insights**

```
~/.cassidy/memory/debugging_lessons.md

## ConversationManager Token Persistence (2025-02-17)

Problem: Token estimates not persisting across conversation switches
Root Cause: Forgot to save token_estimate in conv_update_current()
Solution: Add token_estimate to conversation object
Lesson: Always verify what fields are saved in persistence layer

## Shiny File Tree Performance (2025-02-10)

Problem: Lag with 100+ files using nested divs
Solution: Switched to collapsible structure with lazy rendering
Performance: Improved 10x
```

**Why this works:** You learn from mistakes once, not repeatedly.

#### ✅ **User-Specific Preferences**

```
~/.cassidy/memory/user_prefs.md

Jacob's preferences:
- Detailed explanations of statistical concepts (not just code)
- Always show full function implementations
- Likes understanding the "why" behind decisions
- Realistic effort estimates (tends to take 1.5x longer)
```

**Why this works:** Cassidyr adapts to your working style over time.

### Memory + Compaction = Unlimited Workflows

Here's where memory becomes powerful:

**Without Memory:**
- Conversation grows to 85% capacity
- Auto-compaction summarizes everything
- Some context might be lost
- You repeat yourself in the next session

**With Memory:**
- Conversation grows to 85% capacity
- Claude saves important state to memory files
- Auto-compaction summarizes the conversation
- Memory files persist across compaction
- Next session: Claude reads memory, picks up exactly where you left off

**Result:** Truly unlimited conversation length without losing long-term context.

### Example: Week-Long Refactoring Project

**Monday:**
```r
session <- cassidy_session()
chat(session, "Let's refactor all internal functions to use .prefix")
# Claude works on api-core.R, saves progress to memory
```

Memory file created:
```
~/.cassidy/memory/refactoring_project.md
Completed: api-core.R (15 functions renamed)
Next: context-*.R files
Issues: .detect_ide() needs special handling
```

**Tuesday (new session):**
```r
session <- cassidy_session()
chat(session, "Continue the refactoring")
# Claude reads refactoring_project.md
# Knows exactly what's done and what's next
```

**Friday (85% token capacity):**
```
Auto-compaction triggered...
✓ Conversation summarized
✓ Memory files preserved
✓ Ready to continue
```

**Next Monday:**
```r
session <- cassidy_session()
chat(session, "How's the refactoring going?")
# Claude reads memory, knows full project state
# Even though the conversation was compacted
```

### What NOT to Put in Memory

❌ **Project conventions** → Use ~/.cassidy/rules/ instead
```
# DON'T put this in memory:
~/.cassidy/memory/coding_standards.md
"Always use snake_case"

# It's already in rules:
~/.cassidy/rules/testing-standards.md
```

❌ **Static instructions** → Memory is for dynamic state
```
# DON'T:
~/.cassidy/memory/how_to_test.md

# DO:
~/.cassidy/memory/test_failures.md
"Test X failed 3 times, traced to Y, fixed with Z"
```

### Memory Security

All memory operations are restricted to `~/.cassidy/memory/`:
- Cannot read files outside memory directory
- Path traversal protection (rejects `../` sequences)
- You control the data (stored locally, not on CassidyAI servers)

### Using Memory

**Automatic (recommended):**
```r
# Memory listing is included in context automatically
# Claude decides when to read specific files
session <- cassidy_session()
chat(session, "Continue our work")
# Claude sees memory directory, reads relevant files
```

**Manual:**
```r
# List memory files
cassidy_list_memory_files()

# Read a specific memory file
cassidy_read_memory_file("refactoring_progress.md")

# Claude can also create/update memory files via the memory tool
# (happens automatically during agentic tasks)
```

### The Complete Picture: Rules + Skills + Memory + Context

**For R package development:**

```
~/.cassidy/rules/              Project structure (always loaded)
├── file-structure.md          "chat-handlers-*.R pattern"
├── testing-standards.md       "Use testthat 3e"
└── package-usage.md           "Use fs:: for files"

~/.cassidy/skills/             Methodology templates (on-demand)
├── efa-workflow.md            "How to perform EFA"
└── apa-tables.md              "APA 7th edition formatting"

~/.cassidy/memory/             Workflow & learning (on-demand)
├── context_implementation.md  "Phase 3 in progress"
├── debugging_insights.md      "Learned solutions"
└── user_preferences.md        "Your working style"

Context (current session):
- Project files
- Git status
- Data frames
- Current conversation
```

**All working together:**
- **Rules**: "Here's how this project works"
- **Skills**: "Here's a methodology to follow"
- **Memory**: "Here's where we are and what we've learned"
- **Context**: "Here's what we're working on right now"

### Mental Model: Memory as a Lab Notebook

Think of memory like a scientist's lab notebook:
- **Records experiments** (what you tried)
- **Documents results** (what worked, what didn't)
- **Tracks progress** (where you are in a long project)
- **Preserves insights** (lessons learned)
- **Persists across sessions** (you can close the notebook and reopen it later)

But unlike a physical notebook, Claude can search it, reference it, and update it automatically as you work.

---

## The Bottom Line

**Context management + Memory = A truly intelligent AI assistant**

The cassidyr context system has three complementary layers:

1. **Token Tracking** - You always know where you stand (transparent)
2. **Auto-Compaction** - Conversations never crash (automatic)
3. **Memory Tool** - Long-term knowledge persists (unlimited)

Think of it like this:
- **Context** = Your computer's RAM (fast, current session only)
- **Compaction** = Garbage collection (frees up space automatically)
- **Memory** = Your hard drive (permanent storage, survives restarts)

Together, they enable:
- ✅ Unlimited conversation length (compaction prevents crashes)
- ✅ Long-running workflows (memory tracks state across sessions)
- ✅ Learning over time (memory preserves insights)
- ✅ Zero crashes (auto-compaction before limits)
- ✅ Full transparency (always see token usage)

**For most users:** Just use `cassidy_session()` and forget about it. The system handles:
- Token tracking (automatic)
- Compaction when needed (automatic)
- Memory directory (automatic listing, on-demand reading)

**For power users:** You have full control:
- Adjust compaction thresholds
- Custom summary prompts
- Manual compaction triggers
- Direct memory file management
- Disable auto-compaction if preferred

---

## Further Reading

- **Vignette: "Managing Long Conversations"** (once implemented) - Detailed examples
- **Anthropic Context Engineering Guide** - Best practices for long context work
- **Function documentation:**
  - `?cassidy_session` - Session management
  - `?cassidy_compact` - Manual compaction
  - `?cassidy_session_stats` - Diagnostics
  - `?cassidy_estimate_tokens` - Token estimation
  - `?cassidy_list_memory_files` - Memory file management
  - `?cassidy_read_memory_file` - Reading memory files
- **Memory Tool Resources:**
  - Anthropic Memory Tool Guide - Official documentation
  - Anthropic Context Editing Guide - Using memory with compaction

---

END OF HUMAN-ORIENTED GUIDE
