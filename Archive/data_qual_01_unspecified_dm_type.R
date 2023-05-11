
# For prevalent cohort: identify those without any type-specific diabetes codes and look at characteristics to determine whether actually have diabetes or miscoded

############################################################################################

# Setup
library(tidyverse)
library(aurum)
library(EHRBiomarkr)
library(flextable)
rm(list=ls())

cprd = CPRDData$new(cprdEnv = "test-remote",cprdConf = "~/.aurum.yaml")
codesets = cprd$codesets()
codes = codesets$getAllCodeSetVersion(v = "31/10/2021")

analysis = cprd$analysis("dpctn_prevalent")


############################################################################################

# Set index date
index_date <- as.Date("2020-02-01")

# Get cohort info 
cohort <- cohort %>% analysis$cached("cohort")

############################################################################################

# Get code counts (prior to/at index date) for different diabetes types

## Get raw counts for all time
analysis = cprd$analysis("all_patid")

raw_diabetes_medcodes <- cprd$tables$observation %>%
  inner_join(codes$all_diabetes, by="medcodeid") %>%
  analysis$cached("raw_diabetes_medcodes", indexes=c("patid", "obsdate", "all_diabetes_cat"))

raw_exclusion_diabetes_medcodes <- cprd$tables$observation %>%
  inner_join(codes$exclusion_diabetes, by="medcodeid") %>%
  analysis$cached("raw_exclusion_diabetes_medcodes", indexes=c("patid", "obsdate", "exclusion_diabetes_cat"))

raw_qof_codes <- cprd$tables$observation %>%
  inner_join(codes$qof_diabetes_all_types, by="medcodeid") %>%
  analysis$cached("raw_qof_diabetes_all_types_medcodes", indexes=c("patid", "obsdate", "qof_diabetes_all_types_cat"))

raw_remission_codes <- cprd$tables$observation %>%
  inner_join(codes$diabetes_remission, by="medcodeid") %>%
  analysis$cached("raw_diabetes_remission_medcodes", indexes=c("patid", "obsdate"))


# Get counts for clean (valid dates) codes *at index date*

analysis = cprd$analysis("dpctn_prevalent")


## All diabetes codes

diabetes_code_count <- raw_diabetes_medcodes %>%
  inner_join(cprd$tables$validDateLookup, by="patid") %>%
  filter(obsdate>=min_dob & obsdate<=gp_ons_end_date & obsdate<=index_date) %>%
  mutate(category=case_when(all_diabetes_cat=="type 1" ~ "t1",
                            all_diabetes_cat=="type 2" ~ "t2",
                            all_diabetes_cat=="unspecified" ~ "unspec")) %>%
  group_by(patid, category) %>%
  summarise(count=n()) %>%
  ungroup() %>%
  pivot_wider(patid, names_from=category, names_prefix="non_qof_", values_from="count") %>%
  analysis$cached("diabetes_code_count", unique_indexes="patid")


## Exclusion diabetes codes
### Has diabetes insipidus codes from other work, but not interested in these here

exclusion_diabetes_code_count <- raw_exclusion_diabetes_medcodes %>%
  filter(exclusion_diabetes_cat!="diabetes insipidus") %>%
  inner_join(cprd$tables$validDateLookup, by="patid") %>%
  filter(obsdate>=min_dob & obsdate<=gp_ons_end_date & obsdate<=index_date) %>%
  mutate(category=case_when(exclusion_diabetes_cat=="gestational" ~ "gestational",
                            exclusion_diabetes_cat=="malnutrition" ~ "malnutrition",
                            exclusion_diabetes_cat=="mody" ~ "mody",
                            exclusion_diabetes_cat=="other/unspec genetic inc syndromic" ~ "other_gene",
                            exclusion_diabetes_cat=="secondary" ~ "secondary",
                            exclusion_diabetes_cat=="other/unspec" ~ "other_excl")) %>%
  group_by(patid, category) %>%
  summarise(count=n()) %>%
  ungroup() %>%
  pivot_wider(patid, names_from=category, names_prefix="non_qof_", values_from="count") %>%
  analysis$cached("exclusion_diabetes_code_count", unique_indexes="patid")


