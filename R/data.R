
#' eBird Observations in the Klamath Basin Refuges
#'
#' Bird observations from the eBird Basic Dataset (EBD) for the six Klamath
#' Basin national wildlife refuges, joined to species-level habitat and diet
#' traits from BIRDBASE and to waterbird niche assignments from Donnelly et
#' al. (2022). Each observation is attributed to the refuge it falls within,
#' allowing observations to be grouped into candidate guilds by habitat, diet,
#' or waterbird niche.
#'
#' @format A tibble with 92,329 rows and 9 variables:
#' \describe{
#'   \item{common_name}{Bird species common name (277 distinct species).}
#'   \item{observation_count}{Number of individuals reported. \code{NA} where
#'     the observer recorded eBird's \code{"X"} (species present but not
#'     counted) - 4,235 rows. \code{NA} therefore means "present, uncounted",
#'     never "absent".}
#'   \item{latitude}{Latitude of the observation, WGS84 (EPSG:4326).}
#'   \item{longitude}{Longitude of the observation, WGS84 (EPSG:4326).}
#'   \item{observation_date}{Date of observation, 2015-01-01 to 2025-06-30.}
#'   \item{area}{Refuge the observation was attributed (buffered by 0.5 miles) to: \code{"Bear
#'     Valley"}, \code{"Clear Lake"}, \code{"Klamath Marsh"}, \code{"Lower
#'     Klamath - Sheepy"}, \code{"Tule Lake"}, or \code{"Upper Klamath Lake"}.
#'     This column aligns with \code{area} in
#'     \code{\link{piscivorous_waterbirds}} and with the DSWE data.}
#'   \item{primary_habitat}{Species' primary habitat from BIRDBASE, used as a
#'     grouping variable: \code{"Artificial"}, \code{"Coastal"},
#'     \code{"Forest"}, \code{"Grassland"}, \code{"Plains"},
#'     \code{"Riparian"}, \code{"Rocky"}, \code{"Savanna"}, \code{"Shrub"},
#'     \code{"Wetland"}, or \code{"Woodland"}.}
#'   \item{primary_diet}{Species' primary diet from BIRDBASE, used as a
#'     grouping variable: \code{"Carnivore"}, \code{"Fish"}, \code{"Fruit"},
#'     \code{"Herbivore"}, \code{"Invertebrate"}, \code{"Nectar"},
#'     \code{"Omnivore"}, \code{"Plant"}, \code{"Scavenger"}, \code{"Seed"},
#'     or \code{"Vertebrate"}.}
#'   \item{waterbird_niche}{Waterbird guild from Donnelly et al. (2022):
#'     \code{"Shorebirds"}, \code{"Dabbling ducks"}, \code{"Diving ducks"}, or
#'     \code{"Other waterbirds"}. \code{NA} for the 72,005 observations of
#'     species that are not waterbirds.}
#' }
#'
#' @details
#' \strong{Source data and filtering.} eBird custom downloads were taken for the
#' eight counties intersecting the Klamath Basin (California: Del Norte,
#' Humboldt, Modoc, Siskiyou, Trinity; Oregon: Jackson, Lake, Klamath) and
#' filtered with the \pkg{auk} package to complete checklists using the
#' Traveling or Stationary protocols, with a duration of 0-120 minutes and a
#' travel distance of 0-5 km.
#'
#' \strong{Spatial attribution.} Observations were assigned to refuge boundaries
#' from \code{rivermile::klamath_refuges}, each buffered by 0.5 miles so that
#' observations just outside a refuge's mapped edge are still attributed to
#' it. The Lower Klamath and Tule Lake refuges sit within a mile of each
#' other, so their buffers overlap; observations in that overlap are assigned
#' to whichever refuge is nearer rather than being counted twice.
#'
#' \strong{Interpretation.} eBird is a presence-only, volunteer-collected dataset.
#' A species absent from a checklist does not imply absence from the site.
#' Effort is unevenly distributed in space (concentrated near roads, towns,
#' and known hotspots) and in time (skewed toward weekends and toward May),
#' and detection depends on observer skill, so apparent richness partly
#' reflects survey effort rather than the bird community. See
#' \code{data-raw/bird_data_synthesis.Rmd} for the full compilation and a
#' fuller discussion of these biases.
#'
#' @source
#' eBird Basic Dataset, Cornell Lab of Ornithology.
#'   \url{https://science.ebird.org/en/use-ebird-data/download-ebird-data-products}
#'
#'   Şekercioğlu, Ç. H., Kittelberger, K. D., Mota, F., Buxton, A. N., Orton,
#'   N., DeNiro, A., et al. (2025). BIRDBASE: A Global Database of Avian
#'   Biogeography, Conservation, Ecology and Life History Traits. figshare.
#'   \doi{10.6084/m9.figshare.27051040.v1}
#'
#'   Donnelly, J. P., Moore, J. N., Casazza, M. L., & Coons, S. P. (2022).
#'   Functional wetland loss drives emerging risks to waterbird migration
#'   networks. \emph{Frontiers in Ecology and Evolution, 10}, 844278.
#'   \doi{10.3389/fevo.2022.844278}
#'
#' @seealso \code{\link{piscivorous_waterbirds}} for colony nest counts that
#'   share the \code{area} column.
#'
#' @examples
#' \dontrun{
#' klamath_ebird
#'
#' # Species richness by refuge and year
#' library(dplyr)
#' klamath_ebird |>
#'   mutate(year = lubridate::year(observation_date)) |>
#'   summarise(richness = n_distinct(common_name), .by = c(area, year))
#'
#' # Waterbird niches only
#' klamath_ebird |>
#'   filter(!is.na(waterbird_niche)) |>
#'   count(waterbird_niche, area)
#' }
#' @keywords datasets
"klamath_ebird"


