# 03_calculate_emissions.R
# Calculates Scope 1 (natural gas) and Scope 2 location-based (electricity)
# emissions for each building, then compares them with the city's figures.
#
# Factors come from the EPA GHG Emission Factors Hub, last modified January
# 15, 2025 (https://www.epa.gov/climateleadership/ghg-emission-factors-hub).
# Electricity uses eGRID2023 total output factors for the CAMX subregion.
# GWPs are 100-year values from the IPCC Fifth Assessment Report (AR5).
#
# None of these buildings reported district steam, so there is no steam factor.

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

# Where data is missing or the building did not report, that scope stays NA.
# NA shows the gap in the results. A zero would hide it.
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

    # Difference from the city's published figure
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

# Totals count only buildings with both scopes, so the totals and the
# comparison cover the same buildings.
complete <- results[!is.na(results$calc_total_co2e_mt), ]
portfolio_scope1 <- sum(complete$scope1_co2e_mt)
portfolio_scope2 <- sum(complete$scope2_co2e_mt)
portfolio_total  <- portfolio_scope1 + portfolio_scope2
portfolio_epa    <- sum(complete$epa_reported_co2e_mt)
partial_scope2   <- sum(results$scope2_co2e_mt[is.na(results$calc_total_co2e_mt)], na.rm = TRUE)
cat(sprintf("Scope 2 left out of totals because the building has no Scope 1: %.0f t\n", partial_scope2))
portfolio_diff_pct <- 100 * (portfolio_total - portfolio_epa) / portfolio_epa

cat(sprintf("\nBuildings: %d (complete data: %d, left out: %d)\n",
            n_total, n_calculable, n_excluded))
cat(sprintf("Scope 1 (natural gas):             %s metric tons CO2e\n", format(round(portfolio_scope1, 0), big.mark = ",")))
cat(sprintf("Scope 2 (electricity, location):   %s metric tons CO2e\n", format(round(portfolio_scope2, 0), big.mark = ",")))
cat(sprintf("Total:                             %s metric tons CO2e\n", format(round(portfolio_total, 0), big.mark = ",")))
cat(sprintf("City's published total, same %d buildings: %s metric tons CO2e\n",
            n_calculable, format(round(portfolio_epa, 0), big.mark = ",")))
cat(sprintf("Difference: %.1f%%\n", portfolio_diff_pct))

summary_out <- data.frame(
  metric = c("n_buildings_total", "n_buildings_calculable", "n_buildings_excluded",
             "scope1_co2e_mt", "scope2_co2e_mt", "total_calculated_co2e_mt",
             "total_epa_estimated_co2e_mt", "portfolio_diff_pct"),
  value = c(n_total, n_calculable, n_excluded,
            round(portfolio_scope1, 1), round(portfolio_scope2, 1), round(portfolio_total, 1),
            round(portfolio_epa, 1), round(portfolio_diff_pct, 2))
)
write.csv(summary_out, "output/portfolio_summary.csv", row.names = FALSE)

# Buildings with the largest percent difference from the city's figure
div_check <- results %>%
  filter(!is.na(diff_pct)) %>%
  arrange(desc(abs(diff_pct))) %>%
  select(building_name, category, calc_total_co2e_mt, epa_reported_co2e_mt, diff_pct)
cat("\nLargest differences from the city's figure:\n")
print(head(div_check, 10))
