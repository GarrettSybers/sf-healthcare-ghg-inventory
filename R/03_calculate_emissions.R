# 03_calculate_emissions.R
# Scope 1 (natural gas stationary combustion) and Scope 2 location-based
# (purchased electricity, eGRID CAMX subregion) emissions for the scoped
# SF healthcare building portfolio, FY2024.
#
# Emission factor source: EPA "GHG Emission Factors Hub", Last Modified
# January 15, 2025 (https://www.epa.gov/climateleadership/ghg-emission-factors-hub).
# Electricity factors are eGRID2023 (published Jan 2025), CAMX subregion
# (WECC California), Total Output Emission Factors.
# Global Warming Potentials: IPCC Fifth Assessment Report (AR5), 2013
# (CH4 = 28, N2O = 265, 100-year GWP). CO2 GWP = 1 by definition.
#
# No building in this portfolio reports district steam use (column absent
# from the source pull), so no steam factor is applied; this is stated
# explicitly rather than silently assumed.

library(dplyr)

d <- read.csv("data/processed/healthcare_portfolio_cleaned.csv", stringsAsFactors = FALSE)

# --- Emission factors (EPA Hub, Jan 2025) ---
# Stationary combustion, Natural Gas (Table 1)
EF_GAS_CO2_KG_PER_MMBTU <- 53.06
EF_GAS_CH4_KG_PER_MMBTU <- 1.0 / 1000   # 1.0 g -> kg
EF_GAS_N2O_KG_PER_MMBTU <- 0.10 / 1000  # 0.10 g -> kg

# Electricity, eGRID2023 CAMX subregion (Table 6), Total Output Emission Factors
EF_ELEC_CO2_LB_PER_MWH <- 436.7
EF_ELEC_CH4_LB_PER_MWH <- 0.025
EF_ELEC_N2O_LB_PER_MWH <- 0.003
LB_TO_KG <- 0.45359237

# Global Warming Potentials, AR5 (Table footnote)
GWP_CH4 <- 28
GWP_N2O <- 265

# Exclude buildings flagged in QA as non-compliant / missing data from the
# relevant scope's calculation, but keep them in the table with NA so the
# gap is visible rather than silently zeroed.
d <- d %>%
  mutate(
    gas_mmbtu = ifelse(is.na(natural_gas_use) | natural_gas_use <= 0 |
                          grepl("Did Not Report|Violation", benchmark_status, ignore.case = TRUE),
                        NA_real_, natural_gas_use / 1000),
    elec_mwh = ifelse(is.na(electricity_use_grid_purchase) | electricity_use_grid_purchase <= 0 |
                         grepl("Did Not Report|Violation", benchmark_status, ignore.case = TRUE),
                       NA_real_, electricity_use_grid_purchase / 1000)
  )

d <- d %>%
  mutate(
    # Scope 1: natural gas stationary combustion
    scope1_co2_kg  = gas_mmbtu * EF_GAS_CO2_KG_PER_MMBTU,
    scope1_ch4_kg  = gas_mmbtu * EF_GAS_CH4_KG_PER_MMBTU,
    scope1_n2o_kg  = gas_mmbtu * EF_GAS_N2O_KG_PER_MMBTU,
    scope1_co2e_mt = (scope1_co2_kg + scope1_ch4_kg * GWP_CH4 + scope1_n2o_kg * GWP_N2O) / 1000,

    # Scope 2 location-based: purchased electricity, CAMX
    scope2_co2_lb  = elec_mwh * EF_ELEC_CO2_LB_PER_MWH,
    scope2_ch4_lb  = elec_mwh * EF_ELEC_CH4_LB_PER_MWH,
    scope2_n2o_lb  = elec_mwh * EF_ELEC_N2O_LB_PER_MWH,
    scope2_co2e_mt = (scope2_co2_lb + scope2_ch4_lb * GWP_CH4 + scope2_n2o_lb * GWP_N2O) * LB_TO_KG / 1000,

    calc_total_co2e_mt = rowSums(cbind(scope1_co2e_mt, scope2_co2e_mt), na.rm = FALSE),

    # Reconciliation against DataSF's EPA-estimated figure
    epa_reported_co2e_mt = total_ghg_emissions,
    diff_mt  = calc_total_co2e_mt - epa_reported_co2e_mt,
    diff_pct = 100 * diff_mt / epa_reported_co2e_mt
  )

