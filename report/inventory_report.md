# GHG Inventory: San Francisco Healthcare Building Portfolio, FY2024

Garrett Sybers | Portfolio exercise using public data | November 2026

## A. Summary

This is a Scope 1 and Scope 2 greenhouse gas inventory for a 30-building sample
of San Francisco healthcare facilities — 6 hospitals, 4 urgent care/outpatient
clinics, and the 20 largest medical office buildings (by floor area) in the
city's benchmarking disclosures — for calendar year 2024. Calculated emissions
for the 25 buildings with usable activity data total **32,743 metric tons
CO2e** (17,929 Scope 1, 14,813 Scope 2 location-based). This is **5.5% below**
the EPA-estimated figure the city's own benchmarking data reports for the same
buildings, a gap that is explained in Section F and is most likely due to
electricity emission factor vintage, not a calculation error. Hospitals in the
sample run roughly **2.7 times the energy use intensity** of medical office
buildings (173 vs. 63 kBtu/ft²) and a comparable multiple in carbon intensity
(9.5 vs. 3.7 kg CO2e/ft²) — expected for round-the-clock clinical operations,
but large enough to be worth naming.

This is a self-initiated portfolio exercise built on public data to demonstrate
carbon accounting method, not a commissioned or verified inventory, and it has
not been through third-party assurance.

## B. Boundary and Scope

**Organizational boundary.** This inventory covers a selected sample of 30
healthcare-sector buildings in San Francisco, drawn from the city's Existing
Buildings Energy Performance Ordinance (Environment Code Chapter 20)
disclosures (DataSF resource `96ck-qcfe`). It is a facility-level sample, not
a single company's full emissions footprint — no single entity owns this
portfolio, and the selection was made by the analyst, not by a corporate
consolidation rule (equity share, financial control, or operational control
over an organization). Within that sample, activity data is attributed to
each *building*, consistent with an operational-control approach, because
DataSF publishes metered building-level energy use rather than data separable
by tenant versus owner.

**Operational boundary.** Scope 1 (direct, on-site natural gas combustion)
and Scope 2 (indirect, purchased electricity, location-based). No Scope 3
categories are included — see Section G. No building in the final sample
reports district steam use, so no steam factor is applied anywhere in this
inventory (confirmed by the absence of a `district_steam_use` value for any
of the 30 buildings pulled, not assumed).

**Base year / reporting period.** Calendar year 2024, the most recent
reporting year in the DataSF dataset with the large majority of buildings
already filed as of this pull; 2025 submissions were still being finalized as
of the data-pull date below.

