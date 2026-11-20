# Inventory Management Plan
## San Francisco Healthcare Buildings GHG Inventory

Garrett Sybers | November 2026 | Reporting year 2024, data pulled 2026-11-20

This plan records how the inventory was produced, so that someone else can
check this year's numbers or repeat the work next year. It follows the form
a company would use for verification, scaled down to a portfolio project.

## 1. Data Sources and Owners

| Data | Source | Owner | Updated |
|---|---|---|---|
| Building energy use, floor area and type | DataSF, *Existing Buildings Energy Performance Ordinance Report*, resource `96ck-qcfe` | SF Environment Department runs the program. DataSF publishes it | Monthly, per DataSF |
| Natural gas emission factors | EPA *GHG Emission Factors Hub* | EPA Center for Corporate Climate Leadership | About once a year |
| Electricity emission factors | EPA eGRID, included in the Hub (eGRID2023 in this cycle) | EPA | About once a year, describing grid data one to two years old |
| Comparison figure (`total_ghg_emissions`) | Same DataSF table, calculated in each owner's ENERGY STAR Portfolio Manager account | Building owners | Same as energy data |

For this project I am the owner of every step. In a company, each row would
have a named staff member who pulls that source and confirms its version
before the annual calculation.

## 2. Steps for Each Annual Cycle

1. Check the EPA Hub and eGRID for a newer release, and record the release
   date and link. Decide once, at the start of the cycle, whether to adopt
   it. A factor change moves the comparison with the city's figures, so the
   decision should be written down.
2. Pull `https://data.sfgov.org/resource/96ck-qcfe.json` through the Socrata
   API. Filter `benchmark_year` to the target year and `category` to
   Hospital (General Medical & Surgical), Urgent Care/Clinic/Other
   Outpatient, and Medical Office. Record the pull date, the query and the
   row count. Confirm the resource ID has not changed.
3. Keep every hospital and urgent care building, and the 20 largest medical
   offices by floor area. If the number of buildings in these categories
   changes a lot, revisit this rule and the 10 to 30 building target.
4. Run the quality checks in Section 4 before any calculation.
5. Run the scripts in order: `R/01_download_data.R`, `R/02_profile_qa.R`,
   `R/03_calculate_emissions.R`, `R/04_figures.R`. Each one writes files that
   the next one reads.
6. Compare the results with the city's figures. If the gap is in a
   different direction or much larger than the year before, find out why
   before publishing.
7. Compare the new QA log and gap with the previous year's, then update this
   plan and the report.

## 3. Factors Used This Cycle

| Factor | Value | Source |
|---|---|---|
| Natural gas, CO2 | 53.06 kg/mmBtu | EPA Hub, Table 1, last modified Jan. 15, 2025 |
| Natural gas, CH4 | 1.0 g/mmBtu | EPA Hub, Table 1 |
| Natural gas, N2O | 0.10 g/mmBtu | EPA Hub, Table 1 |
| Electricity (CAMX), CO2 | 436.7 lb/MWh | EPA Hub, Table 6 (eGRID2023, published Jan. 2025) |
| Electricity (CAMX), CH4 | 0.025 lb/MWh | EPA Hub, Table 6 |
| Electricity (CAMX), N2O | 0.003 lb/MWh | EPA Hub, Table 6 |
| GWP, CH4 | 28 | IPCC AR5, as given in the Hub |
| GWP, N2O | 265 | IPCC AR5, as given in the Hub |

Check these values against the current Hub before reusing them. When a total
changes from one year to the next, a new factor version can be the cause
even when the buildings used the same energy. Note any version change so it
isn't mistaken for a change in performance.

## 4. Quality Checks

Run these every cycle:

1. Duplicate rows for the same parcel and year. There should be none.
   Investigate any that appear.
2. Electricity or natural gas missing or zero. Flag it and do not fill in a
   value. Leave that scope out of the building's total, and keep the row in
   the results as blank.
3. Buildings that did not file a report. Leave them out of totals and log
   it.
4. EUI outside the plausible range for the type (100 to 500 kBtu/ft² for
   hospitals, 25 to 300 for the rest). Flag for review but keep the building
   in the calculation.
5. The gap with the city's figures. If it changes direction or grows a lot
   from the year before, check for a new eGRID version, a change in GWP
   values, or a new fuel type such as steam.

Every flagged issue goes in `output/qa_log.csv` with the building, the
problem, the action taken and the reason. Nothing is corrected or removed
without a log entry.

## 5. Open Gaps

There is no market-based Scope 2 figure, because the city doesn't publish
which buildings buy CleanPowerSF power. Scope 3 is not covered. In this
cycle, 5 of the 30 buildings lack data and are left out of the totals.
