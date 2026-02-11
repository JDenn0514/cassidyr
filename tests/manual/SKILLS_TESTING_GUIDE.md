# Skills Context Window - Testing Guide

## Quick Start

```r
# From project root
source("launch_skills_test.R")

# Or manually
devtools::load_all()
cassidy_app(new_chat = TRUE)
```

## What You Should See

### 1. Left Sidebar - Skills Section

```
┌─────────────────────────────────┐
│ ⚙️  Context                     │
├─────────────────────────────────┤
│ 📁 Project                      │
│    ✓ cassidy.md                 │
│    ✓ R session info             │
│    □ Git status                 │
│                                 │
│ 📊 Data (0)                     │
│                                 │
│ 📄 Files (0 selected)           │
│                                 │
│ ✨ Skills (0 selected)  ← NEW! │
│    ┌─────────────────────────┐ │
│    │ Project Skills          │ │
│    │ ○ apa-tables  [manual]  │ │
│    │   Create APA-formatted  │ │
│    │   results tables...     │ │
│    │                         │ │
│    │ ✓ efa-workflow  [auto]  │ │
│    │   Run exploratory...    │ │
│    │   requires: apa-tables  │ │
│    │                         │ │
│    │ ✓ test-skill  [auto]    │ │
│    │   Brief description...  │ │
│    └─────────────────────────┘ │
└─────────────────────────────────┘
```

### 2. Bottom Summary Panel

When you select skills, the summary should show:

```
┌─────────────────────────────────┐
│ 📚 Selected Context             │
├─────────────────────────────────┤
│ ✓ Project: cassidy.md, R session│
│ ○ Data: none                    │
│ ○ Files: none                   │
│ ✓ Skills: efa-workflow          │ ← Shows selected skills
│                                 │
│ [  Apply Context  ]             │
└─────────────────────────────────┘
```

### 3. After Applying Context

Skills that have been sent show:

```
✓ efa-workflow  [auto]  🔄        ← Refresh button appears
  Run exploratory...
  requires: apa-tables
```

The notification shows:
```
✅ Context sent successfully! (1 skill(s))
```

## Test Scenarios

### Scenario 1: Basic Skills Selection

1. Open sidebar (left toggle button)
2. Expand Skills section
3. Check `efa-workflow`
4. Check `test-skill`
5. Verify bottom summary shows: "Skills: efa-workflow, test-skill"
6. Click "Apply Context"
7. Verify notification: "Context sent successfully! (2 skill(s))"
8. Verify skills now show blue indicator and refresh button

### Scenario 2: Incremental Context

1. After Scenario 1, select `apa-tables`
2. Click "Apply Context"
3. Verify notification shows only "(1 skill(s))" - only new skill sent
4. Verify all 3 skills now marked as sent

### Scenario 3: Skill Refresh

1. Click refresh button (🔄) next to `efa-workflow`
2. Verify notification: "efa-workflow queued for refresh"
3. Click "Apply Context"
4. Verify notification shows skill was re-sent
5. Assistant receives updated skill content

### Scenario 4: Skill Dependencies

1. Select `efa-workflow` (requires: apa-tables)
2. Click "Apply Context"
3. Verify both `efa-workflow` AND `apa-tables` content sent
4. Dependencies automatically included

### Scenario 5: Conversation Persistence

1. Select and send `efa-workflow`
2. Click "New Chat" button (right sidebar)
3. Verify skills cleared for new conversation
4. Switch back to first conversation (click it in sidebar)
5. Verify `efa-workflow` still selected and marked as sent

### Scenario 6: Using Skills in Conversation

1. Select and send `efa-workflow`
2. Send message: "I have a dataset with 20 items. Can you help me run EFA following the workflow?"
3. Verify assistant references the EFA workflow steps
4. Verify assistant follows the guidelines in the skill

## Visual Indicators

| Indicator | Meaning |
|-----------|---------|
| Green background | Selected but not sent yet |
| Blue background | Sent to assistant |
| 🔄 button | Refresh this skill |
| `[auto]` badge | Auto-invoke skill |
| `[manual]` badge | Manual invocation only |
| `requires: X` | Has dependencies |

## Expected Behavior

### ✅ Should Work

- [x] Skills section appears in sidebar
- [x] Skills grouped by Project/Personal
- [x] Checkbox selection updates count
- [x] Skills appear in bottom summary
- [x] Apply Context sends skills with full content
- [x] Incremental context (only new skills sent)
- [x] Refresh button for sent skills
- [x] Dependencies auto-included
- [x] Skills persist across conversation switches
- [x] Assistant can access skill content

### ❌ Should Not Happen

- [ ] Skills duplicated in summary
- [ ] Skills sent multiple times without refresh
- [ ] Dependencies missing when skill sent
- [ ] Skills lost when switching conversations
- [ ] Refresh button on unsent skills

## Troubleshooting

### Skills Section Not Visible

- Check sidebar is open (click left toggle)
- Scroll down in sidebar
- Check Skills section is expanded (click header)

### No Skills Shown

```r
# Check skills exist
cassidy_list_skills()

# Should show at least test-skill
```

### Skills Not Sent

- Check API credentials are set
- Check console for errors
- Verify "Apply Context" clicked
- Check notification messages

### Dependencies Not Working

- Check skill file has `**Requires**: skill-name` in header
- Verify dependency skill exists
- Check console for warnings

## Next Steps

After testing:
1. Document any bugs found
2. Verify all scenarios pass
3. Check console for errors
4. Test with real assistant conversation
5. Ready for production!
