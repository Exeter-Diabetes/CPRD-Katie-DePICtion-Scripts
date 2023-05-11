
# Calculate diagnosis dates for everyone in prevalent cohort, and use to find time to insulin

############################################################################################

# Setup
library(tidyverse)
library(aurum)
library(EHRBiomarkr)
rm(list=ls())

cprd = CPRDData$new(cprdEnv = "test-remote",cprdConf = "~/.aurum.yaml")
codesets = cprd$codesets()
codes = codesets$getAllCodeSetVersion(v = "31/10/2021")

analysis = cprd$analysis("dpctn_prevalent")


############################################################################################

# Get cohort info 
cohort <- cohort %>% analysis$cached("cohort")

############################################################################################

# ## First do with raw (i.e. not cleaned) data - except if missing date
# Find diagnosis dates: earliest of diabetes medcode (including exclusion types for now - will want to remove gestational (and others?) eventually), high HbA1c, prescription
## Want to know what earliest code/script is - have to concatenate if >1 row

## Might eventually want to restrict to subset of diabetes codes???

analysis = cprd$analysis("all_patid")

raw_diabetes_medcodes <- cprd$tables$observation %>%
  inner_join(codes$all_diabetes, by="medcodeid") %>%
  analysis$cached("raw_diabetes_medcodes", indexes=c("patid", "obsdate", "all_diabetes_cat"))

raw_exclusion_diabetes_medcodes <- cprd$tables$observation %>%
  inner_join(codes$exclusion_diabetes, by="medcodeid") %>%
  analysis$cached("raw_exclusion_diabetes_medcodes", indexes=c("patid", "obsdate", "exclusion_diabetes_cat"))

raw_hba1c_medcodes <- cprd$tables$observation %>%
  inner_join(codes$hba1c, by="medcodeid") %>%
  analysis$cached("raw_hba1c_medcodes", indexes=c("patid", "obsdate", "testvalue", "numunitid"))

raw_oha_prodcodes <- cprd$tables$drugIssue %>%
  inner_join(cprd$tables$ohaLookup, by="prodcodeid") %>%
  analysis$cached("raw_oha_prodcodes", indexes=c("patid", "issuedate", "INS", "TZD", "SU", "DPP4", "MFN", "GLP1", "Glinide", "Acarbose", "SGLT2"))

raw_insulin_prodcodes <- cprd$tables$drugIssue %>%
  inner_join(codes$insulin, by="prodcodeid") %>%
  analysis$cached("raw_insulin_prodcodes", indexes=c("patid", "issuedate", "insulin_cat"))



analysis = cprd$analysis("dpctn_prevalent")

earliest_raw_nonexcl_dm_code <- raw_diabetes_medcodes %>%
  group_by(patid) %>%
  mutate(earliest_raw_nonexcl_dm_code=min(obsdate, na.rm=TRUE)) %>%
  ungroup() %>%
  filter(obsdate==earliest_raw_nonexcl_dm_code) %>%
  select(patid, earliest_raw_nonexcl_dm_code, medcodeid) %>%
  left_join(cprd$tables$medDict, by="medcodeid") %>%
  group_by(patid, earliest_raw_nonexcl_dm_code) %>%
  summarise(earliest_raw_nonexcl_dm_code_term=sql("group_concat(distinct term order by term separator ' & ')")) %>%
  ungroup() %>%
  analysis$cached("earliest_raw_nonexcl_dm_code", unique_index="patid")

earliest_raw_excl_dm_code <- raw_exclusion_diabetes_medcodes %>%
  group_by(patid) %>%
  mutate(earliest_raw_excl_dm_code=min(obsdate, na.rm=TRUE)) %>%
  ungroup() %>%
  filter(obsdate==earliest_raw_excl_dm_code) %>%
  select(patid, earliest_raw_excl_dm_code, medcodeid) %>%
  left_join(cprd$tables$medDict, by="medcodeid") %>%
  group_by(patid, earliest_raw_excl_dm_code) %>%
  summarise(earliest_raw_excl_dm_code_term=sql("group_concat(distinct term order by term separator ' & ')")) %>%
  ungroup() %>%
  analysis$cached("earliest_raw_excl_dm_code", unique_index="patid")

earliest_raw_high_hba1c <- raw_hba1c_medcodes %>%
  filter((testvalue<=20 & testvalue>=6.5) | testvalue>=48) %>%
  group_by(patid) %>%
  mutate(earliest_raw_high_hba1c=min(obsdate, na.rm=TRUE)) %>%
  ungroup() %>%
  filter(obsdate==earliest_raw_high_hba1c) %>%
  select(patid, earliest_raw_high_hba1c, testvalue) %>%
  group_by(patid, earliest_raw_high_hba1c) %>%
  summarise(earliest_raw_high_hba1c_value=sql("group_concat(distinct testvalue order by testvalue separator ' & ')")) %>%
  ungroup() %>%
  analysis$cached("earliest_raw_high_hba1c", unique_index="patid")

