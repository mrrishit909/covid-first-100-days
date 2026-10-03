# Step 1: the JHU CSSE COVID-19 global confirmed-cases time series.
#
#   Rscript download.R   -> data/time_series_covid19_confirmed_global.csv, results/pull.json
#
# COVID-19 Data Repository by the Center for Systems Science and Engineering (CSSE) at Johns Hopkins University (https://github.com/CSSEGISandData/COVID-19), licence CC BY 4.0.
# Cite: Dong E, Du H, Gardner L. An interactive web-based dashboard to track COVID-19 in real time. Lancet Inf Dis. 20(5):533-534. doi: 10.1016/S1473-3099(20)30120-1
# One row per country or province, one column per day from 22 January 2020 to 9 March 2023, when JHU stopped collecting. The file is 1.8 MB, so it is committed with its checksum.
url <- "https://raw.githubusercontent.com/CSSEGISandData/COVID-19/master/csse_covid_19_data/csse_covid_19_time_series/time_series_covid19_confirmed_global.csv"
dest <- "data/time_series_covid19_confirmed_global.csv"
dir.create("data", showWarnings = FALSE); dir.create("results", showWarnings = FALSE)
download.file(url, dest, mode = "wb", quiet = TRUE)
sha <- sub(" .*", "", system2("shasum", c("-a", "256", dest), stdout = TRUE))
info <- list(pulled = as.character(Sys.Date()), url = url, bytes = file.size(dest), rows = length(readLines(dest)) - 1L, sha256 = sha)
writeLines(jsonlite::toJSON(info, auto_unbox = TRUE, pretty = TRUE), "results/pull.json")
print(info)
