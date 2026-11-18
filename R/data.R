#' Breeding Waterfowl Survey Counts for the Klamath Basin Strata (CDFW and ODFW)
#'
#' Population estimates from the California Department of Fish and Wildlife
#' (CDFW) California Waterfowl Breeding Population Survey and the Oregon
#' Department of Fish and Wildlife (ODFW) Oregon Breeding Waterfowl Population
#' Survey, for the one survey stratum in each state that contains the Klamath
#' Basin. The surveys do not report the basin on its own, so these strata are
#' larger than the basin: they are the smallest areas the reports give counts
#' for. Rows join to \code{klamath_ebird} and \code{ebird_status} by
#' \code{common_name}.
#'
#' @format A tibble with 407 rows and 12 variables:
#' \describe{
#'   \item{agency}{Survey agency: \code{"CDFW"} or \code{"ODFW"}.}
#'   \item{state}{\code{"CA"} or \code{"OR"}.}
#'   \item{stratum}{Survey stratum: \code{"Northeastern California"} (CDFW) or
#'     \code{"Southeast Seasonal Marsh"} (ODFW). One stratum per agency.}
#'   \item{species}{The survey's name for the species or group, standardized
#'     across reports (for example \code{"Canada Geese"} and
#'     \code{"Canada Goose"} both become \code{"Canada Goose"}). Includes
#'     groups such as \code{"Scaup (Greater/Lesser)"} and
#'     \code{"Goldeneye (Common/Barrow's)"}, and \code{"Canada Goose
#'     (goslings)"}.}
#'   \item{common_name}{eBird common name, for joining to
#'     \code{klamath_ebird$common_name} and \code{ebird_status$common_name}.
#'     \code{NA} where there is no single eBird species: the ODFW
#'     \code{"Total ducks"} rows and the Canada goose goslings.}
#'   \item{grouped}{\code{TRUE} when the survey reports several eBird species
#'     together (scaup and goldeneyes). The group's row is repeated once per
#'     eBird common name, with the same estimate, so do not add \code{grouped}
#'     rows together.}
#'   \item{year}{Survey year.}
#'   \item{estimate}{Population estimate. CDFW: total indicated birds (TIB)
#'     corrected for detectability and expanded to the stratum. ODFW: index of
#'     breeding birds expanded from the transects to the stratum. The methods
#'     differ (see Details).}
#'   \item{se}{Standard error of \code{estimate}, when the report gives one.}
#'   \item{tib}{CDFW total indicated birds in the stratum (before expansion),
#'     from the 2003-2015 reports; \code{NA} otherwise.}
#'   \item{lta}{The report's long-term average for the species in the stratum
#'     (one value per species and stratum). \code{NA} for the CDFW species that
#'     appear only in the 2003-2015 reports.}
#'   \item{source}{The report table(s) the row's values come from, estimate
#'     first, for example \code{"2026 CA BPS report, Appendix IV; 2019 CA BPS
#'     report, Table 1"}.}
#' }
#'
#' @details
#' \strong{Coverage.} CDFW: 1992-2026 (not flown in 2020 or 2021). Mallard,
#' gadwall and Cinnamon Teal cover every survey year and Canada goose every year
#' from 1993, from Appendix IV of the 2026 report. Every other species was read
#' from the 2003-2015 reports and covers 2003-2015 only. Sandhill crane (2017,
#' 2018, 2019, 2025, 2026) and goslings (2018, 2019) come from Table 1 of the
#' 2016-2019 and 2026 reports. ODFW: 2025 and 2026 only, because the report gives
#' estimates by stratum for those years and the long-term average; the statewide
#' series back to 1994 is not included.
#'
#' \strong{Strata.} The CDFW Northeastern California stratum contains the
#' Klamath Basin (16 flight legs and 24 waypoints) along with other
#' northeastern areas. The ODFW Southeast Seasonal Marsh stratum contains Upper
#' Klamath, Lower Klamath, Klamath Marsh, the Sprague River Valley and Sycan
#' Marsh, together with the Harney, Malheur, Lake and other basins. ODFW's
#' Forested Wetlands stratum runs along the California border but the report
#' does not say it overlaps the basin, so it is left out. The CDFW survey does
#' not cover Oregon and the ODFW survey does not cover California.
#'
#' \strong{Comparing the surveys.} CDFW flies fixed-wing aircraft and
#' helicopters in the second week of May in northeastern California and
#' corrects for missed birds with visibility correction factors. ODFW flies
#' helicopters on quarter-mile transects (about 4-5 percent of each stratum) in
#' early to mid May, treats detection as complete, and uses no correction. Given
#' the different aircraft, counting rules and corrections, it is unclear
#' whether the two can be combined, so compare trends within an agency.
#'
#' \strong{When reports disagree.} The most recent report is used, because later
#' reports revise earlier estimates (for example, the 2019 report revises the
#' 2018 sandhill crane estimate from 2,489 to 1,823). A value from a report's
#' prior-year column ranks just below that report's own year.
#'
#' \strong{Species notes.} The surveys report some species together. CDFW's
#' "Scaup" is Lesser Scaup and its "Goldeneye" is Common Goldeneye in CDFW's
#' species guidelines, but the grouped names are kept so the two surveys line
#' up. ODFW's crews believe Cinnamon Teal are detected less often than other
#' species, because of their dark coloring and use of flooded emergent
#' vegetation.
#'
#' The estimates were read from the report PDFs and legacy report files; see
#' \code{data-raw/pull-and-process-waterfowl-data.R}.
#'
#' @source California Department of Fish and Wildlife, Waterfowl Program,
#'   California Waterfowl Breeding Population Survey annual reports: 2003-2015
#'   (Summary B tables), 2016-2019 (Table 1), and 2026 (Appendix IV and Table 1);
#'   see \url{https://data.ca.gov/@california-department-of-fish-and-wildlife/waterfowl-breeding-population-california-1992-2022}.
#'   Oregon Department of Fish and Wildlife, Migratory Game Bird Program
#'   (Walton, K., and B. Reishus), \emph{2026 Oregon Breeding Waterfowl
#'   Population Report}, Appendix B.
#'
#' @seealso \code{klamath_ebird}, \code{ebird_status}
#'
#' @examples
#' head(waterfowl_counts)
#'
#' # Cinnamon Teal in both strata, 2026
#' subset(waterfowl_counts, common_name == "Cinnamon Teal" & year == 2026)
#'
#' # The CDFW Cinnamon Teal series
#' subset(waterfowl_counts, agency == "CDFW" & common_name == "Cinnamon Teal")[
#'   c("year", "estimate", "se")
#' ]
#'
#' \dontrun{
#' # Join to eBird sightings by common name
#' merge(
#'   waterfowl_counts,
#'   unique(klamath_ebird["common_name"]),
#'   by = "common_name"
#' )
#' }
"waterfowl_counts"
