
# Look at those with changes in diabetes type over time and/or 'other unspecified diabetes'

# Calculate diagnosis dates (not yet coded)

# Add diagnosis dates and age at diagnosis and time to insulin for all to main cohort table

############################################################################################

# Setup
library(tidyverse)
library(aurum)
rm(list=ls())

cprd = CPRDData$new(cprdEnv = "test-remote",cprdConf = "~/.aurum.yaml")

analysis = cprd$analysis("dpctn")


############################################################################################

# Look at categories of patients by combination of diabetes type codes

cohort_classification <- cohort_classification %>% analysis$cached("cohort_classification")

class_types <- collect(cohort_classification %>%
                         filter(class=="other") %>%
                         mutate(type_1=!is.na(earliest_type_1),
                                type_2=!is.na(earliest_type_2),
                                gestational=!is.na(earliest_any_gestational),
                                mody=!is.na(earliest_mody),
                                other_genetic_syndromic=!is.na(earliest_other_genetic_syndromic),
                                secondary=!is.na(earliest_secondary),
                                malnutrition=!is.na(earliest_malnutrition),
                                other_excl=!is.na(earliest_other_excl),
                                total_count=n()) %>%
                         
                         group_by(type_1, type_2, gestational, mody, other_genetic_syndromic, secondary, malnutrition, other_excl, total_count) %>%
                         summarise(count=n()) %>%
                         mutate(perc=count/total_count) %>%
                         ungroup())


############################################################################################

# Determine diagnosis dates and changes in diagnosis type for those with T1/T2 and T2/gestational
## To do

   

############################################################################################

# Add all diagnosis dates to main cohort table and calculate age at diagnosis and find time to insulin from diagnosis

cohort <- cohort %>% analysis$cached("cohort")


## Diagnosis dates for patients not in class "other" i.e. with diabetes code of only one type

cohort_diag_dates <- cohort_diag_dates %>% analysis$cached("cohort_diag_dates_interim_3", unique_indexes="patid")


## Diagnosis dates for patients with T1/T2 and T2/gestational
### To do as above



## Earliest insulin per patient (clean - those before patient DOB removed)

cohort_clean_dm_indications <- cohort_clean_dm_indications %>% analysis$cached("cohort_clean_dm_indications")

earliest_insulin <- cohort_clean_dm_indications %>%
  filter(category=="insulin_script") %>%
  group_by(patid) %>%
  summarise(earliest_ins=min(date, na.rm=TRUE)) %>%
  ungroup() %>%
  analysis$cached("earliest_ins", unique_indexes="patid")


## Combine (need to add in diagnosis dates for patients with T1/T2 and T2/gestational once done)
### Time to insulin should be set to missing if diagnosed >6 months before registration start

cohort_with_diag_dates <- cohort %>%
  left_join((cohort_diag_dates %>% select(patid, class, dm_diag_date)), by="patid") %>%
  left_join(earliest_insulin, by="patid") %>%
  mutate(time_to_ins_days=ifelse(is.na(earliest_ins) | datediff(regstartdate, dm_diag_date)>183, NA, datediff(earliest_ins, dm_diag_date)),
         dm_diag_age=round((datediff(dm_diag_date, dob))/365.25, 1)) %>%
  analysis$cached("cohort_with_diag_dates", unique_indexes="patid")
