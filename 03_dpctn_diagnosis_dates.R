
# Calculate diagnosis dates for everyone in DePICtion cohort except those with diabetes type that changes over time

# Also look at:
## How many people diagnosed on basis of diabetes code vs high HbA1c vs OHA/insulin script
## Potential data quality issue around diagnoses in year of birth

############################################################################################

# Setup
library(tidyverse)
library(aurum)
rm(list=ls())

cprd = CPRDData$new(cprdEnv = "test-remote",cprdConf = "~/.aurum.yaml")

analysis = cprd$analysis("dpctn")


############################################################################################

# Just use 'clean' diabetes codes/high HbA1cs/OHA/insulin scripts (i.e. those before DOB removed; there will be none after end of records/death as those after index date [01/02/2020] have been removed and whole cohort are alive and registered on 01/02/2020)

# All already earliest and latest (clean) codes for each category cached in table from 02_dpctn_diabetes_type_all_time script

earliest_latest_codes_long <- earliest_latest_codes_long %>% analysis$cached("earliest_latest_codes_long")


# For those classified as unspecified / type 1 / type 2 / gestational only / MODY / genetic/syndromic / secondary / malnutrition, use earliest code / HbA1c / OHA/insulin script as diagnosis date

cohort_classification <- cohort_classification %>% analysis$cached("cohort_classification")

cohort_diag_dates_interim_1 <- cohort_classification %>%
  select(patid, class) %>%
  filter(class!="other") %>%
  inner_join(earliest_latest_codes_long, by="patid") %>%
  group_by(patid, class) %>%
  summarise(dm_diag_date=min(earliest, na.rm=TRUE)) %>%
  ungroup() %>%
  analysis$cached("cohort_diag_dates_interim_1", unique_indexes="patid")
                    

############################################################################################

# Look at potential quality issues:
## Diagnoses by calendar year relative to year of birth
## Diagnoses by calendar year relative to registration start date
### And then how many with potential issues by calendar year

diag_dates <- collect(cohort_diag_dates_interim_1 %>% mutate(diag_year=year(dm_diag_date)) %>% select(patid, class, dm_diag_date, diag_year) %>% left_join((cprd$tables$patient %>% mutate(yor=year(regstartdate)) %>% select(patid, yob, regstartdate, yor)), by="patid"))


# By calendar year relative to year of birth

diag_dates <- diag_dates %>% mutate(year_relative_to_birth=as.integer(diag_year-yob))

ggplot(diag_dates, aes(x=year_relative_to_birth)) + 
  geom_histogram(data=diag_dates, aes(fill=class), binwidth=1) +
  xlab("Year relative to birth year")

diag_dates %>% filter(year_relative_to_birth==0 & class=="type 2") %>% count()
#1,694
1694/576977
#0.3%

# Exclude codes in year of birth for those with Type 2 diabetes



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

# Set to missing if diagnosis date within 3 months of registration start


############################################################################################

# Calculate new diagnosis dates with above cleaning rules, and also record whether diagnosis is based on diabetes code, high HbA1c or prescription for glucose-lowering medication

cohort_clean_dm_indications <- cohort_clean_dm_indications %>% analysis$cached("cohort_clean_dm_indications")

earliest_latest_codes_long_no_yob <- cohort_classification %>%
  select(patid, class) %>%
  inner_join(cohort_clean_dm_indications, by="patid") %>%
  inner_join((cprd$tables$patient %>% select(patid, yob)), by="patid") %>%
  filter(!(class=="type 2" & (category=="unspecified" | category=="type 2") & year(date)==yob)) %>%
  group_by(patid, class, category) %>%
  summarise(earliest=min(date, na.rm=TRUE),
            latest=max(date, na.rm=TRUE),
            count=n()) %>%
  ungroup() %>%
  mutate(category=ifelse(category=="type 1", "type_1",
                         ifelse(category=="type 2", "type_2",
                                ifelse(category=="other/unspec genetic inc syndromic", "other_genetic_syndromic",
                                       ifelse(category=="gestational history", "gest_history",
                                              ifelse(category=="insulin receptor abs", "ins_receptor_abs",
                                                     ifelse(category=="other unspec", "other_excl", category))))))) %>%
  analysis$cached("earliest_latest_codes_long_no_yob", indexes="patid")


