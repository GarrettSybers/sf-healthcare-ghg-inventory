# San Francisco Healthcare Buildings GHG Inventory

Six hospitals in this 30-building sample produce 69% of its Scope 1 and 2
emissions on 45% of its floor area. For the 25 buildings with complete data,
I calculated 32,647 metric tons CO2e for 2024. That is 5.8% below the city's
published estimate for the same buildings.

![Six hospitals account for 69% of emissions on 45% of the floor area](output/figures/fig1_share_floor_vs_emissions.png)

![24 of 25 buildings come in below the published estimate](output/figures/fig3_reconciliation.png)

<details>
<summary>Carbon intensity by building</summary>

![Carbon intensity by building](output/figures/fig2_carbon_intensity_by_building.png)

</details>

This is an exercise built on public data to demonstrate a carbon accounting
method. It covers 6 hospitals, 4 urgent care clinics and 20 medical office
buildings in San Francisco for calendar year 2024. The energy data comes from
the city's building benchmarking program and the emission factors from EPA.

## Files

- [`report/inventory_report.pdf`](report/inventory_report.pdf) is the full
  inventory, including the comparison with the city's estimate.
- [`report/inventory_management_plan.pdf`](report/inventory_management_plan.pdf)
  explains how to repeat the inventory.
- `R/` holds four scripts that run in order, from data download to figures.
- `output/qa_log.csv` lists every data problem I found, what I did about it
  and why.
- `output/emissions_results.csv` has results per building, and
  `output/portfolio_summary.csv` has the totals.
- `data/` holds the raw and cleaned data.

## Method

Scope 1 covers natural gas. Scope 2 covers purchased electricity, using the
eGRID factor for the CAMX region that includes San Francisco. All factors
come from EPA's GHG Emission Factors Hub (January 2025), with global warming
potentials from the IPCC's Fifth Assessment Report. I didn't report a
market-based Scope 2 figure, because the city doesn't publish which
buildings buy cleaner power. The report covers this and the gap with the
city's figures.

## Running it

```
Rscript R/01_download_data.R
Rscript R/02_profile_qa.R
Rscript R/03_calculate_emissions.R
Rscript R/04_figures.R
```

You need R with the `httr`, `jsonlite`, `dplyr`, `ggplot2` and `scales`
packages. The first script downloads current data from DataSF, which updates
monthly. To get the exact numbers in the report, skip it and start with the
second script, which uses the data saved on 2026-11-20.
