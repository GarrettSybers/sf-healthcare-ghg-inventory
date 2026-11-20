# 01_download_data.R
# Pull San Francisco Existing Buildings Energy Performance Ordinance Report
# (DataSF resource 96ck-qcfe) for the healthcare-building subset, FY2024.
#
# Note on source structure: DataSF's documentation describes this dataset as
# two linked views (Basic Info/Audit Compliance, and Benchmark Reports) that
# are joined on parcel number. As of this pull (2026-11-20), both views are
# published as a single consolidated resource (96ck-qcfe) with one row per
# building per benchmark year, so no separate join step is required. This is
# recorded here because it changes step 2 of the planned method.

library(httr)
library(jsonlite)
library(dplyr)

dir.create("data/raw", showWarnings = FALSE, recursive = TRUE)

base_url <- "https://data.sfgov.org/resource/96ck-qcfe.json"

healthcare_categories <- c(
  "Hospital (General Medical & Surgical)",
  "Urgent Care/Clinic/Other Outpatient",
  "Medical Office"
)

reporting_year <- "2024"  # most recent complete reporting year as of pull date;
                          # 2025 rows exist but are still being submitted/finalized

download_date <- Sys.Date()

# Pull all rows for the three healthcare categories for the target year.
cat_filter <- paste0("(", paste(sprintf("'%s'", healthcare_categories), collapse = ","), ")")
where_clause <- sprintf("benchmark_year='%s' AND category in %s", reporting_year, cat_filter)

resp <- GET(base_url, query = list(
  `$where` = where_clause,
  `$limit` = 5000
))
stop_for_status(resp)
raw_df <- fromJSON(content(resp, as = "text", encoding = "UTF-8"), flatten = TRUE)

cat(sprintf("Rows pulled for FY%s healthcare categories: %d\n", reporting_year, nrow(raw_df)))
cat(sprintf("Distinct buildings (parcel_number): %d\n", length(unique(raw_df$parcel_number))))
print(table(raw_df$category))

# Drop the nested 'point' geometry column (list-column); keep flat lat/long,
# which the API already returns as separate scalar fields.
raw_df <- raw_df[, !names(raw_df) %in% "point"]
raw_df <- raw_df[, !sapply(raw_df, is.list)]

write.csv(raw_df, "data/raw/healthcare_benchmark_fy2024_all.csv", row.names = FALSE)

# Scope selection: brief calls for 10-30 buildings. The full healthcare slice
# is 43 buildings (6 hospitals, 4 urgent care/clinic, 33 medical office).
# Keep all hospitals and urgent care/clinic facilities (the energy-intensive,
# "interesting" inpatient/acute-care buildings the brief flags as worth
# commenting on), and cap medical office at the 20 largest by floor area to
# land at 30 buildings total -- at the plan's ceiling, favoring size/data
# completeness over an arbitrary cut.
raw_df$floor_area <- suppressWarnings(as.numeric(raw_df$floor_area))

hospitals <- raw_df %>% filter(category == "Hospital (General Medical & Surgical)")
urgent <- raw_df %>% filter(category == "Urgent Care/Clinic/Other Outpatient")
med_office <- raw_df %>%
  filter(category == "Medical Office") %>%
  arrange(desc(floor_area)) %>%
  distinct(parcel_number, .keep_all = TRUE) %>%
  slice_head(n = 20)

med_office_parcels <- med_office$parcel_number
selected <- raw_df %>%
  filter(
    category != "Medical Office" |
      parcel_number %in% med_office_parcels
  )

cat(sprintf("\nFinal scoped portfolio: %d buildings\n", length(unique(selected$parcel_number))))
print(table(selected$category))

write.csv(selected, "data/raw/healthcare_benchmark_fy2024_scoped.csv", row.names = FALSE)

# Record pull metadata for the Inventory Management Plan.
meta <- data.frame(
  item = c("download_date", "api_endpoint", "where_clause", "rows_all_healthcare",
           "buildings_all_healthcare", "rows_scoped", "buildings_scoped"),
  value = c(as.character(download_date), base_url, where_clause,
            nrow(raw_df), length(unique(raw_df$parcel_number)),
            nrow(selected), length(unique(selected$parcel_number)))
)
write.csv(meta, "data/raw/pull_metadata.csv", row.names = FALSE)
