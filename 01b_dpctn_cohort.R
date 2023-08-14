
# Create new table with all IDs in download who are registered on 01/02/2020 and adults at this date

# Define diagnosis date based on earliest diabetes code: exclude those diagnosed between -30 and +90 days of registration or >50 years of age

# Define diabetes type based on (latest) type codes - and add in variables relating to this

# Pull in variables for MODY and T1D/T2D calculator: current BMI, HbA1c, total cholesterol, HDL, triglycerides, current treatment (and whether have ins/OHA script or DPP4i/GLP1/SU/TZD ever), family history of diabetes, earliest insulin and OHA

# Pull in other variables of interest: GAD and IA2 antibodies (ever prior to index date), C-peptide (ever prior to index date), and whether are non-English speaking / have English as a second language


############################################################################################

# Setup
library(tidyverse)
library(aurum)
library(EHRBiomarkr)
rm(list=ls())

cprd = CPRDData$new(cprdEnv = "test-remote",cprdConf = "~/.aurum.yaml")
codesets = cprd$codesets()
codes = codesets$getAllCodeSetVersion(v = "31/10/2021")

analysis = cprd$analysis("dpctn_final")


############################################################################################

# Set index date

index_date <- as.Date("2020-02-01")


############################################################################################

# Initial data quality checks

## Our download should not have included non-'acceptable' patients (see CPRD data specification for definition)
## It should have only included patients with registration start dates up to 10/2018 (as we used the October 2020 Aurum release, and only included patients with a diabetes medcode within registration and with at least 1 year of UTS data before and after)
## However, we have some non-acceptable patients and some patients registered in 2020 (none between 10/2018-08/2020, inclusive) - remove these people

## Additionally, the codelist we used for our download included some non-diabetes codes (e.g. 'insulin resistance')
## Everyone in download should have diabetes codes between 01/01/2004 and 06/11/2020 with at least 1 year of data before and after 0 exclude people without this from analysis
## NB: for other prevalent/at-diagnosis/treatment response cohorts have not additionally removed these people as they would be removed by using QOF codes anyway


# Keep those which are also 'acceptable' and not with a registration start date in 2020

acceptable_patids <- cprd$tables$patient %>%
  filter(acceptable==1 & year(regstartdate)!=2020)

acceptable_patids %>% count()
#1,480,895 out of 1,481,294 in download


# Find people with diabetes code occurrence (T1/T2/unspec and exclusion codes except diabetes insipidus) with a year of data before and after
## Since extraction was in November 2020, this means everyone who remains in the dataset must have a code before the index date in Feb 2020

analysis = cprd$analysis("all_patid")

raw_diabetes_medcodes <- cprd$tables$observation %>%
  inner_join(codes$all_diabetes, by="medcodeid") %>%
  analysis$cached("raw_diabetes_medcodes", indexes=c("patid", "obsdate", "all_diabetes_cat"))

raw_exclusion_diabetes_medcodes <- cprd$tables$observation %>%
  inner_join(codes$exclusion_diabetes, by="medcodeid") %>%
  analysis$cached("raw_exclusion_diabetes_medcodes", indexes=c("patid", "obsdate", "exclusion_diabetes_cat"))

analysis = cprd$analysis("dpctn_final")

acceptable_patids_with_valid_diabetes_code <- acceptable_patids %>%
  select(patid, pracid, regstartdate, regenddate) %>%
  left_join((cprd$tables$practice %>% select(pracid, prac_region=region, lcd)), by="pracid") %>%
  
  mutate(gp_record_end=pmin(if_else(is.na(lcd), as.Date("2020-10-31"), lcd),
                            if_else(is.na(regenddate), as.Date("2020-10-31"), regenddate),
                            as.Date("2020-10-31"), na.rm=TRUE)) %>%
  
  inner_join((raw_diabetes_medcodes %>%
                select(patid, obsdate) %>%
                union_all((raw_exclusion_diabetes_medcodes %>% filter(exclusion_diabetes_cat!="diabetes insipidus") %>% select(patid, obsdate)))), by="patid") %>%
  
  filter(obsdate>=sql("date_add(regstartdate, interval 365.25 day)") & obsdate<=sql("date_add(gp_record_end, interval -365.25 day)") & obsdate>=as.Date("2004-01-01")) %>%
  
  distinct(patid) %>%
  
  analysis$cached("acceptable_patids_with_valid_diabetes_code", unique_indexes="patid")

acceptable_patids_with_valid_diabetes_code %>% count()
#1,314,373


############################################################################################

# Find IDs of those registered on 01/02/2020

# Include general patient variables as per all_diabetes_cohort:
## gender
## DOB (derived as per: https://github.com/Exeter-Diabetes/CPRD-Codelists/blob/main/readme.md#general-notes-on-implementation, cached for all IDs in 'diagnosis_date_dob' table from all_patid_dob script)
## pracid
## prac_region
## imd2015_10
## ethnicity 5-category and 16-category (derived as per: https://github.com/Exeter-Diabetes/CPRD-Codelists#ethnicity, cached for all IDs in 'all_patid_ethnicity' table from all_patid_ethnicity_table script)
## regstartdate	
## gp_record_end (earliest of last collection date from practice, deregistration and 31/10/2020 (latest date in records))	
## death_date	(earliest of 'cprddeathdate' (derived by CPRD) and ONS death date. ONS death date=date of death [dod] or date of death registration [dor] if dod missing = 'ons_death' variable in validDateLookup table)
## with_hes ('patidsWithLinkage' table has patids of those with linkage to HES APC, IMD and ONS death records plus n_patid_hes (how many patids linked with 1 HES record); with_hes=1 for patients with HES linkage and n_patid_hes<=20)
## Calculate age at index date


