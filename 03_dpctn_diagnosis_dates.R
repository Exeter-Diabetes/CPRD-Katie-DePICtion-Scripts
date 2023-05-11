
# Calculate diagnosis dates for everyone in DePICtion cohort except those with diabetes type that changes over time, and use to find time to insulin from diagnosis

# Also look at:
## How many people diagnosed on basis of diabetes code vs high HbA1c vs OHA/insulin script
## Potential data quality issue around diagnoses in year of birth

############################################################################################

# Setup
library(tidyverse)
library(aurum)
library(EHRBiomarkr)
rm(list=ls())

cprd = CPRDData$new(cprdEnv = "test-remote",cprdConf = "~/.aurum.yaml")

analysis = cprd$analysis("dpctn")


############################################################################################

# Get cohort info

cohort <- cohort %>% analysis$cached("cohort")

############################################################################################

# Just use 'clean' diabetes codes/high HbA1cs/OHA/insulin scripts (i.e. those before DOB removed; there will be none after end of records/death as those after index date [01/02/2020] have been removed and whole cohort are alive and registered on 01/02/2020)

# All already earliest and latest (clean) codes for each category cached in table from 02_dpctn_diabetes_type_all_time script

earliest_latest_codes_long <- earliest_latest_codes_long %>% analysis$cached("earliest_latest_codes_long")


# For those classified as unspecified / type 1 / type 2 / gestational only / MODY / genetic/syndromic / secondary / malnutrition, use earliest code / HbA1c / OHA/insulin script as diagnosis date and record which it is

cohort_classification <- cohort_classification %>% analysis$cached("cohort_classification")

cohort_diag_dates_classified <- cohort_classification %>%
  select(patid, class) %>%
  filter(class!="gestational then type 2" & class!="other") %>%
  inner_join(earliest_latest_codes_long, by="patid") %>%
  group_by(patid) %>%
  mutate(dm_diag_date=min(earliest, na.rm=TRUE)) %>%
  filter(earliest==dm_diag_date) %>%
  ungroup() %>%
  group_by(patid, dm_diag_date, class) %>%
  mutate(category=ifelse(category=="unspecified" | category=="high_hba1c" | category=="oha_script" | category=="insulin_script", category, "type_specific_code")) %>%
  summarise(dm_diag_codetype=ifelse(any(category=="unspecified"), "unspecified_code",
                                 ifelse(any(category=="type_specific_code"), "type_specific_code",
                                               ifelse(any(category=="high_hba1c"), "high_hba1c",
                                                      ifelse(any(category=="oha_script"), "oha_script", "insulin_script")))),
            dm_diag_codetype2=ifelse(any(category=="unspecified") | any(category=="type_specific_code"), "unspecified_or_type_spec_code", NA)) %>%
  ungroup() %>%
  analysis$cached("cohort_diag_dates_classified", unique_indexes="patid")
                    

############################################################################################

# Look at potential quality issues:
## Diagnoses by calendar year relative to year of birth
## Diagnoses by calendar year relative to registration start date

diag_dates <- collect(cohort_diag_dates_classified %>% mutate(diag_year=year(dm_diag_date)) %>% select(patid, class, dm_diag_date, diag_year) %>% left_join((cprd$tables$patient %>% mutate(yor=year(regstartdate)) %>% select(patid, yob, regstartdate, yor)), by="patid"))


# By calendar year relative to year of birth

diag_dates <- diag_dates %>% mutate(year_relative_to_birth=as.integer(diag_year-yob))

ggplot(diag_dates, aes(x=year_relative_to_birth)) + 
  geom_histogram(data=diag_dates, aes(fill=class), binwidth=1) +
  xlab("Year relative to birth year")

diag_dates %>% filter(year_relative_to_birth==0 & class=="type 2") %>% count()
#1,694
1694/576977
#0.3%




# By calendar year relative to year of registration start

diag_dates <- diag_dates %>% mutate(year_relative_to_regstart=as.integer(diag_year-yor))

ggplot(diag_dates, aes(x=year_relative_to_regstart)) + 
  geom_histogram(data=diag_dates, aes(fill=class), binwidth=1) +
  xlab("Year relative to registration start year") +
  ylim(0, 44000)

diag_dates %>% filter(year_relative_to_regstart==0) %>% count()
#43,308
43308/743968
#5.8%

## If remove those within 3 months of registration start

diag_dates_clean <- diag_dates %>% filter(as.integer(difftime(dm_diag_date, regstartdate, units="days"))<0 | as.integer(difftime(dm_diag_date, regstartdate, units="days"))>=91)

ggplot(diag_dates_clean, aes(x=year_relative_to_regstart)) + 
  geom_histogram(data=diag_dates_clean, aes(fill=class), binwidth=1) +
  xlab("Year relative to registration start year") +
  ylim(0, 44000)







# New diagnosis dates

############################################################################################

# Look at number diagnosed on different codes

cohort_diag_dates_classified %>% count()
#743,968

total_by_diag_code_type <- collect(cohort_diag_dates_classified %>% group_by(dm_diag_codetype) %>% summarise(count=n())) 

total_by_diag_code_type2 <- collect(cohort_diag_dates_classified %>% group_by(dm_diag_codetype2) %>% summarise(count=n()))

total_by_class <- collect(cohort_diag_dates_classified %>% group_by(class) %>% summarise(count=n())) 
# matches previous

total_by_class_and_diag_code_type <- collect(cohort_diag_dates_classified %>% group_by(class, dm_diag_codetype) %>% summarise(count=n())) %>%
  pivot_wider(id_cols=class, names_from=dm_diag_codetype, values_from=count)

total_by_class_and_diag_code_type2 <- collect(cohort_diag_dates_classified %>% group_by(class, dm_diag_codetype2) %>% summarise(count=n())) %>%
  pivot_wider(id_cols=class, names_from=dm_diag_codetype2, values_from=count)



