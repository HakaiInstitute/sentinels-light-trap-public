

# Load required packages
library(tidyverse)
library(obistools)
library(worrms)
library(lubridate)
library(janitor)
library(here)

# This .R file contains the script used to standardize the count and size data of M. magister data collected during the Sentinels of Change (SOC) Light Trap project. 
# Through this script, the data is standardized to Darwin Core to allow interoperability with other data records in the Ocean Biodiversity Information System (OBIS).  
# Read in the metadata, count data and associated carapace width data from *_publicrepository.csv files As per the [Sentinels of Change Light Trap Network DMP](https://dmptool.org/plans/78175), 
# some problematic data entries should be filtered out during data analyses and are therefore omitted from the standardized data on OBIS. 
# These problematic data entries are found under "error_code" and include `MET` (missing metadata), `BAT` (trap fished for over 25 hours), `DNF` (trap did not fish properly), 
# and `ERR` (protocols not followed properly and counts likely not accurate).

# Read in the station data:
stations <- read_csv(here("data", "Master_Stations.csv")) %>%
  janitor::clean_names() %>%
  select(code, site, organization)

# Read in the count data from the public repository.csv file:
dung_count <- read_csv(here("data", "Master_QAQC_LightTrap_Counts_publicrepository.csv")) %>%
  janitor::clean_names() %>%
  select(code, site, lat, lon, date, weather, hours_fished, nights_fished,
         metacarcinus_magister_megalopae, metacarcinus_magister_instar) %>%
  mutate(year = as.numeric(format(as.Date(date), "%Y")),
         month = as.numeric(format(as.Date(date), "%m")),
         day = as.numeric(format(as.Date(date), "%d")),
         project = "SOC",
         trap = paste(project, code, sep = "-"),
         stationVisit = paste(trap, year, month, day, sep = "-")) %>%
  distinct()

# Read in associated carapace width (cw) data.
cw_data <- read_csv(here("data", "Master_QAQC_CarapaceWidth_Measurements_publicrepository.csv")) %>%
  janitor::clean_names() %>%
  mutate(site = ifelse(site == "Campbell River Aquarium", "Campbell River", site),
         site = ifelse(site == "Hot Spring Cove", "Hotsprings Cove", site)) %>%
  left_join(stations, by = "site") %>%
  mutate(year = as.numeric(format(as.Date(date), "%Y")),
         month = as.numeric(format(as.Date(date), "%m")),
         day = as.numeric(format(as.Date(date), "%d")),
         project = "SOC",
         trap = paste(project, code, sep = "-"),
         stationVisit = paste(trap, year, month, day, sep = "-")) %>%
  drop_na(carapace_width)

master <- merge(x = dung_count,
                y = cw_data[ , c("stationVisit", "carapace_width")], by = "stationVisit", all.x = TRUE)

## Section 1. Event Core

# Given that there's a sampling event (the deployment of the LED light trap at several stations) for this project, our schema will consist of an Event Core (Section 1) and three extension data tables: 
# occurrence (Section 2), resourceRelationship (Section 3) and extended measurementOrFact (Section 4). In the final section (Section 5) we'll do some basic QAQC to ensure the formatted data follows 
# the standards outlined in the DwC schema. The event table will include information on the sampling event, such as date, location, organization responsible for collecting and owning the data, 
# and data related to the sampling effort (hours fished).  

# Add information that's general to the overall project
project <- dung_count %>%
  select(eventID = project) %>%
  mutate(eventType = "project",
         language = "en",
         license = "http://creativecommons.org/licenses/by/4.0/legalcode",
         bibliographicCitation = "Earle, H., Krzus, L., & Whalen, M. (2024). Larval Dungeness crab abundance and size time series along the coast of British Columbia (v1.0). Hakai Institute. https://doi.org/10.21966/36hp-7f40", 
         accessRights = "https://github.com/HakaiInstitute/sentinels-light-trap-public/blob/main/LICENSE", 
         samplingProtocol = "https://github.com/HakaiInstitute/sentinels-light-trap-public/tree/main/docs/Protocols",
         rightsHolder = "Hakai Institute",
         institutionCode = "Hakai Institute",
         institutionID = "https://edmo.seadatanet.org/report/5148",
         modified = lubridate::today(),
         country = "Canada",
         countryCode = "CA") %>%
  distinct()

# Add information specific to the traps         
trap <- dung_count %>%
  select(eventID = trap,
         parentEventID = project,
         verbatimLocality = site) %>%
  mutate(eventType = "station",
         minimumDepthInMeters = 0,
         maximumDepthInMeters = 2,) %>%
  distinct(eventID, .keep_all = TRUE)

