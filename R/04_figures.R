# 04_figures.R
# Draws the three report figures from output/emissions_results.csv.
# Uses the 25 buildings that have both Scope 1 and Scope 2.

library(dplyr)
library(ggplot2)
library(scales)

dir.create("output/figures", showWarnings = FALSE, recursive = TRUE)

r <- read.csv("output/emissions_results.csv", stringsAsFactors = FALSE) %>%
  filter(!is.na(calc_total_co2e_mt))

cat_labels <- c(
  "Hospital (General Medical & Surgical)" = "Hospital",
  "Medical Office" = "Medical office",
  "Urgent Care/Clinic/Other Outpatient" = "Urgent care clinic"
)
r$type <- factor(cat_labels[r$category], levels = c("Hospital", "Medical office", "Urgent care clinic"))

# These three colors were checked as a set for colorblind readability.
type_cols <- c("Hospital" = "#2a78d6", "Medical office" = "#eb6834", "Urgent care clinic" = "#1baf7a")
surface <- "#fcfcfb"
ink <- "#0b0b0b"; ink2 <- "#52514e"; muted <- "#898781"; grid_col <- "#e1e0d9"; axis_col <- "#c3c2b7"

theme_inv <- theme_minimal(base_size = 11) +
  theme(
    plot.background = element_rect(fill = surface, colour = NA),
    panel.background = element_rect(fill = surface, colour = NA),
    panel.grid.major.y = element_blank(),
    panel.grid.minor = element_blank(),
    panel.grid.major.x = element_line(colour = grid_col, linewidth = 0.3),
    axis.text = element_text(colour = ink2),
    axis.title = element_text(colour = muted, size = 9.5),
    plot.title = element_text(colour = ink, face = "bold", size = 13),
    plot.subtitle = element_text(colour = ink2, size = 10, margin = margin(b = 10)),
    plot.caption = element_text(colour = muted, size = 8, hjust = 0),
    legend.position = "top", legend.justification = "left",
    legend.title = element_blank(), legend.text = element_text(colour = ink2),
    plot.title.position = "plot", plot.caption.position = "plot",
    plot.margin = margin(14, 18, 10, 14)
  )

src <- "Source: DataSF Existing Buildings Energy Performance Ordinance Report (96ck-qcfe), 2024.\nEPA GHG Emission Factors Hub (Jan 2025), eGRID2023 CAMX, AR5 GWPs. 25 buildings with complete data."

# Figure 1: share of floor area and share of emissions
share <- r %>%
  group_by(type) %>%
  summarise(floor = sum(floor_area), emis = sum(calc_total_co2e_mt), .groups = "drop") %>%
  mutate(`Floor area` = floor / sum(floor), `Scope 1 + 2 emissions` = emis / sum(emis))

share_long <- rbind(
  data.frame(measure = "Floor area", type = share$type, value = share$`Floor area`),
  data.frame(measure = "Scope 1 + 2 emissions", type = share$type, value = share$`Scope 1 + 2 emissions`)
)
share_long$measure <- factor(share_long$measure, levels = c("Scope 1 + 2 emissions", "Floor area"))
share_long$type <- factor(share_long$type, levels = rev(levels(r$type)))
share_long$label <- ifelse(share_long$value >= 0.06, percent(share_long$value, accuracy = 1), "")

hosp_floor <- share$`Floor area`[share$type == "Hospital"]
hosp_emis <- share$`Scope 1 + 2 emissions`[share$type == "Hospital"]
n_hosp <- sum(r$type == "Hospital")

f1 <- ggplot(share_long, aes(x = value, y = measure, fill = type)) +
  geom_col(width = 0.45, colour = surface, linewidth = 0.9) +
  geom_text(aes(label = label), position = position_stack(vjust = 0.5),
            colour = "white", fontface = "bold", size = 3.6) +
  scale_fill_manual(values = type_cols, breaks = levels(r$type)) +
  scale_x_continuous(labels = percent, expand = c(0, 0), breaks = seq(0, 1, 0.25)) +
  labs(
    title = sprintf("The %d hospitals have %s of the floor area and %s of the emissions",
                    n_hosp, percent(hosp_floor, 1), percent(hosp_emis, 1)),
    subtitle = "Share of the total by building type, San Francisco healthcare buildings, 2024",
    x = NULL, y = NULL, caption = src
  ) +
  theme_inv +
  theme(panel.grid.major.x = element_blank(), axis.text.x = element_blank(),
        axis.text.y = element_text(colour = ink, size = 10.5))

