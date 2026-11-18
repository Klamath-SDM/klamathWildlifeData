# Pull and process waterfowl survey counts for the Klamath Basin (DRAFT)
#
# Reads the CDFW (California) and ODFW (Oregon) breeding waterfowl survey
# tables straight out of the reports (nothing is typed in by hand) and builds
# ONE data object for the package, `waterfowl_counts`, with only the survey
# stratum that contains the Klamath Basin in each state:
#
#   CDFW  Northeastern California stratum
#   ODFW  Southeast Seasonal Marsh stratum
#
# Neither survey reports the basin on its own, so these strata are larger than
# the basin. They are the smallest areas the reports give counts for.
#
# Tables read (all from the PDFs and legacy report files, nothing typed in):
#   CDFW 2026 report         Appendix IV (mallard, gadwall, Cinnamon Teal and
#                            Canada goose by stratum, 1992-2026); Table 1
#   CDFW 2016-2019 reports   Table 1 rows marked "Northeastern stratum only"
#                            (Canada geese, sandhill cranes, goslings)
#   CDFW 2019 report         Appendix IV, to check the 2026 report's series
#   CDFW 2003-2015 reports   Summary B, Northeastern stratum, every species
#   ODFW 2026 report         Appendix B, by stratum (2026, 2025, long-term average)
# The 2016-2018 reports have no by-stratum tables, and their Table 1 is
# statewide except for the rows above. When reports disagree the most recent
# report is used, since later reports revise earlier estimates.
#
# One row per agency, stratum, species and year:
#   agency, state, stratum   survey and area
#   species                  standard common name
#   species_reported         name as written in the report
#   ebird_species_code       eBird code(s); more than one, separated by ";",
#                            when the survey groups species (e.g. scaup);
#                            NA for totals
#   year
#   estimate                 population estimate (CDFW: total indicated birds
#                            expanded to the stratum; ODFW: index of breeding
#                            birds). The agencies' methods differ, so keep
#                            them apart until it is clear that they can be
#                            combined.
#   se                       standard error, when reported
#   tib                      CDFW total indicated birds, when reported
#   lta                      the report's long-term average for the stratum
#   source                   the report(s) the row's values come from; the
#                            estimate comes first when reports differ
#
# Sections: 0 setup, 1 CDFW, 2 ODFW, 3 species and eBird codes, 4 build the
# object, 5 checks, 6 save. Run from the package root.

# 0. Setup ---------------------------------------------------------------------

suppressPackageStartupMessages({
  library(tidyverse)
  library(pdftools)
  library(here)
})

reports_dir <- here("data-raw", "waterfowl", "reports")
cdfw_dir <- here("data-raw", "waterfowl", "dmp000455_data")

cdfw_2026 <- file.path(reports_dir, "2026 CA BPS Report Final.pdf")
cdfw_2019 <- file.path(cdfw_dir, "BPS annual report 2019  Final.pdf")
odfw_2026 <- file.path(reports_dir, "2026 Oregon Breeding Waterfowl Population Report.pdf")
stopifnot(file.exists(cdfw_2026, odfw_2026))

# The strata that contain the Klamath Basin. Add rows here to include more.
# ODFW's Forested Wetlands stratum runs along the California border, but the
# report does not say it overlaps the basin, so it is left out.
klamath_strata <- tribble(
  ~agency, ~state, ~stratum,
  "CDFW", "CA", "Northeastern California",
  "ODFW", "OR", "Southeast Seasonal Marsh"
)

save_data <- FALSE # section 6 writes data/waterfowl_counts.rda

# Page text is read once per file.
.pdf_cache <- new.env()
pdf_pages <- function(path) {
  if (is.null(.pdf_cache[[path]])) .pdf_cache[[path]] <- pdf_text(path)
  .pdf_cache[[path]]
}
page_lines <- function(path, page) strsplit(pdf_pages(path)[page], "\n")[[1]]

# "1,234" -> 1234; "-", "—" and blanks -> NA
num <- function(x) {
  x <- gsub("[,%*]", "", x)
  x[x %in% c("-", "—", "–", "")] <- NA
  suppressWarnings(as.numeric(x))
}

# 1. CDFW (California) -----------------------------------------------------------

