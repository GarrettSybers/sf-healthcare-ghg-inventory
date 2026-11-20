# Inventory Management Plan
## SF Healthcare Building Portfolio GHG Inventory

Garrett Sybers | November 2026 | Covers reporting year 2024, pulled 2026-11-20

This plan documents how this inventory was produced so another analyst could
reproduce the same number next year, or audit this year's. It is written as
a company would file it for verification, scaled to a portfolio exercise.

## 1. Data Sources and Owners

| Data | Source | Owner / point of contact | Update frequency |
|---|---|---|---|
| Building activity data (electricity, natural gas, floor area, category) | DataSF, *Existing Buildings Energy Performance Ordinance Report*, resource `96ck-qcfe` | SF Environment Department (program); DataSF (publishing) | Monthly refresh per DataSF documentation |
| Scope 1 emission factors (stationary combustion, natural gas) | EPA *GHG Emission Factors Hub* | EPA Center for Corporate Climate Leadership | Updated roughly annually; check for a newer release before each annual inventory |
| Scope 2 emission factors (electricity, CAMX subregion) | EPA eGRID (eGRID2023, published within the Jan. 2025 Hub release) | EPA | New eGRID vintage published roughly annually, with a reporting lag of 1-2 years |
| Comparison figure (EPA-estimated total_ghg_emissions) | Same DataSF resource, calculated by each building's ENERGY STAR Portfolio Manager account | Individual building owners/submitters | Same as activity data |

In this project, "owner" for internal purposes is the analyst (Garrett
Sybers); in a company deployment, each row's owner would be the staff member
responsible for pulling that source and confirming its vintage before the
annual calculation runs.

## 2. Collection Steps (Reproducible From Scratch)

1. Confirm the current EPA GHG Emission Factors Hub release and eGRID
   vintage; record the release date and URL. If a newer release exists,
   decide explicitly whether to adopt it for this reporting year (adopting
   mid-year changes the reconciliation story — see inventory report Section F
   — so this decision should be made once per reporting year, not silently).
2. Pull `https://data.sfgov.org/resource/96ck-qcfe.json` via the Socrata API,
   filtered to `benchmark_year` = the target year and `category` in the
   healthcare set (Hospital (General Medical & Surgical), Urgent
   Care/Clinic/Other Outpatient, Medical Office). Record the pull date,
   the exact `$where` clause used, and the row count returned.
3. Apply the scoping rule: keep all Hospital and Urgent Care/Clinic
   buildings; cap Medical Office at the 20 largest by floor area. If the
   underlying building population changes materially (new construction,
   demolitions, category reclassification), re-document the scoping
   decision rather than assuming last year's building list still applies.
4. Run the data profiling checks (Section 4 below) before any calculation.
5. Calculate Scope 1 and Scope 2 location-based emissions per the factors
   and formulas in `R/03_calculate_emissions.R`.
6. Reconcile against the DataSF EPA-estimated figure; investigate and
   document any divergence pattern that changes from the prior year's.
7. Update this plan and the inventory report with the new year's numbers
   and any method changes.

## 3. Factor Versions Used This Cycle

| Factor | Value | Source document | Version / date |
|---|---|---|---|
| Natural gas, CO2 | 53.06 kg/mmBtu | EPA GHG Emission Factors Hub, Table 1 | Last Modified Jan. 15, 2025 |
| Natural gas, CH4 | 1.0 g/mmBtu | same | same |
| Natural gas, N2O | 0.10 g/mmBtu | same | same |
| Electricity (CAMX), CO2 | 436.7 lb/MWh | EPA Hub, Table 6 (eGRID2023) | eGRID2023, published Jan. 2025 |
| Electricity (CAMX), CH4 | 0.025 lb/MWh | same | same |
| Electricity (CAMX), N2O | 0.003 lb/MWh | same | same |
| GWP, CH4 | 28 | IPCC AR5 (2013), as cited in the Hub | AR5 |
| GWP, N2O | 265 | same | AR5 |

**Any analyst reproducing this inventory must re-verify these values against
the current EPA Hub before reuse** — the Hub is updated roughly annually and
factor changes (especially eGRID vintage) are the leading driver of
year-over-year inventory drift that is not a real change in building
performance (see inventory report Section F).

## 4. Quality Control Checks (Run Every Cycle)

1. Duplicate building-year rows (same parcel number, same benchmark year) —
   should not occur; investigate if found.
2. Non-positive or missing electricity and natural gas values — flag, do not
   impute; exclude that building from the relevant Scope's total; retain the
   row in the output table as NA so the gap stays visible.
3. Benchmark non-compliance / "did not report" status — exclude from totals,
   log the exclusion.
4. Site EUI outside the plausible range for the building's category
   (100-500 kBtu/ft² hospital; 25-300 medical office/urgent care) — flag for
   manual review, do not auto-exclude.
5. Reconciliation check against the DataSF EPA-estimated figure — if the
   portfolio-level divergence changes sign or magnitude materially from the
   prior cycle, investigate before publishing (candidate causes: eGRID
   vintage change, GWP set change, new fuel type appearing in the portfolio
   such as steam).

Every flagged issue is written to `output/qa_log.csv` with the building,
the issue, what was done, and why — never silently corrected or dropped.

## 5. What Would Have to Happen to Reproduce This Next Year

- Re-pull the DataSF resource for the new benchmark year (the resource ID
  should be stable; confirm it hasn't changed before relying on that
  assumption).
- Re-check the EPA GHG Emission Factors Hub and eGRID release for updates;
  if updated, apply the new factors and flag the vintage change in the
  reconciliation write-up rather than treating a factor-driven number change
  as a performance change.
- Re-run the building scoping rule against the new year's category counts —
  if the healthcare slice size changes meaningfully, the 10-30 building
  target and the 20-largest-medical-office cutoff should be reconsidered,
  not applied mechanically.
- Re-run `R/01_download_data.R` -> `R/02_profile_qa.R` ->
  `R/03_calculate_emissions.R` in order; each writes its output to `data/`
  or `output/` for the next script to consume.
- Diff the new year's QA log and reconciliation gap against this cycle's to
  catch any process drift.

## 6. Known Gaps Carried Forward

- No market-based Scope 2 figure (building-level clean energy program
  enrollment is not public).
- No Scope 3 categories.
- 5 of 30 buildings in the current cycle have no usable activity data and
  are excluded from totals rather than estimated.