## QOF codes

qof_diabetes_code_count <- raw_qof_codes %>%
  inner_join(cprd$tables$validDateLookup, by="patid") %>%
  filter(obsdate>=min_dob & obsdate<=gp_ons_end_date & obsdate<=index_date) %>%
  mutate(category=case_when(qof_diabetes_all_types_cat=="type 1" ~ "t1",
                            qof_diabetes_all_types_cat=="type 2" ~ "t2",
                            qof_diabetes_all_types_cat=="mody" ~ "mody",
                            qof_diabetes_all_types_cat=="secondary" ~ "secondary",
                            qof_diabetes_all_types_cat=="other/unspec genetic inc syndromic" ~ "other_gene",
                            qof_diabetes_all_types_cat=="unspecified" ~ "unspec")) %>%
  group_by(patid, category) %>%
  summarise(count=n()) %>%
  ungroup() %>%
  pivot_wider(patid, names_from=category, names_prefix="qof_", values_from="count") %>%
  analysis$cached("qof_diabetes_code_count", unique_indexes="patid")


## Remission codes

remission_code_count <- raw_remission_codes %>%
  inner_join(cprd$tables$validDateLookup, by="patid") %>%
  filter(obsdate>=min_dob & obsdate<=gp_ons_end_date & obsdate<=index_date) %>%
  group_by(patid) %>%
  summarise(remission=n()) %>%
  ungroup() %>%
  analysis$cached("remission_code_count", unique_indexes="patid")

remission_code_count %>% count()
#29,676

# Join together to make table of code counts
## Replace missing values with 0

code_counts <- cohort %>%
  select(patid) %>%
  left_join(diabetes_code_count, by="patid") %>%
  left_join(exclusion_diabetes_code_count, by="patid") %>%
  left_join(qof_diabetes_code_count, by="patid") %>%
  left_join(remission_code_count, by="patid") %>%
  mutate(across(everything(), coalesce, 0L)) %>%
  analysis$cached("code_counts", unique_indexes="patid")
  

############################################################################################

# Look at people with unspecified codes only vs those with T2 and unspecified codes

analysis = cprd$analysis("dpctn_data_qual")

unspec_comparison <- code_counts %>%
  filter(non_qof_t1==0 & non_qof_gestational==0 & non_qof_malnutrition==0 & non_qof_mody==0 & non_qof_other_excl==0 & non_qof_other_gene==0 & non_qof_secondary==0) %>%
  mutate(unspec=ifelse(non_qof_t2>0, "t2&unspec", "unspec_only")) %>%
  analysis$cached("unspec_comparison", unique_indexes="patid")

unspec_comparison %>% group_by(unspec) %>% summarise(count=n())
#244,415 with only unspecified codes
#577,095 with T2 and unspecified codes


############################################################################################

# 1. Look at number with multiple codes

## How many with single code and what is it?
### Unspec only
unspec_comparison %>% filter(unspec=="unspec_only" & non_qof_unspec==1) %>% count()
#151,426=62%

### T2&unspec with single T2 code
unspec_comparison %>% filter(unspec=="t2&unspec" & non_qof_t2==1) %>% count()
#47,287=8.2%

### What is single code for those with no type specific codes
codes <- unspec_comparison %>%
  filter(unspec=="unspec_only" & non_qof_unspec==1) %>%
  select(patid) %>%
  inner_join(raw_diabetes_medcodes, by="patid") %>%
  inner_join(cprd$tables$validDateLookup, by="patid") %>%
  filter(obsdate>=min_dob & obsdate<=gp_ons_end_date & obsdate<=index_date) %>%
  group_by(medcodeid) %>%
  summarise(count=n()) %>%
  ungroup() %>%
  left_join(cprd$tables$medDict, by="medcodeid") %>%
  analysis$cached("unspec_codes")

codes %>% filter(count>4000)
#81,415 (58%) = seen in diabetes clinic
# Rest are all <4%