# Just want those registered on 01/02/2020 (the index date)

analysis = cprd$analysis("diabetes_cohort")
dob <- dob %>% analysis$cached("dob")

analysis = cprd$analysis("all_patid")
ethnicity <- ethnicity %>% analysis$cached("ethnicity")


analysis = cprd$analysis("dpctn_final")

cohort <- acceptable_patids_with_valid_diabetes_code %>%
  inner_join(cprd$tables$patient, by="patid") %>%
  select(patid, gender, pracid, regstartdate, regenddate, cprd_ddate) %>%
  left_join((dob %>% select(patid, dob)), by="patid") %>%
  left_join((cprd$tables$practice %>% select(pracid, prac_region=region, lcd)), by="pracid") %>%
  left_join((cprd$tables$patientImd2015 %>% select(patid, imd2015_10)), by="patid") %>%
  left_join((ethnicity %>% select(patid, ethnicity_5cat, ethnicity_16cat)), by="patid") %>%
  left_join((cprd$tables$validDateLookup %>% select(patid, ons_death)), by="patid") %>%
  left_join((cprd$tables$patidsWithLinkage %>% select(patid, n_patid_hes)), by="patid") %>%
  
  mutate(gp_record_end=pmin(if_else(is.na(lcd), as.Date("2020-10-31"), lcd),
                            if_else(is.na(regenddate), as.Date("2020-10-31"), regenddate),
                            as.Date("2020-10-31"), na.rm=TRUE),
         
         death_date=pmin(if_else(is.na(cprd_ddate), as.Date("2050-01-01"), cprd_ddate),
                         if_else(is.na(ons_death), as.Date("2050-01-01"), ons_death), na.rm=TRUE),
         death_date=if_else(death_date==as.Date("2050-01-01"), as.Date(NA), death_date),
         
         with_hes=ifelse(!is.na(n_patid_hes) & n_patid_hes<=20, 1L, 0L),
         
         age_at_index=round(datediff(index_date, dob)/365.25, 1)) %>%
  
  select(patid, gender, dob, age_at_index, pracid, prac_region, imd2015_10, ethnicity_5cat, ethnicity_16cat, regstartdate, gp_record_end, death_date, with_hes) %>%
  
  filter(regstartdate<=index_date & !(!is.na(death_date) & death_date<index_date) & !(!is.na(gp_record_end) & gp_record_end<index_date)) %>%
  
  analysis$cached("cohort_interim_1", unique_indexes="patid")

cohort %>% count()
# 779,498


## Just keep those which are adults

cohort <- cohort %>%
  filter(age_at_index>=18) %>%
  analysis$cached("cohort_interim_2", unique_indexes="patid")

cohort %>% count()
# 769,493


############################################################################################

# Define diabetes type (NB: not removing codes before DOB for this)

## Combine all diabetes codes prior to/at index date

analysis = cprd$analysis("dpctn_final")

all_patid_dm_codes <- raw_diabetes_medcodes %>%
  select(patid, date=obsdate, enterdate, category=all_diabetes_cat) %>%
  union_all(raw_exclusion_diabetes_medcodes %>%
              filter(exclusion_diabetes_cat!="diabetes insipidus") %>%
              select(patid, date=obsdate, enterdate, category=exclusion_diabetes_cat)) %>%
  filter(date<=index_date) %>%
  analysis$cached("all_patid_dm_codes", indexes=c("patid", "date", "category"))


## Find code counts for each diabetes type

all_patid_code_counts <- all_patid_dm_codes %>%
  group_by(patid, category) %>%
  summarise(count=n()) %>%
  ungroup() %>%
  pivot_wider(id_cols=patid, names_from=category, values_from=count, values_fill=list(count=0)) %>%
  analysis$cached("all_patid_code_counts", indexes="patid")

## NB: no insulin receptor Abs codes


## Find latest type code, excluding unspecified and gestational, and keep date
 
all_patid_latest_type_code <- all_patid_dm_codes %>%
  filter(category!="unspecified" & category!="gestational" & category!="gestational history") %>%
  group_by(patid) %>%
  mutate(most_recent_date=max(date, na.rm=TRUE),
         days_since_type_code=datediff(index_date, most_recent_date)) %>%
  filter(date==most_recent_date) %>%
  ungroup() %>%
  group_by(patid, days_since_type_code) %>%
  summarise(provisional_diabetes_type=sql("group_concat(distinct category order by category separator ' & ')")) %>%
  ungroup() %>%
  analysis$cached("all_patid_latest_type_code", indexes="patid")

### Sensitivity analysis including gestational codes