cohort_diag_dates <- earliest_latest_codes_long_no_yob %>%
  filter(class!="other") %>%
  mutate(category=ifelse(category=="unspecified" | category=="high_hba1c" | category=="oha_script" | category=="insulin_script", category, "type_specific_code")) %>%
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
  analysis$cached("cohort_diag_dates_interim_2", unique_indexes="patid")

cohort_diag_dates <- cohort_diag_dates %>%
  inner_join((cprd$tables$patient %>% select(patid, regstartdate)), by="patid") %>%
  mutate(dm_diag_date=if_else(dm_diag_date>=regstartdate & datediff(dm_diag_date, regstartdate)<91, as.Date(NA), dm_diag_date),
         dm_diag_codetype=ifelse(is.na(dm_diag_date), NA, dm_diag_codetype),
         dm_diag_codetype2=ifelse(is.na(dm_diag_date), NA, dm_diag_codetype2)) %>%
  analysis$cached("cohort_diag_dates_interim_3", unique_indexes="patid")


############################################################################################

# Look at potential issues by calendar year before and after cleaning

diag_dates <- collect(cohort_diag_dates_interim_1 %>% mutate(diag_year=year(dm_diag_date)) %>% select(patid, class, dm_diag_date, diag_year) %>% left_join((cprd$tables$patient %>% mutate(yor=year(regstartdate)) %>% select(patid, yob, regstartdate, yor)), by="patid")) %>%
  mutate(year_relative_to_birth=as.integer(diag_year-yob),
         year_relative_to_regstart=as.integer(diag_year-yor))

diag_dates_clean <- collect(cohort_diag_dates %>% mutate(diag_year=year(dm_diag_date)) %>% select(patid, class, dm_diag_date, diag_year) %>% left_join((cprd$tables$patient %>% mutate(yor=year(regstartdate)) %>% select(patid, yob, regstartdate, yor)), by="patid")) %>%
  mutate(year_relative_to_birth=as.integer(diag_year-yob),
         year_relative_to_regstart=as.integer(diag_year-yor))
  
diag_dates_summ <- diag_dates %>%
  mutate(flag=as.factor(ifelse(year_relative_to_birth==0, "diag in birth year",
                               ifelse(year_relative_to_regstart==0, "diag in same year as reg start", "no issue"))),
         diag_year=as.integer(diag_year)) %>%
  group_by(diag_year) %>%
  mutate(total_count=n()) %>%
  ungroup() %>%
  filter(flag!="no issue") %>%
  group_by(diag_year, flag) %>%
  summarise(flag_count=n(),
            flag_perc=100*(flag_count/total_count)) %>%
  slice(1)

diag_dates_summ_clean <- diag_dates %>%
  mutate(flag=as.factor(ifelse(year_relative_to_birth==0, "diag in birth year",
                               ifelse(year_relative_to_regstart==0, "diag in same year as reg start", "no issue"))),
         diag_year=as.integer(diag_year)) %>%
  group_by(diag_year) %>%
  mutate(total_count=n()) %>%
  ungroup() %>%
  filter(flag!="no issue") %>%
  group_by(diag_year, flag) %>%
  summarise(flag_count=n(),
            flag_perc=100*(flag_count/total_count)) %>%
  slice(1)

ggplot(diag_dates_summ, aes(x=diag_year, y=flag_perc, fill=flag)) +
  geom_bar(position="stack", stat="identity") +
  xlab("Year of diagnosis") +
  ylab("% of diagnoses with potential issues") +
  ylim(0, 30) +
  xlim(1960, 2020)