cdfw_strata <- c(
  SV = "Sacramento Valley", DE = "Sacramento-San Joaquin Delta",
  SJD = "San Joaquin Desert", SJG = "San Joaquin Grasslands",
  SM = "Suisun Marsh", NSR = "Napa-Santa Rosa",
  NE = "Northeastern California", EV = "East Valley", WV = "West Valley"
)

# 1a. Appendix IV of the 2026 report: mallard, gadwall, Cinnamon Teal and Canada
# goose estimates by stratum and year, 1992-2026, plus the long-term average
# (LTA). One page per species.
read_cdfw_appendix_iv <- function(pdf) {
  species_titles <- c(
    "Mallards?" = "Mallard", "Gadwall" = "Gadwall",
    "Cinnamon Teal" = "Cinnamon Teal", "Canada Geese?" = "Canada Geese"
  )
  pages <- pdf_pages(pdf)

  map(seq_along(pages), \(i) {
    lines <- page_lines(pdf, i)
    header <- grep("^\\s*Year\\s+SV", lines, value = TRUE)
    if (length(header) == 0 || !str_detect(pages[i], "Appendix IV")) {
      return(NULL)
    }
    title <- names(species_titles)[map_lgl(names(species_titles), \(p) any(str_detect(lines, paste0("^\\s+", p, "\\s*$"))))]
    stopifnot(length(title) == 1)
    cols <- str_split(trimws(header), "\\s+")[[1]]
    cols[cols == "STATE"] <- "TOTAL" # the 2019 report calls the total column "STATE"

    rows <- grep("^\\s*((19|20)\\d{2}|LTA)\\s+[0-9]", lines, value = TRUE)
    map(rows, \(r) {
      tok <- str_split(trimws(r), "\\s+")[[1]]
      tibble(
        species_reported = species_titles[[title]],
        year = suppressWarnings(as.integer(tok[1])), # NA for the LTA row
        code = cols[-1],
        value = num(tok[-1])[seq_along(cols[-1])],
        n_tokens = length(tok)
      )
    }) |>
      list_rbind()
  }) |>
    list_rbind() |>
    mutate(stratum = if_else(code == "TOTAL", "California total", unname(cdfw_strata[code])))
}

cdfw_appendix_iv <- read_cdfw_appendix_iv(cdfw_2026) |>
  # A row is suspect if it has the wrong number of values or its strata do not
  # add up to the row total (the PDF has at least one typo: "4,11" for Canada
  # goose, San Joaquin Grasslands, 2024). The report rounds, so allow a few birds.
  mutate(
    parse_flag = n_tokens != 11 |
      abs(sum(value[code != "TOTAL"], na.rm = TRUE) - value[code == "TOTAL"][1]) > 5,
    .by = c(species_reported, year)
  ) |>
  select(-n_tokens)

# 1b. Table 1 of the 2016-2019 and 2026 reports. Table 1 is statewide, except for
# the rows the footnotes mark as "Northeastern stratum estimates only": Canada
# geese (all five reports), sandhill cranes (2018, 2019, 2026) and Canada goose
# goslings (2019). Those rows are the Northeastern stratum, so they are kept.
# Each report gives its own year and the year before, with SEs and the LTA.
cdfw_table1_reports <- tribble(
  ~report_year, ~file, ~has_cv,
  2016, file.path(cdfw_dir, "CDFW BPS annual report 2016 Final.pdf"), FALSE,
  2017, file.path(cdfw_dir, "BPS annual report 2017 Final.pdf"), FALSE,
  2018, file.path(cdfw_dir, "BPS annual report 2018 Final.pdf"), FALSE,
  2019, cdfw_2019, TRUE,
  2026, cdfw_2026, TRUE
)

read_cdfw_table1 <- function(file, report_year, has_cv, rows = "Canada Geese|Sandhill Crane|Goslings|Mallard|Cinnamon Teal") {
  pages <- pdf_pages(file)
  p <- which(str_detect(pages, "Table 1\\.") & str_detect(pages, "Mallard"))[1]
  lines <- page_lines(file, p)
  lines <- str_replace_all(trimws(lines), "\u2212", "-") # unicode minus in the 2017 report

  m <- str_match(lines, paste0("^(", rows, ")\\s*(.*)$"))
  m <- m[!is.na(m[, 1]), , drop = FALSE]

  map(seq_len(nrow(m)), \(i) {
    # drop footnote markers ("2,3" or "3") between the name and the numbers
    rest <- str_replace(trimws(m[i, 3]), "^[1-4](,[1-4])*\\s+", "")
    tok <- str_split(gsub("%", "", rest), "\\s+")[[1]]
    k <- if (has_cv) 4 else 3 # position of the prior-year estimate
    tibble(
      species_reported = m[i, 2], report_year = report_year,
      year = report_year + c(0L, -1L),
      estimate = num(tok[c(1, k)]), se = num(tok[c(2, k + 1)]),
      lta = num(tok[k + 2])
    )
  }) |>
    list_rbind()
}

