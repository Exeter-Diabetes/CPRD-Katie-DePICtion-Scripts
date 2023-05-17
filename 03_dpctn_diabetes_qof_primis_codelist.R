
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

# Get cohort info with classes

cohort_classification <- cohort_classification %>% analysis$cached("cohort_classification")

############################################################################################

# Look at number with QOF code with a valid date

analysis = cprd$analysis("all_patid")

raw_qof_diabetes_medcodes <- cprd$tables$observation %>%
  inner_join(codes$qof_diabetes, by="medcodeid") %>%
  analysis$cached("raw_qof_diabetes_medcodes", indexes=c("patid", "obsdate", "qof_diabetes_cat"))

analysis = cprd$analysis("dpctn")

with_qof <- raw_qof_diabetes_medcodes %>%
  inner_join(cprd$tables$validDateLookup, by="patid") %>%
  filter(obsdate>=min_dob & obsdate<=gp_ons_end_date) %>%
  distinct(patid)

cohort_with_qof <- cohort_classification %>%
  select(patid, class) %>%
  inner_join(with_qof, by="patid") %>%
  analysis$cached("cohort_with_qof", unique_indexes="patid", indexes="class")

counts <- collect(cohort_with_qof %>% group_by(class) %>% count())


############################################################################################

# Look at number with PRIMIS code

## Import PRIMIS codelist
setwd("C:/Users/ky279/OneDrive - University of Exeter/CPRD/2023/DePICtion/Scripts")
primis <- read_csv("primis-covid19-vacc-uptake-diab-v.1.5.3.csv", col_types=cols(.default=col_character()))
#545

## Merge with aurum Medical Dictionary
setwd("C:/Users/ky279/OneDrive - University of Exeter/CPRD/New dictionaries")
aurum <- read_delim("CPRDAurumMedical.txt", col_types=cols(.default=col_character()))


## Find which occur in medical dictionary
primis_aurum <- primis %>% inner_join(aurum, by=c("code"="SnomedCTConceptId"))
#1,415

primis_aurum %>% distinct(code) %>% count()
#458


## How many in the list that defines our cohort

dpctn_diabetes_list <- collect(codes$all_diabetes %>% union(codes$exclusion_diabetes))




primis %>% anti_join(diabetes_snomed, by=c("code"="SnomedCTConceptId"))
#364

diabetes_snomed %>% anti_join(primis, by=c("SnomedCTConceptId"="code"))
#450