# add metadata on specific sampling events ('station visits'):
stationVisit <- dung_count %>%
  select(parentEventID = trap,
         eventID = stationVisit,
         sampleSizeValue = hours_fished,
         decimalLatitude = lat,
         decimalLongitude = lon,
         eventDate = date,
         weather,
         nights_fished) %>%
  mutate(eventType = "stationVisit",
         year = as.numeric(format(as.Date(dung_count$date), "%Y")),
         month = as.numeric(format(as.Date(dung_count$date), "%m")),
         day = as.numeric(format(as.Date(dung_count$date), "%d")),
         eventID = paste(parentEventID, year, month, day, sep = "-"),
         samplingEffort = paste(sampleSizeValue, "hours of light trap fishing"),
         sampleSizeUnit = "hours",
         geodeticDatum = "WGS84",
         footprintWKT = paste("POINT", " (", decimalLongitude, " ", decimalLatitude, ")"),
         eventRemarks = ifelse(!is.na(weather), paste0(weather, "."), "")) %>%
  mutate(eventRemarks = ifelse(nights_fished == 1, paste(eventRemarks, "Hours fished were spread over", nights_fished, "night."), 
                               ifelse(nights_fished == 2, paste(eventRemarks, "Hours fished were spread over", nights_fished, "nights."),
                                      eventRemarks))) %>%
  select(-c(weather, nights_fished)) %>%
  distinct(eventID, .keep_all = TRUE)

# add information on specimens:
individual <- master %>%
  filter(!is.na(carapace_width)) %>%
  select(parentEventID = stationVisit) %>%
  group_by(parentEventID) %>%
  mutate(eventID = paste(parentEventID, "m", sep = "-"),
         eventID = paste0(eventID, row_number()),
         eventType = "single specimen sample") %>%
  ungroup() %>%
  distinct(eventID, .keep_all = TRUE)

# Merge these data tables:
SOC_event <- bind_rows(project, trap, stationVisit, individual) %>%
  mutate_all(as.character)

SOC_event <- obistools::flatten_event(SOC_event)

# Remove NAs from the dataframe and save locally:
SOC_event[is.na(SOC_event)] <- ""
SOC_event <- as_tibble(SOC_event)
write_csv(SOC_event, here("obis", "SOC_event.csv")) 

# -------

## Section 2. Occurrence extension

# The first extension that we create is the occurrence extension. We create two tables which we'll eventually join. The first occurrence extension table will 
# contain the occurrenceIDs that are nested under an eventID. These occurrenceIDs will uniquely reflect the count of M. magister instar and megalopae lifestages 
# during each sampling event. When creating the occurrenceID I will `group_by` eventID, in the event that future iterations of this dataset will include bycatch. 
# This should ensure that occurrenceID will remain the same irrespective of these species being added. The second occurrence extension data table is used to 
# create unique occurrenceIDs for individual specimens that have their carapace width measured. 

occ <- left_join(dung_count, stations, by = c("code", "site")) %>%
  mutate(year = as.numeric(format(as.Date(dung_count$date), "%Y")),
         month = as.numeric(format(as.Date(dung_count$date), "%m")),
         day = as.numeric(format(as.Date(dung_count$date), "%d")),
         eventID = paste("SOC", code, year, month,day, sep = "-")) %>%
  select(eventID, organization, metacarcinus_magister_instar, metacarcinus_magister_megalopae) %>%
  pivot_longer(metacarcinus_magister_instar:metacarcinus_magister_megalopae,
               names_to = "verbatimIdentification",
               values_to = "individualCount")

# Add lifestage columns:
occ <- occ %>%
  mutate(lifeStage = case_when(
    grepl("megalopae", verbatimIdentification) ~ "megalopae",
    grepl("instar", verbatimIdentification) ~ "instar"))

# Add column with scientific name so we can match that to WoRMS. Easy as it's only 1 species!
occ <- occ %>% mutate(scientificName = "Metacarcinus magister")

soc_worms <- worrms::wm_records_names(unique(occ$scientificName), marine_only = T) %>%
  dplyr::bind_rows() %>% rename(scientificName = scientificname)

# Join back to the occurrence table:
occ <- left_join(occ, soc_worms, by = "scientificName")

# Add additional fields, such as specificEpithet, occurrenceID, occurrenceStatus and basisOfRecord 
occ <- occ %>%
  mutate(specificEpithet = stringr::word(scientificName, 2),
         scientificName = ifelse(!is.na(authority),
                                 paste(scientificName, authority),
                                 scientificName)) %>%
  group_by(eventID) %>%
  mutate(occurrenceID = paste(eventID, "occ", row_number(), sep = "-"),
         occurrenceStatus = ifelse(individualCount > 0, "present", "absent"),
         basisOfRecord = "HumanObservation") %>%
  ungroup()

