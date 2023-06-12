
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

# Set index date

index_date <- as.Date("2020-02-01")


############################################################################################

# Look at categories of patients by combination of diabetes type codes

cohort_classification <- cohort_classification %>% analysis$cached("cohort_classification_with_primis")

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

t1dt2d_classification %>% filter(latest_code_no_ins==our_algorithm_ins_ever) %>% count()
#14,407 = 77.1%

t1dt2d_classification %>% filter(latest_code_no_ins!=our_algorithm_ins_ever) %>% group_by(latest_code_no_ins, our_algorithm_ins_ever) %>% count()

median_time <- collect(t1dt2d_classification %>%
                         filter(latest_code_no_ins!=our_algorithm_ins_ever) %>%
                         mutate(time_to_correct_code=ifelse(our_algorithm_ins_ever=="type 1", datediff(index_date, latest_type_1), datediff(index_date, latest_type_2))))

summary(median_time$time_to_correct_code)
#1,142 days = 3.1 years


t1dt2d_classification %>% filter(latest_code_current_ins==our_algorithm_ins_ever) %>% count()
#14,789 = 79.1%

t1dt2d_classification %>% filter(latest_code_current_ins!=our_algorithm_ins_ever) %>% group_by(latest_code_current_ins, our_algorithm_ins_ever) %>% count()

median_time <- collect(t1dt2d_classification %>%
                         filter(latest_code_current_ins!=our_algorithm_ins_ever) %>%
                         mutate(time_to_correct_code=ifelse(our_algorithm_ins_ever=="type 1", datediff(index_date, latest_type_1), datediff(index_date, latest_type_2))))

summary(median_time$time_to_correct_code)
#1,088 days


t1dt2d_classification %>% filter(latest_code_ins_ever==our_algorithm_ins_ever) %>% count()
#14,851 = 79.4%

t1dt2d_classification %>% filter(latest_code_ins_ever!=our_algorithm_ins_ever) %>% group_by(latest_code_ins_ever, our_algorithm_ins_ever) %>% count()

median_time <- collect(t1dt2d_classification %>%
                         filter(latest_code_ins_ever!=our_algorithm_ins_ever) %>%
                         mutate(time_to_correct_code=ifelse(our_algorithm_ins_ever=="type 1", datediff(index_date, latest_type_1), datediff(index_date, latest_type_2))))

summary(median_time$time_to_correct_code)
#1,142 days


############################################################################################

# Add all diagnosis dates to main cohort table and calculate age at diagnosis and find time to insulin from diagnosis

cohort <- cohort %>% analysis$cached("cohort")


## Diagnosis dates (based on codes only) for patients not in class "other" i.e. with diabetes code of only one type

cohort_diag_dates_not_other <- cohort_diag_dates %>% analysis$cached("cohort_diag_dates_codes_only_interim_2", unique_indexes="patid")


## Diagnosis dates for patients in class 'other' - only those with Type 1 and Type 2; Type 2 and gestational; Type 2 and secondary; Type 1 and gestational; or Type 1, Type 2 and gestational
### If class is Type 2, haven't removed if in year of birth

earliest_latest_codes_long_no_yob <- earliest_latest_codes_long_no_yob %>% analysis$cached("earliest_latest_codes_long_no_yob")

