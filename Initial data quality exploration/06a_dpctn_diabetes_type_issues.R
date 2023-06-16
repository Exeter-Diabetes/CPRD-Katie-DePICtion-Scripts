
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
# type 1                        28986
# mixed; type 1                  7098


## No insulin scripts

type_1_cohort %>% filter(is.na(earliest_ins)) %>% group_by(class) %>% count()
# type 1                     134
# mixed; type 1              127

134/28986 #0.5%
127/7098 #1.8%


## Without bolus/mix insulin

analysis = cprd$analysis("all_patid")

clean_insulin_prodcodes <- clean_insulin_prodcodes %>% analysis$cached("clean_insulin_prodcodes")

analysis = cprd$analysis("dpctn")

with_bolus_mix <- clean_insulin_prodcodes %>%
  filter(insulin_cat=="Bolus insulin" | insulin_cat=="Mix insulin") %>%
  distinct(patid) %>%
  analysis$cached("with_bolus_mix", unique_index="patid")

type_1_cohort %>% inner_join(with_bolus_mix, by="patid") %>% group_by(class) %>% count()
 
# type 1          28755
# mixed; type 1    6887

(28986-28755)/28986 #0.8%
(7098-6887)/7098 #3.0%


## With insulin but also OHA with isn't MFN or SGLT2i

analysis = cprd$analysis("all_patid")

clean_oha_prodcodes <- clean_oha_prodcodes %>% analysis$cached("clean_oha_prodcodes")

analysis = cprd$analysis("dpctn")

clean_oha_no_mfn_sglt <- clean_oha_prodcodes %>%
  filter(DPP4==1 | GLP1==1 | SU==1 | TZD==1) %>%
  distinct(patid) %>%
  analysis$cached("clean_oha_no_mfn_sglt", unique_index="patid")

type_1_cohort %>% filter(!is.na(earliest_ins)) %>% inner_join(clean_oha_no_mfn_sglt, by="patid") %>% group_by(class) %>% count()

# type 1                    1672
# mixed; type 1             1734

1672/28986 #5.8%
1734/7098 #24.4%


## More than 3 years between diagnosis and insulin

### Those with time to insulin i.e. with insulin script and registered before or within 6 months of diabetes diagnosis, and diagnosis date

type_1_cohort %>% filter(!is.na(time_to_ins_days) & !is.na(dm_diag_date)) %>% group_by(class) %>% count()

# type 1          10203
# mixed; type 1    2813

### Those with insulin more than three years from diagnosis

type_1_cohort %>% filter(!is.na(time_to_ins_days) & !is.na(dm_diag_date) & time_to_ins_days>(3*365.25)) %>% group_by(class) %>% count()

# type 1           1439
# mixed; type 1     808

1439/10203 #14.1%
808/2813 #28.7%


############################################################################################

# Find proportion with Type 2 and:
## On insulin in <6 months
## No OHAs earlier than first insulin script
## No OHA / insulin / high HbA1c

type_2_cohort <- cohort %>%
  filter(class=="type 2" | class=="mixed; type 2") %>%
  analysis$cached("type_2_cohort", unique_indexes="patid")

type_2_cohort %>% group_by(class) %>% count()
# type 2                       165215
# mixed; type 2                 13625

## On insulin within 6 months

### Only include those with no insulin or valid time to insulin i.e. registered before or within 6 months of diabetes diagnosis

type_2_cohort %>% filter(is.na(earliest_ins) | is.na(time_to_ins_days)) %>% group_by(class) %>% count()

# type 2                       143479
# mixed; type 2                  9257

### Those with insulin less than 6 months

type_2_cohort %>% filter(!is.na(time_to_ins_days) & time_to_ins_days<=183) %>% group_by(class) %>% count()

# type 2                         2809
# mixed; type 2                  2099

2809/143479 #2.0%
2099/9257 #22.7%


## Insulin script earlier than first OHA or insulin and no OHA
earliest_latest_codes_wide <- earliest_latest_codes_wide %>% analysis$cached("earliest_latest_codes_wide")

type_2_cohort %>% inner_join(earliest_latest_codes_wide) %>% filter(!is.na(earliest_insulin_script) & (is.na(earliest_oha_script) | earliest_oha_script>earliest_insulin_script)) %>% group_by(class) %>% count()

# type 2                         5532
# mixed; type 2                  3995

5532/165215 #3.3%
3995/13625 #29.3%


## No OHA / insulin / high HbA1c

type_2_cohort %>% inner_join(earliest_latest_codes_wide) %>% filter(is.na(earliest_oha_script) & is.na(earliest_insulin_script) & is.na(earliest_high_hba1c)) %>% group_by(class) %>% count()

# type 2                         2062
# mixed; type 2                  84

2062/165215 #1.2%
84/13625 #0.6%


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