all_patid_latest_type_code_inc_gest <- all_patid_dm_codes %>%
  filter(category!="unspecified") %>%
  group_by(patid) %>%
  mutate(most_recent_date=max(date, na.rm=TRUE),
         days_since_type_code=datediff(index_date, most_recent_date)) %>%
  filter(date==most_recent_date) %>%
  ungroup() %>%
  group_by(patid, days_since_type_code) %>%
  summarise(provisional_diabetes_type=sql("group_concat(distinct category order by category separator ' & ')")) %>%
  ungroup() %>%
  analysis$cached("all_patid_latest_type_code_inc_gest", indexes="patid")


## Find who has PRIMIS code
### Use table from Initial data quality checks/03a_dpctn_diabetes_qof_primis_codelist.R

analysis = cprd$analysis("dpctn")

with_primis <- with_primis %>% analysis$cached("with_primis")

analysis = cprd$analysis("dpctn_final")

with_primis <- with_primis %>%
  distinct(patid) %>%
  mutate(with_primis=1L)


## Determine diabetes type and add to cohort table

diabetes_type <- cohort %>%
  select(patid) %>%
  left_join(all_patid_code_counts, by="patid") %>%
  left_join(all_patid_latest_type_code, by="patid") %>%
  left_join(with_primis, by="patid") %>%
  mutate(diabetes_type=case_when(
    `type 1`==0 & `type 2`==0 & gestational==0 & `gestational history`==0 & malnutrition==0 & mody==0 & `other unspec`==0 & `other/unspec genetic inc syndromic`==0 & secondary==0 & is.na(with_primis) ~ "unspecified",
    
    `type 1`==0 & `type 2`==0 & gestational==0 & `gestational history`==0 & malnutrition==0 & mody==0 & `other unspec`==0 & `other/unspec genetic inc syndromic`==0 & secondary==0 & !is.na(with_primis) ~ "unspecified_with_primis",
    
    `type 1`>0 & `type 2`==0 & gestational==0 & `gestational history`==0 & malnutrition==0 & mody==0 & `other unspec`==0 & `other/unspec genetic inc syndromic`==0 & secondary==0 ~ "type 1",
    
    `type 1`==0 & `type 2`>0 & gestational==0 & `gestational history`==0 & malnutrition==0 & mody==0 & `other unspec`==0 & `other/unspec genetic inc syndromic`==0 & secondary==0 ~ "type 2",
    
    `type 1`==0 & `type 2`==0 & (gestational>0 | `gestational history`>0) & malnutrition==0 & mody==0 & `other unspec`==0 & `other/unspec genetic inc syndromic`==0 & secondary==0 ~ "gestational",
    
    `type 1`==0 & `type 2`==0 & gestational==0 & `gestational history`==0 & malnutrition==0 & mody==0 & `other unspec`==0 & `other/unspec genetic inc syndromic`==0 & secondary==0 ~ "insulin receptor abs",
    
    `type 1`==0 & `type 2`==0 & gestational==0 & `gestational history`==0 & malnutrition>0 & mody==0 & `other unspec`==0 & `other/unspec genetic inc syndromic`==0 & secondary==0 ~ "malnutrition",
    
    `type 1`==0 & `type 2`==0 & gestational==0 & `gestational history`==0 & malnutrition==0 & mody>0 & `other unspec`==0 & `other/unspec genetic inc syndromic`==0 & secondary==0 ~ "mody",
    
    `type 1`==0 & `type 2`==0 & gestational==0 & `gestational history`==0 & malnutrition==0 & mody==0 & `other unspec`>0 & `other/unspec genetic inc syndromic`>0 & secondary==0 ~ "other unspec",
    
    `type 1`==0 & `type 2`==0 & gestational==0 & `gestational history`==0 & malnutrition==0 & mody==0 & `other unspec`==0 & `other/unspec genetic inc syndromic`>0 & secondary==0 ~ "other/unspec genetic inc syndromic",
    
    `type 1`==0 & `type 2`==0 & gestational==0 & `gestational history`==0 & malnutrition==0 & mody==0 & `other unspec`==0 & `other/unspec genetic inc syndromic`==0 & secondary>0 ~ "secondary"),
    
    diabetes_type=ifelse(!is.na(diabetes_type), diabetes_type, paste("mixed;", provisional_diabetes_type)),
    
    type1_code_count= `type 1`,
    type2_code_count= `type 2`,
    mody_code_count=mody
    
    ) %>%
  
  select(patid, diabetes_type, type1_code_count, type2_code_count, mody_code_count, days_since_type_code) %>%
  
  analysis$cached("diabetes_type", unique_indexes="patid")
    
cohort <- cohort %>%
  inner_join(diabetes_type, by="patid") %>%
  analysis$cached("cohort_interim_3", unique_indexes="patid")


## Sensitivity analysis including gestational codes when finding most recent code

diabetes_type %>% inner_join(all_patid_latest_type_code_inc_gest, by="patid") %>% filter((provisional_diabetes_type=="gestational" | provisional_diabetes_type=="gestational_history") & diabetes_type!="gestational") %>% group_by(diabetes_type) %>% summarise(count=n())
# mixed; type 2                                 197
# mixed; type 1                                  17
# mixed; other/unspec genetic inc syndromic       2
# mixed; type 1 & type 2                          1
# mixed; mody                                     2
# mixed; secondary                                1

