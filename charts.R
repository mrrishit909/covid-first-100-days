# Step 6: charts, with ggplot2.   Rscript charts.R -> charts/00_cover.png, 01_countries.png, 02_world.png, 03_doubling.png, 04_periods.png, 05_spread.png
suppressPackageStartupMessages({ library(ggplot2); library(dplyr); library(readr); library(tidyr); library(scales); library(lubridate); library(ragg); library(patchwork) })
INK <- "#f2f2f0"; DIM <- "#8a8a87"; GRID <- "#1d1d1d"; BG <- "#0b0b0b"; BLUE <- "#3987e5"; ORANGE <- "#d95926"; GRAY <- "#9a9a96"; GREEN <- "#3aa876"
theme_house <- function(base = 11) theme_minimal(base_size = base, base_family = "Helvetica Neue") + theme(
  plot.background = element_rect(fill = BG, color = NA), panel.background = element_rect(fill = BG, color = NA), panel.grid.major = element_line(color = GRID, linewidth = 0.5), panel.grid.minor = element_blank(),
  text = element_text(color = INK), axis.text = element_text(color = DIM), axis.title = element_text(color = DIM), axis.line = element_line(color = "#3a3a3a", linewidth = 0.4), axis.ticks = element_blank(),
  plot.title = element_text(color = INK, size = base + 2, hjust = 0, margin = margin(b = 10)), plot.title.position = "plot", legend.text = element_text(color = INK, size = base - 1), legend.title = element_blank(),
  legend.key = element_rect(fill = BG, color = NA), legend.background = element_rect(fill = BG, color = NA), plot.margin = margin(10, 14, 8, 8))
save <- function(p, name, w = 10, h = 4, dpi = 150) ggsave(file.path("charts", name), p, width = w, height = h, dpi = dpi, device = ragg::agg_png, bg = BG)

tj <- read_csv("results/trajectories.csv", show_col_types = FALSE) |> mutate(country = recode(country, `Korea, South` = "South Korea", US = "United States"))
cols <- c("China" = GRAY, "South Korea" = GREEN, "Italy" = BLUE, "Spain" = "#7fb2f0", "United States" = ORANGE, "United Kingdom" = "#c9a227", "Brazil" = "#b36fd1", "India" = INK)
tj$country <- factor(tj$country, levels = names(cols))
refs <- bind_rows(lapply(c(2, 3, 5, 10), function(T) { d <- seq(0, min(100, T * log2(3e6 / 100)), length.out = 60); tibble(T = T, day = d, cases = 100 * 2^(d / T)) }))
labs_ref <- refs |> group_by(T) |> slice_tail(n = 1) |> mutate(label = paste0(T, " days"))
p1 <- ggplot(tj, aes(day, cases, color = country)) +
  geom_line(data = refs, aes(day, cases, group = T), color = "#4a4a48", linetype = "dashed", linewidth = 0.5, inherit.aes = FALSE) +
  geom_text(data = labs_ref, aes(day, cases, label = label), color = DIM, size = 2.7, hjust = 1.02, vjust = -0.6, inherit.aes = FALSE) +
  geom_line(linewidth = 1.0) + scale_color_manual(values = cols) + scale_y_log10(labels = label_comma(), breaks = 10^(2:6), limits = c(100, 3e6)) + scale_x_continuous(breaks = seq(0, 100, 20)) +
  labs(x = "days since the country reached 100 confirmed cases", y = "confirmed cases (log scale)", title = "Eight countries after they passed 100 cases", subtitle = "dashed lines: cases doubling every 2, 3, 5 and 10 days") + theme_house() + theme(plot.subtitle = element_text(color = DIM, size = 9, margin = margin(b = 8)))
save(p1, "01_countries.png", 10, 4.4)

w <- read_csv("results/world.csv", show_col_types = FALSE) |> filter(day <= 100) |> mutate(date = ymd(date))
lw <- w |> transmute(date, World = cumulative, `Outside China` = outside_china) |> pivot_longer(-date, names_to = "series", values_to = "cases")
p2 <- ggplot(lw, aes(date, cases, color = series)) + geom_line(linewidth = 1.2) + scale_color_manual(values = c("World" = INK, "Outside China" = ORANGE)) + scale_y_log10(labels = label_comma(), breaks = 10^(1:6)) +
  scale_x_date(date_breaks = "1 month", date_labels = "%b") + labs(x = "2020", y = "confirmed cases (log scale)", title = "The first 100 days: the world, and the world outside China") + theme_house()
save(p2, "02_world.png", 10, 3.8)