ggsave("output/figures/fig1_share_floor_vs_emissions.png", f1, width = 8, height = 3.4, dpi = 200, bg = surface)

# Figure 2: emissions per square foot, by building
r <- r %>% mutate(intensity = calc_total_co2e_mt * 1000 / floor_area)
r$bname <- reorder(tools::toTitleCase(tolower(r$building_name)), r$intensity)

means <- r %>% group_by(type) %>% summarise(m = mean(intensity), .groups = "drop")
ratio <- means$m[means$type == "Hospital"] / means$m[means$type == "Medical office"]

top <- r %>% arrange(desc(intensity)) %>% slice_head(n = 3)

f2 <- ggplot(r, aes(x = intensity, y = bname, fill = type)) +
  geom_col(width = 0.68) +
  geom_text(data = top, aes(label = sprintf("%.1f", intensity)),
            hjust = -0.25, colour = ink2, size = 3.2) +
  scale_fill_manual(values = type_cols) +
  scale_x_continuous(expand = expansion(mult = c(0, 0.08))) +
  labs(
    title = sprintf("Hospitals emit %.1f times as much per square foot as medical offices", ratio),
    subtitle = sprintf("Scope 1 and 2 emissions per square foot, 2024. Averages: hospital %.1f, urgent care %.1f, medical office %.1f kg CO2e",
                       means$m[means$type == "Hospital"], means$m[means$type == "Urgent care clinic"],
                       means$m[means$type == "Medical office"]),
    x = "kg CO2e per square foot", y = NULL, caption = src
  ) +
  theme_inv +
  theme(axis.text.y = element_text(size = 8.5, colour = ink2),
        axis.line.y = element_line(colour = axis_col, linewidth = 0.4),
        plot.subtitle = element_text(size = 9))

ggsave("output/figures/fig2_carbon_intensity_by_building.png", f2, width = 8, height = 6.2, dpi = 200, bg = surface)

# Figure 3: difference from the city's published figure
n_below <- sum(r$diff_pct < 0)
med <- median(r$diff_pct)
port_diff <- 100 * (sum(r$calc_total_co2e_mt) - sum(r$epa_reported_co2e_mt)) / sum(r$epa_reported_co2e_mt)
r$bname3 <- reorder(tools::toTitleCase(tolower(r$building_name)), r$diff_pct)
above <- r %>% filter(diff_pct >= 0)

f3 <- ggplot(r, aes(x = diff_pct, y = bname3)) +
  geom_vline(xintercept = 0, colour = ink2, linewidth = 0.5) +
  geom_vline(xintercept = med, colour = "#2a78d6", linewidth = 0.4, linetype = "solid", alpha = 0.5) +
  geom_segment(aes(x = 0, xend = diff_pct, yend = bname3), colour = grid_col, linewidth = 0.6) +
  geom_point(size = 3.2, colour = "#2a78d6", stroke = 0) +
  annotate("text", x = med, y = 0.4, label = sprintf("median %.1f%%", med),
           hjust = 1.05, vjust = 0, colour = ink2, size = 3.1) +
  geom_text(data = above, aes(label = sprintf("+%.1f%%", diff_pct)),
            hjust = -0.4, colour = ink2, size = 3.1) +
  scale_x_continuous(labels = function(x) paste0(x, "%"), limits = c(-16, 3),
                     breaks = seq(-15, 0, 5)) +
  scale_y_discrete(expand = expansion(add = c(1, 1.6))) +
  labs(
    title = sprintf("My figure is lower than the city's for %d of %d buildings", n_below, nrow(r)),
    subtitle = sprintf("Difference between my total and the city's published estimate for each building. Overall: %.1f%%.\nNearly every building moves the same way, which suggests the two use different emission factors.", port_diff),
    x = "Difference from the city's estimate (below zero means my figure is lower)", y = NULL, caption = src
  ) +
  theme_inv +
  theme(axis.text.y = element_text(size = 8.5, colour = ink2),
        plot.subtitle = element_text(size = 9.5, lineheight = 1.1))

ggsave("output/figures/fig3_reconciliation.png", f3, width = 8, height = 6.2, dpi = 200, bg = surface)

cat("Wrote 3 figures to output/figures/\n")
