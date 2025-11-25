#===============================================================================
# Sentinels Larval Crab Monitoring | Light Trap Abundance and Size Data
# Merge data from different years and run QAQC codes to produce master dataset
# Filter out sensitive data for public facing repository (i.e. sites that 
# don't want data published yet)
# 
#
# Input:
#     2022_CountData_QC.csv
#     2023_CountData_QC.csv
#     2024_CountData_QC.csv
#     2025_CountData_QC.csv
#     2023_Megalopae_Carapace_Widths.csv
#     2024_Megalopae_Carapace_Widths.csv
#     2025_Megalopae_Carapace_Widths.csv
#
# Output:
#     Master_QAQC_LT_counts.csv
#     Master_QAQC_LightTrap_Counts_publicrepository.csv
#     Master_QAQC_CarapaceWidth_Measurements.csv
#     Master_QAQC_CarapaceWidth_Measurements_publicrepository.csv
#
# Heather Earle (Hakai Institute) heather.earle@hakai.org
# First Created 11/2023
# Last Updated 10/2025
#===============================================================================

#clean up Enivronment
rm(list = ls(all = TRUE))
options(stringsAsFactors = FALSE)

library(tidyverse)
library(dplyr)




#==== FORMATTED COUNT DATA =====================================================

# BC Count Data - all years available
counts22 <- read_csv("data/2022/2022_CountData_QC.csv")
counts23 <- read_csv("data/2023/2023_CountData_QC.csv")
counts24 <- read_csv("data/2024/2024_CountData_QC.csv")
counts24 <- select(counts24, -Battery, -submissionid, -Comments) #remove columns from rough dataset that 
                                        #don't match
counts25 <- read_csv("data/2025/2025_CountData_QC.csv",
                     col_select = 2:27)


#combine them
counts_all <- rbind(counts22, counts23, counts24, counts25)

###Bring in Stations data to get lats and longs
stations <- read.csv("data/Master_Stations.csv") %>% 
  dplyr::select( Site = Site, lat, lon)

#join datasets, now all entries have an associated lat and long
counts_raw <- merge(counts_all,stations,by=c("Site"))


#==== QAQC DETERMINATIONS ======================================================

# MET - missing metadata (hours or nights fished)
# BAT - trap fished for over 25 hours
# HRS - timer on/off times were off by 1+ hr
# DNF - trap did not fish properly
# INC - trap did not fish for over 25% of nights in any given month from 
# ERR - protocols not followed properly and counts likely not accurate
#       Apr 15 to Sep 1

# These can be assigned using code Assign_QAQC.R before importing here

# For annual reports and Hakai Data Catalogue, remove all MET, DNF, ERR, & INC
# entries:
counts_QC <- counts_raw %>%  filter(Error_Code== "None" | Error_Code== "HRS" 
                                        | Error_Code == "BAT")



##Create dataframe w/ removed entries to keep track
counts_removed <- counts_raw %>% filter (Error_Code =="DNF" | 
                                            Error_Code =="MET" |
                                            Error_Code == "ERR" | 
                                            Error_Code == "INC")


#====FORMATED MEASUREMENT DATA =================================================


#upload measurement data from individual years
measurements23 <- read_csv("data/2023/2023_Megalopae_Carapace_Widths.csv")
measurements24 <- read_csv("data/2024/2024_Megalopae_Carapace_Widths.csv")
measurements24 <- select(measurements24, -submission_id, -measured_by,
                         -photo_comments) #remove columns from rough dataset that don't match
measurements25 <- read_csv("data/2025/2025_Megalopae_Carapace_Widths.csv")

#combine years
measurements_all <- rbind(measurements23, measurements24, measurements25)


#==== MASTER Datasets for Internal GITHUB ======================================

####COUNTS#####
# Select columns for dataframe that will be on internal github
counts_master <- counts_QC %>%
 dplyr:: select(Code, Site, lat, lon, Year, Month, Date, 
         Nights_Fished, Hours_Fished, Weather, Subsample, 
         Metacarcinus_magister_megalopae,
         Metacarcinus_magister_instar, 
         TotalMmagister = TotalMmagister, 
         CPUE_Night, CPUE_Hour, Error_Code)

counts_raw <- counts_raw %>%
  dplyr:: select(Code, Site, lat, lon, Year, Month, Date, 
                 Nights_Fished, Hours_Fished, Weather, Subsample, 
                 Metacarcinus_magister_megalopae,
                 Metacarcinus_magister_instar, 
                 TotalMmagister = TotalMmagister, 
                 CPUE_Night, CPUE_Hour, Error_Code)


##create raw csv
write_csv(counts_raw, "data/Master_raw_LightTrap_Counts.csv")

##create master csv filtered by QC codes
write_csv(counts_master, "data/Master_QAQC_LightTrap_Counts.csv")

##create csv of removed entries from QC codes
write_csv(counts_removed, "data/Master_Removed_Counts.csv")

#####MEASUREMENTS#####
write_csv(measurements_all, "data/Master_QAQC_Carapace_Width_Measurements.csv")


#===== MASTER Datasets for PUBLIC GITHUB =======================================

#####COUNTS#####

##Remove sites requiring further permissions and with incomplete data
counts_master_p <- counts_master %>%
  dplyr::filter(Code != "PRP" & Code != "PDH" & Code != "POW"
          & Code != "BOO" & Code != "LYA" & Code != "WIN" & Code != "PRI" & Code != "MAS")


write_csv(counts_master_p, "data/Master_QAQC_LightTrap_Counts_publicrepository.csv")

#####MEASUREMENTS#####

##Remove sites requiring further permissions and with incomplete data
measurements_all <- measurements_all %>%
  dplyr::filter(site != "Pender Harbour" & site != "Sechelt Inlet" & site != 
                  "Powell River" & site != "Boot Cove" & site != "Lyall Harbour"
                & site != "Winter Cove")

#write csv for public repository
write_csv(measurements_all, "data/Master_QAQC_CarapaceWidth_Measurements_publicrepository.csv")

#================================ END ==========================================

