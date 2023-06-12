
# Look at those with anomalies between their coding and assigned diabetes type

############################################################################################

# Setup
library(tidyverse)
library(aurum)
rm(list=ls())

cprd = CPRDData$new(cprdEnv = "test-remote",cprdConf = "~/.aurum.yaml")

analysis = cprd$analysis("dpctn")


############################################################################################

# Cohort table
## Only include those diagnosed under the age of 50

cohort_with_diag_dates <- cohort_with_diag_dates %>% analysis$cached("cohort_with_diag_dates")

cohort <- cohort_with_diag_dates %>% filter(dm_diag_age<=50)


############################################################################################

# Find proportion with Type 1 and:
## No insulin scripts
### No basal insulin scripts
## With insulin but also OHA with isn't MFN or SGLT2i
## More than 3 years between diagnosis and insulin

type_1_cohort <- cohort %>%
  filter(class=="type 1" | class=="mixed; type 1") %>%
  analysis$cached("type_1_cohort", unique_indexes="patid")

type_1_cohort %>% group_by(class) %>% count()
# type 1                        30079
# mixed; type 1                  7338


## No insulin scripts

type_1_cohort %>% filter(is.na(earliest_ins)) %>% group_by(class) %>% count()
# type 1                     139
# mixed; type 1              132

139/30079 #0.5%
132/7338 #1.8%


## Without basal and bolus insulin

analysis = cprd$analysis("all_patid")

clean_insulin_prodcodes <- clean_insulin_prodcodes %>% analysis$cached("clean_insulin_prodcodes")

analysis = cprd$analysis("dpctn")

with_basal <- clean_insulin_prodcodes %>%
  filter(insulin_cat=="Basal insulin") %>%
  distinct(patid) %>%
  analysis$cached("with_basal", unique_index="patid")

with_bolus <- clean_insulin_prodcodes %>%
  filter(insulin_cat=="Bolus insulin") %>%
  distinct(patid) %>%
  analysis$cached("with_bolus", unique_index="patid")

type_1_cohort %>% inner_join(with_basal, by="patid") %>% inner_join(with_bolus, by="patid") %>% group_by(class) %>% count()
 
# type 1          27698
# mixed; type 1    6358

(30079-27698)/30079 #7.9%
(7338-6358)/7338 #13.4%


## With insulin but also OHA with isn't MFN or SGLT2i

analysis = cprd$analysis("all_patid")

clean_oha_prodcodes <- clean_oha_prodcodes %>% analysis$cached("clean_oha_prodcodes")

analysis = cprd$analysis("dpctn")

clean_oha_no_mfn_sglt <- clean_oha_prodcodes %>%
  filter(DPP4==1 | GLP1==1 | SU==1 | TZD==1) %>%
  distinct(patid) %>%
  analysis$cached("clean_oha_no_mfn_sglt", unique_index="patid")

type_1_cohort %>% filter(!is.na(earliest_ins)) %>% inner_join(clean_oha_no_mfn_sglt, by="patid") %>% group_by(class) %>% count()

# type 1                    1731
# mixed; type 1             1800

1731/30079 #5.8%
1800/7338 #24.5%


## More than 3 years between diagnosis and insulin

### Those with time to insulin i.e. with insulin script and registered before or within 6 months of diabetes diagnosis

type_1_cohort %>% filter(!is.na(time_to_ins_days)) %>% group_by(class) %>% count()

# type 1          11291
# mixed; type 1    3048

### Those with insulin more than three years from diagnosis

type_1_cohort %>% filter(!is.na(time_to_ins_days) & time_to_ins_days>(3*365.25)) %>% group_by(class) %>% count()

# type 1           1528
# mixed; type 1     858

1528/30079 #5.1%
858/7338 #11.7%


############################################################################################

# Find proportion with Type 2 and:
## On insulin in <6 months
## No OHAs earlier than first insulin script
## No OHA / insulin / high HbA1c

type_2_cohort <- cohort %>%
  filter(class=="type 2" | class=="mixed; type 2") %>%
  analysis$cached("type_2_cohort", unique_indexes="patid")

type_2_cohort %>% group_by(class) %>% count()
# type 2                       171073
# mixed; type 2                 14064

## On insulin within 6 months

### Only include those with no insulin or valid time to insulin i.e. registered before or within 6 months of diabetes diagnosis

type_2_cohort %>% filter(is.na(earliest_ins) | is.na(time_to_ins_days)) %>% group_by(class) %>% count()

# type 2                       147736
# mixed; type 2                  9401

### Those with insulin less than 6 months

type_2_cohort %>% filter(!is.na(time_to_ins_days) & time_to_ins_days<=183) %>% group_by(class) %>% count()

# type 2                         3186
# mixed; type 2                  2242

3186/147736 #2.2%
2242/9401 #23.8%


## Insulin script earlier than first OHA or insulin and no OHA
earliest_latest_codes_wide <- earliest_latest_codes_wide %>% analysis$cached("earliest_latest_codes_wide")

type_2_cohort %>% inner_join(earliest_latest_codes_wide) %>% filter(!is.na(earliest_insulin_script) & (is.na(earliest_oha_script) | earliest_oha_script>earliest_insulin_script)) %>% group_by(class) %>% count()

# type 2                         5760
# mixed; type 2                  4146

5760/147736 #3.9%
4146/9401 #44.1%


## No OHA / insulin / high HbA1c

type_2_cohort %>% inner_join(earliest_latest_codes_wide) %>% filter(is.na(earliest_oha_script) & is.na(earliest_insulin_script) & is.na(earliest_high_hba1c)) %>% group_by(class) %>% count()

# type 2                         2113
# mixed; type 2                  87

2113/147736 #1.4%
87/9401 #0.9%


############################################################################################

# Those with gestational diabetes codes only but unspecified diabetes codes >1 prior to earliest / >1 year after latest gestational diabetes code (excluding history of gestational diabetes), implying possible Type 1/2 diabetes

gestational_cohort <- cohort %>%
  filter(class=="gestational only") %>%
  analysis$cached("gestational_cohort", unique_indexes="patid")

gestational_cohort %>% count()
#14935

gestational_cohort %>% inner_join(earliest_latest_codes_wide) %>% filter(!is.na(earliest_unspecified) & (datediff(earliest_gestational, earliest_unspecified)>365 | datediff(latest_unspecified, latest_gestational)>365)) %>% count()
#3687                                                                      
 
3687/14935 #24.7%