cdfw_table1_all <- cdfw_table1_reports |>
  pmap(\(report_year, file, has_cv) read_cdfw_table1(file, report_year, has_cv)) |>
  list_rbind()

# the statewide rows are only used to check Appendix IV; the stratum rows are
# the three marked in the footnotes
cdfw_table1_ne <- cdfw_table1_all |>
  filter(species_reported %in% c("Canada Geese", "Sandhill Crane", "Goslings"))

# 1c. Northeastern California stratum, every survey-sheet species, 2003-2015
# ("Summary B" in the older reports). The legacy .doc/.docx files are converted
# with macOS `textutil`.
read_report_text <- function(path) {
  if (tolower(tools::file_ext(path)) == "txt") {
    readLines(path, warn = FALSE)
  } else {
    system2("textutil", c("-convert", "txt", "-stdout", shQuote(path)), stdout = TRUE)
  }
}

cdfw_ne_files <- c(
  "2003" = "ca-pop2003.doc", "2004" = "ca-pop2004.doc", "2005" = "ca-pop2005.doc",
  "2006" = "ca-pop2006.doc", "2007" = "ca-pop2007.doc", "2008" = "ca-pop2008.doc",
  "2009" = "ca-pop_2009.doc", "2010" = "ca-po2010.doc", "2011" = "2011 ca_bpop_rep1.docx",
  "2012" = "2012 ca_bpop_rep1.txt", "2013" = "2013 ca_bpop_rep1.docx",
  "2014" = "2014 ca_bpop_rep1.docx", "2015" = "2015 ca_bpop_rep1.docx"
)

read_cdfw_ne_species <- function() {
  row_rx <- "^\\s*(\\d{4})\\s+([A-Za-z][A-Za-z .'-]*?)\\s+(\\d+)\\s+(\\d+)\\s+(\\d+)\\s+\\((\\d+),\\s*([0-9?]+)\\)"

  ne <- imap(cdfw_ne_files, \(file, year) {
    text <- read_report_text(file.path(cdfw_dir, file))
    header <- grep("Northeastern Cal.*\\(EF", text)[1]
    first <- str_match(text[header], "^\\s*([A-Za-z/ ]+?)\\s*\\(EF")[, 2]
    stopifnot("Northeastern must be the first stratum on its header" = str_detect(first, "Northeastern"))

    rows <- str_match(text[(header + 1):min(length(text), header + 45)], row_rx)
    rows <- rows[!is.na(rows[, 1]) & !duplicated(rows[, 2]), , drop = FALSE]
    stopifnot(nrow(rows) >= 19)

    tibble(
      year = as.integer(year), aou = rows[1:19, 2], species_reported = trimws(rows[1:19, 3]),
      tib = as.numeric(rows[1:19, 4]), estimate = as.numeric(rows[1:19, 5]),
      se = as.numeric(rows[1:19, 6])
    )
  }) |>
    list_rbind()

  # Species spellings change between reports; use the 2012 spelling per AOU code.
  ne |>
    select(-species_reported) |>
    left_join(ne |> filter(year == 2012) |> select(aou, species_reported), by = "aou") |>
    select(-aou)
}

stopifnot("2003-2015 CDFW reports are .doc/.docx files and need macOS `textutil`" = nzchar(Sys.which("textutil")))
cdfw_ne_species <- read_cdfw_ne_species()

# 2. ODFW (Oregon) ---------------------------------------------------------------

