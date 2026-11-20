# 02_profile_qa.R
# Checks the 30 selected buildings for data problems before any calculation.
# Writes output/qa_log.csv with one row per problem, the action taken and the
# reason. Problems are flagged and logged. No rows are deleted.

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

# 1. Duplicate rows. Each parcel should appear once for 2024.
dupe_counts <- d %>% count(parcel_number)
dupes <- dupe_counts %>% filter(n > 1)
if (nrow(dupes) > 0) {
  for (i in seq_len(nrow(dupes))) {
    pn <- dupes$parcel_number[i]
    name <- d$building_name[d$parcel_number == pn][1]
    qa_log <- add_issue(qa_log, pn, name, "duplicate_building_year",
      sprintf("%d rows for this parcel in 2024", dupes$n[i]),
      "Kept the first row and dropped the others",
      "The source should have one row per building per year, so extra rows are treated as reporting errors")
  }
  d <- d %>% distinct(parcel_number, .keep_all = TRUE)
}

# 2. Buildings that did not file a benchmark report.
noncompliant <- d %>% filter(grepl("Did Not Report|Violation", benchmark_status, ignore.case = TRUE))
for (i in seq_len(nrow(noncompliant))) {
  qa_log <- add_issue(qa_log, noncompliant$parcel_number[i], noncompliant$building_name[i],
    "benchmark_noncompliance",
    sprintf("benchmark_status = '%s'", noncompliant$benchmark_status[i]),
    "Left out of the Scope 1 and 2 totals",
    "The building filed no energy data, so any value used for it would be made up")
}

# 3. Electricity missing or zero.
bad_elec <- d %>% filter(is.na(electricity_use_grid_purchase) | electricity_use_grid_purchase <= 0)
for (i in seq_len(nrow(bad_elec))) {
  qa_log <- add_issue(qa_log, bad_elec$parcel_number[i], bad_elec$building_name[i],
    "missing_or_nonpositive_electricity",
    sprintf("electricity_use_grid_purchase = %s", as.character(bad_elec$electricity_use_grid_purchase[i])),
    "Left Scope 2 blank for this building and out of the totals",
    "There is no basis for a value. The building may be submetered, vacant or missing part of its report")
}

# 4. Natural gas missing or zero.
bad_gas <- d %>% filter(is.na(natural_gas_use) | natural_gas_use <= 0)
for (i in seq_len(nrow(bad_gas))) {
  qa_log <- add_issue(qa_log, bad_gas$parcel_number[i], bad_gas$building_name[i],
    "missing_or_nonpositive_natural_gas",
    sprintf("natural_gas_use = %s", as.character(bad_gas$natural_gas_use[i])),
    "Left Scope 1 blank for this building and out of the totals",
    "Some SF buildings are all electric, but zero gas can't be assumed without knowing the building's heating system")
}

# 5. Construction year missing.
bad_year <- d %>% filter(is.na(year_built) | year_built == "")
for (i in seq_len(nrow(bad_year))) {
  qa_log <- add_issue(qa_log, bad_year$parcel_number[i], bad_year$building_name[i],
    "missing_year_built",
    "year_built is blank",
    "Left blank",
    "Construction year is not used in any calculation, so nothing needs to be filled in")
}

# 6. Energy use intensity (EUI) outside a plausible range. The bounds are set
#    wide around ENERGY STAR national medians: 100 to 500 kBtu/ft2 for
#    hospitals, 25 to 300 for the other types. A value outside them gets a
#    second look. It is not treated as an error.
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
    "Kept in the calculation and flagged for review",
    "The building may be unusual, for example partly vacant or occupied for part of the year. There is not enough evidence to call the data wrong")
}

cat(sprintf("Issues logged: %d\n", nrow(qa_log)))
print(table(qa_log$issue))

dir.create("output", showWarnings = FALSE)
write.csv(qa_log, "output/qa_log.csv", row.names = FALSE)

# Save the checked data for 03_calculate_emissions.R.
write.csv(d, "data/processed/healthcare_portfolio_cleaned.csv", row.names = FALSE)