# Find people with only 'seen in diabetes clinic' code
## Medcode 285223014

other_codes <- raw_diabetes_medcodes %>%
  filter(medcodeid!=285223014) %>%
  inner_join(cprd$tables$validDateLookup, by="patid") %>%
  filter(obsdate>=min_dob & obsdate<=gp_ons_end_date & obsdate<=index_date) %>%
  distinct(patid) %>%
  mutate(other_codes=1L) %>%
  analysis$cached("other_codes", unique_indexes="patid")


# What are other codes

other_code_types <- unspec_comparison %>%
  filter(unspec=="unspec_only") %>%
  inner_join(raw_diabetes_medcodes, by="patid") %>%
  filter(medcodeid!=285223014) %>%
  inner_join(cprd$tables$validDateLookup, by="patid") %>%
  filter(obsdate>=min_dob & obsdate<=gp_ons_end_date & obsdate<=index_date) %>%
  group_by(medcodeid) %>%
  summarise(count=n()) %>%
  ungroup() %>%
  left_join(cprd$tables$medDict, by="medcodeid") %>%
  analysis$cached("other_code_types")

other_code_types %>% filter(count>20000)


# How many have only seen in diabetes clinic + diabetic monitoring codes x 2

unspec_comparison %>%
  filter(unspec=="unspec_only") %>%
  inner_join(raw_diabetes_medcodes, by="patid") %>%
  filter(medcodeid==285223014 | medcodeid==616731000006114 | medcodeid==264676010) %>%
  inner_join(cprd$tables$validDateLookup, by="patid") %>%
  filter(obsdate>=min_dob & obsdate<=gp_ons_end_date & obsdate<=index_date) %>%
  distinct(patid) %>%
  count()
#152,839


############################################################################################

# 2. Look at number with follow up time <2 years - might expect to only have 1 code as annual review

unspec_earliest_code <- unspec_comparison %>%
  inner_join(raw_diabetes_medcodes, by="patid") %>%
  inner_join(cprd$tables$validDateLookup, by="patid") %>%
  filter(obsdate>=min_dob & obsdate<=gp_ons_end_date & obsdate<=index_date) %>%
  group_by(patid) %>%
  summarise(earliest_code=min(obsdate, na.rm=TRUE)) %>%
  ungroup() %>%
  analysis$cached("unspec_earliest_code", unique_index="patid")
  
code_times <- unspec_earliest_code %>%
  mutate(time_diff_yrs=datediff(index_date, earliest_code)/265.25) %>%
  analysis$cached("unspec_code_times", unique_index="patid")

code_times <- collect(unspec_comparison %>% left_join(code_times, by="patid") %>% select(unspec, time_diff_yrs)) %>% mutate(time_diff_yrs=as.numeric(time_diff_yrs))

code_time_cut <- code_times %>% filter(time_diff_yrs<15)

ggplot (code_time_cut, aes(x=time_diff_yrs, color=unspec, fill=unspec)) + 
  geom_histogram(alpha = 0.4, position="identity")
# More people with shorter followup time

code_times <- code_times %>% analysis$cached("unspec_code_times")

############################################################################################

# 3. Look at those with other features of diabetes

analysis = cprd$analysis("all_patid")

## All HbA1c measurements
clean_hba1c <- cprd$tables$observation %>%
  inner_join(codes$hba1c, by="medcodeid") %>%
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

analysis = cprd$analysis("dpctn_data_qual")

with_any_hba1c <- clean_hba1c %>%
  distinct(patid) %>%
  mutate(with_any_hba1c=1L)

with_predm_hba1c <- clean_hba1c %>%
  filter(testvalue>=42 & testvalue<48) %>%
  distinct(patid) %>%
  mutate(with_predm_hba1c=1L)

with_high_hba1c <- clean_hba1c %>%
  filter(testvalue>=48) %>%
  distinct(patid) %>%
  mutate(with_high_hba1c=1L)