# Appendix B of the 2026 report: one table per species by stratum, for 2026,
# 2025 and the long-term average (1994-2025).
read_odfw_appendix_b <- function(pdf) {
  pages <- pdf_pages(pdf)
  idx <- grep("Region\\s+2026\\s+2025", pages)
  region_rx <- "^\\s*(Southeast Seasonal Marsh|Northeast Seasonal Marsh|Forested Wetlands|Willamette Valley|Lower Columbia River|Total)\\s+(.*)$"

  map(idx, \(i) {
    lines <- page_lines(pdf, i)
    species <- str_trim(lines[str_detect(lines, "^\\s*[A-Z][A-Z' /-]+\\s*$")][1])
    m <- str_match(lines, region_rx)
    m <- m[!is.na(m[, 1]), , drop = FALSE]

    # With a 2025 estimate of 0 the "% change from 2025" cell is blank, so read
    # the 2026 and 2025 values from the front and the LTA from the back.
    map(seq_len(nrow(m)), \(j) {
      tok <- str_split(str_trim(gsub("[,%*]", "", m[j, 3])), "\\s+")[[1]]
      tibble(
        species_reported = species, stratum = m[j, 2],
        est_2026 = num(tok[1]), est_2025 = num(tok[2]), lta = num(tok[length(tok) - 1])
      )
    }) |>
      list_rbind()
  }) |>
    list_rbind() |>
    mutate(
      species_reported = str_to_title(species_reported) |>
        str_replace("Ring-Necked", "Ring-necked") |>
        str_replace("Blue-Winged", "Blue-winged") |>
        str_replace("Green-Winged", "Green-winged")
    )
}

odfw_appendix_b <- read_odfw_appendix_b(odfw_2026)

# 3. Species and eBird codes -------------------------------------------------------
#
# The surveys report some species together (scaup, goldeneyes, snow and Ross's
# goose), so one survey name can map to several eBird species. The crosswalk is
# conservative: CDFW's "Scaup" is Lesser Scaup and "Goldeneye" is Common
# Goldeneye in CDFW's species guidelines, but the grouped names are kept so that
# the two surveys line up. eBird codes come from ebirdst's species list.

standardize_species <- function(x) {
  x <- str_squish(x)
  case_when(
    x %in% c("Mallards", "Mallard") ~ "Mallard",
    x %in% c("Canada Geese", "Canada Goose") ~ "Canada Goose",
    x %in% c("Green-winged Teal", "American Green-winged Teal") ~ "Green-winged Teal",
    x %in% c("Greater/Lesser Scaup", "Scaup") ~ "Scaup (Greater/Lesser)",
    x %in% c("Common/Barrow's Goldeneye", "Goldeneye", "Goldeneyes") ~ "Goldeneye (Common/Barrow's)",
    x %in% c("Goslings") ~ "Canada Goose (goslings)",
    x %in% c("Merganser", "Common Merganser") ~ "Common Merganser", # CDFW AOU 1290
    x %in% c("TOTAL DUCKS", "Total Ducks") ~ "Total ducks",
    .default = x
  )
}

# standard name -> eBird common name(s)
ebird_names <- tribble(
  ~species, ~ebird_common_name,
  "Mallard", "Mallard",
  "Gadwall", "Gadwall",
  "American Wigeon", "American Wigeon",
  "Green-winged Teal", "Green-winged Teal",
  "Blue-winged Teal", "Blue-winged Teal",
  "Cinnamon Teal", "Cinnamon Teal",
  "Northern Shoveler", "Northern Shoveler",
  "Northern Pintail", "Northern Pintail",
  "Wood Duck", "Wood Duck",
  "Redhead", "Redhead",
  "Canvasback", "Canvasback",
  "Scaup (Greater/Lesser)", "Greater Scaup",
  "Scaup (Greater/Lesser)", "Lesser Scaup",
  "Ring-necked Duck", "Ring-necked Duck",
  "Goldeneye (Common/Barrow's)", "Common Goldeneye",
  "Goldeneye (Common/Barrow's)", "Barrow's Goldeneye",
  "Bufflehead", "Bufflehead",
  "Ruddy Duck", "Ruddy Duck",
  "Common Merganser", "Common Merganser",
  "Hooded Merganser", "Hooded Merganser",
  "Canada Goose", "Canada Goose",
  "Canada Goose (goslings)", "Canada Goose",
  "Trumpeter Swan", "Trumpeter Swan",
  "American Coot", "American Coot",
  "Sandhill Crane", "Sandhill Crane"
)

stopifnot("this script needs the ebirdst package for species codes" = requireNamespace("ebirdst", quietly = TRUE))