print(diabetes_type %>% filter(substr(diabetes_type, 1, 5)=="mixed") %>% group_by(diabetes_type) %>% summarise(count=n()), n=100)

# mixed; type 2                                                              19997
# mixed; type 1                                                               9264
# mixed; other/unspec genetic inc syndromic                                     66
# mixed; type 1 & type 2                                                       581
# mixed; mody                                                                   90
# mixed; secondary                                                             243

197*100/19997 #1.0%
17*100/9264 #0.2%
2*100/66 #3.0%
1*100/581 #0.2%
2*100/90 #2.2%
1*100/243 #0.4%

# Doesn't make any difference to counts in Type 1 and 2 groups
# And their code shouldn't be gestational if they have pre-existing Type 1 or 2! And if not pre-existing, latest code should be Type 1 or 2


############################################################################################

# Define diagnosis dates
## Remove if before DOB
## Exclude codes if Type 2 and in year in birth

diagnosis_dates <- all_patid_dm_codes %>%
  inner_join(cprd$tables$validDateLookup, by="patid") %>%
  filter(date>=min_dob) %>%
  inner_join(cohort, by="patid") %>%
  filter(!(diabetes_type=="type 2" & year(date)==year(dob))) %>%
  group_by(patid) %>%
  summarise(diagnosis_date=min(date, na.rm=TRUE)) %>%
  ungroup() %>%
  analysis$cached("diagnosis_dates", unique_indexes="patid")


# Also get earliest enterdate for diagnosis date- ignore those before date of birth

earliest_enterdate <- diagnosis_dates %>%
  inner_join(all_patid_dm_codes, by=c("patid", "diagnosis_date"="date")) %>%
  inner_join(cprd$tables$validDateLookup, by="patid") %>%
  filter(enterdate>=min_dob) %>%
  group_by(patid) %>%
  summarise(earliest_enterdate=min(enterdate, na.rm=TRUE)) %>%
  ungroup() %>%
  analysis$cached("earliest_enterdate", unique_indexes="patid")
# Not everyone has an enterdate; if null

# Add to cohort table and remove those diagnosed aged >50

cohort <- cohort %>%
  inner_join(diagnosis_dates, by="patid") %>%
  mutate(dm_diag_age=round((datediff(diagnosis_date, dob))/365.25, 1)) %>%
  filter(dm_diag_age<51) %>%
  left_join(earliest_enterdate, by="patid") %>%
  mutate(enterdate_datediff=datediff(earliest_enterdate, diagnosis_date)) %>%
  select(-earliest_enterdate) %>%
  analysis$cached("cohort_interim_4", unique_indexes="patid")

cohort %>% count()
#294,019


# Set diagnosis date to missing where within -30 to +90 days of registration start
## Keep age at diagnosis

cohort <- cohort %>%
  mutate(diagnosis_date=if_else(datediff(diagnosis_date, regstartdate)< -30 | datediff(diagnosis_date, regstartdate)>90, diagnosis_date, as.Date(NA))) %>%
  analysis$cached("cohort_interim_5", unique_indexes="patid")

cohort %>% count()
#294,019


############################################################################################

# Add in biomarkers

## Don't set any limit on how far back to go - will remove those before diagnosis

# Clean biomarkers:
## Only keep those within acceptable value limits
## Only keep those with valid unit codes (numunitid)
## If multiple values on the same day, take mean
## Remove those with invalid dates (before DOB or after LCD/death/deregistration)

# Find baseline values
## Use closest date to index date as long as prior to this


biomarkers <- c("bmi", "hdl", "triglyceride", "totalcholesterol", "hba1c")


# Pull out all raw biomarker values and cache

analysis = cprd$analysis("all_patid")

for (i in biomarkers) {
  
  print(i)
  
  raw_tablename <- paste0("raw_", i, "_medcodes")
  
  data <- cprd$tables$observation %>%
    inner_join(codes[[i]], by="medcodeid") %>%
    analysis$cached(raw_tablename, indexes=c("patid", "obsdate", "testvalue", "numunitid"))
  
  assign(raw_tablename, data)
  
}


# Clean biomarkers:
## Only keep those within acceptable value limits
## Only keep those with valid unit codes (numunitid)
## If multiple values on the same day, take mean
## Remove those with invalid dates (before min DOB or after LCD/death/deregistration)

## HbA1c only: remove before 1990, and convert all values to mmol/mol

analysis = cprd$analysis("all_patid")

for (i in biomarkers) {
  
  print(i)
  
  raw_tablename <- paste0("raw_", i, "_medcodes")
  clean_tablename <- paste0("clean_", i, "_medcodes")
  
  data <- get(raw_tablename)
  
  if (i=="hba1c") {
    
    data <- data %>%
      filter(year(obsdate)>=1990) %>%
      mutate(testvalue=ifelse(testvalue<=20, ((testvalue-2.152)/0.09148), testvalue))
        
  }
    
  data <- data %>%
    
    clean_biomarker_values(testvalue, i) %>%
    clean_biomarker_units(numunitid, i) %>%
    
    group_by(patid,obsdate) %>%
    summarise(testvalue=mean(testvalue, na.rm=TRUE)) %>%
    ungroup() %>%
    
    inner_join(cprd$tables$validDateLookup, by="patid") %>%
    filter(obsdate>=min_dob & obsdate<=gp_ons_end_date) %>%
    
    select(patid, date=obsdate, testvalue) %>%
    
    analysis$cached(clean_tablename, indexes=c("patid", "date", "testvalue"))
  
  assign(clean_tablename, data)
  
}