ggplot(diag_dates_summ_clean, aes(x=diag_year, y=flag_perc, fill=flag)) +
  geom_bar(position="stack", stat="identity") +
  xlab("Year of diagnosis") +
  ylab("% of diagnoses with potential issues") +
  ylim(0, 30) +
  xlim(1960, 2020)


############################################################################################

# Look at number diagnosed on different codes

cohort_diag_dates %>% count()
#743,279

total_by_diag_code_type <- collect(cohort_diag_dates %>% group_by(dm_diag_codetype) %>% summarise(count=n())) 

total_by_diag_code_type2 <- collect(cohort_diag_dates %>% group_by(dm_diag_codetype2) %>% summarise(count=n()))

total_by_class <- collect(cohort_diag_dates %>% group_by(class) %>% summarise(count=n())) 
# matches previous

total_by_class_and_diag_code_type <- collect(cohort_diag_dates %>% group_by(class, dm_diag_codetype) %>% summarise(count=n())) %>%
  pivot_wider(id_cols=class, names_from=dm_diag_codetype, values_from=count)

total_by_class_and_diag_code_type2 <- collect(cohort_diag_dates %>% group_by(class, dm_diag_codetype2) %>% summarise(count=n())) %>%
  pivot_wider(id_cols=class, names_from=dm_diag_codetype2, values_from=count)


############################################################################################

# Look at time between HbA1c / script and next diabetes code i.e. how much difference using diabetes codes alone would make

cohort_diag_dates_codes_only <- earliest_latest_codes_long_no_yob %>%
  filter(class!="other") %>%
  mutate(category=ifelse(category=="unspecified" | category=="high_hba1c" | category=="oha_script" | category=="insulin_script", category, "type_specific_code")) %>%
  filter(category=="unspecified" | category=="type_specific_code") %>%
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
  analysis$cached("cohort_diag_dates_codes_only_interim_1", unique_indexes="patid")

cohort_diag_dates_codes_only <- cohort_diag_dates_codes_only %>%
  inner_join((cprd$tables$patient %>% select(patid, regstartdate)), by="patid") %>%
  mutate(dm_diag_date=if_else(dm_diag_date>=regstartdate & datediff(dm_diag_date, regstartdate)<91, as.Date(NA), dm_diag_date),
         dm_diag_codetype=ifelse(is.na(dm_diag_date), NA, dm_diag_codetype),
         dm_diag_codetype2=ifelse(is.na(dm_diag_date), NA, dm_diag_codetype2)) %>%
  analysis$cached("cohort_diag_dates_codes_only_interim_2", unique_indexes="patid")

time_diff <- collect(cohort_diag_dates %>%
  select(patid, class, dm_diag_date) %>%
  inner_join((cohort_diag_dates_codes_only %>% select(patid, code_only_dm_diag_date=dm_diag_date)), by="patid") %>%
  mutate(time_diff=datediff(code_only_dm_diag_date, dm_diag_date)) %>%
  select(class, time_diff))

time_diff_summary <- time_diff %>%
  group_by(class) %>%
  mutate(total=n(),
         missing=sum(is.na(time_diff)),
         missing_perc=missing/total,
         no_change=sum(!is.na(time_diff) & time_diff==0),
         no_change_perc=no_change/total,
         median_time_diff=median(time_diff, na.rm=TRUE)) %>%
  filter((!is.na(time_diff) & time_diff>0) | class=="malnutrition") %>%
  mutate(median_time_diff_no_0=median(time_diff, na.rm=TRUE)) %>%
  slice(1)

time_diff_summary <- time_diff %>%
  mutate(total=n(),
         missing=sum(is.na(time_diff)),
         missing_perc=missing/total,
         no_change=sum(!is.na(time_diff) & time_diff==0),
         no_change_perc=no_change/total,
         median_time_diff=median(time_diff, na.rm=TRUE)) %>%
  filter((!is.na(time_diff) & time_diff>0)) %>%
  mutate(median_time_diff_no_0=median(time_diff, na.rm=TRUE)) %>%
  slice(1)