species_codes <- ebird_names |>
  left_join(
    ebirdst::ebirdst_runs |> select(species_code, ebird_common_name = common_name),
    by = "ebird_common_name"
  ) |>
  summarise(ebird_species_code = paste(species_code, collapse = ";"), .by = species)

# 4. Build the object ----------------------------------------------------------------

# Every value is a row (agency, stratum, species, year, metric) with a priority
# for choosing between reports. When more than one report gives the same value
# the most recent report wins, because later reports revise earlier estimates
# (e.g. the 2019 report revises the 2018 sandhill crane estimate from 2,489 to
# 1,823). A value from a report's prior-year column ranks just below that
# report's own year.
cdfw_rows <- bind_rows(
  # Appendix IV of the 2026 report: four species, 1992-2026, plus the LTA
  cdfw_appendix_iv |>
    filter(stratum == "Northeastern California") |>
    mutate(
      metric = if_else(is.na(year), "lta", "estimate"),
      source = "2026 CA BPS report, Appendix IV", priority = 2026
    ) |>
    select(species_reported, stratum, year, metric, value, source, priority),
  # Summary B of the 2003-2015 reports: every species, Northeastern stratum
  cdfw_ne_species |>
    pivot_longer(c(tib, estimate, se), names_to = "metric", values_to = "value") |>
    mutate(
      stratum = "Northeastern California",
      source = "2003-2015 CA BPS reports, Summary B", priority = year
    ) |>
    select(species_reported, stratum, year, metric, value, source, priority),
  # Table 1 of the 2016-2019 and 2026 reports: Northeastern-only rows
  cdfw_table1_ne |>
    pivot_longer(c(estimate, se, lta), names_to = "metric", values_to = "value") |>
    mutate(
      stratum = "Northeastern California",
      priority = report_year - 0.5 * (year != report_year),
      year = if_else(metric == "lta", NA_integer_, as.integer(year)),
      source = paste(report_year, "CA BPS report, Table 1")
    ) |>
    select(species_reported, stratum, year, metric, value, source, priority)
) |>
  mutate(agency = "CDFW", state = "CA")

# ODFW: Appendix B of the 2026 report, 2026 and 2025 estimates and the LTA
odfw_rows <- odfw_appendix_b |>
  pivot_longer(c(est_2026, est_2025, lta), names_to = "metric", values_to = "value") |>
  mutate(
    year = case_when(metric == "est_2026" ~ 2026L, metric == "est_2025" ~ 2025L, .default = NA_integer_),
    metric = if_else(metric == "lta", "lta", "estimate"),
    source = "2026 OR breeding waterfowl report, Appendix B", priority = 2026,
    agency = "ODFW", state = "OR"
  ) |>
  select(species_reported, stratum, year, metric, value, source, priority, agency, state)

chosen <- bind_rows(cdfw_rows, odfw_rows) |>
  semi_join(klamath_strata, by = c("agency", "stratum")) |>
  mutate(species = standardize_species(species_reported)) |>
  filter(!is.na(value)) |>
  slice_max(priority, by = c(agency, stratum, species, year, metric), with_ties = FALSE)

waterfowl_counts <- chosen |>
  filter(metric != "lta") |>
  pivot_wider(
    id_cols = c(agency, state, stratum, species, year),
    names_from = metric, values_from = value
  ) |>
  left_join(
    # name as reported with the estimate that was kept
    chosen |> filter(metric == "estimate") |> select(agency, stratum, species, year, species_reported),
    by = c("agency", "stratum", "species", "year")
  ) |>
  left_join(
    # every report the row's values (estimate, SE, TIB) come from
    chosen |>
      filter(metric != "lta") |>
      summarise(source = paste(unique(source), collapse = "; "), .by = c(agency, stratum, species, year)),
    by = c("agency", "stratum", "species", "year")
  ) |>
  left_join(
    chosen |> filter(metric == "lta") |> select(agency, stratum, species, lta = value),
    by = c("agency", "stratum", "species")
  ) |>
  left_join(species_codes, by = "species") |>
  select(agency, state, stratum, species, species_reported, ebird_species_code, year, estimate, se, tib, lta, source) |>
  arrange(agency, species, year)

# 5. Checks ---------------------------------------------------------------------------
# Each parse is compared with a total or an average the report itself gives.