# For each biomarker, find baseline value at index date
## Use closest date to index date as long as prior to this - weight and height don't need to be on same day as height doesn't change

analysis = cprd$analysis("dpctn_final")


for (i in biomarkers) {
  
  print(i)
  
  clean_tablename <- paste0("clean_", i, "_medcodes")
  biomarker_date_variable <- paste0(i, "date")
  biomarker_indexdiff_variable <- paste0(i, "indexdiff")
  
  data <- get(clean_tablename) %>%
    mutate(indexdatediff=datediff(date, index_date)) %>%
    filter(indexdatediff<=0) %>%
    group_by(patid) %>%
    mutate(min_timediff=min(abs(indexdatediff), na.rm=TRUE)) %>%
    filter(abs(indexdatediff)==min_timediff) %>%
    ungroup() %>%
    select(patid, testvalue, date, indexdatediff) %>%
    rename({{i}}:=testvalue,
           {{biomarker_date_variable}}:=date,
           {{biomarker_indexdiff_variable}}:=indexdatediff)
  
  cohort <- cohort %>%
    left_join(data, by="patid")
  
}

cohort <- cohort %>% analysis$cached("cohort_interim_6", unique_indexes="patid")


############################################################################################

# Add in GAD and IA2 antibodies

analysis = cprd$analysis("all_patid")

# GAD
raw_gad <- cprd$tables$observation %>%
  inner_join(codes$gad, by="medcodeid") %>%
  analysis$cached("raw_gad", indexes=c("patid", "obsdate", "testvalue", "numunitid"))
#n=3,993

# IA2
raw_ia2 <- cprd$tables$observation %>%
  inner_join(codes$ia2, by="medcodeid") %>%
  analysis$cached("raw_ia2", indexes=c("patid", "obsdate", "testvalue", "numunitid"))
#n=35


# Assume those with missing units are in U/mL
## GAD: majority are missing (2,280), then rest are U/mL / kU/L (equivalent) / 'units'; 1 with mu/L and 1 with n/ml - exclude
## IA2: 3 with missing, 25 U/mL, 6 kU/L, 1 U/L - value is 0 anyway but also exclude
## Use >=11 U/mL as positive for GAD; >=7.5 U/mL for IA2 as per: https://www.exeterlaboratory.com/

# Assume 0 values are 0, not missing

analysis = cprd$analysis("dpctn_final")

### GAD

gad <- raw_gad %>%
  filter(obsdate<=index_date & (is.na(numunitid) | (numunitid!=229 & numunitid!=11589))) %>%
  mutate(result=ifelse(!is.na(testvalue) & testvalue<11, "negative",
                    ifelse(!is.na(testvalue) & testvalue>=11, "positive", NA))) %>%
  filter(!is.na(result)) %>%
  distinct(patid, obsdate, result)

earliest_gad <- gad %>%
  group_by(patid, result) %>%
  mutate(earliest_gad=min(obsdate, na.rm=TRUE)) %>%
  filter(obsdate==earliest_gad) %>%
  ungroup() %>%
  pivot_wider(id_cols="patid", names_from=result, values_from=obsdate)

latest_gad <- gad %>%
  group_by(patid, result) %>%
  mutate(latest_gad=max(obsdate, na.rm=TRUE)) %>%
  filter(obsdate==latest_gad) %>%
  ungroup() %>%
  pivot_wider(id_cols="patid", names_from=result, values_from=obsdate)

gad <- earliest_gad %>%
  rename(earliest_negative_gad=negative, earliest_positive_gad=positive) %>%
  left_join((latest_gad %>% rename(latest_negative_gad=negative, latest_positive_gad=positive)), by="patid") %>%
  select(patid, earliest_negative_gad, latest_negative_gad, earliest_positive_gad, latest_positive_gad) %>%
  analysis$cached("gad", unique_indexes="patid")


### IA2

ia2 <- raw_ia2 %>%
  filter(obsdate<=index_date & (is.na(numunitid) | numunitid!=276)) %>%
  mutate(result=ifelse(!is.na(testvalue) & testvalue<11, "negative",
                       ifelse(!is.na(testvalue) & testvalue>=11, "positive", NA))) %>%
  filter(!is.na(result)) %>%
  distinct(patid, obsdate, result)

earliest_ia2 <- ia2 %>%
  group_by(patid, result) %>%
  mutate(earliest_ia2=min(obsdate, na.rm=TRUE)) %>%
  filter(obsdate==earliest_ia2) %>%
  ungroup() %>%
  pivot_wider(id_cols="patid", names_from=result, values_from=obsdate)

latest_ia2 <- ia2 %>%
  group_by(patid, result) %>%
  mutate(latest_ia2=max(obsdate, na.rm=TRUE)) %>%
  filter(obsdate==latest_ia2) %>%
  ungroup() %>%
  pivot_wider(id_cols="patid", names_from=result, values_from=obsdate)