with_hes_dm <- cprd$tables$hesDiagnosisEpi %>%
  filter(sql("ICD like 'E10%' or ICD like 'E11%' or ICD like 'E12' or ICD like 'E13%' or ICD like 'E14%'")) %>%
  distinct(patid) %>%
  mutate(with_hes_dm=1L)

unspec_other_dm_features <- unspec_comparison %>%
  select(patid, unspec) %>%
  left_join((cohort %>% select(patid, oha_ever, ins_ever)), by="patid") %>%
  left_join(with_any_hba1c, by="patid") %>%
  left_join(with_predm_hba1c, by="patid") %>%
  left_join(with_high_hba1c, by="patid") %>%
  left_join(with_hes_dm, by="patid") %>%
  mutate(across(everything(), coalesce, 0L)) %>%
  analysis$cached("unspec_other_dm_features", unique_indexes="patid")


############################################################################################

# 4. Look at those with remission codes

unspec_comparison %>% filter(remission>0) %>% group_by(unspec) %>% count()
#18245 with T2 and unspecified codes = 3.2%
#1648 with only unspecified codes = 0.7%


############################################################################################

# 5. Combine above with other features (age, BMI etc)
## Including age at earliest code and age at latest code

unspec_age_earliest_code <- unspec_earliest_code %>%
  left_join((cohort %>% select(patid, dob)), by="patid") %>%
  mutate(age_earliest_code=round(datediff(earliest_code, dob)/365.25, 2)) %>%
  analysis$cached("unspec_age_earliest_code", unique_index="patid")

unspec_age_latest_code <- unspec_comparison %>%
  inner_join(raw_diabetes_medcodes, by="patid") %>%
  inner_join(cprd$tables$validDateLookup, by="patid") %>%
  filter(obsdate>=min_dob & obsdate<=gp_ons_end_date & obsdate<=index_date) %>%
  group_by(patid) %>%
  summarise(latest_code=max(obsdate, na.rm=TRUE)) %>%
  ungroup() %>%
  left_join((cohort %>% select(patid, dob)), by="patid") %>%
  mutate(age_latest_code=round(datediff(latest_code, dob)/365.25, 2)) %>%
  analysis$cached("unspec_age_latest_code", unique_index="patid")

unspec_data_all <- unspec_comparison %>%
  left_join(cohort, by="patid") %>%
  left_join(other_codes, by="patid") %>%
  left_join((unspec_age_earliest_code %>% select(patid, age_earliest_code)), by="patid") %>%
  left_join((unspec_age_latest_code %>% select(patid, age_latest_code)), by="patid") %>%
  left_join((code_times %>% select(patid, time_diff_yrs)), by="patid") %>%
  left_join((unspec_other_dm_features %>% select(patid, with_any_hba1c, with_predm_hba1c, with_high_hba1c, with_hes_dm)), by="patid") %>%
  analysis$cached("unspec_data_all", unique_indexes="patid")

