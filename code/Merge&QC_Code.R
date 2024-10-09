#===============================================================================
# Sentinels Larval Crab Monitoring | Light Trap Abundance Data
# Merge data from different years and run QAQC codes to produce master dataset
# Filter out sensitive data for public facing repository (i.e. sites that 
# don't want data published yet)
# 
#
# Input:
#     2022_CountData_QC.csv
#     2023_CountData_QC.csv
#
# Output:
#     Master_QAQC_LT_counts.csv
#     Master_QAQC_LightTrap_Counts_publicrepository.csv
#     2023_Megalopae_Carapace_Widths.csv
#     Master_QAQC_CarapaceWidth_Measurements_publicrepository.csv
#
# Heather Earle (Hakai Institute) heather.earle@hakai.org
# First Created 11/2023
# Last Updated 09/2024
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
counts24 <- select(counts24, -Battery, -submissionid, -Comments, -...28) #remove columns from rough dataset that 
                                        #don't match

#combine them
counts_all <- rbind(counts22, counts23, counts24)

###Bring in Stations data to get lats and longs
stations <- read.csv("data/Master_Stations.csv") %>% 
  dplyr::select( Site = Site, Lat, Lon)

#join datasets, now all entries have an associated lat and long
counts_master <- merge(counts_all,stations,by=c("Site"))


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
counts_QC <- counts_master %>%  filter(Error_Code=="NA" | Error_Code== "HRS" 
                                        | Error_Code == "BAT" | Error_Code == "SUB")
###note, here I added teh "SUB" error code so that the Whaler Bay subsampled 
#numbers from late June/early July 2024 would still be included in the fall gathering
#graphs. Will decide what to do with these problematic data at a later date 


##Create dataframe w/ removed entries to keep track
counts_removed <- counts_master %>% filter (Error_Code =="DNF" | 
                                            Error_Code =="MET" |
                                            Error_Code == "ERR" | 
                                            Error_Code == "INC")


#==== MASTER for GITHUB ========================================================


# Select columns for dataframe that will be on internal github
counts_master <- counts_QC %>%
 dplyr:: select(Code, Site, Lat, Lon, Year, Month, Date, 
         Nights_Fished, Hours_Fished, Weather, Subsample, 
         Metacarcinus_magister_megalopae,
         Metacarcinus_magister_instar, 
         TotalMmagister = TotalMmagister, 
         CPUE_Night, CPUE_Hour, Error_Code)

write_csv(counts_master, "data/Master_QAQC_LightTrap_Counts.csv")

#===== MASTER for PUBLIC GITHUB ================================================

##Remove sites requiring further permissions and with incomplete data
counts_master_p <- counts_master %>%
  dplyr::filter(Code != "PRP" & Code != "PDH" & Code != "POW"
          & Code != "BOO" & Code != "LYA" & Code != "WIN")


write_csv(counts_master_p, "data/Master_QAQC_LightTrap_Counts_publicrepository.
          csv")

#===== 2023 Measurements for PUBLIC GITHUB =====================================

meas23 <- read_csv("data/2023/2023_Megalopae_Carapace_Widths.csv")

meas23p <- meas23 %>%
 dplyr::filter(site != "Pender Harbour" & site != "Sechelt Inlet" & site != 
                 "Powell River" & site != "Boot Cove" & site != "Lyall Harbour"
               & site != "Winter")

write_csv(meas23p, "data/Master_QAQC_CarapaceWidth_Measurements_publicrepository.
          csv")
#================================ END ==========================================