ia2 <- earliest_ia2 %>%
  rename(earliest_negative_ia2=negative, earliest_positive_ia2=positive) %>%
  left_join((latest_ia2 %>% rename(latest_negative_ia2=negative, latest_positive_ia2=positive)), by="patid") %>%
  select(patid, earliest_negative_ia2, latest_negative_ia2, earliest_positive_ia2, latest_positive_ia2) %>%
  analysis$cached("ia2", unique_indexes="patid")


cohort <- cohort %>%
  left_join(gad, by="patid") %>%
  left_join(ia2, by="patid") %>%
  analysis$cached("cohort_interim_7", unique_indexes="patid")


############################################################################################

# Add in C-peptide

analysis = cprd$analysis("all_patid")

raw_c_peptide <- cprd$tables$observation %>%
  inner_join(codes$c_peptide, by="medcodeid") %>%
  analysis$cached("raw_c_peptide", indexes=c("patid", "obsdate", "testvalue", "numunitid"))

raw_c_peptide %>% count()
#5,144 only


# Look at units

raw_c_peptide %>% filter(c_peptide_cat=="ucpcr") %>% group_by(numunitid) %>% summarise(count=n())
## 433 are 899 (nmol/mmol), 52 are missing, 25 are 2434 (nM/mM crea), 6 are 959 (umol/mol)
### All the same unit (nmol/mmol)

raw_c_peptide %>% filter(c_peptide_cat=="blood") %>% group_by(numunitid) %>% summarise(count=n())
## 2685 are 256 (pmol/L), 1533 are missing, 290 are 235 (nmol/L), 80 are 283 (ug/L), 32 are 899 (nmol/mmol), 1 of each of 218 (mmol/L), 229 (mu/L), 2339 (pm/L)
### Convert 235 to pmol/L (divide by 1000)
### Convert 218 to pmol/L (divide by 10^6)
### Exclude 283, 899, 229


# Clean and define insulin status
## Use thresholds of <0.2 and >=0.6 (UCPCR) / <200 and >=600 (blood) to define insulin status (https://www.exeterlaboratory.com/test/c-peptide-urine/)
### No indication as to whether blood samples are fasted or not so assume not
## Assume 0 values are 0, not missing

analysis = cprd$analysis("dpctn_final")

processed_c_peptide <- raw_c_peptide %>%
  filter(obsdate<=index_date & !is.na(testvalue) & numunitid!=283 & numunitid!=229 & !(numunitid==899 & c_peptide_cat=="blood")) %>%
  mutate(new_testvalue=ifelse(numunitid==235, testvalue/1000,
                              ifelse(numunitid==218, testvalue/1000000, testvalue))) %>%
  mutate(c_pep_insulin=ifelse(c_peptide_cat=="ucpcr" & new_testvalue<0.2, "c_pep_ins_deficient",
                              ifelse(c_peptide_cat=="ucpcr" & new_testvalue>=0.2 & testvalue<0.6, "c_pep_ins_intermediate",
                                     ifelse(c_peptide_cat=="ucpcr" & new_testvalue>=0.6, "c_pep_ins_normal",
                                            ifelse(c_peptide_cat=="blood" & new_testvalue<200, "c_pep_ins_deficient",
                                                   ifelse(c_peptide_cat=="blood" & new_testvalue>=200 & testvalue<600, "c_pep_ins_intermediate",
                                                          ifelse(c_peptide_cat=="blood" & new_testvalue>=600, "c_pep_ins_normal", NA))))))) %>%
  select(patid, date=obsdate, testvalue=new_testvalue, c_pep_cat=c_peptide_cat, c_pep_insulin) %>%
  distinct() %>%
  analysis$cached("processed_c_peptide", indexes=c("patid", "date", "c_pep_insulin"))


# Add earliest and latest result for each category to table

earliest_c_pep <- processed_c_peptide %>%
  group_by(patid, c_pep_insulin) %>%
  mutate(earliest=min(date, na.rm=TRUE)) %>%
  filter(date==earliest) %>%
  ungroup() %>%
  pivot_wider(id_cols="patid", names_from=c_pep_insulin, values_from=date)

latest_c_pep <- processed_c_peptide %>%
  group_by(patid, c_pep_insulin) %>%
  mutate(latest=max(date, na.rm=TRUE)) %>%
  filter(date==latest) %>%
  ungroup() %>%
  pivot_wider(id_cols="patid", names_from=c_pep_insulin, values_from=date)

c_pep <- earliest_c_pep %>%
  rename(earliest_c_pep_ins_deficient=c_pep_ins_deficient, earliest_c_pep_ins_intermediate=c_pep_ins_intermediate, earliest_c_pep_ins_normal=c_pep_ins_normal) %>%
  left_join((latest_c_pep %>% rename(latest_c_pep_ins_deficient=c_pep_ins_deficient, latest_c_pep_ins_intermediate=c_pep_ins_intermediate, latest_c_pep_ins_normal=c_pep_ins_normal)), by="patid") %>%
  select(patid, earliest_c_pep_ins_deficient, latest_c_pep_ins_deficient, earliest_c_pep_ins_intermediate, latest_c_pep_ins_intermediate, earliest_c_pep_ins_normal, latest_c_pep_ins_normal) %>%
  analysis$cached("c_pep", unique_indexes="patid")


