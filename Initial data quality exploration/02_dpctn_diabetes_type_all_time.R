
# Want to:
## a) Exclude those who don't actually have diabetes
## b) Determine diabetes type at 01/02/2020 - might determine how diagnosis date is determined (e.g. if previous gestational diabetes)

# NB: this script uses pre-made table validDateLookup, which has min_dob (earliest possible DOB based on day, month and year provided by CPRD)

############################################################################################

# Setup
library(tidyverse)
library(aurum)
rm(list=ls())

cprd = CPRDData$new(cprdEnv = "test-remote",cprdConf = "~/.aurum.yaml")
codesets = cprd$codesets()
codes = codesets$getAllCodeSetVersion(v = "31/10/2021")

analysis = cprd$analysis("dpctn")


############################################################################################

# Set index date
index_date <- as.Date("2020-02-01")

# Get cohort info 
cohort <- cohort %>% analysis$cached("cohort")

############################################################################################

# Look at number of codes/HbA1cs/scripts before DOB (can't be after end of records as people are still actively registered on 01/02/2020 in this cohort)

# Previously, number with remission codes <5% but do look at too

# Then put together history of type codes for each person



# Pull raw code/HbA1c/script occurrences

analysis = cprd$analysis("all_patid")

raw_diabetes_medcodes <- cprd$tables$observation %>%
  inner_join(codes$all_diabetes, by="medcodeid") %>%
  analysis$cached("raw_diabetes_medcodes", indexes=c("patid", "obsdate", "all_diabetes_cat"))

raw_exclusion_diabetes_medcodes <- cprd$tables$observation %>%
  inner_join(codes$exclusion_diabetes, by="medcodeid") %>%
  analysis$cached("raw_exclusion_diabetes_medcodes", indexes=c("patid", "obsdate", "exclusion_diabetes_cat"))

raw_diabetes_remission_medcodes <- cprd$tables$observation %>%
  inner_join(codes$diabetes_remission, by="medcodeid") %>%
  analysis$cached("raw_diabetes_remission_medcodes", indexes=c("patid", "obsdate"))

raw_hba1c_medcodes <- cprd$tables$observation %>%
  inner_join(codes$hba1c, by="medcodeid") %>%
  analysis$cached("raw_hba1c_medcodes", indexes=c("patid", "obsdate", "testvalue", "numunitid"))
  
raw_oha_prodcodes <- cprd$tables$drugIssue %>%
  inner_join(cprd$tables$ohaLookup, by="prodcodeid") %>%
  analysis$cached("raw_oha_prodcodes", indexes=c("patid", "issuedate"))

raw_insulin_prodcodes <- cprd$tables$drugIssue %>%
  inner_join(codes$insulin, by="prodcodeid") %>%
  analysis$cached("raw_insulin_prodcodes", indexes=c("patid", "issuedate"))



# Join together so can use table for further analysis
## Remove diabetes insipidus codes in exclusion table

analysis = cprd$analysis("dpctn")

all_patid_raw_dm_indications <- raw_diabetes_medcodes %>% select(patid, date=obsdate, category=all_diabetes_cat, code=medcodeid) %>%
  union_all(raw_exclusion_diabetes_medcodes %>% filter(exclusion_diabetes_cat!="diabetes insipidus") %>% select(patid, date=obsdate, category=exclusion_diabetes_cat, code=medcodeid)) %>%
  union_all(raw_diabetes_remission_medcodes %>% mutate(category="remission", code=NA) %>% select(patid, date=obsdate, category, code)) %>%
  union_all(raw_hba1c_medcodes %>% mutate(category="high_hba1c", code=NA) %>% filter(testvalue>47.5 | (testvalue<=20 & testvalue>6.497)) %>% select(patid, date=obsdate, category, code)) %>%
  union_all(raw_oha_prodcodes %>% mutate(category="oha_script", code=NA) %>% select(patid, date=issuedate, category, code)) %>%
  union_all(raw_insulin_prodcodes %>% mutate(category="insulin_script", code=NA) %>% select(patid, date=issuedate, category, code)) %>%
  filter(date<=index_date) %>%
  analysis$cached("all_patid_raw_dm_indications", indexes=c("patid", "date", "category", "code"))
  


# Look at number of codes/high HbA1cs/scripts before DOB for our cohort

cohort_raw_dm_indications <- cohort %>%
  select(patid) %>%
  inner_join(all_patid_raw_dm_indications, by="patid") %>% 
  analysis$cached("cohort_raw_dm_indications", indexes="patid")

cohort_clean_dm_indications <- cohort_raw_dm_indications %>%
  inner_join(cprd$tables$validDateLookup, by="patid") %>%
  filter(date>=min_dob) %>%
  select(patid, date, category, code) %>%
  analysis$cached("cohort_clean_dm_indications", indexes=c("patid", "date", "category"))