earliest_raw_oha_prodcode <- raw_oha_prodcodes %>%
  group_by(patid) %>%
  mutate(earliest_raw_oha_prodcode=min(issuedate, na.rm=TRUE)) %>%
  ungroup() %>%
  filter(issuedate==earliest_raw_oha_prodcode) %>%
  analysis$cached("earliest_raw_oha_prodcode_interim_1", indexes="patid")

earliest_raw_oha_prodcode <- earliest_raw_oha_prodcode %>%
  pivot_longer(cols=c(Acarbose, DPP4, Glinide, GLP1, MFN, SGLT2, SU, TZD, INS), names_to="drugclass", values_to="drugclassval") %>%
  filter(drugclassval==1) %>%
  pivot_longer(cols=starts_with("drug_substance"), names_to="whichdrugsubstance", values_to="drugsubstance") %>%
  filter(!is.na(drugsubstance)) %>%
  group_by(patid, earliest_raw_oha_prodcode) %>%
  summarise(earliest_raw_oha_prodcode_drugclass=sql("group_concat(distinct drugclass order by drugclass separator ' & ')"),
            earliest_raw_oha_prodcode_drugsubstance=sql("group_concat(distinct drugsubstance order by drugsubstance separator ' & ')")) %>%
  ungroup() %>%
  analysis$cached("earliest_raw_oha_prodcode", unique_index="patid")


earliest_raw_insulin_prodcode <- raw_insulin_prodcodes %>%
  group_by(patid) %>%
  mutate(earliest_raw_insulin_prodcode=min(issuedate, na.rm=TRUE)) %>%
  ungroup() %>%
  filter(issuedate==earliest_raw_insulin_prodcode) %>%
  select(patid, earliest_raw_insulin_prodcode, insulin_cat) %>%
  group_by(patid, earliest_raw_insulin_prodcode) %>%
  summarise(earliest_raw_insulin_prodcode_cat=sql("group_concat(distinct insulin_cat order by insulin_cat separator ' & ')")) %>%
  ungroup() %>%
  analysis$cached("earliest_raw_insulin_prodcode", unique_index="patid")


cohort <- cohort %>%
  left_join(earliest_raw_nonexcl_dm_code, by="patid") %>%
  left_join(earliest_raw_excl_dm_code, by="patid") %>%
  left_join(earliest_raw_high_hba1c, by="patid") %>%
  left_join(earliest_raw_oha_prodcode, by="patid") %>%
  left_join(earliest_raw_insulin_prodcode, by="patid") %>%
  mutate(raw_diagnosis_date=pmin(ifelse(is.na(earliest_raw_nonexcl_dm_code), as.Date("2050-01-01"), earliest_raw_nonexcl_dm_code),
                                 ifelse(is.na(earliest_raw_excl_dm_code), as.Date("2050-01-01"), earliest_raw_excl_dm_code),
                                 ifelse(is.na(earliest_raw_high_hba1c), as.Date("2050-01-01"), earliest_raw_high_hba1c),
                                 ifelse(is.na(earliest_raw_oha_prodcode), as.Date("2050-01-01"), earliest_raw_oha_prodcode),
                                 ifelse(is.na(earliest_raw_insulin_prodcode), as.Date("2050-01-01"), earliest_raw_insulin_prodcode), na.rm=TRUE),
         
         raw_dm_diag_codetype=ifelse(!is.na(earliest_raw_nonexcl_dm_code) & raw_diagnosis_date==earliest_raw_nonexcl_dm_code, "dm_code",
                                     ifelse(!is.na(earliest_raw_excl_dm_code) & raw_diagnosis_date==earliest_raw_excl_dm_code, "excl_dm_code",
                                            ifelse(!is.na(earliest_raw_high_hba1c) & raw_diagnosis_date==earliest_raw_high_hba1c, "high_hba1c",
                                                   ifelse(!is.na(earliest_raw_oha_prodcode) & raw_diagnosis_date==earliest_raw_oha_prodcode, "oha_script", "insulin_script")))),
         
         raw_age_at_diagnosis=datediff(raw_diagnosis_date, dob)/365.25,
         
         raw_time_to_insulin_yrs=ifelse(!is.na(earliest_raw_insulin_prodcode), datediff(earliest_raw_insulin_prodcode, raw_diagnosis_date)/365.25, NA)) %>%
  
  analysis$cached("cohort_raw_diag_dates", unique_index="patid")
  
                                              