#' Piscivorous Waterbird Colony Counts in the Klamath Basin
#'
#' Peak counts of nesting piscivorous waterbirds at colonies in the Upper
#' Klamath Basin, compiled from Real Time Research (RTR) and USGS survey
#' reports. These species are of interest as predators of juvenile and adult
#' Lost River and Shortnose suckers.
#'
#' @format A tibble with 110 rows and 6 variables:
#' \describe{
#'   \item{nesting_location}{Colony name as given in the original report:
#'     \code{"Clear Lake Reservoir"}, \code{"Klamath River"}, \code{"Sheepy
#'     Lake"}, \code{"Tule Lake"}, or \code{"Upper Klamath Lake"}.}
#'   \item{common_name}{Species or species group: \code{"American White
#'     Pelican"}, \code{"Caspian Tern"}, \code{"Double-crested Cormorant"},
#'     \code{"Gulls"} (California and Ring-billed gulls combined), or
#'     \code{"Herons"} (Great Blue Heron, Great Egret, and Black-crowned
#'     Night Heron combined).}
#'   \item{year}{Year of survey, 2009 to 2024.}
#'   \item{count}{Peak number of adults observed on-colony, 0 to 3,872.
#'     \code{0} means the colony was surveyed and the species was absent;
#'     \code{NA} (10 rows) means the colony was active but not counted. The
#'     two are not interchangeable.}
#'   \item{source}{Table and report the value was transcribed from.}
#'   \item{area}{Refuge area, aligned with \code{area} in
#'     \code{\link{klamath_ebird}} and with the DSWE data. \code{"Sheepy
#'     Lake"} maps to \code{"Lower Klamath - Sheepy"}; other locations keep
#'     their names.}
#' }
#'
#' @details
#' \strong{Methods.} RTR estimates are based on the number of adult birds visible
#' on-colony in oblique aerial photographs taken during the breeding season,
#' with one to three aerial surveys per year. Colony size is taken from the
#' late incubation / early chick-rearing period, when the greatest number of
#' breeding adults is generally present. Values are therefore peak counts of
#' adults, not nest counts or totals across the season.
#'
#' \strong{Temporal coverage.} This dataset is restricted to 2009 onward. A
#' historical baseline for Clear Lake Reservoir covering 1952-1956 (USFWS
#' 1957 Clear Lake Refuge Report, table 8) is transcribed in
#' \code{data-raw/bird_data_synthesis.Rmd} and used there to compare against
#' present-day trends, but it is \strong{not} included here. Coverage is also
#' uneven within 2009-2024 and the panel is unbalanced: 2016 and 2017 are
#' absent entirely; Sheepy Lake and Tule Lake records begin in 2018; Klamath
#' River appears only in 2024; Upper Klamath Lake has no 2021 record; and
#' Tule Lake has none for 2022-2023. Trends should not be read as though
#' every colony were surveyed every year.
#'
#' @source
#' Evans, A. F., Payton, Q., Banet, N., Cramer, B. M., Kelsey, C., & Hewitt,
#'   D. A. (2022). Avian predation on juvenile and adult Lost River and
#'   Shortnose suckers: An updated multi-predator species evaluation.
#'   \emph{North American Journal of Fisheries Management}.
#'   \doi{10.1002/nafm.10838}
#'
#'   Banet, N., Payton, Q., Evans, A., Krause, J., Hayes, B., Paul-Wilson,
#'   R., & Benham, E. (2024). Predation of Lost River and Shortnose suckers by
#'   piscivorous colonial waterbirds in the Upper Klamath Basin: An analysis
#'   of predation effects in 2021-2023. U.S. Bureau of Reclamation.
#'
#'   Banet, N., Payton, Q., Devincenzi, D., Evans, A., Krause, J., Hayes, B.,
#'   Paul-Wilson, R., & Benham, E. (2025). Predation of Lost River and
#'   Shortnose suckers by piscivorous colonial waterbirds in the Upper
#'   Klamath Basin: An analysis of predation effects in 2024 (Final report).
#'   U.S. Bureau of Reclamation.
#'
#' @seealso \code{\link{klamath_ebird}} for eBird observations that share the
#'   \code{area} column.
#'
#' @examples
#' \dontrun{
#' piscivorous_waterbirds
#'
#' # Counts over time by colony, dropping uncounted-but-active colonies
#' library(dplyr)
#' piscivorous_waterbirds |>
#'   filter(!is.na(count)) |>
#'   summarise(total = sum(count), .by = c(year, nesting_location))
#' }
#' @keywords datasets
"piscivorous_waterbirds"