results <- d %>%
  select(parcel_number, building_name, category, floor_area, year_built,
         benchmark_status, gas_mmbtu, elec_mwh,
         scope1_co2e_mt, scope2_co2e_mt, calc_total_co2e_mt,
         epa_reported_co2e_mt, diff_mt, diff_pct)

write.csv(results, "output/emissions_results.csv", row.names = FALSE)

# --- Portfolio-level summary ---
n_total <- nrow(results)
n_calculable <- sum(!is.na(results$calc_total_co2e_mt))
n_excluded <- n_total - n_calculable

# Portfolio totals use only buildings with BOTH scopes, so every total and the
# reconciliation cover the same building set.
complete <- results[!is.na(results$calc_total_co2e_mt), ]
portfolio_scope1 <- sum(complete$scope1_co2e_mt)
portfolio_scope2 <- sum(complete$scope2_co2e_mt)
portfolio_total  <- portfolio_scope1 + portfolio_scope2
portfolio_epa    <- sum(complete$epa_reported_co2e_mt)
partial_scope2   <- sum(results$scope2_co2e_mt[is.na(results$calc_total_co2e_mt)], na.rm = TRUE)
cat(sprintf("Scope 2 from buildings missing Scope 1 (excluded from totals): %.0f t\n", partial_scope2))
portfolio_diff_pct <- 100 * (portfolio_total - portfolio_epa) / portfolio_epa

cat(sprintf("\nBuildings in portfolio: %d (calculable: %d, excluded for missing/non-reported data: %d)\n",
            n_total, n_calculable, n_excluded))
cat(sprintf("Portfolio Scope 1 (natural gas):      %s metric tons CO2e\n", format(round(portfolio_scope1, 0), big.mark = ",")))
cat(sprintf("Portfolio Scope 2 (location-based):   %s metric tons CO2e\n", format(round(portfolio_scope2, 0), big.mark = ",")))
cat(sprintf("Portfolio total (calculated):         %s metric tons CO2e\n", format(round(portfolio_total, 0), big.mark = ",")))
cat(sprintf("Portfolio total (EPA-estimated, DataSF, same %d buildings): %s metric tons CO2e\n",
            n_calculable, format(round(portfolio_epa, 0), big.mark = ",")))
cat(sprintf("Portfolio-level difference: %.1f%%\n", portfolio_diff_pct))

summary_out <- data.frame(
  metric = c("n_buildings_total", "n_buildings_calculable", "n_buildings_excluded",
             "scope1_co2e_mt", "scope2_co2e_mt", "total_calculated_co2e_mt",
             "total_epa_estimated_co2e_mt", "portfolio_diff_pct"),
  value = c(n_total, n_calculable, n_excluded,
            round(portfolio_scope1, 1), round(portfolio_scope2, 1), round(portfolio_total, 1),
            round(portfolio_epa, 1), round(portfolio_diff_pct, 2))
)
write.csv(summary_out, "output/portfolio_summary.csv", row.names = FALSE)

# Per-building divergence check, ordered by absolute % difference
div_check <- results %>%
  filter(!is.na(diff_pct)) %>%
  arrange(desc(abs(diff_pct))) %>%
  select(building_name, category, calc_total_co2e_mt, epa_reported_co2e_mt, diff_pct)
cat("\nTop divergences from EPA-estimated figure (by |%|):\n")
print(head(div_check, 10))