unspec_data_all <- collect(unspec_data_all %>%
                             mutate(sex=ifelse(gender==1, "male", ifelse(gender==2, "female", "unknown")),
                                    ethnicity=case_when(ethnicity_5cat==0 ~"White",
                                                        ethnicity_5cat==1 ~"South Asian",
                                                        ethnicity_5cat==2 ~"Black",
                                                        ethnicity_5cat==3 ~"Other",
                                                        ethnicity_5cat==4 ~"Mixed"),
                                    multiple_codes=ifelse(non_qof_unspec + non_qof_t2>1, 1L, 0L),
                                    remission_codes=ifelse(remission>0, 1L, 0L),
                                    follow_up_under_2_years=ifelse(time_diff_yrs<2, 1L, 0L),
                                    under_35_diag=ifelse(age_earliest_code<35, 1L, 0L),
                                    with_qof=ifelse(qof_t1>0 | qof_t2>0 | qof_unspec>0 | qof_mody>0 | qof_other_gene>0 | qof_secondary>0, 1L, 0L)) %>%
                         select(unspec, age_at_index, age_earliest_code, age_latest_code, sex, bmi, imd2015_10, ethnicity, multiple_codes, follow_up_under_2_years, remission_codes, other_codes, with_any_hba1c, with_predm_hba1c, with_high_hba1c, with_hes_dm, oha_ever, ins_ever, under_35_diag, with_qof)) %>%
  mutate(imd2015_quintile=as.factor(ifelse(imd2015_10==1 | imd2015_10==2, 1,
                                           ifelse(imd2015_10==3 | imd2015_10==4, 2,
                                                  ifelse(imd2015_10==5 | imd2015_10==6, 3,
                                                         ifelse(imd2015_10==7 | imd2015_10==8, 4,
                                                                ifelse(imd2015_10==9 | imd2015_10==10, 5, NA)))))),
         multiple_codes=as.factor(multiple_codes),
         follow_up_under_2_years=as.factor(follow_up_under_2_years),
         remission_codes=as.factor(remission_codes),
         with_any_hba1c=as.factor(with_any_hba1c),
         with_predm_hba1c=as.factor(with_predm_hba1c),
         with_high_hba1c=as.factor(with_high_hba1c),
         with_hes_dm=as.factor(with_hes_dm),
         oha_ever=as.factor(oha_ever),
         ins_ever=as.factor(ins_ever),
         under_35_diag=as.factor(under_35_diag),
         with_qof=as.factor(with_qof),
         other_codes=as.factor(ifelse(is.na(other_codes), 0, 1)))

unspec_data_all <- unspec_data_all %>%
  mutate(group=ifelse(unspec=="unspec_only" & (with_high_hba1c==1 | oha_ever==1 | ins_ever==1), "unspec_extra",
                      ifelse(unspec=="unspec_only" & with_high_hba1c!=1 & oha_ever!=1 & ins_ever!=1 & other_codes==1, "unspec_other",
                             ifelse(unspec=="unspec_only" & with_high_hba1c!=1 & oha_ever!=1 & ins_ever!=1 & other_codes==0, "unspec_seen_only", "t2"))))


as_flextable(summarizor(unspec_data_all, by="group"))


unspec_data_all %>% filter(unspec=="unspec_only") %>% filter(with_high_hba1c==1 | oha_ever==1 | ins_ever==1) %>% count()
#36,943

unspec_data_all %>% filter(unspec=="unspec_only") %>% filter(with_high_hba1c==1 | oha_ever==1 | ins_ever==1 | with_qof==1) %>% count()
#37,971

unspec_data_all %>% filter(unspec=="unspec_only") %>% filter((with_high_hba1c==1 | oha_ever==1 | ins_ever==1) & with_hes_dm==1) %>% count()
#13884
unspec_data_all %>% filter(unspec=="unspec_only") %>% filter(!(with_high_hba1c==1 | oha_ever==1 | ins_ever==1) & with_hes_dm==1) %>% count()
#6023



unspec_data_all %>% filter(unspec=="unspec_only") %>% filter(with_high_hba1c==1 | oha_ever==1 | ins_ever==1 | multiple_codes==1) %>% count()
#116917

unspec_data_all %>% filter(unspec=="unspec_only") %>% filter((with_high_hba1c==1 | oha_ever==1 | ins_ever==1 | multiple_codes==1) & with_hes_dm==1) %>% count()
#17664
unspec_data_all %>% filter(unspec=="unspec_only") %>% filter(!(with_high_hba1c==1 | oha_ever==1 | ins_ever==1 | multiple_codes==1) & with_hes_dm==1) %>% count()
#2243


test <- unspec_data_all %>% filter(unspec=="unspec_only") %>% mutate(incl=ifelse(with_high_hba1c==1 | oha_ever==1 | ins_ever==1, "incl", "excl"))
prop.table(table(test$follow_up_under_2_years, test$incl), margin=1)

test <- unspec_data_all %>% filter(unspec=="unspec_only") %>% mutate(incl=ifelse(with_high_hba1c==1 | oha_ever==1 | ins_ever==1 | multiple_codes==1, "incl", "excl"))
prop.table(table(test$follow_up_under_2_years, test$incl), margin=1)