# Select columns for the occurrence extension:
SOC_occ <- occ %>%
  select(eventID, occurrenceID, verbatimIdentification,
         recordedBy = organization,
         individualCount, scientificName,
         scientificNameID = lsid,
         taxonRank = rank,
         scientificNameAuthorship = authority,
         taxonomicStatus = status,
         occurrenceStatus,
         kingdom, phylum, class, order, family, genus, specificEpithet,
         lifeStage, basisOfRecord) %>%
  distinct()

# Next, we create the 'second occurrence extension' data table, to include occurrenceIDs for just the megalopae lifestage occurrences. 
# Instar lifestages were not measured. We'll use these individual occurrenceIDs in the extended measurement or fact extension as well.

ind_cw <- cw_data %>%
  group_by(stationVisit) %>%
  mutate(eventID = paste(stationVisit, "m", sep = "-"),
         eventID = paste0(eventID, row_number()),
         occurrenceID = paste(eventID, "-occ", sep = ""),
         individualCount = 1) %>%
  ungroup() %>%
  select(eventID, occurrenceID, individualCount) %>%
  mutate(scientificName = "Metacarcinus magister",
         lifeStage = "megalopae") 

# Add column with scientific name so we can match that to WoRMS. Easy as it's only 1 species!

ind_worms <- worrms::wm_records_names(unique(ind_cw$scientificName), marine_only = T) %>%
  dplyr::bind_rows() %>% rename(scientificName = scientificname)

# Join back to the occurrence table:
ind_cw <- left_join(ind_cw, ind_worms, by = "scientificName")

# Add additional fields, such as specificEpithet, occurrenceID, occurrenceStatus and basisOfRecord 
ind_cw <- ind_cw %>%
  mutate(specificEpithet = stringr::word(scientificName, 2),
         scientificName = ifelse(!is.na(authority),
                                 paste(scientificName, authority),
                                 scientificName),
         occurrenceStatus = "present",
         basisOfRecord = "HumanObservation") %>%
  select(eventID, occurrenceID, 
         individualCount,
         scientificName, lifeStage, 
         scientificNameID = lsid,
         taxonRank = rank,
         scientificNameAuthorship = authority,
         taxonomicStatus = status,
         occurrenceStatus,
         kingdom, phylum, class, order, family, genus, specificEpithet,
         basisOfRecord)

# Finally, we combine these two occurrence data tables. I prefer re-ordering the occurrenceIDs to better visualize the nested hierarchy. 

overall_occ <- dplyr::bind_rows(SOC_occ, ind_cw) %>%
  distinct()

# Re-order the eventIDs:
SOC_occ_extension <- overall_occ[gtools::mixedorder(overall_occ$eventID),]

SOC_occ_extension <- SOC_occ_extension %>% 
  mutate(individualCount = as.numeric(individualCount)) %>%
  mutate_if(is.numeric, round)

# Remove NAs and save locally in the obis folder:
SOC_occ_extension <- SOC_occ_extension %>% mutate_all(as.character)
SOC_occ_extension[is.na(SOC_occ_extension)] <- ""
SOC_occ_extension <- as_tibble(SOC_occ_extension)
write_csv(SOC_occ_extension, here("obis", "SOC_occ.csv"))

## Section 3. Extended measurement Or Fact extension

# Finally, we create the extended measurementOrFact (eMOF) data table, which will include information on sampling effort, as well as carapace width measurements 
# and controlled vocabulary for the M. magister observed (count, lifestage, carapace width). Initially, we create separate tables because measurements or facts 
# are associated at different levels (project, stationVisit and individual measurements). The measurementIDs created will be nested either directly under the eventID 
# (when it concerns the measurements or facts on the sampling event), or more directly nested under the occurrenceID when it concerns biometric data. 

# Measurements or facts data related to the project sampling:
emof_project <- project %>%
  select(eventID, 
         measurementValue = samplingProtocol) %>%
  mutate(measurementType = "sampling_method",
         measurementID = paste(eventID, measurementType, row_number(), sep = "-"),
         measurementValueID = "https://vocab.nerc.ac.uk/collection/L22/current/TOOL2026/",
         measurementTypeID = "https://vocab.nerc.ac.uk/collection/Q01/current/Q0100003/",
         measurementUnit = "not applicable", 
         measurementUnitID = "https://vocab.nerc.ac.uk/collection/P06/current/XXXX/",
         occurrenceID = NA)