**Scope selection.** The full healthcare-category slice (Hospital, Urgent
Care/Clinic/Other Outpatient, Medical Office) contained 43 buildings, above
the project's 10-30 target. All 6 hospitals and all 4 urgent care/clinic
facilities were kept (the energy-intensive, round-the-clock facilities most
relevant to a healthcare system's footprint); Medical Office was capped at
the 20 largest buildings by floor area, landing at 30 buildings total. This
favors data completeness and scale over an arbitrary cut, and is a judgment
call the analyst made, not a property of the data.

## C. Data Sources

**Activity data.** DataSF, *Existing Buildings Energy Performance Ordinance
Report*, resource id `96ck-qcfe`, pulled 2026-11-20 via the Socrata API
(`https://data.sfgov.org/resource/96ck-qcfe.json`). DataSF's own documentation
describes this dataset as two linked views (Basic Info/Audit Compliance, and
Benchmark Reports) joined on parcel number; as published and pulled, both
views are already consolidated into one table with one row per building per
benchmark year, so no separate join step was needed — a change from the
originally planned method, noted here because it removes a planned QA step
(no join-induced row loss to investigate). 43 rows matched the healthcare
category filter for benchmark year 2024; 30 were retained after scoping (see
Section B); `data/raw/pull_metadata.csv` in the repository records the exact
query and row counts.

**Emission factors.** EPA, *GHG Emission Factors Hub*, Last Modified
January 15, 2025 (https://www.epa.gov/climateleadership/ghg-emission-factors-hub).
- Stationary combustion, natural gas (Table 1): 53.06 kg CO2, 1.0 g CH4, and
  0.10 g N2O per mmBtu.
- Electricity (Table 6), eGRID2023 (published January 2025), **CAMX**
  subregion (WECC California, which covers San Francisco), Total Output
  Emission Factors: 436.7 lb CO2, 0.025 lb CH4, and 0.003 lb N2O per MWh.
- Global Warming Potentials: IPCC Fifth Assessment Report (AR5), 2013 —
  CH4 = 28, N2O = 265 (100-year, as stated in the Hub).

No newer official EPA release was available as of the pull date. A
non-EPA, eGRID2024-based third-party update exists (Cornerstone, via Zenodo)
but was not used, per the project's intent to stay on a reviewable, official
factor source.

**Comparison figure.** The same DataSF resource carries an EPA-estimated
`total_ghg_emissions` value per building-year, calculated by the submitter's
ENERGY STAR Portfolio Manager account. That figure is used only for
reconciliation in Section F — it is not treated as this inventory's answer.

## D. Data Profiling and Quality Control

Before calculation, every building was checked for: duplicate building-year
rows, missing or non-positive fuel/electricity values, missing year built,
and site energy use intensity (EUI) outside a plausible range for the
building's category (100-500 kBtu/ft² for hospitals, 25-300 for medical
office/urgent care, based on approximate ENERGY STAR national medians).
Issues were flagged, not deleted. The full log is in
`output/qa_log.csv` (18 rows); in summary:

| Issue | Count | Disposition |
|---|---|---|
| Benchmark non-compliance (did not report) | 3 buildings | Excluded from totals — no activity data exists to calculate from |
| Missing/non-positive electricity | 3 buildings | Scope 2 set to NA for that building, excluded from total, kept visible in the results table |
| Missing/non-positive natural gas | 5 buildings | Scope 1 set to NA for that building (treated as a data gap, not assumed to be zero — an all-electric building is plausible in SF) |
| Missing year built | 1 building | Left blank; not used in any emissions calculation |
| EUI outside plausible range | 6 buildings | Retained in the calculation and flagged for manual review; no evidence found that these are measurement errors rather than genuinely unusual buildings |

No duplicate building-year rows were found in the final 30-building sample.
Net effect: **25 of 30 buildings have a complete, calculable Scope 1 and
Scope 2 total**; 5 are excluded from the portfolio sum and shown as NA in
`output/emissions_results.csv` rather than silently zeroed.

## E. Results

| | Scope 1 (natural gas) | Scope 2, location-based (electricity) | Total |
|---|---|---|---|
| **Metric tons CO2e** | 17,929 | 14,813 | **32,743** |

25 buildings, 4,845,858 ft² of combined floor area in the calculable subset.
Per-building detail, including the 5 excluded buildings (shown as NA), is in
`output/emissions_results.csv`.

**Scope 2 reporting basis.** The figure above is **location-based** only, per
the GHG Protocol Scope 2 Guidance's dual-reporting requirement — it reflects
the average grid mix of the CAMX eGRID subregion, not the specific electricity
product each building purchases. A **market-based** figure is not provided.
San Francisco buildings may be enrolled in CleanPowerSF (a lower-emissions
default/opt-up community choice program) or remain on PG&E's standard tariff,
and that enrollment is not published at the individual-building level in this
or any public dataset identified for this project. Producing a market-based
number would require either (a) each building's utility account data showing
its actual program enrollment and any renewable energy certificates retired
against it, or (b) a residual-mix emission factor for the portion not covered
by contractual instruments — neither of which is available here. Reporting
only the location-based figure and stating this gap is preferable to
asserting a market-based number without support.

**Energy and carbon intensity by building type** (calculable buildings):

| Category | Mean site EUI (kBtu/ft²) | Mean carbon intensity (kg CO2e/ft²) |
|---|---|---|
| Hospital (General Medical & Surgical) | 172.9 | 9.52 |
| Urgent Care/Clinic/Other Outpatient | 72.2 | 4.62 |
| Medical Office | 62.9 | 3.67 |

Hospitals in this sample run about 2.7x the energy intensity, and roughly the
same multiple in carbon intensity, of the medical office buildings in the
sample — consistent with 24/7 clinical operations (imaging, sterilization,
HVAC for infection control) that medical offices don't carry.

## F. Reconciliation Against the EPA-Estimated Figure

DataSF's benchmarking data already carries an EPA-estimated
`total_ghg_emissions` figure per building, calculated through ENERGY STAR
Portfolio Manager at the time of submission. Comparing it to this inventory's
independently calculated total, building by building, for the 25 calculable
buildings:

- Calculated portfolio total: 32,743 metric tons CO2e
- DataSF EPA-estimated total (same 25 buildings): 34,642 metric tons CO2e
- **Portfolio-level difference: -5.5%**
- Per-building difference: median **-7.3%**, range -14.0% to +0.8%
- **24 of 25 buildings** run below the EPA-estimated figure; only one
  (Chinese Hospital, +0.8%) runs slightly above it.

The direction and consistency of this gap — nearly every building running a
similar few percent below the published estimate, rather than a scatter of
over- and under-estimates — points to a **systematic factor difference**
rather than random data noise. The leading candidate: Portfolio Manager
calculates a building's GHG emissions using the eGRID electricity factor
vintage current at the time that building's energy was benchmarked, which for
most of this portfolio's submissions predates the eGRID2023 (Jan. 2025)
factors used here. California's CAMX grid has gotten measurably cleaner
across recent eGRID vintages as renewable generation has grown, so an older
vintage would assign more CO2 per MWh than eGRID2023 does — which would
produce exactly this pattern: a higher historical estimate, consistently,
across nearly every electricity-consuming building. Other candidates that
were considered and are less likely to explain the full gap: a different GWP
set (Portfolio Manager has historically used AR4 values, under which CH4 is
*lower* and N2O is *higher* than the AR5 values used here — the net effect on
a natural-gas-and-electricity-only inventory is small, since N2O's
contribution is minor) and differences in how any minor fuel categories are
handled (not applicable here, as no steam or other fuel appears in this
sample). This analysis cannot confirm the exact eGRID vintage Portfolio
Manager used for each submission without access to each building's
underlying ENERGY STAR account, so this is presented as the best-supported
explanation available from public data, not a certainty.

## G. Uncertainty and Limitations

In rough order of how much each would move the final number:

1. **Self-reported, unverified meter data.** All activity data originates
   from each building owner's benchmarking submission. Nothing in this
   project independently confirms meter readings against utility bills.
   This is the largest source of uncertainty and is inherent to the data
   source, not something this analysis can resolve.
2. **Excluded buildings understate the true portfolio total.** 5 of 30
   buildings (17%) have no usable Scope 1/2 data and are excluded rather
   than estimated. If their emissions resemble the portfolio average per
   square foot, the true 30-building total would run several thousand
   metric tons CO2e higher than the 32,743 reported here.
3. **Missing market-based Scope 2.** As discussed in Section E, no
   building-level renewable energy program enrollment is public. The
   location-based figure may overstate or understate a given building's
   actual contractual emissions depending on its CleanPowerSF status.
4. **Emission factor vintage.** As discussed in Section F, this inventory
   uses a single factor vintage (EPA Hub, Jan. 2025 / eGRID2023) applied
   uniformly across the year. A year-round average factor cannot capture
   within-year grid mix changes, and the reconciliation in Section F
   suggests vintage choice alone can move a building's total by roughly
   5-15%.

**On precision.** Results above are rounded to whole metric tons at the
portfolio level and one decimal place per building in the underlying CSV.
Reporting a number like "32,743.18" would imply a level of certainty the
underlying self-reported meter data and averaged regional emission factors
do not support.

## H. Repository Contents

- `R/01_download_data.R` — pulls and scopes the DataSF activity data
- `R/02_profile_qa.R` — produces `output/qa_log.csv`
- `R/03_calculate_emissions.R` — Scope 1/2 calculation and reconciliation,
  produces `output/emissions_results.csv` and `output/portfolio_summary.csv`
- `output/qa_log.csv`, `output/emissions_results.csv`,
  `output/portfolio_summary.csv`
- `report/inventory_report.md` (this document) and `report/inventory_report.pdf`
- `report/inventory_management_plan.md` / `.pdf`
