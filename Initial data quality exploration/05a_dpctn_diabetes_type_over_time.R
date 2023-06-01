
# Look at those with changes in diabetes type over time and/or 'other unspecified diabetes' - just counts

# For mixed T1/T2 group, look at different ways of classifying and calculate diagnosis dates

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

# Compare different ways of classifying T1/T2 group: most recent code vs our algorithm

cohort <- cohort %>% analysis$cached("cohort")

t1dt2d_classification <- cohort_classification %>%
  filter(class=="other" & !is.na(earliest_type_1) & !is.na(earliest_type_2) & is.na(earliest_any_gestational) & is.na(earliest_mody) & is.na(earliest_other_genetic_syndromic) & is.na(earliest_secondary) & is.na(earliest_malnutrition) & is.na(earliest_other_excl)) %>%
  select(patid, earliest_type_1, latest_type_1, count_type_1, earliest_type_2, latest_type_2, count_type_2) %>%
  inner_join((cohort %>% select(patid, current_ins_6m, ins_ever)), by="patid") %>%
  analysis$cached("t1dt2d_classification_interim_1", indexes="patid")
  
t1dt2d_classification <- t1dt2d_classification %>%
  mutate(latest_code_no_ins=ifelse(latest_type_2==latest_type_1, NA,
                            ifelse(latest_type_2>latest_type_1, "type 2", "type 1")),
         latest_code_current_ins=ifelse(latest_type_2==latest_type_1, NA,
                                   ifelse(current_ins_6m==0 | latest_type_2>latest_type_1, "type 2", "type 1")),
         latest_code_ins_ever=ifelse(latest_type_2==latest_type_1, NA,
                                   ifelse(ins_ever==0 | latest_type_2>latest_type_1, "type 2", "type 1")),
         
         our_algorithm_no_ins=ifelse(count_type_1>=(2*count_type_2), "type 1", "type 2"),
         our_algorithm_current_ins=ifelse(current_ins_6m==1 & count_type_1>=(2*count_type_2), "type 1", "type 2"),
         our_algorithm_ins_ever=ifelse(ins_ever==1 & count_type_1>=(2*count_type_2), "type 1", "type 2")) %>%
  analysis$cached("t1dt2d_classification", indexes="patid")
         
t1dt2d_classification %>% count()
#18,695

t1dt2d_classification %>% filter(latest_code_no_ins==our_algorithm_no_ins) %>% count()
#14,412 = 77.1%

t1dt2d_classification %>% filter(latest_code_current_ins==our_algorithm_current_ins) %>% count()
#15,038 = 80.4%

t1dt2d_classification %>% filter(latest_code_ins_ever==our_algorithm_ins_ever) %>% count()
#14,851 = 79.4%


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
