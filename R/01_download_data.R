# 01_download_data.R
# Downloads 2024 benchmarking data for SF healthcare buildings from DataSF
# (resource 96ck-qcfe) and selects the 30 buildings in the inventory.
#
# DataSF describes this dataset as two tables joined on parcel number. When
# pulled on 2026-11-20 they were already merged, one row per building per
# year, so no join is needed.

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

reporting_year <- "2024"  # 2025 reports were still coming in at the pull date

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

# The API returns location as a nested column, which write.csv can't handle.
# Latitude and longitude also come as plain columns, so the nested one is dropped.
raw_df <- raw_df[, !names(raw_df) %in% "point"]
raw_df <- raw_df[, !sapply(raw_df, is.list)]

write.csv(raw_df, "data/raw/healthcare_benchmark_fy2024_all.csv", row.names = FALSE)

# The three categories hold 43 buildings (6 hospitals, 4 urgent care, 33
# medical offices). The target was 10 to 30. Keep every hospital and urgent
# care building, and the 20 largest medical offices, for 30 in total.
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

cat(sprintf("\nBuildings selected: %d\n", length(unique(selected$parcel_number))))
print(table(selected$category))

write.csv(selected, "data/raw/healthcare_benchmark_fy2024_scoped.csv", row.names = FALSE)

# Record the pull date, query and row counts.
meta <- data.frame(
  item = c("download_date", "api_endpoint", "where_clause", "rows_all_healthcare",
           "buildings_all_healthcare", "rows_scoped", "buildings_scoped"),
  value = c(as.character(download_date), base_url, where_clause,
            nrow(raw_df), length(unique(raw_df$parcel_number)),
            nrow(selected), length(unique(selected$parcel_number)))
)
write.csv(meta, "data/raw/pull_metadata.csv", row.names = FALSE)