# Table 1 parse: every report gives 2 years for each row, and the statewide
# mallard and Cinnamon Teal rows match the statewide totals in Appendix IV
statewide_check <- cdfw_table1_all |>
  filter(species_reported %in% c("Mallard", "Cinnamon Teal")) |>
  inner_join(
    cdfw_appendix_iv |> filter(code == "TOTAL", !is.na(year)) |> select(species_reported, year, appendix = value),
    by = c("species_reported", "year")
  )

# CDFW Appendix IV: 4 species, every year 1992-2026 has 9 strata and a total
stopifnot(
  "Appendix IV should cover 4 species" = n_distinct(cdfw_appendix_iv$species_reported) == 4,
  "Appendix IV year range" = identical(range(cdfw_appendix_iv$year, na.rm = TRUE), c(1992L, 2026L)),
  "Table 1 should give 5 reports x 2 years x 5 rows plus goslings and sandhill cranes" = nrow(cdfw_table1_all) == 38,
  "Table 1 statewide mallard and Cinnamon Teal match Appendix IV (within 1) for most years" =
    nrow(statewide_check) >= 14 && mean(abs(statewide_check$estimate - statewide_check$appendix) <= 1) > 0.8
)

# CDFW: Northeastern-stratum Cinnamon Teal in the old reports matches Appendix IV
ne_cmp <- cdfw_ne_species |>
  filter(species_reported == "Cinnamon Teal") |>
  inner_join(
    cdfw_appendix_iv |> filter(species_reported == "Cinnamon Teal", code == "NE") |> select(year, appendix = value),
    by = "year"
  )
stopifnot("Summary B Cinnamon Teal should match Appendix IV within 1" = mean(abs(ne_cmp$estimate - ne_cmp$appendix) <= 1) > 0.9)

# CDFW: the 2019 report's Appendix IV (1992-2019) against the 2026 report's
cdfw_iv_2019 <- read_cdfw_appendix_iv(cdfw_2019)
iv_compare <- inner_join(
  cdfw_iv_2019 |> filter(!is.na(year)) |> select(species_reported, stratum, year, v2019 = value),
  cdfw_appendix_iv |> filter(!is.na(year)) |> select(species_reported, stratum, year, v2026 = value),
  by = c("species_reported", "stratum", "year")
)
stopifnot("2019 and 2026 Appendix IV should cover the same cells for 1992-2019" = nrow(iv_compare) == (3 * 28 + 27) * 10) # Canada geese start in 1993

# CDFW: Northeastern Canada goose in Table 1 against Appendix IV (NE column)
goose_compare <- cdfw_table1_ne |>
  filter(species_reported == "Canada Geese") |>
  inner_join(
    cdfw_appendix_iv |> filter(species_reported == "Canada Geese", code == "NE") |> select(year, appendix = value),
    by = "year"
  )

# ODFW: strata add up to the state total for every species; 22 species tables
odfw_sum <- odfw_appendix_b |>
  summarise(
    strata = sum(est_2026[stratum != "Total"]), total = est_2026[stratum == "Total"],
    .by = species_reported
  )
stopifnot(
  "ODFW Appendix B should cover 22 tables" = nrow(odfw_sum) == 22,
  "ODFW strata should add up to the state total (within 3)" = all(abs(odfw_sum$strata - odfw_sum$total) <= 3)
)

# The object: one stratum per agency, no duplicate keys, and the report values
# for Cinnamon Teal in 2026
ct_2026 <- waterfowl_counts |> filter(species == "Cinnamon Teal", year == 2026)
stopifnot(
  "only the applicable strata should remain" =
    nrow(distinct(waterfowl_counts, agency, stratum)) == nrow(klamath_strata),
  "one row per agency, species and year" =
    !anyDuplicated(waterfowl_counts[c("agency", "species", "year")]),
  "CDFW Northeastern Cinnamon Teal 2026 is 28,077" = ct_2026$estimate[ct_2026$agency == "CDFW"] == 28077,
  "ODFW Southeast Seasonal Marsh Cinnamon Teal 2026 is 26,405" = ct_2026$estimate[ct_2026$agency == "ODFW"] == 26405,
  "CDFW Northeastern sandhill crane 2026 (Table 1) is 5,831" =
    waterfowl_counts$estimate[waterfowl_counts$agency == "CDFW" & waterfowl_counts$species == "Sandhill Crane" & waterfowl_counts$year == 2026] == 5831
)