cohort_other_class <- cohort_classification %>%
  filter((!is.na(earliest_type_1) & !is.na(earliest_type_2) & is.na(earliest_any_gestational) & is.na(earliest_mody) & is.na(earliest_other_genetic_syndromic) & is.na(earliest_secondary) & is.na(earliest_malnutrition) & is.na(earliest_other_excl)) |
      (is.na(earliest_type_1) & !is.na(earliest_type_2) & !is.na(earliest_any_gestational) & is.na(earliest_mody) & is.na(earliest_other_genetic_syndromic) & is.na(earliest_secondary) & is.na(earliest_malnutrition) & is.na(earliest_other_excl)) |
         (is.na(earliest_type_1) & !is.na(earliest_type_2) & is.na(earliest_any_gestational) & is.na(earliest_mody) & is.na(earliest_other_genetic_syndromic) & !is.na(earliest_secondary) & is.na(earliest_malnutrition) & is.na(earliest_other_excl)) |
            (!is.na(earliest_type_1) & is.na(earliest_type_2) & !is.na(earliest_any_gestational) & is.na(earliest_mody) & is.na(earliest_other_genetic_syndromic) & is.na(earliest_secondary) & is.na(earliest_malnutrition) & is.na(earliest_other_excl)) |
               (!is.na(earliest_type_1) & !is.na(earliest_type_2) & !is.na(earliest_any_gestational) & is.na(earliest_mody) & is.na(earliest_other_genetic_syndromic) & is.na(earliest_secondary) & is.na(earliest_malnutrition) & is.na(earliest_other_excl))) %>%
  select(patid) %>%
  inner_join(earliest_latest_codes_long_no_yob, by="patid") %>%
  filter(category!="unspecified" & category!="remission" & category!="high_hba1c" & category!="oha_script" & category!="insulin_script") %>%
  group_by(patid) %>%
  mutate(latest_type_code_date=max(latest, na.rm=TRUE)) %>%
  filter(latest==latest_type_code_date) %>%
  mutate(category=ifelse(category=="type_1", "type 1",
                         ifelse(category=="type_2", "type 2", category))) %>%
  summarise(new_class=sql("group_concat(distinct category order by category separator ' & ')")) %>%
  ungroup() %>%
  mutate(class=paste("mixed;", new_class)) %>%
  select(patid, class) %>%
  analysis$cached("cohort_other_class", unique_indexes="patid")
  

cohort_diag_dates_other <- earliest_latest_codes_long_no_yob %>%
  filter(class=="other" & category!="high_hba1c" & category!="oha_script" & category!="insulin_script") %>%
  group_by(patid) %>%
  summarise(dm_diag_date=min(earliest, na.rm=TRUE)) %>%
  ungroup() %>%
  analysis$cached("cohort_diag_dates_codes_only_interim_4", unique_indexes="patid")

cohort_diag_dates_other <- cohort_diag_dates_other %>%
  inner_join((cprd$tables$patient %>% select(patid, regstartdate)), by="patid") %>%
  mutate(dm_diag_date=if_else(datediff(dm_diag_date, regstartdate)>=-30 & datediff(dm_diag_date, regstartdate)<=90, as.Date(NA), dm_diag_date)) %>%
  analysis$cached("cohort_diag_dates_codes_only_interim_5", unique_indexes="patid")

cohort_diag_dates_other <- cohort_other_class %>%
  inner_join(cohort_diag_dates_other, by="patid") %>%
  analysis$cached("cohort_diag_dates_codes_only_interim_6", unique_indexes="patid")


cohort_diag_dates_all <- cohort_diag_dates_not_other %>%
  select(patid, class, dm_diag_date) %>%
  union_all(cohort_diag_dates_other) %>%
  analysis$cached("cohort_diag_dates_all", unique_indexes="patid")


## Earliest insulin per patient (clean - those before patient DOB removed)

cohort_clean_dm_indications <- cohort_clean_dm_indications %>% analysis$cached("cohort_clean_dm_indications")

earliest_insulin <- cohort_clean_dm_indications %>%
  filter(category=="insulin_script") %>%
  group_by(patid) %>%
  summarise(earliest_ins=min(date, na.rm=TRUE)) %>%
  ungroup() %>%
  analysis$cached("earliest_ins", unique_indexes="patid")
## NB: this is identical to earliest_insulin_script in main cohort table


## Combine
### Time to insulin should be set to missing if diagnosed >6 months before registration start

cohort_with_diag_dates <- cohort %>%
  left_join((cohort_diag_dates_all %>% select(patid, class, dm_diag_date)), by="patid") %>%
  left_join(earliest_insulin, by="patid") %>%
  mutate(time_to_ins_days=ifelse(is.na(earliest_ins) | datediff(regstartdate, dm_diag_date)>183, NA, datediff(earliest_ins, dm_diag_date)),
         dm_diag_age=round((datediff(dm_diag_date, dob))/365.25, 1)) %>%
  analysis$cached("cohort_with_diag_dates", unique_indexes="patid")


## Those in groups not analysed (mixed codes except for most popular groups) will have missing class

