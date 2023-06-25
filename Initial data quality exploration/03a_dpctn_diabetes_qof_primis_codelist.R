
# Look at impact of restricting cohort to those with QOF code or PRIMIS code

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

# Get cohort info with classes
cohort_classification <- cohort_classification %>% analysis$cached("cohort_classification")

############################################################################################

# Look at number with QOF code with a valid date

analysis = cprd$analysis("all_patid")

raw_qof_diabetes_medcodes <- cprd$tables$observation %>%
  inner_join(codes$qof_diabetes, by="medcodeid") %>%
  analysis$cached("raw_qof_diabetes_medcodes", indexes=c("patid", "obsdate", "qof_diabetes_cat"))

analysis = cprd$analysis("dpctn")

latest_qof <- raw_qof_diabetes_medcodes %>%
  inner_join(cprd$tables$validDateLookup, by="patid") %>%
  filter(obsdate>=min_dob & obsdate<=index_date) %>%
  group_by(patid) %>%
  summarise(latest_qof=max(obsdate, na.rm=TRUE)) %>%
  ungroup()

cohort_with_qof <- cohort_classification %>%
  select(patid, class) %>%
  inner_join(latest_qof, by="patid") %>%
  analysis$cached("cohort_with_qof", unique_indexes="patid", indexes="class")

counts <- collect(cohort_with_qof %>% group_by(class) %>% count())

time_to_latest <- collect(cohort_with_qof %>%
  mutate(datediff_var=datediff(index_date, latest_qof))) %>%
  group_by(class) %>%
  summarise(median_time=median(datediff_var, na.rm=TRUE)) %>%
  ungroup()


############################################################################################

# Look at number with PRIMIS code

## Import PRIMIS codelist
setwd("C:/Users/ky279/OneDrive - University of Exeter/CPRD/2023/DePICtion/Scripts/PRIMIS codelist")
primis <- read_csv("primis-covid19-vacc-uptake-diab-v.1.5.3.csv", col_types=cols(.default=col_character()))
#545

## Merge with aurum Medical Dictionary
### Using old version: more recent versions contain more codes but no more diabetes codes are used in our dataset
setwd("C:/Users/ky279/OneDrive - University of Exeter/CPRD/CPRD_Aurum/Codelists and algorithms/Reference files/202005_Lookups_CPRDAurum")
aurum <- read_delim("202005_EMISMedicalDictionary.txt", col_types=cols(.default=col_character()))


## Find which occur in medical dictionary
primis_aurum <- primis %>% inner_join(aurum, by=c("code"="SnomedCTConceptId"))
#753

primis_aurum %>% distinct(code) %>% count()
#187


## How many in the list that defines our cohort

dpctn_diabetes_list <- collect(codes$all_diabetes %>% union((codes$exclusion_diabetes %>% filter(exclusion_diabetes_cat !="diabetes_insipidus"))))
#1,361

primis_aurum %>% inner_join(dpctn_diabetes_list, by=c("MedCodeId"="medcodeid")) %>% count()
#711

primis_aurum %>% anti_join(dpctn_diabetes_list, by=c("MedCodeId"="medcodeid")) %>% count()
#42

primis_extras <- primis_aurum %>% anti_join(dpctn_diabetes_list, by=c("MedCodeId"="medcodeid"))
# Most are infrequently used codes with ^ESCT Read codes, but also includes (some include diabetes mellitus in description in their codelist - 3, 11-16):

# 1 O/E - right eye clinically significant macular oedema 2BBm            
# 2 O/E - left eye clinically significant macular oedema  2BBn            
# 3 Loss of hypoglycaemic warning                         66AJ2           
# 4 Hypoglycaemic warning absent                          66AJ4           
# 5 Insulin autoimmune syndrome                           C10J            
# 6 Insulin autoimmune syndrome without complication      C10J0           
# 7 Achard - Thiers syndrome                              C152-1          
# 8 Leprechaunism                                         C1zy3           
# 9 Donohue's syndrome                                    C1zy3-1         
# 10 Mauriac's syndrome                                    EMISNQMA111     
# 11 Ballinger-Wallace syndrome                            ESCTDI21-1      
# 12 HHS - Hyperosmolar hyperglycaemic syndrome            ESCTDI23-1      
# 13 HHS - Hyperosmolar hyperglycemic syndrome             ESCTDI23-2      
# 14 Rogers syndrome                                       ESCTME15-1      
# 15 Herrmann syndrome                                     ESCTPH1-1       
# 16 Kimmelstiel - Wilson disease                          K01x1-1

