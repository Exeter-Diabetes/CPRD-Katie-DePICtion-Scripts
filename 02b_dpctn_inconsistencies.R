
# Look at inconsistencies between diabetes type and other features

# Do overall (for Github repo), and add flags so know later on if these people picked up by MODY/T1DT2D calculator

############################################################################################

# Setup
library(tidyverse)
library(aurum)
rm(list=ls())

cprd = CPRDData$new(cprdEnv = "test-remote",cprdConf = "~/.aurum.yaml")

analysis = cprd$analysis("dpctn_final")


############################################################################################

# Get cohort info and set index date

cohort <- cohort %>% analysis$cached("cohort")

cohort_with_diag <- cohort %>% filter(!is.na(diagnosis_date))

index_date <- as.Date("2020-02-01")


############################################################################################

# Add flag for each inconsistency:
## Type 1 but not on insulin in last 12 months
## Type 1 but not on DPP4/SU/TZD in last 6 months
## Type 1 but not on GLP1 in last 6 months
## Type 1 but not on SGLT2 in last 6 months
## Type 2 but on insulin within 3 years of diagnosis

cohort_with_flags <- cohort %>%
  mutate(t1_no_ins=ifelse((diabetes_type=="type 1" | diabetes_type=="mixed; type 1") & current_insulin_12m==0, 1L, 0L),
         t1_dpp4sutzd=ifelse((diabetes_type=="type 1" | diabetes_type=="mixed; type 1") & current_dpp4sutzd==1, 1L, 0L),
         t1_glp1=ifelse((diabetes_type=="type 1" | diabetes_type=="mixed; type 1") & current_glp1==1, 1L, 0L),
         t1_sglt2=ifelse((diabetes_type=="type 1" | diabetes_type=="mixed; type 1") & current_sglt2==1, 1L, 0L),
         t2_ins_3yrs=ifelse((diabetes_type=="type 2" | diabetes_type=="mixed; type 2") & !is.na(earliest_ins) & (datediff(earliest_ins, diagnosis_date))/365.25<=3, 1L, 0L)) %>%
  mutate(flags=concat(ifelse(t1_no_ins==1, "t1_no_ins + ", ""),
                      ifelse(t1_dpp4sutzd==1, "t1_dpp4sutzd + ", ""),
                      ifelse(t1_glp1==1, "t1_glp1 + ", ""),
                      ifelse(t1_sglt2==1, "t1_sglt2 + ", ""),
                      ifelse(t2_ins_3yrs==1, "t2_ins_3yrs + ", ""))) %>%
  mutate(flags=sql("trim(trailing ' + ' from flags)")) %>%
  select(-c(t1_no_ins, t1_dpp4sutzd, t1_glp1, t1_sglt2, t2_ins_3yrs)) %>%
  analysis$cached("cohort_with_flags", unique_index="patid")


############################################################################################

# Find counts

## Denominators

cohort_with_flags %>% filter(diabetes_type=="type 1" | diabetes_type=="mixed; type 1") %>% count()
#38225
cohort_with_flags %>% filter(diabetes_type=="type 1") %>% count()
#30476
cohort_with_flags %>% filter(diabetes_type=="mixed; type 1") %>% count()
#7749
cohort_with_flags %>% filter(diabetes_type=="type 2" | diabetes_type=="mixed; type 2") %>% count()
#203106
cohort_with_flags %>% filter(diabetes_type=="type 2") %>% count()
#188103
cohort_with_flags %>% filter(diabetes_type=="mixed; type 2") %>% count()
#15003



## Type 1 no insulin
cohort_with_flags %>% filter(sql("flags like '%t1_no_ins%'")) %>% group_by(diabetes_type) %>% count()
#type 1           882
#mixed; type 1    314

882/30476 #2.9%
314/7749 #4.1%
(882+314)/38225 #3.1%


## Type 1 but on DPP4/SU/TZD
cohort_with_flags %>% filter(sql("flags like '%t1_dpp4sutzd%'")) %>% group_by(diabetes_type) %>% count()
#type 1           126
#mixed; type 1    254

126/30476 #0.4%
254/7749 #3.3%
(126+254)/38225 #1.0%


##  Type 1 but on GLP1
cohort_with_flags %>% filter(sql("flags like '%t1_glp1%'")) %>% group_by(diabetes_type) %>% count()
#type 1           198
#mixed; type 1    123

198/30476 #0.6%
123/7749 #1.6%
(198+123)/38225 #0.8%


##  Type 1 but on SGLT2
cohort_with_flags %>% filter(sql("flags like '%t1_sglt2%'")) %>% group_by(diabetes_type) %>% count()
#type 1           232
#mixed; type 1    165

232/30476 #0.7%
165/7749 #2.1%
(232+165)/38225 #1.0%


##  Type 1 but on DPP4/SU/TZD/GLP1
cohort_with_flags %>% filter(sql("flags like '%t1_dpp4sutzd%' or flags like '%t1_glp1%'")) %>% count()
#678
678/38225 #1.8%

##  Type 1  but on DPP4/SU/TZD/SGLT2
cohort_with_flags %>% filter(sql("flags like '%t1_dpp4sutzd%' or flags like '%t1_sglt2%'")) %>% count()
#730
730/38225 #1.9%

##  Type 1 but on DPP4/SU/TZD/GLP1/SGLT2
cohort_with_flags %>% filter(sql("flags like '%t1_dpp4sutzd%' or flags like '%t1_glp1%' or flags like '%t1_sglt2%'")) %>% count()
#984
984/38225 #2.6%



## Type 2 but with insulin within 3 years of diagnosis
cohort_with_flags %>% filter(sql("flags like '%t2_ins_3yrs%'")) %>% group_by(diabetes_type) %>% count()
#type 2            8119
#mixed; type 2      3889

8119/188103 #4.3%
3889/15003 #25.9%
(8119+3889)/203106 #5.9%