cohort <- cohort %>%
  left_join(c_pep, by="patid") %>%
  analysis$cached("cohort_interim_8", unique_indexes="patid")


############################################################################################

# Add in current treatment (last 6 months)

# Get clean OHA and insulin scripts

analysis = cprd$analysis("all_patid")

## All OHA scripts
clean_oha <- cprd$tables$drugIssue %>%
  inner_join(cprd$tables$ohaLookup, by="prodcodeid") %>%
  inner_join(cprd$tables$validDateLookup, by="patid") %>%
  filter(issuedate>=min_dob & issuedate<=gp_ons_end_date) %>%
  select(patid, date=issuedate, dosageid, quantity, quantunitid, duration, INS, TZD, SU, DPP4, MFN, GLP1, Glinide, Acarbose, SGLT2) %>%
  analysis$cached("clean_oha_prodcodes", indexes=c("patid", "date", "INS", "TZD", "SU", "DPP4", "MFN", "GLP1", "Glinide", "Acarbose", "SGLT2"))

## All insulin scripts
clean_insulin <- cprd$tables$drugIssue %>%
  inner_join(codes$insulin, by="prodcodeid") %>%
  inner_join(cprd$tables$validDateLookup, by="patid") %>%
  filter(issuedate>=min_dob & issuedate<=gp_ons_end_date) %>%
  select(patid, date=issuedate, dosageid, quantity, quantunitid, duration) %>%
  analysis$cached("clean_insulin_prodcodes", indexes=c("patid", "date"))


analysis = cprd$analysis("dpctn_final")


# OHA

current_oha <- clean_oha %>%
  filter(date<=index_date & datediff(index_date, date)<=183) %>%
  distinct(patid) %>%
  mutate(current_oha=1L) %>%
  analysis$cached("current_oha", unique_indexes="patid")


# DPP4/SU/TZD and GLP1 and SGLT2
  
current_dpp4sutzd <- clean_oha %>%
  filter(date<=index_date & datediff(index_date, date)<=183 & (TZD==1 | SU==1 | DPP4==1)) %>%
  distinct(patid) %>%
  mutate(current_dpp4sutzd=1L) %>%
  analysis$cached("current_dpp4sutzd", unique_indexes="patid")

current_glp1 <- clean_oha %>%
  filter(date<=index_date & datediff(index_date, date)<=183 & GLP1==1) %>%
  distinct(patid) %>%
  mutate(current_glp1=1L) %>%
  analysis$cached("current_glp1", unique_indexes="patid")

current_sglt2 <- clean_oha %>%
  filter(date<=index_date & datediff(index_date, date)<=183 & SGLT2==1) %>%
  distinct(patid) %>%
  mutate(current_sglt2=1L) %>%
  analysis$cached("current_sglt2", unique_indexes="patid")


# Insulin

current_insulin <- clean_insulin %>%
  filter(date<=index_date & datediff(index_date, date)<=183) %>%
  distinct(patid) %>%
  mutate(current_insulin=1L) %>%
  analysis$cached("current_insulin", unique_indexes="patid")

current_insulin_12m <- clean_insulin %>%
  filter(date<=index_date & datediff(index_date, date)<=366) %>%
  distinct(patid) %>%
  mutate(current_insulin_12m=1L) %>%
  analysis$cached("current_insulin_12m", unique_indexes="patid")


# Bolus/mix insulin

current_bolusmix_insulin <- clean_insulin %>%
  filter(date<=index_date & datediff(index_date, date)<=183 & (insulin_cat=="Bolus insulin" | insulin_cat=="Mix insulin")) %>%
  distinct(patid) %>%
  mutate(current_bolusmix_insulin=1L) %>%
  analysis$cached("current_bolusmix_insulin", unique_indexes="patid")


cohort <- cohort %>%
  left_join(current_oha, by="patid") %>%
  left_join(current_dpp4sutzd, by="patid") %>%
  left_join(current_glp1, by="patid") %>%
  left_join(current_sglt2, by="patid") %>%
  left_join(current_insulin, by="patid") %>%
  left_join(current_insulin_12m, by="patid") %>%
  left_join(current_bolusmix_insulin, by="patid") %>%
  mutate(across(c("current_oha", "current_dpp4sutzd", "current_dpp4sutzd", "current_glp1", "current_sglt2", "current_insulin", "current_insulin_12m", "current_bolusmix_insulin"), coalesce, 0L)) %>%
  analysis$cached("cohort_interim_9", unique_indexes="patid")


############################################################################################

# Add in family history of diabetes (cleaned: includes 99% of raw occurrences so no difference)

# For people with positive and negative codes:
## If all negative codes are earlier than positive codes, fine - use positive
## Otherwise, treat as missing

analysis = cprd$analysis("all_patid")

## Raw FH of diabetes
raw_fh_diabetes_medcodes <- cprd$tables$observation %>%
  inner_join(codes$fh_diabetes, by="medcodeid") %>%
  analysis$cached("raw_fh_diabetes_medcodes", indexes=c("patid", "obsdate"))