# Measurements as related to the sampling effort:
emof_trap_effort <- stationVisit %>%
  select(eventID, 
         measurementValue = sampleSizeValue) %>%
  mutate(measurementType = "hours_fished",
         measurementID = paste(eventID, measurementType, row_number(), sep = "-"),
         measurementValueID = "",
         measurementTypeID = "http://vocab.nerc.ac.uk/collection/P01/current/AZDRZZ01",
         measurementUnit = "hours", 
         measurementUnitID = "http://vocab.nerc.ac.uk/collection/P06/current/UHOR/",
         occurrenceID = NA,
         measurementValue = as.character(measurementValue))

# Measurements related to the overall occurrenceID (count, lifestage)

emof_occ <- left_join(SOC_occ, SOC_event, by = "eventID") %>%
  select(eventID, occurrenceID, individualCount, lifeStage) %>%
  distinct(occurrenceID, .keep_all = T) %>%
  mutate_all(as.character) %>%
  pivot_longer(cols = individualCount:lifeStage,
               names_to = "measurementType",
               values_to = "measurementValue") %>%
  mutate(measurementID = paste(occurrenceID, row_number(), sep = "-")) %>%
  mutate(measurementTypeID = case_when(
    measurementType == "lifeStage" ~ "http://vocab.nerc.ac.uk/collection/P01/current/LSTAGE01/",
    measurementType == "individualCount" ~ "http://vocab.nerc.ac.uk/collection/P01/current/OCOUNT01/")) %>%
  mutate(measurementValueID = case_when(
    measurementValue == "instar" ~ "http://vocab.nerc.ac.uk/collection/S11/current/S1105/",
    measurementValue == "megalopae" ~ "http://vocab.nerc.ac.uk/collection/S11/current/S1167/")) %>%
  mutate(measurementUnit = case_when(
    measurementType == "individualCount" ~ "individuals",
    measurementType == "lifeStage" ~ "not applicable")) %>%
  mutate(measurementUnitID = case_when(
    measurementUnit == "individuals" ~ "http://vocab.nerc.ac.uk/collection/P06/current/UUUU/",
    measurementUnit == "not applicable" ~ "https://vocab.nerc.ac.uk/collection/P06/current/XXXX/"))

# Measurements (carapace width) related to individuals:
indMeasurement <- master %>% 
  filter(!is.na(carapace_width)) %>%
  mutate(eventID = paste(stationVisit, "m", sep = "-")) %>%
  group_by(eventID) %>%
  mutate(eventID = paste0(eventID, row_number())) %>%
  select(eventID, carapace_width)

carapace <- merge(x = indMeasurement, y = SOC_occ_extension[ , c("eventID", "occurrenceID")],
                  by = "eventID", all.x = T)

emof_carapace <- carapace %>%
  rename(measurementValue = carapace_width) %>%
  mutate(measurementValue = as.character(measurementValue),
         measurementID = paste(occurrenceID, row_number(), sep = "-"),
         measurementType = "carapace width", 
         measurementTypeID = "http://vocab.nerc.ac.uk/collection/P01/current/CAPWID01/",
         measurementUnit = "mm",
         measurementUnitID = "http://vocab.nerc.ac.uk/collection/P06/current/UXMM/")

# Combine the two emof data tables:  
SOC_emof <- dplyr::bind_rows(emof_project, emof_trap_effort, emof_occ, emof_carapace) 

# Remove NAs:
SOC_emof[is.na(SOC_emof)] <- ""
SOC_emof <- as_tibble(SOC_emof)

order <- c("eventID", "occurrenceID", "measurementID", "measurementType", "measurementTypeID", 
           "measurementValue", "measurementValueID", "measurementUnit", "measurementUnitID")
SOC_emof <- SOC_emof[, order]

# Save locally as .csv file:
write_csv(SOC_emof, here("obis", "SOC_emof.csv"))

# -----------------------

## Section 4. Basic QAQC

# Plot points on a map:
SOC_event$decimalLatitude <- as.numeric(SOC_event$decimalLatitude)
SOC_event$decimalLongitude <- as.numeric(SOC_event$decimalLongitude)
SOC_leaflet <- obistools::plot_map_leaflet(SOC_event)
SOC_map <- obistools::plot_map(SOC_event, zoom = TRUE)

# If you want to save a basic map to look at coordinates:
# ggsave(filename = "SOC_map.png", plot = SOC_map, path = here::here("obis", "maps"))

# check eventDate
obistools::check_eventdate(SOC_event) # Confirm that this shows a 0 x 0 tibble (i.e. no errors).

# As we're working with an Event Core, the fields for eventDate, decimalLatitude and decimalLongitude should be in that table (no need for duplication)
obistools::check_fields(SOC_occ)

# check_extension_eventids() checks if all eventIDs in an extension have a matching eventID in the core table (should be empty dataframe):
obistools::check_extension_eventids(SOC_event, SOC_occ)
obistools::check_extension_eventids(SOC_event, SOC_emof)