raw_all <- collect(cohort_raw_dm_indications %>% mutate(category2=ifelse(category=="gestational history", "gestational", category)) %>% group_by(category2) %>% summarise(raw_all_count=n()) %>% ungroup())

clean_all <- collect(cohort_clean_dm_indications %>% mutate(category2=ifelse(category=="gestational history", "gestational", category)) %>% group_by(category2) %>% summarise(clean_all_count=n()) %>% ungroup())

counts <- raw_all %>%
  left_join(clean_all, by="category2")  %>%
  mutate(prop_codes=round((clean_all_count/raw_all_count)*100, 2))
#All >99.9%

cohort_raw_dm_indications %>%
  anti_join(cohort_clean_dm_indications, by=c("patid", "date", "category")) %>%
  distinct(patid) %>%
  count()
#1,994 people affected

## NB: no insulin receptor antibody-type codes in this cohort


# Look at earliest and latest codes and counts for each category

earliest_latest_codes_long <- cohort_clean_dm_indications %>%
  group_by(patid, category) %>%
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
  analysis$cached("earliest_latest_codes_long", indexes="patid")
  
earliest_latest_codes_wide <- earliest_latest_codes_long %>%
  pivot_wider(id_cols=patid, names_from=category, values_from=c(earliest, latest, count)) %>%
  analysis$cached("earliest_latest_codes_wide", unique_indexes="patid")



# Classify patients based on codes

cohort_classification <- earliest_latest_codes_wide %>%
  
  mutate(earliest_any_gestational=pmin(ifelse(is.na(earliest_gestational), as.Date("2050-01-01"), earliest_gestational),
                                       ifelse(is.na(earliest_gest_history), as.Date("2050-01-01"), earliest_gest_history), na.rm=TRUE),
         earliest_any_gestational=if_else(earliest_any_gestational=="2050-01-01", NA, earliest_any_gestational),
         
         class=case_when(
           
    is.na(earliest_type_1) & is.na(earliest_type_2) & is.na(earliest_any_gestational) & is.na(earliest_mody) & is.na(earliest_other_genetic_syndromic) & is.na(earliest_secondary) & is.na(earliest_malnutrition) & is.na(earliest_other_excl) ~ "unspecified",
    
    !is.na(earliest_type_1) & is.na(earliest_type_2) & is.na(earliest_any_gestational) & is.na(earliest_mody) & is.na(earliest_other_genetic_syndromic) & is.na(earliest_secondary) & is.na(earliest_malnutrition) & is.na(earliest_other_excl) ~ "type 1",
    
    is.na(earliest_type_1) & !is.na(earliest_type_2) & is.na(earliest_any_gestational) & is.na(earliest_mody) & is.na(earliest_other_genetic_syndromic) & is.na(earliest_secondary) & is.na(earliest_malnutrition) & is.na(earliest_other_excl) ~ "type 2",
    
    is.na(earliest_type_1) & is.na(earliest_type_2) & !is.na(earliest_any_gestational) & is.na(earliest_mody) & is.na(earliest_other_genetic_syndromic) & is.na(earliest_secondary) & is.na(earliest_malnutrition) & is.na(earliest_other_excl) ~ "gestational only",
    
    is.na(earliest_type_1) & is.na(earliest_type_2) & is.na(earliest_any_gestational) & !is.na(earliest_mody) & is.na(earliest_other_genetic_syndromic) & is.na(earliest_secondary) & is.na(earliest_malnutrition) & is.na(earliest_other_excl) ~ "mody",
    
    is.na(earliest_type_1) & is.na(earliest_type_2) & is.na(earliest_any_gestational) & is.na(earliest_mody) & !is.na(earliest_other_genetic_syndromic) & is.na(earliest_secondary) & is.na(earliest_malnutrition) & is.na(earliest_other_excl) ~ "genetic/syndromic",
    
    is.na(earliest_type_1) & is.na(earliest_type_2) & is.na(earliest_any_gestational) & is.na(earliest_mody) & is.na(earliest_other_genetic_syndromic) & !is.na(earliest_secondary) & is.na(earliest_malnutrition) & is.na(earliest_other_excl) ~ "secondary",
    
    is.na(earliest_type_1) & is.na(earliest_type_2) & is.na(earliest_any_gestational) & is.na(earliest_mody) & is.na(earliest_other_genetic_syndromic) & is.na(earliest_secondary) & !is.na(earliest_malnutrition) & is.na(earliest_other_excl) ~ "malnutrition"),
    
    class=ifelse(is.na(class), "other", class)) %>%
  
  analysis$cached("cohort_classification", unique_indexes="patid")


class <- collect(cohort_classification %>% group_by(class) %>% summarise(count=n()) %>% ungroup())