# Can't really see if using these codes changes who is identified as wouldn't have included them in download

# But can see who is our cohort has them

primis_aurum <- primis_aurum %>% select(medcodeid=MedCodeId)

with_primis <- cprd$tables$observation %>%
  inner_join(primis_aurum, by="medcodeid", copy=TRUE) %>%
  filter(obsdate<=index_date) %>%
  analysis$cached("with_primis", indexes="patid")

with_primis_clean <- with_primis %>%
  inner_join(cprd$tables$validDateLookup, by="patid") %>%
  filter(obsdate>=min_dob) %>%
  analysis$cached("with_primis_clean", indexes="patid")

cohort_with_primis_clean <- cohort_classification %>%
  select(patid, class) %>%
  inner_join((with_primis_clean %>% distinct(patid)), by="patid") %>%
  analysis$cached("cohort_with_primis_clean", unique_indexes="patid", indexes="class")

counts <- collect(cohort_with_primis_clean %>% group_by(class) %>% count())


############################################################################################

# What are most common codes in unspecified group, in those with and without PRIMIS code?

cohort_clean_dm_indications <- cohort_clean_dm_indications %>% analysis$cached("cohort_clean_dm_indications")

unspecified_codes_all <- cohort_classification %>%
  select(patid, class) %>%
  filter(class=="unspecified") %>%
  inner_join(cohort_clean_dm_indications, by="patid") %>%
  distinct(patid, code, category) %>%
  group_by(code, category) %>%
  summarise(count=n()) %>%
  ungroup() %>%
  analysis$cached("unspecified_codes_all")

unspecified_codes_non_primis <- cohort_classification %>%
  select(patid, class) %>%
  filter(class=="unspecified") %>%
  anti_join((cohort_with_primis_clean %>% select(patid)), by="patid") %>%
  inner_join(cohort_clean_dm_indications, by="patid") %>%
  distinct(patid, code, category) %>%
  group_by(code, category) %>%
  summarise(count=n()) %>%
  ungroup() %>%
  analysis$cached("unspecified_codes_non_primis")

unspecified_codes_single <- cohort_classification %>%
  select(patid, class) %>%
  filter(class=="unspecified") %>%
  inner_join(cohort_clean_dm_indications, by="patid") %>%
  group_by(patid) %>%
  summarise(patid_count=n()) %>%
  ungroup() %>%
  filter(patid_count==1) %>%
  inner_join(cohort_clean_dm_indications, by="patid") %>%
  group_by(code, category) %>%
  summarise(count=n()) %>%
  ungroup() %>%
  analysis$cached("unspecified_codes_single")

unspecified_codes_single_non_primis <- cohort_classification %>%
  select(patid, class) %>%
  filter(class=="unspecified") %>%
  anti_join((cohort_with_primis_clean %>% select(patid)), by="patid") %>%
  inner_join(cohort_clean_dm_indications, by="patid") %>%
  group_by(patid) %>%
  summarise(patid_count=n()) %>%
  ungroup() %>%
  filter(patid_count==1) %>%
  inner_join(cohort_clean_dm_indications, by="patid") %>%
  group_by(code, category) %>%
  summarise(count=n()) %>%
  ungroup() %>%
  analysis$cached("unspecified_codes_single_non_primis")


cohort_classification %>%
  select(patid, class) %>%
  filter(class=="unspecified") %>%
  anti_join((cohort_with_primis_clean %>% select(patid)), by="patid") %>%
  inner_join(cohort_clean_dm_indications, by="patid") %>%
  group_by(patid) %>%
  summarise(patid_count=n()) %>%
  ungroup() %>%
  filter(patid_count==1) %>%
  count()


############################################################################################

# Remake classification table so includes whether unspecified has PRIMIS code or not

cohort_classification <- cohort_classification %>%
  left_join((with_primis_clean %>% distinct(patid) %>% mutate(with_primis=1L)), by="patid") %>%
  mutate(class=ifelse(class=="unspecified" & !is.na(with_primis) & with_primis==1, "unspecified_with_primis", class)) %>%
  select(-with_primis) %>%
  analysis$cached("cohort_classification_with_primis", unique_indexes="patid", indexes="class")


