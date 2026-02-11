# EFA Workflow

**Description**: Run exploratory factor analysis following psychometric best practices
**Auto-invoke**: yes
**Requires**: apa-tables

---

## When to Use This Skill

Use this workflow when:
- Validating survey instrument structure
- Determining dimensionality of a scale
- Exploring underlying factor structure
- User mentions "EFA", "factor analysis", or "scale validation"

## Prerequisites

- Data: Item-level responses (numeric)
- Minimum N = 200 (or 5:1 item ratio)
- Interval/ordinal data suitable for correlations
- Required packages: psych, GPArotation

## Workflow Steps

### 1. Data Quality Check

**Check for issues that would invalidate EFA:**

```r
# Check sample size
n <- nrow(data)
n_items <- ncol(data)
ratio <- n / n_items

cat("Sample size:", n, "\n")
cat("Items:", n_items, "\n")
cat("Ratio:", round(ratio, 1), ":1\n")

if (n < 200) warning("Sample size < 200 may be problematic")
if (ratio < 5) warning("Ratio < 5:1 may be problematic")

# Check missing values
missing_pct <- colMeans(is.na(data)) * 100
if (any(missing_pct > 5)) {
  cat("\nItems with >5% missing:\n")
  print(missing_pct[missing_pct > 5])
}

# Check variance
zero_var <- apply(data, 2, var, na.rm = TRUE) == 0
if (any(zero_var)) {
  warning("Zero variance items found: ", paste(names(data)[zero_var], collapse = ", "))
}
```

Proceed only if:
- N ≥ 200 or ratio ≥ 5:1
- Missing values < 10% per item
- All items have variance

### 2. Factorability Assessment

Check if data is suitable for factor analysis:

```r
library(psych)

# KMO measure (want > 0.6)
kmo_result <- KMO(data)
cat("Overall KMO:", round(kmo_result$MSA, 3), "\n")

if (kmo_result$MSA < 0.6) {
  warning("KMO < 0.6 suggests data may not be suitable for FA")
}

# Bartlett's test (want p < .05)
bart_result <- cortest.bartlett(data, n = nrow(data))
cat("Bartlett's p-value:", format.pval(bart_result$p.value), "\n")

if (bart_result$p.value > 0.05) {
  warning("Bartlett's test not significant - correlations may be too small")
}
```

### 3. Determine Number of Factors

Use parallel analysis (most reliable method):

```r
# Run parallel analysis
pa_result <- fa.parallel(data,
                         fa = "fa",           # Factor analysis (not PCA)
                         fm = "pa",           # Principal axis factoring
                         n.iter = 100)        # 100 iterations

cat("\nSuggested number of factors:", pa_result$nfact, "\n")

# Visual inspection of scree plot
# Look for elbow in actual eigenvalues above simulated values
```

Parallel analysis suggests number of factors where:
- Actual eigenvalues > simulated eigenvalues
- Clear drop-off (elbow) in scree plot

### 4. Extract Factors

Run EFA with determined number of factors:

```r
n_factors <- pa_result$nfact  # Or use your theoretical number

# Extract factors
efa_result <- fa(data,
                 nfactors = n_factors,
                 rotate = "promax",      # Oblique rotation (factors can correlate)
                 fm = "pa",              # Principal axis factoring
                 max.iter = 100)

# Check model fit
cat("\nModel Fit:\n")
cat("RMSEA:", round(efa_result$RMSEA[1], 3),
    " [", round(efa_result$RMSEA[2], 3), ", ",
    round(efa_result$RMSEA[3], 3), "]\n", sep = "")
cat("TLI:", round(efa_result$TLI, 3), "\n")
cat("BIC:", round(efa_result$BIC, 1), "\n")

# Good fit: RMSEA < .08, TLI > .90
```

### 5. Interpret Loadings

Examine factor structure:

```r
# Print loadings (suppress < 0.3)
print(efa_result$loadings, cutoff = 0.3, sort = TRUE)

# Check for problems:
# - Items with no loadings > 0.4
# - Items with multiple loadings > 0.4 (cross-loading)
# - Factors with < 3 items

# Item-level diagnostics
communalities <- efa_result$communality
cat("\nLow communalities (< 0.3):\n")
print(communalities[communalities < 0.3])

# Factor correlations (if oblique rotation)
cat("\nFactor correlations:\n")
print(round(efa_result$Phi, 2))
```

Criteria for good structure:
- Factor loadings ≥ 0.40
- Cross-loadings < 0.30
- Each factor has ≥ 3 items
- Communalities ≥ 0.30
- Interpretable factor pattern

### 6. Generate Results Table

Format results using APA guidelines (from apa-tables skill):

```r
# Extract loadings as data frame
loadings_df <- as.data.frame(unclass(efa_result$loadings))
loadings_df$Item <- rownames(loadings_df)
loadings_df$h2 <- efa_result$communality

# Reorder columns
loadings_df <- loadings_df[, c("Item", paste0("PA", 1:n_factors), "h2")]

# Create table (using apa-tables formatting)
library(kableExtra)

kable(loadings_df,
      caption = "*Factor Loadings and Communalities from Exploratory Factor Analysis*",
      digits = 2,
      col.names = c("Item", paste("Factor", 1:n_factors), "h²"),
      align = c('l', rep('r', n_factors + 1))) %>%
  kable_styling() %>%
  add_footnote(c(
    paste("Note. N =", nrow(data), ". Extraction: Principal axis factoring.",
          "Rotation: Promax. Loadings < .30 suppressed."),
    paste("Model fit: RMSEA =", round(efa_result$RMSEA[1], 3),
          ", TLI =", round(efa_result$TLI, 3))
  ), notation = "none")
```

### 7. Document Interpretation

Provide interpretation guide:

For each factor:
1. Review which items load (≥ 0.40)
2. Identify common theme across items
3. Propose factor name based on content
4. Note any cross-loadings or anomalies

Example:
- **Factor 1**: [Name] (items 1, 3, 5, 7)
  - Common theme: [description]
  - All loadings > 0.50
  - No significant cross-loadings

- **Factor 2**: [Name] (items 2, 4, 6, 8)
  - Common theme: [description]
  - Item 4 has moderate cross-loading (0.32 on Factor 1)
  - Consider rewording or removing Item 4

## Expected Output

Provide:
1. Sample characteristics: N, item count, missing data summary
2. Factorability: KMO, Bartlett's test results
3. Number of factors: Parallel analysis recommendation + scree plot
4. Model fit: RMSEA, TLI, BIC
5. Factor loadings table: APA-formatted with communalities
6. Factor correlations: If oblique rotation used
7. Interpretation: Proposed factor names and descriptions
8. Recommendations: Items to revise/remove, next steps

## Common Issues

- **Poor model fit**: Try different number of factors
- **Cross-loadings**: Consider removing ambiguous items
- **Low communalities**: Item may not fit factor structure
- **Unstable solution**: May need more data or different rotation
- **Factor correlations > 0.85**: Factors may not be distinct
