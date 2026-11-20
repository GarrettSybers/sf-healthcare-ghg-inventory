# 02_profile_qa.R
# Data quality profiling for the scoped healthcare building portfolio.
# Produces output/qa_log.csv: one row per issue found, what was done, and why.
# Per the project method, issues are flagged, not silently dropped.

library(dplyr)

d <- read.csv("data/raw/healthcare_benchmark_fy2024_scoped.csv", stringsAsFactors = FALSE)

qa_log <- data.frame(
  parcel_number = character(), building_name = character(),
  issue = character(), detail = character(), action = character(),
  rationale = character(), stringsAsFactors = FALSE
)

add_issue <- function(log, pn, name, issue, detail, action, rationale) {
  rbind(log, data.frame(parcel_number = pn, building_name = name, issue = issue,
                         detail = detail, action = action, rationale = rationale,
                         stringsAsFactors = FALSE))
}

# 1. Duplicate building-year rows (same parcel_number, should be exactly 1 row
#    per building for this FY2024 pull).
dupe_counts <- d %>% count(parcel_number)
dupes <- dupe_counts %>% filter(n > 1)
if (nrow(dupes) > 0) {
  for (i in seq_len(nrow(dupes))) {
    pn <- dupes$parcel_number[i]
    name <- d$building_name[d$parcel_number == pn][1]
    qa_log <- add_issue(qa_log, pn, name, "duplicate_building_year",
      sprintf("%d rows found for this parcel in FY2024", dupes$n[i]),
      "Kept first row, dropped remaining duplicates",
      "Source should yield one row per building per benchmark year; extras are treated as reporting artifacts")
  }
  d <- d %>% distinct(parcel_number, .keep_all = TRUE)
}

# 2. Non-compliant buildings (did not report / no usable activity data).
noncompliant <- d %>% filter(grepl("Did Not Report|Violation", benchmark_status, ignore.case = TRUE))
for (i in seq_len(nrow(noncompliant))) {
  qa_log <- add_issue(qa_log, noncompliant$parcel_number[i], noncompliant$building_name[i],
    "benchmark_noncompliance",
    sprintf("benchmark_status = '%s'", noncompliant$benchmark_status[i]),
    "Excluded from Scope 1/2 totals; building-years-of-coverage reduced accordingly",
    "No verified activity data exists for a non-reporting building; including it would require fabricating a value")
}

# 3. Missing or non-positive electricity.
bad_elec <- d %>% filter(is.na(electricity_use_grid_purchase) | electricity_use_grid_purchase <= 0)
for (i in seq_len(nrow(bad_elec))) {
  qa_log <- add_issue(qa_log, bad_elec$parcel_number[i], bad_elec$building_name[i],
    "missing_or_nonpositive_electricity",
    sprintf("electricity_use_grid_purchase = %s", as.character(bad_elec$electricity_use_grid_purchase[i])),
    "Scope 2 (electricity) emissions for this building set to NA, excluded from total, and flagged in results table",
    "Cannot assume a value for missing metered electricity; building may be submetered, vacant, or have an incomplete submission")
}

# 4. Missing or non-positive natural gas.
bad_gas <- d %>% filter(is.na(natural_gas_use) | natural_gas_use <= 0)
for (i in seq_len(nrow(bad_gas))) {
  qa_log <- add_issue(qa_log, bad_gas$parcel_number[i], bad_gas$building_name[i],
    "missing_or_nonpositive_natural_gas",
    sprintf("natural_gas_use = %s", as.character(bad_gas$natural_gas_use[i])),
    "Scope 1 (natural gas) emissions for this building set to NA, excluded from total, and flagged in results table",
    "All-electric buildings are plausible in SF; treated as a data gap rather than assumed to be zero without the building's mechanical/fuel profile")
}

# 5. Missing year_built.
bad_year <- d %>% filter(is.na(year_built) | year_built == "")
for (i in seq_len(nrow(bad_year))) {
  qa_log <- add_issue(qa_log, bad_year$parcel_number[i], bad_year$building_name[i],
    "missing_year_built",
    "year_built is blank",
    "Left blank; excluded from any age-based subgroup analysis",
    "Not used in emissions calculation, only contextual framing, so no substitution is needed")
}

# 6. Energy use intensity outside a plausible range for the building type.
#    Healthcare EUI benchmarks (ENERGY STAR Portfolio Manager national medians,
#    approximate): Hospitals ~200-350 kBtu/ft2/yr; Medical Office/Urgent Care
#    ~60-180 kBtu/ft2/yr. Flag values far outside this as needing a look, not
#    as proof of an error.
d$site_energy_use <- suppressWarnings(as.numeric(d$site_energy_use))
d$eui <- d$site_energy_use / d$floor_area  # kBtu/ft2

eui_bounds <- d %>%
  mutate(
    lo = ifelse(category == "Hospital (General Medical & Surgical)", 100, 25),
    hi = ifelse(category == "Hospital (General Medical & Surgical)", 500, 300)
  ) %>%
  filter(!is.na(eui) & (eui < lo | eui > hi))

for (i in seq_len(nrow(eui_bounds))) {
  qa_log <- add_issue(qa_log, eui_bounds$parcel_number[i], eui_bounds$building_name[i],
    "eui_outside_plausible_range",
    sprintf("EUI = %.1f kBtu/ft2 (category: %s)", eui_bounds$eui[i], eui_bounds$category[i]),
    "Retained in calculation (activity data itself is not out of range), flagged for manual review",
    "Could reflect a genuinely unusual building (e.g., partial-year occupancy, large vacant floor area, 24/7 specialty use) rather than a data error; not enough evidence here to exclude it")
}

cat(sprintf("Total QA issues logged: %d\n", nrow(qa_log)))
print(table(qa_log$issue))

dir.create("output", showWarnings = FALSE)
write.csv(qa_log, "output/qa_log.csv", row.names = FALSE)

# Save cleaned (deduplicated) dataset for the emissions calculation step.
write.csv(d, "data/processed/healthcare_portfolio_cleaned.csv", row.names = FALSE)
