# SF Healthcare Building Portfolio GHG Inventory

San Francisco hospitals in this sample run about 2.7x the energy intensity of
medical office buildings in the same portfolio (173 vs. 63 kBtu/ft²/yr), and
the calculated Scope 1 + 2 total for the 25 buildings with usable data
(32,743 metric tons CO2e) comes in 5.5% below the city's own EPA-estimated
figure for the same buildings — a gap that's consistent across 24 of 25
buildings and most likely traces to electricity emission factor vintage, not
a calculation error.

This is a self-initiated portfolio exercise, built on public data, to
demonstrate carbon accounting method — not a commissioned or verified
inventory. It covers 30 San Francisco healthcare facilities (6 hospitals, 4
urgent care/outpatient clinics, 20 medical office buildings) for calendar
year 2024, built from San Francisco's building energy benchmarking
disclosures and EPA/eGRID emission factors.

## Why this exists

Carbon accounting job postings (e.g., utility and health-system GHG/ESG
reporting roles) ask for experience maintaining emissions inventories,
calculation support, QA logs, and inventory management plans — the kind of
work a reviewer can't verify from a resume line alone. This repository is
that evidence: a method a reader can open, check, and reproduce.

## What's here

- **[`report/inventory_report.pdf`](report/inventory_report.pdf)** — the
  full inventory: boundary, method, results, reconciliation against the
  published EPA estimate, and uncertainty. Start here.
- **[`report/inventory_management_plan.pdf`](report/inventory_management_plan.pdf)**
  — the reproducibility procedure: data owners, factor versions, QC checks,
  and what changes year to year.
- **`R/`** — the three scripts, in order, from raw download to final table
  (`01_download_data.R`, `02_profile_qa.R`, `03_calculate_emissions.R`).
- **`output/qa_log.csv`** — every data quality issue found, what was done
  about it, and why.
- **`output/emissions_results.csv`** / **`output/portfolio_summary.csv`** —
  per-building and portfolio-level results.
- **`data/`** — raw and cleaned intermediate data.

## Method at a glance

Scope 1 (natural gas) and Scope 2 location-based (purchased electricity,
eGRID CAMX subregion) emissions, calculated from San Francisco's Existing
Buildings Energy Performance Ordinance disclosures using EPA's January 2025
GHG Emission Factors Hub (AR5 GWPs). Market-based Scope 2 is explicitly not
reported — building-level clean-energy program enrollment isn't public — and
that limitation is documented rather than papered over. Full detail,
including why the calculated total runs below the city's own published
estimate, is in the inventory report.

## Reproducing this

```
Rscript R/01_download_data.R
Rscript R/02_profile_qa.R
Rscript R/03_calculate_emissions.R
```

Requires R with `httr`, `jsonlite`, and `dplyr`. Each script reads the
previous step's output from `data/` and writes its own output before the
next step runs.
