# Steps 2-4: audit the series, follow the world through its first 100 days, see how far it had spread, and measure each country's growth after it passed 100 cases.
#
#   Rscript analyze.R
#     -> results/audit.csv  falls.csv  world.csv  spread.csv  spread_daily.csv  countries.csv  by_period.csv  summary.csv
#
# JHU CSSE confirmed cases, cumulative, by country or province, 22 January 2020 to 9 March 2023. Provinces are summed into countries. Four rows are not countries (two cruise ships and two
# Olympic Games) and are left out of every country count and of the world total. "Day 0" of a country is the first day its cumulative count reached 100. Growth in the next 14 days is the slope
# of a straight line through the logarithm of the cumulative count on days 0 to 14, and the doubling time is ln 2 divided by that slope.
suppressPackageStartupMessages({ library(dplyr); library(tidyr); library(readr); library(lubridate) })
NON_COUNTRIES <- c("Diamond Princess", "MS Zaandam", "Summer Olympics 2020", "Winter Olympics 2022")
dir.create("results", showWarnings = FALSE)

raw <- read_csv("data/time_series_covid19_confirmed_global.csv", show_col_types = FALSE, progress = FALSE)
long <- raw |> pivot_longer(-(1:4), names_to = "date", values_to = "cum") |> mutate(date = mdy(date))
by_country <- long |> group_by(country = `Country/Region`, date) |> summarise(cum = sum(cum), .groups = "drop")
cty <- by_country |> filter(!country %in% NON_COUNTRIES) |> arrange(country, date)
dates <- sort(unique(cty$date)); n_days <- length(dates)

# Step 2: audit
cty <- cty |> group_by(country) |> mutate(new = cum - lag(cum)) |> ungroup()
falls <- cty |> filter(new < 0) |> arrange(new, country, date)
china <- cty |> filter(country == "China", date <= dates[100], !is.na(new)) |> arrange(desc(new))
last_total <- by_country |> filter(country %in% NON_COUNTRIES, date == max(date)) |> summarise(total = sum(cum)) |> pull(total)
audit <- tibble(check = c("rows in the file", "country or region names", "rows that are not countries", "countries and territories", "first date", "last date", "days", "missing case values",
                          "cases on the last day in the four rows left out", "country-days where the cumulative count fell", "countries where it fell at least once", "largest one-day fall",
                          "China's largest one-day rise in its first 100 days", "China's second largest one-day rise in its first 100 days"),
                value = c(nrow(raw), n_distinct(raw$`Country/Region`), length(NON_COUNTRIES), n_distinct(cty$country), as.numeric(min(dates)), as.numeric(max(dates)), n_days, sum(is.na(long$cum)),
                          last_total, nrow(falls), n_distinct(falls$country), -min(falls$new), china$new[1], china$new[2]))
write_csv(audit, "results/audit.csv")
write_csv(falls |> head(5) |> transmute(country, date = as.character(date), change = new), "results/falls.csv")

# Step 3: the world in its first 100 days
world <- cty |> group_by(date) |> summarise(outside = sum(cum[country != "China"]), cum = sum(cum), .groups = "drop") |>
  mutate(day = row_number(), new = cum - lag(cum), doubling7 = 7 * log(2) / log(cum / lag(cum, 7)), outside_doubling7 = 7 * log(2) / log(outside / lag(outside, 7)))
write_csv(world |> transmute(date = as.character(date), day, cumulative = cum, new, doubling7_days = doubling7, outside_china = outside, outside_china_doubling7_days = outside_doubling7), "results/world.csv")
fast <- world |> filter(day >= 8, day <= 100) |> slice_min(doubling7, n = 1, with_ties = FALSE)
fast_out <- world |> filter(day >= 8, day <= 100, outside >= 1000) |> slice_min(outside_doubling7, n = 1, with_ties = FALSE)      # a rate means little on a handful of cases: windows ending with 1,000 cases or more
spread <- bind_rows(lapply(c(1, 25, 50, 75, 100), function(d) {
  v <- cty |> filter(date == dates[d]) |> pull(cum); tibble(day = d, date = as.character(dates[d]), at_least_1 = sum(v >= 1), at_least_100 = sum(v >= 100), at_least_1000 = sum(v >= 1000))
}))
write_csv(spread, "results/spread.csv")
write_csv(bind_rows(lapply(1:100, function(d) { v <- cty |> filter(date == dates[d]) |> pull(cum); tibble(day = d, date = as.character(dates[d]), at_least_1 = sum(v >= 1), at_least_100 = sum(v >= 100), at_least_1000 = sum(v >= 1000)) })), "results/spread_daily.csv")

