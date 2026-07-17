# Compile Klamath County records from the USGS Oregon spotted frog
# (Rana pretiosa) observations dataset for use as package data.
#
# Source: Oregon spotted frog (Rana pretiosa) observations in Oregon
# (ver. 6.0, March 2025), USGS ScienceBase item 5c50d257e4b0708288f95251
# https://doi.org/10.5066/P940A4DW


library(dplyr)
library(stringr)
library(readr)
library(lubridate)
library(arcgislayers)
library(sf)

raw_path <- file.path("data-raw", "osf-frog", "Oregon_Spotted_Frog_Observations_in_Oregon_2016-2024.csv")

osf_raw <- read_csv(raw_path, show_col_types = FALSE)

# Township/Range are inconsistently formatted in the source file
# ("21S" vs "T21S", "9E" vs "09E" vs "7-1/2E" vs "07.5E"). Normalize both
# to a common "NNS" / "NN(.N)E" form before matching.
normalize_township <- function(x) {
  x <- str_remove(toupper(trimws(x)), "^T")
  num <- as.numeric(str_extract(x, "[0-9.]+"))
  dir <- str_extract(x, "[NS]$")
  paste0(formatC(num, width = 2, flag = "0", format = "d"), dir)
}

normalize_range <- function(x) {
  x <- str_remove(toupper(trimws(x)), "^R")
  x <- str_replace(x, "-?1/2", ".5")
  num <- as.numeric(str_extract(x, "[0-9.]+"))
  dir <- str_extract(x, "[EW]$")
  whole <- num == floor(num)
  num_str <- if_else(
    whole,
    formatC(num, width = 2, flag = "0", format = "d"),
    formatC(num, width = 4, flag = "0", format = "f", digits = 1)
  )
  paste0(num_str, dir)
}

osf_clean <- osf_raw %>%
  mutate(
    date = mdy(Date),
    count = as.integer(Count),
    township = normalize_township(Township),
    range = normalize_range(Range)
  )

# connecting to basins ----------------------------------------------------

# Layer 2 of this service = PLSS First Division (i.e., Sections)
plss_url <- "https://gis.blm.gov/arcgis/rest/services/Cadastral/BLM_Natl_PLSS_CadNSDI/MapServer/2"
plss_layer <- arc_open(plss_url)

# bbox from your huc layer, buffered a bit, in the service's CRS (WGS84 is fine)
klamath_bbox <- rivermile::klamath_hucs |>
  st_transform(4326) |>
  st_bbox() |>
  st_as_sfc()

plss_sections <- arc_select(plss_layer, filter_geom = klamath_bbox)

osf_klamath <- osf_clean |>
  janitor::clean_names() |>
  mutate(trs_key = paste0(township, "_", range, "_", sprintf("%02d", section)))

plss_sections <- plss_sections |>
  mutate(
    state        = substr(PLSSID, 1, 2),
    meridian     = substr(PLSSID, 3, 4),
    township_fmt = paste0(sprintf("%02d", as.integer(substr(PLSSID, 5, 7))), substr(PLSSID, 9, 9)),
    range_fmt    = paste0(sprintf("%02d", as.integer(substr(PLSSID, 10, 12))), substr(PLSSID, 14, 14)),
    section_fmt  = sprintf("%02d", as.integer(FRSTDIVNO)),
    trs_key      = paste0(township_fmt, "_", range_fmt, "_", section_fmt)
  )

osf_klamath <- osf_klamath |>
  mutate(trs_key = paste0(township, "_", range, "_", sprintf("%02d", section)))

osf_sf <- osf_klamath |>
  left_join(
    plss_sections |> st_drop_geometry() |> select(trs_key) |> bind_cols(geometry = st_geometry(plss_sections)),
    by = "trs_key"
  ) |>
  st_as_sf(crs = st_crs(plss_sections))

osf_hucs <- osf_sf |>
  st_centroid() |>
  st_transform(st_crs(rivermile::klamath_hucs)) |>
  st_join(rivermile::klamath_hucs, join = st_intersects)

ggplot() +
  geom_sf(data = rivermile::klamath_hucs) +
  geom_sf(data = osf_hucs)

oregon_spotted_frog <- osf_hucs |>
  filter(!is.na(huc8)) |>
  select(date = date_2, species, count, life_stage, sex, township, range, section, project) |>
  mutate(project = tolower(project),
         species = tolower(species)) |>
  glimpse()

usethis::use_data(oregon_spotted_frog, overwrite = TRUE)