# Things to look at rather than stop for
no_code <- waterfowl_counts |> filter(is.na(ebird_species_code), species != "Total ducks") |> distinct(species)
if (nrow(no_code) > 0) warning("No eBird code for: ", paste(no_code$species, collapse = ", "))

flagged <- cdfw_appendix_iv |> filter(parse_flag, stratum == "Northeastern California")
if (nrow(flagged) > 0) {
  warning("CDFW Appendix IV rows whose strata do not add up to the total (check the source PDF): ",
          paste(distinct(flagged, species_reported, year) |> unite("x", species_reported, year, sep = " ") |> pull(x), collapse = ", "))
}

iv_changed <- iv_compare |> filter(abs(v2019 - v2026) > 5, stratum == "Northeastern California")
if (nrow(iv_changed) > 0) {
  message("Appendix IV: the 2026 report revises ", nrow(iv_changed), " Northeastern values from the 2019 report (",
          paste(unique(iv_changed$species_reported), collapse = ", "), "; years ", paste(sort(unique(iv_changed$year)), collapse = ", "),
          "). The 2026 values are used.")
}

goose_off <- goose_compare |> filter(abs(estimate - appendix) > 5)
if (nrow(goose_off) > 0) {
  warning("Canada goose Northeastern estimate differs between Table 1 and Appendix IV in ", paste(goose_off$year, collapse = ", "),
          " (Appendix IV is used)")
}


# visualize ---------------------------------------------------------------

plot_data <- waterfowl_counts |>
  filter(species != "Total ducks", !is.na(estimate)) |>
  filter(max(estimate) > 0, .by = species) |>      # drops species never recorded (hooded merganser)
  mutate(
    species = fct_reorder(species, estimate, .fun = max, .desc = TRUE),   # biggest first
    survey = if_else(state == "CA",
                     "California (CDFW), Northeastern stratum",
                     "Oregon (ODFW), Southeast Seasonal Marsh")
  ) |>
  arrange(agency, species, year) |>
  mutate(run = cumsum(c(TRUE, diff(year) > 1)), .by = c(agency, species))  # break lines across survey gaps

ggplot(plot_data, aes(year, estimate, color = survey, fill = survey)) +
  geom_ribbon(
    aes(ymin = pmax(estimate - se, 0), ymax = estimate + se, group = interaction(survey, run)),
    alpha = 0.15, color = NA, na.rm = TRUE
  ) +
  geom_line(aes(group = interaction(survey, run)), linewidth = 0.5) +
  geom_point(size = 1.2) +
  facet_wrap(~species, scales = "free_y", ncol = 4) +
  scale_y_continuous(
    labels = scales::label_number(scale_cut = scales::cut_short_scale()),
    limits = c(0, NA), expand = expansion(mult = c(0, 0.08))
  ) +
  scale_x_continuous(breaks = seq(1995, 2025, by = 10)) +
  scale_color_manual(values = c("#2a78d6", "#eb6834"), name = NULL) +
  scale_fill_manual(values = c("#2a78d6", "#eb6834"), name = NULL) +
  labs(
    title = "Breeding waterfowl estimates in the Klamath Basin strata",
    subtitle = "Shaded band is plus or minus one standard error where reported. Each panel has its own y-axis.",
    x = NULL, y = "Estimated birds",
    caption = "Sources: CDFW and ODFW breeding waterfowl survey reports. The surveys use different methods; compare trends, not totals."
  ) +
  theme_minimal(base_size = 10) +
  theme(
    legend.position = "top", legend.justification = "left",
    plot.title = element_text(face = "bold"), plot.title.position = "plot",
    #strip.text = element_text(face = "bold", hjust = 0),
    panel.grid.minor = element_blank(), panel.spacing = unit(1, "lines"),
    plot.caption = element_text(color = "grey40", hjust = 0)
  )

# 6. Save ---------------------------------------------------------------------------------

if (save_data) {
  usethis::use_data(waterfowl_counts, overwrite = TRUE)
}

message(
  "waterfowl_counts: ", nrow(waterfowl_counts), " rows, ",
  n_distinct(waterfowl_counts$species), " species, ",
  paste(range(waterfowl_counts$year), collapse = "-"),
  ". Set save_data <- TRUE to write data/waterfowl_counts.rda."
)