# Step 4: each country after it passed 100 cases
rows <- lapply(split(cty, cty$country), function(g) {
  i0 <- which(g$cum >= 100)[1]; if (is.na(i0) || i0 + 14 > nrow(g)) return(NULL)
  v <- g$cum[i0:(i0 + 14)]; x <- 0:14; fit <- lm(log(v) ~ x); b <- unname(coef(fit)[2]); at <- function(k) if (i0 + k <= nrow(g)) g$cum[i0 + k] else NA_real_
  tibble(country = g$country[1], day0 = as.character(g$date[i0]), slope = b, doubling = if (b > 0) log(2) / b else Inf, r2 = summary(fit)$r.squared, factor14 = v[15] / v[1], c30 = at(30), c60 = at(60), c100 = at(100))
})
cs <- bind_rows(rows) |> arrange(doubling, country); write_csv(cs, "results/countries.csv")
reached <- cty |> filter(cum >= 100) |> group_by(country) |> summarise(day0 = min(date), .groups = "drop")
fin <- cs |> filter(is.finite(doubling)) |> mutate(d0 = as.numeric(ymd(day0)))
cs$period <- cut(as.numeric(ymd(cs$day0)), breaks = as.numeric(ymd(c("1900-01-01", "2020-03-01", "2020-04-01", "2020-05-01", "2020-07-01", "2021-01-01", "2100-01-01"))), right = FALSE,
                 labels = c("to Feb 2020", "Mar 2020", "Apr 2020", "May-Jun 2020", "Jul-Dec 2020", "2021 or later"))
byp <- cs |> filter(is.finite(doubling)) |> group_by(period) |> summarise(countries = n(), median_doubling = median(doubling), q1 = quantile(doubling, 0.25), q3 = quantile(doubling, 0.75), .groups = "drop")
write_csv(byp, "results/by_period.csv")
sp <- suppressWarnings(cor.test(fin$d0, fin$doubling, method = "spearman", exact = FALSE))
summ <- tibble(key = c("countries_and_territories", "reached_100", "reached_100_within_first_100_days", "world_day_100_cases", "outside_china_day_100_cases", "outside_china_share_day_25_pct", "outside_china_share_day_50_pct", "outside_china_share_day_100_pct",
                       "world_fastest_doubling_days", "world_fastest_doubling_day_number", "outside_china_fastest_doubling_days", "outside_china_fastest_doubling_day_number",
                       "countries_with_15_days_after_100", "median_doubling_14d", "doubling_q1", "doubling_q3", "no_growth_countries", "median_r2", "share_r2_above_95_pct", "spearman_rho", "spearman_p", "spearman_n"),
               value = c(n_distinct(cty$country), nrow(reached), sum(reached$day0 <= dates[100]), world$cum[100], world$outside[100], 100 * world$outside[25] / world$cum[25], 100 * world$outside[50] / world$cum[50], 100 * world$outside[100] / world$cum[100],
                         fast$doubling7, fast$day, fast_out$outside_doubling7, fast_out$day, nrow(cs), median(fin$doubling), quantile(fin$doubling, 0.25), quantile(fin$doubling, 0.75),
                         sum(!is.finite(cs$doubling)), median(cs$r2), 100 * mean(cs$r2 > 0.95), unname(sp$estimate), sp$p.value, nrow(fin)))
write_csv(summ, "results/summary.csv")
for (f in c("audit", "falls", "spread", "by_period", "summary")) { cat("==", f, "\n"); print(as.data.frame(read_csv(paste0("results/", f, ".csv"), show_col_types = FALSE)), digits = 6) }
cat("== fastest and slowest\n"); print(as.data.frame(bind_rows(head(cs |> select(country, day0, doubling, r2), 5), tail(cs |> filter(is.finite(doubling)) |> select(country, day0, doubling, r2), 5))), digits = 4)
cat("== world fastest:", format(fast$date), "day", fast$day, "doubling", round(fast$doubling7, 3), "| outside China (windows with >= 1,000 cases):", format(fast_out$date), "day", fast_out$day, "doubling", round(fast_out$outside_doubling7, 3), "\n")