fa <- read_csv("results/summary.csv", show_col_types = FALSE) |> filter(key %in% c("outside_china_fastest_doubling_days", "outside_china_fastest_doubling_day_number")) |> pull(value)
ld <- w |> filter(day >= 8) |> transmute(date, World = doubling7_days, `Outside China` = outside_china_doubling7_days) |> pivot_longer(-date, names_to = "series", values_to = "days")
pt <- w |> filter(day == fa[2]) |> transmute(date, days = fa[1])
p3 <- ggplot(ld, aes(date, days, color = series)) + geom_line(linewidth = 1.2) + geom_point(data = pt, aes(date, days), color = INK, size = 2.6, inherit.aes = FALSE) +
  geom_text(data = pt, aes(date, days, label = sprintf("%.1f days, 28 Feb", days)), color = INK, size = 3.2, hjust = -0.12, vjust = 2.0, inherit.aes = FALSE) +
  scale_color_manual(values = c("World" = INK, "Outside China" = ORANGE)) + scale_y_log10(breaks = c(2, 3, 5, 10, 20, 40, 80)) + scale_x_date(date_breaks = "1 month", date_labels = "%b") +
  labs(x = "2020", y = "days to double (log scale)", title = "How long cases took to double, over a 7-day window") + theme_house()
save(p3, "03_doubling.png", 10, 3.8)

cs <- read_csv("results/countries.csv", show_col_types = FALSE) |> filter(is.finite(doubling)) |> mutate(d0 = ymd(day0))
cs$period <- cut(as.numeric(cs$d0), breaks = as.numeric(ymd(c("1900-01-01", "2020-03-01", "2020-04-01", "2020-05-01", "2020-07-01", "2021-01-01", "2100-01-01"))), right = FALSE,
                 labels = c("to Feb 2020", "Mar 2020", "Apr 2020", "May-Jun 2020", "Jul-Dec 2020", "2021 or later"))
bp <- read_csv("results/by_period.csv", show_col_types = FALSE) |> mutate(period = factor(period, levels = levels(cs$period)))
p4 <- ggplot(cs, aes(period, doubling)) + geom_jitter(width = 0.18, height = 0, color = BLUE, alpha = 0.55, size = 1.6) +
  geom_crossbar(data = bp, aes(y = median_doubling, ymin = q1, ymax = q3), color = INK, fill = NA, width = 0.55, linewidth = 0.5, inherit.aes = TRUE) +
  geom_text(data = bp, aes(y = 700, label = paste0("n = ", countries)), color = DIM, size = 3.1, inherit.aes = TRUE) +
  scale_y_log10(breaks = c(2, 5, 10, 20, 50, 100, 300), limits = c(1.5, 900)) + labs(x = "when the country reached 100 cases", y = "days to double (log scale)", title = "Doubling time over the 14 days after passing 100 cases, by arrival (box: quartiles and median)") + theme_house() + theme(panel.grid.major.x = element_blank())
save(p4, "04_periods.png", 10, 3.9)

sd <- read_csv("results/spread_daily.csv", show_col_types = FALSE) |> mutate(date = ymd(date)) |> pivot_longer(starts_with("at_least"), names_to = "k", values_to = "countries") |>
  mutate(k = recode(k, at_least_1 = "at least 1 case", at_least_100 = "at least 100", at_least_1000 = "at least 1,000"), k = factor(k, levels = c("at least 1 case", "at least 100", "at least 1,000")))
ends <- sd |> filter(day == 100)
p5 <- ggplot(sd, aes(date, countries, color = k)) + geom_line(linewidth = 1.2) + geom_text(data = ends, aes(label = countries), hjust = -0.3, size = 3.3, show.legend = FALSE) +
  scale_color_manual(values = c("at least 1 case" = GRAY, "at least 100" = BLUE, "at least 1,000" = ORANGE)) + scale_x_date(date_breaks = "1 month", date_labels = "%b", expand = expansion(mult = c(0.01, 0.07))) +
  labs(x = "2020", y = "countries and territories", title = "How many countries had passed each mark") + theme_house()
save(p5, "05_spread.png", 10, 3.6)

cover <- (p1 + theme(legend.position = "right", plot.title = element_text(size = 15)) | p4 + labs(title = "Days to double, by arrival date") + theme(plot.title = element_text(size = 15))) + plot_layout(widths = c(1.1, 1)) +
  plot_annotation(title = "How fast did COVID-19 spread in its first 100 days? The typical country doubled its cases every six days", theme = theme(plot.background = element_rect(fill = BG, color = NA), plot.title = element_text(color = INK, size = 20, hjust = 0)))
ggsave("charts/00_cover.png", cover, width = 14, height = 8, dpi = 100, device = ragg::agg_png, bg = BG)
cat("charts written\n")
