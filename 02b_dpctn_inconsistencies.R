
# Look at inconsistencies between diabetes type and other features

# Do overall (for Github repo), and then just in those with diagnosis date (simpler version for slides)

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

# In all - look at proportion within Type 1 or Type 2 and then by specific diabetes type (mixed or not)

## Type 1

cohort %>% filter(diabetes_type=="type 1" | diabetes_type=="mixed; type 1") %>% group_by(diabetes_type) %>% count()
#type 1          30338
#mixed; type 1    7627

30338+7627 #37965


## But not on insulin
cohort %>% filter((diabetes_type=="type 1" | diabetes_type=="mixed; type 1") & current_insulin==0) %>% group_by(diabetes_type) %>% count()
#type 1          1241
#mixed; type 1    399

1241/30338 #4.1%
399/7627 #5.2%
(1241+399)/37965 #4.3%


## But not on bolus/mix insulin
cohort %>% filter((diabetes_type=="type 1" | diabetes_type=="mixed; type 1") & current_bolusmix_insulin==0) %>% group_by(diabetes_type) %>% count()
#type 1          2076
#mixed; type 1    722

2076/30338 #6.8%
722/7627 #9.5%
(2076+722)/37965 #7.4%


## But on DPP4/GLP1/SU/TZD
cohort %>% filter((diabetes_type=="type 1" | diabetes_type=="mixed; type 1") & current_dpp4glp1sutzd==1) %>% group_by(diabetes_type) %>% count()
#type 1           314
#mixed; type 1    354

314/30338 #1.0%
354/7627 #4.6%
(314+354)/37965 #1.8%


## Type 2

cohort %>% filter(diabetes_type=="type 2" | diabetes_type=="mixed; type 2") %>% group_by(diabetes_type) %>% count()
#type 2          173277
#mixed; type 2    14726

173277+14726 #188003


## But with diabetes duration <=3 years and on insulin
cohort %>% filter((diabetes_type=="type 2" | diabetes_type=="mixed; type 2") & (datediff(index_date, diagnosis_date))/365.25<=3 & current_insulin==1) %>% group_by(diabetes_type) %>% count()
#type 2            559
#mixed; type 2      61

559/173277 #0.3%
61/14726 #0.4%
(559+61)/188003 #0.3%


############################################################################################

# Just in those with diagnosis date - look at proportion within Type 1 or Type 2 and overall in whole cohort

## Type 1

cohort %>% filter(diabetes_type=="type 1" | diabetes_type=="mixed; type 1" | diabetes_type=="type 2" | diabetes_type=="mixed; type 2") %>% count()
#214770

cohort %>% filter(diabetes_type=="type 1" | diabetes_type=="mixed; type 1") %>% count()
#36271


## But not on insulin
cohort %>% filter((diabetes_type=="type 1" | diabetes_type=="mixed; type 1") & current_insulin==0) %>% count()
#1521

1521/36271 #4.2%
1521/214770 #0.7


## But not on bolus/mix insulin
cohort %>% filter((diabetes_type=="type 1" | diabetes_type=="mixed; type 1") & current_bolusmix_insulin==0) %>% count()
#2633

2633/36271 #7.3%
2633/214770 #1.2%


## But on DPP4/GLP1/SU/TZD
cohort %>% filter((diabetes_type=="type 1" | diabetes_type=="mixed; type 1") & current_dpp4glp1sutzd==1) %>% count()
#631

631/36271 #1.7%
631/214770 #0.3%


## Type 2

cohort %>% filter(diabetes_type=="type 2" | diabetes_type=="mixed; type 2") %>% count()
#178499


## But with diabetes duration <=3 years and on insulin
cohort %>% filter((diabetes_type=="type 2" | diabetes_type=="mixed; type 2") & (datediff(index_date, diagnosis_date))/365.25<=3 & current_insulin==1) %>% count()
#620

620/178499 #0.3%
620/214770 #0.3%
