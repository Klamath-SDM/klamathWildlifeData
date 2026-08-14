# Summarizes the contents of data-raw/cinnamon-teal/dmp000455_data
#
# The folder is a mixed dump of historical California breeding waterfowl
# survey (BPS/BPOP) materials: annual reports, population estimate reports,
# totals tables, program guidelines, and GIS/map assets. Most source files
# are legacy .doc/.docx/.xls, so this script only profiles the folder
# (file names, types, sizes, years, categories) rather than parsing contents.

library(dplyr)
library(stringr)
library(tibble)
library(readxl)
library(pdftools)
library(usethis)

data_dir <- file.path("data-raw", "cinnamon-teal", "dmp000455_data")

categorize <- function(path, file_name) {
  case_when(
    str_detect(path, regex("GIS info for Air Services", ignore_case = TRUE)) ~
      "GIS data (flight segments/waypoints)",
    str_detect(path, regex("MAPS_CA BPOP", ignore_case = TRUE)) ~
      "Survey area maps (images)",
    str_detect(file_name, regex("bpop_rep1|bpop_rpt2|ca-pop|ca-po\\d", ignore_case = TRUE)) ~
      "Annual population report (CA breeding waterfowl)",
    str_detect(file_name, regex("popest", ignore_case = TRUE)) ~
      "Population estimate report",
    str_detect(file_name, regex("bps annual report|bps report", ignore_case = TRUE)) ~
      "BPS annual report (PDF)",
    str_detect(file_name, regex("^totals", ignore_case = TRUE)) ~
      "Annual totals report",
    str_detect(file_name, regex("guidelines", ignore_case = TRUE)) ~
      "Program guidelines/methodology doc",
    str_detect(file_name, regex("vcf criteria", ignore_case = TRUE)) ~
      "VCF criteria doc",
    str_detect(file_name, regex("standard operating procedures", ignore_case = TRUE)) ~
      "Survey SOP reference",
    TRUE ~ "Other"
  )
}

summarize_dmp000455_data <- function(dir = data_dir) {
  files <- list.files(dir, recursive = TRUE, full.names = TRUE)
  files <- files[basename(files) != ".DS_Store"]

  info <- file.info(files)

  inventory <- tibble(
    path = files,
    relative_path = fs_relative(files, dir),
    file_name = basename(files),
    extension = tolower(tools::file_ext(files)),
    size_kb = round(info$size / 1024, 1),
    modified = as.Date(info$mtime)
  ) %>%
    mutate(
      year = str_extract(file_name, "(19|20)\\d{2}"),
      category = categorize(relative_path, file_name)
    )

  by_category <- inventory %>%
    count(category, extension, wt = 1, name = "n_files") %>%
    group_by(category) %>%
    summarise(
      n_files = sum(n_files),
      extensions = paste(sort(unique(extension)), collapse = ", "),
      .groups = "drop"
    ) %>%
    arrange(desc(n_files))

  by_extension <- inventory %>%
    count(extension, sort = TRUE, name = "n_files")

  year_range <- inventory %>%
    filter(!is.na(year)) %>%
    summarise(min_year = min(year), max_year = max(year))

  list(
    inventory = inventory,
    by_category = by_category,
    by_extension = by_extension,
    year_range = year_range
  )
}

# tools::file_path_sans_ext-style helper for a readable relative path
fs_relative <- function(paths, base) {
  sub(paste0("^", base, "/?"), "", paths)
}

# --- run summary ------------------------------------------------------

dmp_summary <- summarize_dmp000455_data()

cat("Files by category:\n")
print(dmp_summary$by_category, n = Inf)

cat("\nFiles by extension:\n")
print(dmp_summary$by_extension, n = Inf)

cat("\nYear range covered by filenames:\n")
print(dmp_summary$year_range)

# Full file-level inventory, saved alongside the raw data for reference
write.csv(
  dmp_summary$inventory,
  file.path("data-raw", "cinnamon-teal", "dmp000455_data_inventory.csv"),
  row.names = FALSE
)

# --- Cinnamon Teal population estimate aggregation ---------------------
#
# The statewide Cinnamon Teal population estimate for a given survey year
# shows up in three different source formats in this folder, depending on
# the year:
#   - 2003-2015: a "Summary A" statewide estimate row in the ca-pop*/
#     ca_bpop_rep1 annual reports (.doc/.docx/.txt)
#   - 1991-1992: no statewide row exists, but the *POPEST.xls worksheets
#     have a "POPULATION TOTALS" rollup with a per-species TOTALS column
#   - 2016-2019, 2022: a "Table 1" species estimate table in the BPS
#     annual report PDFs (no surveys were flown in 2020/2021)
# There is no Cinnamon-Teal-specific source for 1993-2002 in this dump (the
# "rpt2"/totals* files for those years only cover mallards and total ducks).
#
# Legacy .doc/.docx files are converted to plain text via macOS's built-in
# `textutil` CLI, so this section requires macOS.

read_lines_any <- function(path) {
  if (tolower(tools::file_ext(path)) == "txt") {
    readLines(path, warn = FALSE)
  } else {
    system2("textutil", c("-convert", "txt", "-stdout", shQuote(path)), stdout = TRUE)
  }
}