############################################################################################

## Then apply our cleaning rules
# Find diagnosis dates: earliest of diabetes medcode (including exclusion types for now - will want to remove gestational (and others?) eventually), high HbA1c, prescription

analysis = cprd$analysis("all_patid")

clean_diabetes_medcodes <- raw_diabetes_medcodes %>%
  inner_join(cprd$tables$validDateLookup, by="patid") %>%
  filter(obsdate>=min_dob & obsdate<=gp_ons_end_date) %>%
  analysis$cached("clean_diabetes_medcodes", indexes=c("patid", "obsdate", "all_diabetes_cat"))

clean_exclusion_diabetes_medcodes <- raw_exclusion_diabetes_medcodes %>%
  inner_join(cprd$tables$validDateLookup, by="patid") %>%
  filter(obsdate>=min_dob & obsdate<=gp_ons_end_date) %>%
  analysis$cached("clean_exclusion_diabetes_medcodes", indexes=c("patid", "obsdate", "exclusion_diabetes_cat"))

clean_hba1c_medcodes <- raw_hba1c_medcodes %>%
  filter(year(obsdate)>=1990) %>%
  mutate(testvalue=ifelse(testvalue<=20, ((testvalue-2.152)/0.09148), testvalue)) %>%
  clean_biomarker_units(testvalue, "hba1c") %>%
  clean_biomarker_values(numunitid, "hba1c") %>%
  group_by(patid, obsdate) %>%
  summarise(testvalue=mean(testvalue, na.rm=TRUE)) %>%
  ungroup() %>%
  inner_join(cprd$tables$validDateLookup, by="patid") %>%
  filter(obsdate>=min_dob & obsdate<=gp_ons_end_date) %>%
  select(patid, date=obsdate, testvalue) %>%
  analysis$cached("clean_hba1c_medcodes", indexes=c("patid", "date", "testvalue"))

clean_oha_prodcodes <- raw_oha_prodcodes %>%
  inner_join(cprd$tables$validDateLookup, by="patid") %>%
  filter(issuedate>=min_dob & issuedate<=gp_ons_end_date) %>%
  select(patid, date=issuedate, dosageid, quantity, quantunitid, duration, INS, TZD, SU, DPP4, MFN, GLP1, Glinide, Acarbose, SGLT2) %>%
  analysis$cached("clean_oha_prodcodes", indexes=c("patid", "date", "INS", "TZD", "SU", "DPP4", "MFN", "GLP1", "Glinide", "Acarbose", "SGLT2"))

clean_insulin_prodcodes <- raw_insulin_prodcodes %>%
    inner_join(cprd$tables$validDateLookup, by="patid") %>%
    filter(issuedate>=min_dob & issuedate<=gp_ons_end_date) %>%
    select(patid, date=issuedate, dosageid, quantity, quantunitid, duration) %>%
    analysis$cached("clean_insulin_prodcodes", indexes=c("patid", "date"))


analysis = cprd$analysis("dpctn_prevalent")

earliest_clean_nonexcl_dm_code <- clean_diabetes_medcodes %>%
  group_by(patid) %>%
  mutate(earliest_clean_nonexcl_dm_code=min(obsdate, na.rm=TRUE)) %>%
  ungroup() %>%
  filter(obsdate==earliest_clean_nonexcl_dm_code) %>%
  select(patid, earliest_clean_nonexcl_dm_code, medcodeid) %>%
  left_join(cprd$tables$medDict, by="medcodeid") %>%
  group_by(patid, earliest_clean_nonexcl_dm_code) %>%
  summarise(earliest_clean_nonexcl_dm_code_term=sql("group_concat(distinct term order by term separator ' & ')")) %>%
  ungroup() %>%
  analysis$cached("earliest_clean_nonexcl_dm_code", unique_index="patid")

earliest_clean_excl_dm_code <- clean_exclusion_diabetes_medcodes %>%
  group_by(patid) %>%
  mutate(earliest_clean_excl_dm_code=min(obsdate, na.rm=TRUE)) %>%
  ungroup() %>%
  filter(obsdate==earliest_clean_excl_dm_code) %>%
  select(patid, earliest_clean_excl_dm_code, medcodeid) %>%
  left_join(cprd$tables$medDict, by="medcodeid") %>%
  group_by(patid, earliest_clean_excl_dm_code) %>%
  summarise(earliest_clean_excl_dm_code_term=sql("group_concat(distinct term order by term separator ' & ')")) %>%
  ungroup() %>%
  analysis$cached("earliest_clean_excl_dm_code", unique_index="patid")

