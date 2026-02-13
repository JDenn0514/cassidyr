---
name: "APA Tables"
description: "Create APA-formatted results tables following 7th edition guidelines"
auto_invoke: false
requires: []
---

# APA Tables

## Table Formatting Rules

### Number Formatting
- **p-values**: Report as `p = .003` (not `p = 0.003`), use `p < .001` for very small values
- **Correlations/coefficients**: 2 decimals (e.g., `.45`)
- **Means/SDs**: 2 decimals (e.g., `M = 3.21, SD = 0.87`)
- **Chi-square**: 2 decimals (e.g., `χ²(3) = 12.45`)
- **F-values**: 2 decimals (e.g., `F(2, 145) = 5.23`)
- **t-values**: 2 decimals (e.g., `t(98) = 3.21`)

### Table Structure
- Title above table in italics
- Column headers bold
- Horizontal lines: top, below headers, bottom only (no vertical lines)
- Notes below table: *Note.* General notes here. Asterisks for significance levels.
- Significance: Use * p < .05, ** p < .01, *** p < .001

### General Guidelines
- Left-align text, right-align numbers
- Use en-dash for ranges (e.g., 1–10)
- Spell out Greek letters in text, use symbols in tables (α, β, χ²)
- Table numbers (Table 1, Table 2) in sequence

## Example Factor Loadings Table

Use this format for EFA/CFA results:

```r
library(kableExtra)

loadings_table <- data.frame(
  Item = c("Item 1", "Item 2", "Item 3", "Item 4", "Item 5"),
  Factor1 = c(.82, .75, .68, .12, .08),
  Factor2 = c(.10, .15, .22, .79, .71),
  Communality = c(.68, .59, .51, .64, .52)
)

kable(loadings_table,
      caption = "*Factor Loadings from Exploratory Factor Analysis*",
      digits = 2,
      align = c('l', 'r', 'r', 'r')) %>%
  kable_styling(bootstrap_options = c("striped", "condensed")) %>%
  add_footnote(c("Note. N = 250. Loadings > .40 are shown in bold.",
                 "Extraction: Principal axis factoring. Rotation: Promax."),
               notation = "none")
```

## Example Correlation Table

```r
cor_table <- data.frame(
  Variable = c("1. Age", "2. Experience", "3. Satisfaction", "4. Performance"),
  M = c(35.2, 8.5, 4.2, 3.8),
  SD = c(6.3, 3.2, 0.8, 0.6),
  `1` = c("—", ".45**", ".23*", ".18"),
  `2` = c("", "—", ".38**", ".42**"),
  `3` = c("", "", "—", ".56**"),
  `4` = c("", "", "", "—")
)

kable(cor_table,
      caption = "*Descriptive Statistics and Correlations*",
      align = c('l', 'r', 'r', 'r', 'r', 'r', 'r')) %>%
  kable_styling() %>%
  add_footnote(c("Note. N = 150.",
                 "* p < .05. ** p < .01."),
               notation = "none")
```

## Output Requirements

When creating tables:
1. Use the number formatting rules above
2. Include descriptive table title in italics
3. Add appropriate notes below table
4. Mark significance levels with asterisks
5. Include sample size in notes
6. Specify analysis method in notes (if relevant)