## Clean FH of diabetes
clean_fh_diabetes_medcodes <- raw_fh_diabetes %>%
  inner_join(cprd$tables$validDateLookup, by="patid") %>%
  filter(obsdate>=min_dob & obsdate<=gp_ons_end_date) %>%
  select(patid, date=obsdate, fh_diabetes_cat) %>%
  analysis$cached("clean_fh_diabetes_medcodes", indexes=c("patid", "date"))


analysis = cprd$analysis("dpctn_final")

fh_code_types <- clean_fh_diabetes_medcodes %>%
  filter(fh_diabetes_cat!="positive - sibling" & fh_diabetes_cat!="positive - child" & fh_diabetes_cat!="positive - gestational" & date<=index_date) %>%
  mutate(fh_diabetes_cat=ifelse(fh_diabetes_cat=="negative", "negative", "positive")) %>%
  group_by(patid, fh_diabetes_cat) %>%
  summarise(earliest_date=min(date, na.rm=TRUE),
            latest_date=max(date, na.rm=TRUE)) %>%
  ungroup() %>%
  group_by(patid) %>%
  pivot_wider(id_cols=patid, names_from = c(fh_diabetes_cat), names_glue = "{fh_diabetes_cat}_{.value}", values_from=c(earliest_date, latest_date)) %>%
  ungroup() %>%
  analysis$cached("fh_code_types", unique_indexes="patid")

final_fh <- fh_code_types %>%
  mutate(fh_diabetes=ifelse(is.na(positive_earliest_date), 0L,
                            ifelse(is.na(negative_earliest_date), 1L,
                                   ifelse(!is.na(positive_earliest_date) & !is.na(negative_earliest_date) & negative_latest_date<positive_earliest_date, 1L, NA)))) %>%
  analysis$cached("final_fh", unique_indexes="patid")

cohort <- cohort %>%
  left_join((final_fh %>% select(patid, fh_diabetes)), by="patid") %>%
  analysis$cached("cohort_interim_10", unique_indexes="patid")


############################################################################################

# Add in whether non-English speaking or English not first language
## If have codes for both, assume non-English speaking

analysis = cprd$analysis("all_patid")

## Raw language codes
raw_language_medcodes <- cprd$tables$observation %>%
  inner_join(codes$language, by="medcodeid") %>%
  analysis$cached("raw_language_medcodes", indexes=c("patid", "obsdate"))

## Clean language codes
clean_language_medcodes <- raw_language_medcodes %>%
  inner_join(cprd$tables$validDateLookup, by="patid") %>%
  filter(obsdate>=min_dob & obsdate<=gp_ons_end_date) %>%
  select(patid, date=obsdate, language_cat) %>%
  analysis$cached("clean_language_medcodes", indexes=c("patid", "date"))


analysis = cprd$analysis("dpctn_final")

non_english <- clean_language_medcodes %>%
  filter(language_cat=="Non-English speaking") %>%
  distinct(patid) %>%
  mutate(non_english=1L)

english_not_first <- clean_language_medcodes %>%
  filter(language_cat=="First Language Not English") %>%
  distinct(patid) %>%
  mutate(english_not_first=1L)

cohort <- cohort %>%
  left_join(non_english, by="patid") %>%
  left_join(english_not_first, by="patid") %>%
  mutate(language=ifelse(!is.na(non_english) & non_english==1, "Non-English speaking",
                         ifelse(!is.na(english_not_first) & english_not_first==1, "First language not English", NA))) %>%
  select(-c(non_english, english_not_first)) %>%
  analysis$cached("cohort_interim_11", unique_indexes="patid")


cohort %>% count()
#294019

cohort %>% filter(diabetes_type=="type 1" | diabetes_type=="type 2" | diabetes_type=="mixed; type 1" | diabetes_type=="mixed; type 2") %>% count()
#241331

cohort %>% filter((diabetes_type=="type 1" | diabetes_type=="type 2" | diabetes_type=="mixed; type 1" | diabetes_type=="mixed; type 2") & !is.na(language) & language=="Non-English speaking") %>% count()
#8872
8872/241331 #3.7%


cohort %>% filter((diabetes_type=="type 1" | diabetes_type=="type 2" | diabetes_type=="mixed; type 1" | diabetes_type=="mixed; type 2") & !is.na(language) & language=="First language not English") %>% count()
#25623
25623/241331 #10.6%


############################################################################################

# Add earliest insulin and OHA

## Earliest insulin per patient

earliest_insulin <- clean_insulin %>%
  group_by(patid) %>%
  summarise(earliest_ins=min(date, na.rm=TRUE)) %>%
  ungroup() %>%
  analysis$cached("earliest_insulin", unique_indexes="patid")


## Earliest OHA per patient

earliest_oha <- clean_oha %>%
  group_by(patid) %>%
  summarise(earliest_oha=min(date, na.rm=TRUE)) %>%
  ungroup() %>%
  analysis$cached("earliest_oha", unique_indexes="patid")


## Combine

cohort <- cohort %>%
  left_join(earliest_insulin, by="patid") %>%
  left_join(earliest_oha, by="patid") %>%
  analysis$cached("cohort", unique_indexes="patid")


############################################################################################

# Look at diabetes type counts

counts <- cohort %>% group_by(diabetes_type) %>% count() %>% collect()

counts2 <- cohort %>% filter(mody_code_count>0) %>% group_by(diabetes_type) %>% count() %>% collect()