# Parses the statewide "Summary A" row, e.g.:
#   1410 Cinnamon Teal   3.85  0.59  15.4   4   63704   15884   (32571, 94838)
# Always takes the FIRST "Cinnamon Teal" line in the text, since the
# statewide Summary A row precedes the per-stratum Summary B rows.
parse_summary_a <- function(lines) {
  line <- lines[str_detect(lines, regex("cinnamon teal", ignore_case = TRUE))][1]
  if (is.na(line)) return(NULL)

  m <- str_match(line, "([\\d,]+)\\s+([\\d,]+)\\s+\\(([\\d,]+),\\s*([\\d,?]+)\\)\\s*$")
  if (is.na(m[1, 1])) return(NULL)

  num <- function(x) suppressWarnings(as.numeric(str_remove_all(x, ",")))
  tibble(
    pop_est = num(m[1, 2]),
    se = num(m[1, 3]),
    ci_low = num(m[1, 4]),
    ci_high = num(m[1, 5])
  )
}

# Sums the per-stratum "POPULATION TOTALS" rollup already present in the
# 1991/1992 POPEST worksheets, reading off the precomputed TOTALS column
# for the Cinnamon Teal ("CINN. TEAL") row rather than re-summing strata.
parse_popest_xls <- function(path) {
  for (sheet in excel_sheets(path)) {
    raw <- suppressMessages(read_excel(path, sheet = sheet, col_names = FALSE, .name_repair = "minimal"))
    names(raw) <- paste0("V", seq_len(ncol(raw)))

    totals_row <- which(apply(raw, 1, function(r) {
      any(str_detect(r, regex("population totals", ignore_case = TRUE)), na.rm = TRUE)
    }))
    if (length(totals_row) == 0) next
    totals_row <- totals_row[1]

    header_row <- totals_row + 1
    totals_col <- which(str_detect(trimws(as.character(raw[header_row, ])), regex("^totals$", ignore_case = TRUE)))
    if (length(totals_col) == 0) next
    totals_col <- paste0("V", totals_col[1])

    body <- raw[(header_row + 2):nrow(raw), ]
    cinn_row <- which(str_detect(trimws(as.character(body$V1)), regex("^cinn", ignore_case = TRUE)))
    if (length(cinn_row) == 0) next

    pop_est <- suppressWarnings(as.numeric(body[[totals_col]][cinn_row[1]]))
    return(tibble(pop_est = pop_est, se = NA_real_, ci_low = NA_real_, ci_high = NA_real_))
  }
  NULL
}

# Parses the "Cinnamon Teal" row of the annual report's "Table 1". Column
# order varies by year (some years insert a CV column, %-change columns
# move around), but the first two numbers on the row are always the
# current survey year's population estimate and SE.
parse_table1_pdf <- function(path) {
  lines <- trimws(unlist(str_split(pdf_text(path), "\n")))
  candidates <- lines[str_detect(lines, regex("^cinnamon teal", ignore_case = TRUE))]
  candidates <- candidates[str_count(candidates, "\\d") > 8]
  if (length(candidates) == 0) return(NULL)

  nums <- str_remove_all(str_extract_all(candidates[1], "-?[\\d,]+\\.?\\d*")[[1]], ",")
  nums <- suppressWarnings(as.numeric(nums))
  nums <- nums[!is.na(nums)]
  tibble(pop_est = nums[1], se = nums[2], ci_low = NA_real_, ci_high = NA_real_)
}

extract_cinnamon_teal_populations <- function(dir = data_dir) {
  files <- list.files(dir, full.names = TRUE)
  files <- files[basename(files) != ".DS_Store"]
  bn <- basename(files)

  summary_a_files <- files[
    str_detect(bn, regex("^ca-?po|bpop_rep1", ignore_case = TRUE)) &
      str_detect(bn, regex("\\.(doc|docx|txt)$", ignore_case = TRUE))
  ]
  popest_files <- files[str_detect(bn, regex("popest.*\\.xls$", ignore_case = TRUE))]
  report_pdf_files <- files[str_detect(bn, regex("bps.*report.*\\.pdf$", ignore_case = TRUE))]

  summary_a_rows <- lapply(summary_a_files, function(f) {
    parsed <- parse_summary_a(read_lines_any(f))
    if (is.null(parsed)) return(NULL)
    year <- as.integer(str_extract(basename(f), "(19|20)\\d{2}"))
    bind_cols(year = year, parsed, source_file = basename(f), source_type = "summary_a_statewide")
  })

  popest_rows <- lapply(popest_files, function(f) {
    parsed <- parse_popest_xls(f)
    if (is.null(parsed)) return(NULL)
    yy <- as.integer(str_extract(basename(f), "^\\d{2}"))
    year <- if (yy >= 50) 1900L + yy else 2000L + yy
    bind_cols(year = year, parsed, source_file = basename(f), source_type = "stratum_totals_rollup")
  })

  report_rows <- lapply(report_pdf_files, function(f) {
    parsed <- parse_table1_pdf(f)
    if (is.null(parsed)) return(NULL)
    year <- as.integer(str_extract(basename(f), "(19|20)\\d{2}"))
    bind_cols(year = year, parsed, source_file = basename(f), source_type = "annual_report_table1")
  })

  bind_rows(summary_a_rows, popest_rows, report_rows) %>%
    arrange(year)
}

cinnamon_teal_population <- extract_cinnamon_teal_populations()

cat("\nCinnamon Teal statewide population estimates by year:\n")
print(cinnamon_teal_population, n = Inf)

#usethis::use_data(cinnamon_teal_population, overwrite = TRUE)

