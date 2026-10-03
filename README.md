# How fast did COVID-19 spread in its first 100 days?

Daily confirmed COVID-19 cases for every country, from the Johns Hopkins CSSE record that starts on 22 January 2020. Five questions:
- how big was the world's count after 100 days, and how much of it was outside China;
- how fast was it doubling, for the world and for the world outside China;
- how many countries had passed 100 and 1,000 cases, day by day;
- how fast did a typical country's count double in the 14 days after it passed 100 cases, and which countries were fastest and slowest;
- did countries that arrived later grow more slowly.

The questions follow DataCamp's "Visualizing COVID-19" (R, ggplot, logarithmic scales): the same Johns Hopkins data, the analysis and the charts written in R. Real data, not a course file.

Build log: https://mrrishit909.github.io/projects/covid-first-100-days/

## Data

COVID-19 Data Repository by the Center for Systems Science and Engineering (CSSE) at Johns Hopkins University (https://github.com/CSSEGISandData/COVID-19), the global confirmed-cases time series; licence CC BY 4.0. Cite:
Dong E, Du H, Gardner L. An interactive web-based dashboard to track COVID-19 in real time. Lancet Inf Dis. 20(5):533-534. doi: 10.1016/S1473-3099(20)30120-1. One row per country or province (289), one column per day
from 22 January 2020 to 9 March 2023 (1,143 days), cumulative; JHU stopped collecting on 10 March 2023. 1.8 MB, so the file is committed with its checksum; `download.R` fetches it.

```
Rscript download.R    # data/*.csv
Rscript analyze.R     # results/*     (R with dplyr, tidyr, readr, lubridate)
python3 check.py      # needs scipy for the t distribution
Rscript charts.R      # charts/*      (R with ggplot2, patchwork, ragg)
```

## Steps

1. **Download** the confirmed-cases file.
2. **Audit:** missing values, the four rows that are not countries (two cruise ships and two Olympic Games), provinces summed into countries (197 countries and territories remain), and every day on which a country's cumulative count fell.
3. **The world in its first 100 days:** the world's cumulative cases and its doubling time over a 7-day window (7 ln 2 / ln of the ratio of today's count to the count a week ago), for all countries and for all but China; the fastest windows.
4. **Spread:** on each of the first 100 days, how many countries had passed 1, 100 and 1,000 cases.
5. **Each country after 100 cases:** day 0 is the first day a country's count reached 100; its growth over the next 14 days is the slope of a least-squares line through the logarithm of the count on days 0 to 14, and its doubling time is ln 2
   divided by that slope. Countries are grouped by when they reached 100 cases, and a Spearman correlation compares arrival date with doubling time.
6. **Check.** `check.py` recomputes 9,758 numbers in plain Python from the raw CSV, with no R, pandas or numpy: the audit, every day of the world and of the world outside China, the spread, every country's day 0 and its regression
   (slope, R squared, doubling time), the medians and quartiles, and a Spearman correlation with tied ranks averaged. Changing the quantile rule or the regression window makes it fail.
7. **Charts,** with ggplot2.

## Results

- **The first 100 days.** The world's record starts at 557 cases on 22 January 2020 and reaches 3,281,366 on day 100, 30 April 2020. Outside China the count was 3,194,538: 0.5% of the world's cases on day 25 (15 February), 35.7% on day 50 (11 March)
  and 97.4% on day 100.
- **Spread.** Countries with at least one case: 6 on day 1, 27 on day 25, 110 on day 50, 180 on day 75 and 183 on day 100. With at least 100: 1, 1, 24, 116 and 139. With at least 1,000: 0, 1, 9, 59 and 86. 194 of the 197 reached 100 cases at some point.
- **Doubling time.** The world's fastest 7-day doubling was 1.92 days on 30 January, when China was catching up its counts. Outside China, among windows with at least 1,000 cases, the fastest was 2.53 days on 28 February (4,519 cases); the answer
  is the same for any threshold from 100 to 3,000 cases and 2.68 days at 5,000 or 10,000. Outside China it was 4.2 days on 11 March, 4.5 on 21 March, 5.8 on 31 March, 11.7 on 10 April, 17.8 on 20 April and 25.9 on 30 April.
- **A typical country.** In the 14 days after passing 100 cases the median country's count doubled in 6.30 days (quartiles 4.06 and 10.84); one country did not grow at all. The fit is close to a straight line on a log scale for many but not all: the median R squared is 0.96 and
  56.2% of countries have an R squared above 0.95. The fastest were the Marshall Islands (1.97 days, in August 2022, R squared 0.89), Spain (2.11), Turkey (2.23), the United States (2.30) and Iran (2.36); the slowest the Bahamas (332.9), Barbados (198.2),
  Dominica (156.8), Monaco (152.5) and Timor-Leste (123.6).
- **Later arrivals grew more slowly.** By the month a country reached 100 cases, the median doubling time was 2.55 days for the 7 that did so by February 2020, 5.05 for the 102 in March (quartiles 3.73 and 7.57), 9.81 for 30 in April, 10.02 for 27 in May and June,
  46.10 for 12 in July to December and 3.78 for the 15 in 2021 or later (quartiles 3.38 and 8.99). Across 193 countries the Spearman correlation between arrival date and doubling time is 0.50 (p = 1.3e-13).
- **Data quirks.** The cumulative count falls on 171 country-days in 84 countries; the largest falls are France on 20 May 2021 (-348,840), Spain on 2 March 2021 (-74,347), Peru on 25 December 2022 (-65,286), Kazakhstan on 24 July 2021 (-59,375) and France on 4 November 2020 (-46,121).
  China's count jumps by 15,136 on 13 February 2020, then 6,463 the next day. The four rows left out hold 2,121 cases on the last day.

## Not done, and caveats

- Confirmed cases are not infections. They depend on how much testing there was, on the case definition and on how fast countries reported, so a doubling of confirmed cases in March 2020 partly records testing catching up. Nothing here estimates the true number of infections.
- Later arrivals growing more slowly is a description. The countries differ in size, in how much warning they had and in testing, and the data cannot separate those. The late groups are small (12 and 15 countries).
- China was already above 100 cases when the record starts, so its day 0 is 22 January, not the day it passed 100. The jump of 15,136 on 13 February 2020 looks like a change in counting, not a day of new cases; it is left as published.
- Cumulative counts include revisions. A fall inside a country's 14-day window or a world 7-day window distorts that rate; the 171 falls are left as published.
- The 14-day window and the 100-case start are choices of mine; with an R squared above 0.95 for 56% of countries, growth was not always a clean exponential.
- The world total here is the sum of the 197 countries and territories, without the four non-country rows. Names are JHU's (for example "US" and "Korea, South"), and Taiwan and others appear as JHU lists them.