earliest_clean_high_hba1c <- clean_hba1c_medcodes %>%
  filter(testvalue>=48) %>%
  group_by(patid) %>%
  mutate(earliest_clean_high_hba1c=min(date, na.rm=TRUE)) %>%
  ungroup() %>%
  filter(date==earliest_clean_high_hba1c) %>%
  select(patid, earliest_clean_high_hba1c, earliest_clean_high_hba1c_value=testvalue) %>%
  analysis$cached("earliest_clean_high_hba1c", unique_index="patid")


earliest_clean_oha_prodcode <- clean_oha_prodcodes %>%
  group_by(patid) %>%
  mutate(earliest_clean_oha_prodcode=min(date, na.rm=TRUE)) %>%
  ungroup() %>%
  filter(date==earliest_clean_oha_prodcode) %>%
  analysis$cached("earliest_clean_oha_prodcode_interim_1", indexes="patid")

earliest_clean_oha_prodcode <- earliest_clean_oha_prodcode %>%
  pivot_longer(cols=c(Acarbose, DPP4, Glinide, GLP1, MFN, SGLT2, SU, TZD, INS), names_to="drugclass", values_to="drugclassval") %>%
  filter(drugclassval==1) %>%
  pivot_longer(cols=starts_with("drug_substance"), names_to="whichdrugsubstance", values_to="drugsubstance") %>%
  group_by(patid, earliest_clean_oha_prodcode) %>%
  summarise(earliest_clean_oha_prodcode_drugclass=sql("group_concat(distinct drugclass order by drugclass separator ' & ')"),
            earliest_clean_oha_prodcode_drugsubstance=sql("group_concat(distinct drugsubstance order by drugsubstance separator ' & ')")) %>%
  ungroup() %>%
  analysis$cached("earliest_clean_oha_prodcode", unique_index="patid")


earliest_clean_insulin_prodcode <- clean_insulin_prodcodes %>%
  group_by(patid) %>%
  mutate(earliest_clean_insulin_prodcode=min(date, na.rm=TRUE)) %>%
  ungroup() %>%
  filter(date==earliest_clean_insulin_prodcode) %>%
  select(patid, earliest_clean_insulin_prodcode, insulin_cat) %>%
  group_by(patid, earliest_clean_insulin_prodcode) %>%
  summarise(earliest_clean_insulin_prodcode_cat=sql("group_concat(distinct insulin_cat order by insulin_cat separator ' & ')")) %>%
  ungroup() %>%
  analysis$cached("earliest_clean_insulin_prodcode", unique_index="patid")


cohort <- cohort %>%
  left_join(earliest_clean_nonexcl_dm_code, by="patid") %>%
  left_join(earliest_clean_excl_dm_code, by="patid") %>%
  left_join(earliest_clean_high_hba1c, by="patid") %>%
  left_join(earliest_clean_oha_prodcode, by="patid") %>%
  left_join(earliest_clean_insulin_prodcode, by="patid") %>%
  mutate(clean_diagnosis_date=pmin(ifelse(is.na(earliest_clean_nonexcl_dm_code), as.Date("2050-01-01"), earliest_clean_nonexcl_dm_code),
                                 ifelse(is.na(earliest_clean_excl_dm_code), as.Date("2050-01-01"), earliest_clean_excl_dm_code),
                                 ifelse(is.na(earliest_clean_high_hba1c), as.Date("2050-01-01"), earliest_clean_high_hba1c),
                                 ifelse(is.na(earliest_clean_oha_prodcode), as.Date("2050-01-01"), earliest_clean_oha_prodcode),
                                 ifelse(is.na(earliest_clean_insulin_prodcode), as.Date("2050-01-01"), earliest_clean_insulin_prodcode), na.rm=TRUE),
         
         clean_dm_diag_codetype=ifelse(!is.na(earliest_clean_nonexcl_dm_code) & clean_diagnosis_date==earliest_clean_nonexcl_dm_code, "dm_code",
                                     ifelse(!is.na(earliest_clean_excl_dm_code) & clean_diagnosis_date==earliest_clean_excl_dm_code, "excl_dm_code",
                                            ifelse(!is.na(earliest_clean_high_hba1c) & clean_diagnosis_date==earliest_clean_high_hba1c, "high_hba1c",
                                                   ifelse(!is.na(earliest_clean_oha_prodcode) & clean_diagnosis_date==earliest_clean_oha_prodcode, "oha_script", "insulin_script")))),
         
         clean_age_at_diagnosis=datediff(clean_diagnosis_date, dob)/365.25,
         
         clean_time_to_insulin_yrs=ifelse(!is.na(earliest_clean_insulin_prodcode), datediff(earliest_clean_insulin_prodcode, clean_diagnosis_date)/365.25, NA)) %>%
  
  analysis$cached("cohort_diag_dates", unique_index="patid")