#' Oregon Spotted Frog Observations in Klamath County, Oregon
#'
#' Point observations of Oregon spotted frog (\emph{Rana pretiosa}) within
#' Klamath County, Oregon, filtered from a statewide USGS dataset of
#' observations spanning 2016-2024. Records are drawn from monitoring and
#' research projects including breeding surveys, trapping, telemetry, and
#' genetics studies. Each record was matched to a HUC8 subbasin from its
#' PLSS Township/Range/Section location.
#'
#' @format An \code{sf} object with 462 rows and 10 variables:
#' \describe{
#'   \item{date}{Date of observation, 2016-04-26 to 2024-08-29.}
#'   \item{species}{Species observed, lowercased (\code{"rana pretiosa"}).}
#'   \item{count}{Number of individuals/egg masses observed, 1-91.}
#'   \item{life_stage}{Life stage observed: \code{"egg mass"}, \code{"larva"},
#'     \code{"metamorph"}, \code{"juvenile"}, \code{"subadult"}, or
#'     \code{"adult"}.}
#'   \item{sex}{Sex of the individual(s): \code{"male"}, \code{"female"}, or
#'     \code{"unknown"}.}
#'   \item{township}{PLSS Township, normalized to \code{"NNS"} form (e.g.
#'     \code{"33S"}).}
#'   \item{range}{PLSS Range, normalized to \code{"NNE"} / \code{"NN.NE"}
#'     form (e.g. \code{"07.5E"}).}
#'   \item{section}{PLSS Section number.}
#'   \item{project}{Project or survey type under which the observation was
#'     recorded, lowercased (e.g. \code{"breeding"}, \code{"trapping"},
#'     \code{"telemetry"}, \code{"genetics"}, \code{"apex"}, \code{"mid-level"},
#'     \code{"water quality"}).}
#'   \item{geometry}{Point geometry (\code{sfc_POINT}) giving the centroid of
#'     the observation's PLSS section, in NAD83 (EPSG:4269).}
#' }
#'
#' @details
#' Only rows whose Township/Range fall within a manually compiled list of
#' Klamath County PLSS combinations are retained, and only rows that could
#' be matched to a HUC8 subbasin (via spatial join of the PLSS section
#' centroid against Klamath basin HUCs) are included. See
#' \code{data-raw/osf-frog/compile_osf_klamath.R} for the full compilation
#' script.
#'
#' @source Oregon spotted frog (\emph{Rana pretiosa}) observations in Oregon
#'   (ver. 6.0, March 2025), U.S. Geological Survey data release.
#'   \doi{10.5066/P940A4DW}
#'
#' @examples
#' \dontrun{
#' oregon_spotted_frog
#'
#' # Egg mass counts by year
#' library(dplyr)
#' oregon_spotted_frog |>
#'   filter(life_stage == "egg mass") |>
#'   mutate(year = lubridate::year(date)) |>
#'   count(year, wt = count)
#' }
"oregon_spotted_frog"

