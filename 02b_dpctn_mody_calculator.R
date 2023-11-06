
# Apply the MODY calculator to everyone in prevalent cohort diagnosed aged 1-35 years

# Investigate time to insulin issues

############################################################################################
  
# Setup
library(tidyverse)
library(aurum)
library(flextable)
rm(list=ls())

cprd = CPRDData$new(cprdEnv = "test-remote",cprdConf = "~/.aurum.yaml")

analysis = cprd$analysis("dpctn_final")


############################################################################################

# Get cohort info

cohort <- cohort %>% analysis$cached("cohort")


############################################################################################

# Look at cohort size

cohort %>% filter(dm_diag_age>=1 & dm_diag_age<36) %>% count()
#94873


cohort %>% filter(dm_diag_age>=1 & dm_diag_age<36 & (diabetes_type=="unspecified" | diabetes_type=="unspecified_with_primis")) %>% count()
#13410
13410/94873 #14.1%
94873-13410 #81463
81463/94873 #85.9

cohort %>% filter(dm_diag_age>=1 & dm_diag_age<36 & (diabetes_type=="type 2" | diabetes_type=="mixed; type 2" | diabetes_type=="type 1" | diabetes_type=="mixed; type 1")) %>% count()
#70258
70258/81463 #86.2%

cohort %>% filter(dm_diag_age>=1 & dm_diag_age<36 & (diabetes_type=="type 1" | diabetes_type=="mixed; type 1")) %>% count()
#31288
70258-31288 #38970

cohort %>% filter(dm_diag_age>=1 & dm_diag_age<36 & (diabetes_type=="type 2" | diabetes_type=="mixed; type 2" | diabetes_type=="type 1" | diabetes_type=="mixed; type 1") & is.na(diagnosis_date)) %>% count()
#3174
3174/70258 #4.5

cohort %>% filter(dm_diag_age>=1 & dm_diag_age<36 & (diabetes_type=="type 1" | diabetes_type=="mixed; type 1") & is.na(diagnosis_date)) %>% count()
#1183
3174-1183 #1991

cohort %>% filter(dm_diag_age>=1 & dm_diag_age<36 & (diabetes_type=="type 2" | diabetes_type=="mixed; type 2" | diabetes_type=="type 1" | diabetes_type=="mixed; type 1") & !is.na(diagnosis_date)) %>% count()
#67084

cohort %>% filter(dm_diag_age>=1 & dm_diag_age<36 & (diabetes_type=="type 1" | diabetes_type=="mixed; type 1") & !is.na(diagnosis_date)) %>% count()
#30105
67084-30105 #36979


# Define MODY cohort: patients diagnosed with a current Type 1 or Type 2 diagnosis, diagnosed aged 1-35, with valid diagnosis date and BMI/HbA1c before diagnosis

mody_calc_cohort <- cohort %>%
  filter(dm_diag_age>=1 & dm_diag_age<36 & (diabetes_type=="type 1" | diabetes_type=="type 2" | diabetes_type=="mixed; type 1" | diabetes_type=="mixed; type 2") & !is.na(diagnosis_date)) %>%
  mutate(hba1c_post_diag=ifelse(hba1cdate>=diagnosis_date, hba1c, NA),
         hba1c_post_diag_datediff=ifelse(!is.na(hba1c_post_diag), hba1cindexdiff, NA),
         age_at_bmi=datediff(bmidate, dob)/365.25,
         bmi_post_diag=ifelse(bmidate>=diagnosis_date & age_at_bmi>=18, bmi, NA),
         bmi_post_diag_datediff=ifelse(!is.na(bmi_post_diag), bmiindexdiff, NA),
         insoha=ifelse(current_oha==1 | current_insulin==1, 1L, 0L)) %>%
  filter(!is.na(bmi_post_diag) & !is.na(hba1c_post_diag)) %>%
  analysis$cached("mody_calc_cohort", unique_indexes="patid")

mody_calc_cohort %>% count()
#65172
67084-65172 #1912
1912/67084 #2.9

mody_calc_cohort %>% group_by(diabetes_type) %>% count()
# type 1          24113
# type 2          27846
# mixed; type 2    8264
# mixed; type 1    4949
24113+4949 #29062
27846+8264 #36110

30105-29062 #1032 
36979-36110 #770


############################################################################################

# Look at variables

mody_calc_cohort_local <- mody_calc_cohort %>%
  select(diabetes_type, dm_diag_age, current_insulin, hba1c_post_diag_datediff, bmi_post_diag_datediff, fh_diabetes, days_since_type_code, mody_code_count) %>%
  collect() %>%
  mutate(hba1c_post_diag_datediff_yrs=as.numeric(hba1c_post_diag_datediff)/365.25,
         bmi_post_diag_datediff_yrs=as.numeric(bmi_post_diag_datediff)/365.25,
         diabetes_type=factor(diabetes_type, levels=c("type 1", "type 2", "mixed; type 1", "mixed; type 2")),
         time_to_ins_cat=factor(ifelse(dm_diag_age<18, "diag_under_18",
                                ifelse(current_insulin==0, "diag_atover_18_ins0", "diag_atover_18_ins1")), levels=c("diag_under_18", "diag_atover_18_ins0", "diag_atover_18_ins1")))


## Time to insulin
prop.table(table(mody_calc_cohort_local$time_to_ins_cat))

prop.table(table(mody_calc_cohort_local$time_to_ins_cat, mody_calc_cohort_local$diabetes_type), margin=2)



## Time to HbA1c

ggplot ((mody_calc_cohort_local %>% filter(hba1c_post_diag_datediff_yrs>-3)), aes(x=hba1c_post_diag_datediff_yrs, fill=diabetes_type)) + 
  geom_histogram(aes(y = after_stat(count / sum(count))), binwidth=0.05) +
  scale_y_continuous(labels = scales::percent) +
  xlab("Years from HbA1c to current date") +
  ylab("Percentage")

mody_calc_cohort_local <- mody_calc_cohort_local %>%
  mutate(hba1c_in_6_mos=hba1c_post_diag_datediff_yrs>=-0.5,
         hba1c_in_1_yr=hba1c_post_diag_datediff_yrs>=-1,
         hba1c_in_2_yrs=hba1c_post_diag_datediff_yrs>=-2,
         hba1c_in_5_yrs=hba1c_post_diag_datediff_yrs>=-5)

prop.table(table(mody_calc_cohort_local$hba1c_in_6_mos))
prop.table(table(mody_calc_cohort_local$diabetes_type, mody_calc_cohort_local$hba1c_in_6_mos), margin=1)

prop.table(table(mody_calc_cohort_local$hba1c_in_1_yr))
prop.table(table(mody_calc_cohort_local$diabetes_type, mody_calc_cohort_local$hba1c_in_1_yr), margin=1)

prop.table(table(mody_calc_cohort_local$hba1c_in_2_yrs))
prop.table(table(mody_calc_cohort_local$diabetes_type, mody_calc_cohort_local$hba1c_in_2_yrs), margin=1)

prop.table(table(mody_calc_cohort_local$hba1c_in_5_yrs))
prop.table(table(mody_calc_cohort_local$diabetes_type, mody_calc_cohort_local$hba1c_in_5_yrs), margin=1)



## Time to BMI

ggplot ((mody_calc_cohort_local %>% filter(bmi_post_diag_datediff_yrs>-3)), aes(x=bmi_post_diag_datediff_yrs, fill=diabetes_type)) + 
  geom_histogram(aes(y = after_stat(count / sum(count))), binwidth=0.05) +
  scale_y_continuous(labels = scales::percent) +
  xlab("Years from BMI to current date") +
  ylab("Percentage")


mody_calc_cohort_local <- mody_calc_cohort_local %>%
  mutate(bmi_in_6_mos=bmi_post_diag_datediff_yrs>=-0.5,
         bmi_in_1_yr=bmi_post_diag_datediff_yrs>=-1,
         bmi_in_2_yrs=bmi_post_diag_datediff_yrs>=-2,
         bmi_in_5_yrs=bmi_post_diag_datediff_yrs>=-5)

prop.table(table(mody_calc_cohort_local$bmi_in_6_mos))
prop.table(table(mody_calc_cohort_local$diabetes_type, mody_calc_cohort_local$bmi_in_6_mos), margin=1)

prop.table(table(mody_calc_cohort_local$bmi_in_1_yr))
prop.table(table(mody_calc_cohort_local$diabetes_type, mody_calc_cohort_local$bmi_in_1_yr), margin=1)

prop.table(table(mody_calc_cohort_local$bmi_in_2_yrs))
prop.table(table(mody_calc_cohort_local$diabetes_type, mody_calc_cohort_local$bmi_in_2_yrs), margin=1)

prop.table(table(mody_calc_cohort_local$bmi_in_5_yrs))
prop.table(table(mody_calc_cohort_local$diabetes_type, mody_calc_cohort_local$bmi_in_5_yrs), margin=1)



## Current insulin

prop.table(table(mody_calc_cohort_local$current_insulin))
prop.table(table(mody_calc_cohort_local$diabetes_type, mody_calc_cohort_local$current_insulin), margin=1)



## Family history

prop.table(table(mody_calc_cohort_local$fh_diabetes))
prop.table(table(mody_calc_cohort_local$diabetes_type, mody_calc_cohort_local$fh_diabetes), margin=1)

prop.table(table(mody_calc_cohort_local$fh_diabetes, useNA="always"))
prop.table(table(mody_calc_cohort_local$diabetes_type, mody_calc_cohort_local$fh_diabetes, useNA="always"), margin=1)



## Time since last type code

mody_calc_cohort_local %>% summarise(median_time=median(days_since_type_code))
mody_calc_cohort_local %>% group_by(diabetes_type) %>% summarise(median_time=median(days_since_type_code))



## MODY code history

mody_calc_cohort_local <- mody_calc_cohort_local %>%
  mutate(mody_code_hist=mody_code_count>1)

table(mody_calc_cohort_local$mody_code_hist)
table(mody_calc_cohort_local$diabetes_type, mody_calc_cohort_local$mody_code_hist)

prop.table(table(mody_calc_cohort_local$mody_code_hist))
prop.table(table(mody_calc_cohort_local$diabetes_type, mody_calc_cohort_local$mody_code_hist), margin=1)


rm(mody_calc_cohort_local)


############################################################################################

# Look at inclusions from using different rules to decide which equation

mody_calc_cohort <- mody_calc_cohort %>% mutate(diabetes_type_new=ifelse(diabetes_type=="type 1" | diabetes_type=="mixed; type 1", "Type 1", "Type 2"))

mody_calc_cohort %>% count()
#65172

mody_calc_cohort %>% group_by(diabetes_type_new) %>% count()
#Type 1              29062
#Type 2              36110


mody_calc_cohort %>% filter(dm_diag_age<18 | (current_insulin==1 & current_mfn==0 & current_su==0 & current_dpp4==0 & current_sglt2==0 & current_glp1==0 & current_tzd==0)) %>% count()
#30092
30092/65172

mody_calc_cohort %>% filter(dm_diag_age<18 | (current_insulin==1 & current_mfn==0 & current_su==0 & current_dpp4==0 & current_sglt2==0 & current_glp1==0 & current_tzd==0)) %>% group_by(diabetes_type_new) %>% count()
#Type 1              26597
#Type 2               3495
26597/30092
(36110-3495)/36110


mody_calc_cohort %>% filter(current_insulin==1 & current_mfn==0 & current_su==0 & current_dpp4==0 & current_sglt2==0 & current_glp1==0 & current_tzd==0) %>% count()
#27354
27354/65172

mody_calc_cohort %>% filter(current_insulin==1 & current_mfn==0 & current_su==0 & current_dpp4==0 & current_sglt2==0 & current_glp1==0 & current_tzd==0) %>% group_by(diabetes_type_new) %>% count()
#Type 1              24790
#Type 2               2564
24790/27354
(36110-2564)/36110


mody_calc_cohort %>% filter(current_insulin_12m==1 & current_mfn==0 & current_su==0 & current_dpp4==0 & current_sglt2==0 & current_glp1==0 & current_tzd==0) %>% count()
#27844
27844/65172

mody_calc_cohort %>% filter(current_insulin_12m==1 & current_mfn==0 & current_su==0 & current_dpp4==0 & current_sglt2==0 & current_glp1==0 & current_tzd==0) %>% group_by(diabetes_type_new) %>% count()
#Type 1              25125
#Type 2               2719
25125/27844
(36110-2719)/36110

  
mody_calc_cohort %>% filter(current_insulin_12m==1 & current_mfn==0 & current_su==0 & current_dpp4==0 & current_sglt2==0 & current_glp1==0 & current_tzd==0) %>% count()
#27844
27844/65172

mody_calc_cohort %>% filter(current_insulin_12m==1 & current_mfn==0 & current_su==0 & current_dpp4==0 & current_sglt2==0 & current_glp1==0 & current_tzd==0) %>% group_by(diabetes_type_new) %>% count()
#Type 1              25125
#Type 2               2719
25125/27844
(36110-2719)/36110


mody_calc_cohort %>% filter((current_insulin_12m==1 & current_mfn==0 & current_su==0 & current_dpp4==0 & current_sglt2==0 & current_glp1==0 & current_tzd==0) | ((diabetes_type=="type 1" | diabetes_type=="mixed; type 1") & dm_diag_age<10 & hba1c_post_diag>58) | ((diabetes_type=="type 1" | diabetes_type=="mixed; type 1") & dm_diag_age<25 & current_insulin_12m==1 & current_mfn==1 & current_su==0 & current_dpp4==0 & current_sglt2==0 & current_glp1==0 & current_tzd==0)) %>% count()
#29617
29617/65172

mody_calc_cohort %>% filter((current_insulin_12m==1 & current_mfn==0 & current_su==0 & current_dpp4==0 & current_sglt2==0 & current_glp1==0 & current_tzd==0) | ((diabetes_type=="type 1" | diabetes_type=="mixed; type 1") & dm_diag_age<10 & hba1c_post_diag>58) | ((diabetes_type=="type 1" | diabetes_type=="mixed; type 1") & dm_diag_age<25 & current_insulin_12m==1 & current_mfn==1 & current_su==0 & current_dpp4==0 & current_sglt2==0 & current_glp1==0 & current_tzd==0)) %>% group_by(diabetes_type_new) %>% count()
#Type 1              26898
#Type 2               2719
26898/29617
(36110-2719)/36110


############################################################################################

# Run MODY calculator

## First add in MODY group

## Use diagnosis age and current medication as proxy for whether on insulin within 6 months of diagnosis (which determines which equation is run):
### If diagnosed <18, assume on insulin within 6 months of diagnosis
### If diagnosed >=18 and currently on insulin only (no OHAs), assume on insulin within 6 months of diagnosis

## If missing family history, run twice (assume negative and then assume positive)

## Do use prevalence adjustments from referrals (final probability will not be correct for this population, but relative to other equation will be)


mody_calc_results <- mody_calc_cohort %>%
  
#  union(mody_diag) %>%
 
  mutate(fh_diabetes0=ifelse(is.na(fh_diabetes), 0L, fh_diabetes),
         fh_diabetes1=ifelse(is.na(fh_diabetes), 1L, fh_diabetes),
         
         hba1c_post_diag_perc=(0.09148*hba1c_post_diag)+2.152,
         
         which_equation=ifelse((current_insulin==1 & current_mfn==0 & current_su==0 & current_dpp4==0 & current_sglt2==0 & current_glp1==0 & current_tzd==0) | ((diabetes_type=="type 1" | diabetes_type=="mixed; type 1") & dm_diag_age<10 & hba1c_post_diag>58) | ((diabetes_type=="type 1" | diabetes_type=="mixed; type 1") & dm_diag_age<25 & current_insulin==1 & current_mfn==1 & current_su==0 & current_dpp4==0 & current_sglt2==0 & current_glp1==0 & current_tzd==0), "t1", "t2"),
         
         mody_logOR_fh0=ifelse(which_equation=="t1", 1.8196 + (3.1404*fh_diabetes0) - (0.0829*age_at_index) - (0.6598*hba1c_post_diag_perc) + (0.1011*dm_diag_age) + (1.3131*gender),
                               19.28 - (0.3154*dm_diag_age) - (0.2324*bmi_post_diag) - (0.6276*hba1c_post_diag_perc) + (1.7473*fh_diabetes0) - (0.0352*age_at_index) - (0.9952*insoha) + (0.6943*gender)),
         
         mody_logOR_fh1=ifelse(which_equation=="t1", 1.8196 + (3.1404*fh_diabetes1) - (0.0829*age_at_index) - (0.6598*hba1c_post_diag_perc) + (0.1011*dm_diag_age) + (1.3131*gender),
                               19.28 - (0.3154*dm_diag_age) - (0.2324*bmi_post_diag) - (0.6276*hba1c_post_diag_perc) + (1.7473*fh_diabetes1) - (0.0352*age_at_index) - (0.9952*insoha) + (0.6943*gender)),
         
         
         across(contains("mody_logOR"),
                ~ (exp(.)/(1+exp(.)))*100,
                .names="{sub('mody_logOR', 'mody_prob', col)}"),
         
         across(contains("mody_prob"),
                ~ ifelse(which_equation=="t1", case_when(
                  . < 10 ~ 0.7,
                  . < 20 ~ 1.9,
                  . < 30 ~ 2.6,
                  . < 40 ~ 4.0,
                  . < 50 ~ 4.9,
                  . < 60 ~ 6.4,
                  . < 70 ~ 7.2,
                  . < 80 ~ 8.2,
                  . < 90 ~ 12.6,
                  . < 100 ~ 49.4
                ),
                case_when(
                  . < 10 ~ 4.6,
                  . < 20 ~ 15.1,
                  . < 30 ~ 21.0,
                  . < 40 ~ 24.4,
                  . < 50 ~ 32.9,
                  . < 60 ~ 35.8,
                  . < 70 ~ 45.5,
                  . < 80 ~ 58.0,
                  . < 90 ~ 62.4,
                  . < 100 ~ 75.5
                )),
                .names="{sub('mody_prob', 'mody_adj_prob', col)}")) %>%
  
  analysis$cached("mody_calc_results", unique_indexes="patid")

         
mody_diag_mody_calc_results <-  cohort %>%
  filter(dm_diag_age>=1 & dm_diag_age<36 & (diabetes_type=="mody" | diabetes_type=="mixed; mody") & !is.na(diagnosis_date)) %>%
  mutate(hba1c_post_diag=ifelse(hba1cdate>=diagnosis_date, hba1c, NA),
         hba1c_post_diag_datediff=ifelse(!is.na(hba1c_post_diag), hba1cindexdiff, NA),
         age_at_bmi=datediff(bmidate, dob)/365.25,
         bmi_post_diag=ifelse(bmidate>=diagnosis_date & age_at_bmi>=18, bmi, NA),
         bmi_post_diag_datediff=ifelse(!is.na(bmi_post_diag), bmiindexdiff, NA),
         insoha=ifelse(current_oha==1 | current_insulin==1, 1L, 0L)) %>%
  filter(!is.na(bmi_post_diag) & !is.na(hba1c_post_diag)) %>%
  mutate(fh_diabetes0=ifelse(is.na(fh_diabetes), 0L, fh_diabetes),
         fh_diabetes1=ifelse(is.na(fh_diabetes), 1L, fh_diabetes),
         
         hba1c_post_diag_perc=(0.09148*hba1c_post_diag)+2.152,
         
         which_equation=ifelse((current_insulin==1 & current_mfn==0 & current_su==0 & current_dpp4==0 & current_sglt2==0 & current_glp1==0 & current_tzd==0) | ((diabetes_type=="type 1" | diabetes_type=="mixed; type 1") & dm_diag_age<10 & hba1c_post_diag>58) | ((diabetes_type=="type 1" | diabetes_type=="mixed; type 1") & dm_diag_age<25 & current_insulin==1 & current_mfn==1 & current_su==0 & current_dpp4==0 & current_sglt2==0 & current_glp1==0 & current_tzd==0), "t1", "t2"),
         
         mody_logOR_fh0=ifelse(which_equation=="t1", 1.8196 + (3.1404*fh_diabetes0) - (0.0829*age_at_index) - (0.6598*hba1c_post_diag_perc) + (0.1011*dm_diag_age) + (1.3131*gender),
                               19.28 - (0.3154*dm_diag_age) - (0.2324*bmi_post_diag) - (0.6276*hba1c_post_diag_perc) + (1.7473*fh_diabetes0) - (0.0352*age_at_index) - (0.9952*insoha) + (0.6943*gender)),
         
         mody_logOR_fh1=ifelse(which_equation=="t1", 1.8196 + (3.1404*fh_diabetes1) - (0.0829*age_at_index) - (0.6598*hba1c_post_diag_perc) + (0.1011*dm_diag_age) + (1.3131*gender),
                               19.28 - (0.3154*dm_diag_age) - (0.2324*bmi_post_diag) - (0.6276*hba1c_post_diag_perc) + (1.7473*fh_diabetes1) - (0.0352*age_at_index) - (0.9952*insoha) + (0.6943*gender)),
         
         
         across(contains("mody_logOR"),
                ~ (exp(.)/(1+exp(.)))*100,
                .names="{sub('mody_logOR', 'mody_prob', col)}"),
         
         across(contains("mody_prob"),
                ~ ifelse(which_equation=="t1", case_when(
                  . < 10 ~ 0.7,
                  . < 20 ~ 1.9,
                  . < 30 ~ 2.6,
                  . < 40 ~ 4.0,
                  . < 50 ~ 4.9,
                  . < 60 ~ 6.4,
                  . < 70 ~ 7.2,
                  . < 80 ~ 8.2,
                  . < 90 ~ 12.6,
                  . < 100 ~ 49.4
                ),
                case_when(
                  . < 10 ~ 4.6,
                  . < 20 ~ 15.1,
                  . < 30 ~ 21.0,
                  . < 40 ~ 24.4,
                  . < 50 ~ 32.9,
                  . < 60 ~ 35.8,
                  . < 70 ~ 45.5,
                  . < 80 ~ 58.0,
                  . < 90 ~ 62.4,
                  . < 100 ~ 75.5
                )),
                .names="{sub('mody_prob', 'mody_adj_prob', col)}")) %>%
  
  analysis$cached("mody_diag_mody_calc_results", unique_indexes="patid")
  


# Mean adjusted probability per group: use fh0

mody_calc_results_local <- mody_calc_results %>%
  union_all(mody_diag_mody_calc_results) %>%
  select(diabetes_type, dm_diag_age, current_insulin, current_oha, starts_with("mody"), ethnicity_5cat, which_equation) %>%
  collect() %>%
  mutate(diabetes_type=factor(diabetes_type, levels=c("type 1", "type 2", "mixed; type 1", "mixed; type 2", "mody", "mixed; mody")),
         diabetes_type_new=factor(ifelse(diabetes_type=="type 1" | diabetes_type=="mixed; type 1", "Type 1",
                              ifelse(diabetes_type=="type 2" | diabetes_type=="mixed; type 2", "Type 2", "MODY")), levels=c("MODY", "Type 2", "Type 1")),
         no_treatment=ifelse(current_insulin==0 & current_oha==0, 1, 0),
         diag_under_18=ifelse(dm_diag_age<18, 1, 0),
         current_insulin=as.factor(current_insulin))




# By actual diabetes type including mixed groups separately (for Github repo)- also separate by ethnicity

## Overall
mody_calc_results_local %>% filter(diabetes_type!="mody" & diabetes_type!="mixed; mody") %>% summarise(mean_adjusted=mean(mody_adj_prob_fh0))
mody_calc_results_local %>% group_by(diabetes_type) %>% summarise(mean_adjusted=mean(mody_adj_prob_fh0))


## Overall non-missing White ethnicity
mody_calc_results_local %>% filter(!is.na(ethnicity_5cat) & ethnicity_5cat==0) %>% summarise(mean_adjusted=mean(mody_adj_prob_fh0), count=n())
mody_calc_results_local %>% filter(!is.na(ethnicity_5cat) & ethnicity_5cat==0) %>% group_by(diabetes_type) %>% summarise(mean_adjusted=mean(mody_adj_prob_fh0), count=n())


## Overall non-missing non-White ethnicity
mody_calc_results_local %>% filter(!is.na(ethnicity_5cat) & ethnicity_5cat!=0) %>% summarise(mean_adjusted=mean(mody_adj_prob_fh0), count=n())
mody_calc_results_local %>% filter(!is.na(ethnicity_5cat) & ethnicity_5cat!=0) %>% group_by(diabetes_type) %>% summarise(mean_adjusted=mean(mody_adj_prob_fh0), count=n())


# Plot unadjusted probability

ggplot((mody_calc_results_local %>% filter(diabetes_type!="mody" & diabetes_type!="mixed; mody")), aes(x=mody_prob_fh0, fill=diabetes_type, color=diabetes_type)) +
  geom_histogram(binwidth=1) +
  xlab("MODY unadjusted probability (%)")




# Grouping mixed and single-code groups together for slides
table(mody_calc_results_local$diabetes_type_new)

table(mody_calc_results_local$diabetes_type_new, mody_calc_results_local$diag_under_18)
prop.table(table(mody_calc_results_local$diabetes_type_new, mody_calc_results_local$diag_under_18), margin=1)

table(mody_calc_results_local$diabetes_type_new, mody_calc_results_local$current_insulin)
prop.table(table(mody_calc_results_local$diabetes_type_new, mody_calc_results_local$current_insulin), margin=1)

table(mody_calc_results_local$diabetes_type_new, mody_calc_results_local$no_treatment)
prop.table(table(mody_calc_results_local$diabetes_type_new, mody_calc_results_local$no_treatment), margin=1)

mody_calc_results_local %>% group_by(diabetes_type_new) %>% summarise(mean_adjusted=mean(mody_adj_prob_fh0))

mody_calc_results_local %>% group_by(diabetes_type_new) %>% summarise(mean_unadjusted=mean(mody_prob_fh0))

ggplot(mody_calc_results_local, aes(mody_adj_prob_fh0, fill=diabetes_type_new)) +
  geom_histogram(
    aes(y=after_stat(c(
      count[group==1]/sum(count[group==1]),
      count[group==2]/sum(count[group==2]),
      count[group==3]/sum(count[group==3])
    )*100)),
    binwidth=1
  ) +
  scale_fill_manual(values=c("#00BFC4", "#F8766D", "#7CAE00")) +
  guides(fill=guide_legend(title="Diabetes type")) +
  theme(text = element_text(size = 22)) +
  ylab("Percentage by diabetes type") + xlab("Adjusted MODY probability (%)")


mody_calc_results_local <- mody_calc_results_local %>% filter(diabetes_type_new!="MODY")

ggplot(mody_calc_results_local, aes(mody_adj_prob_fh0, fill=diabetes_type_new)) +
  geom_histogram(binwidth=1) +
  scale_fill_manual(values=c("#00BFC4", "#F8766D", "#7CAE00")) +
  guides(fill=guide_legend(title="Diabetes type")) +
  theme(text = element_text(size = 18)) +
  ylab("Frequency") + xlab("Adjusted MODY probability (%)")


mody_calc_results_local <- mody_calc_results_local %>% filter(diabetes_type_new=="MODY")

ggplot(mody_calc_results_local, aes(mody_adj_prob_fh0, fill=diabetes_type)) +
  geom_histogram(binwidth=1) +
  scale_fill_manual(values=c("#00BFC4", "#F8766D", "#7CAE00")) +
  guides(fill=guide_legend(title="Diabetes type")) +
  theme(text = element_text(size = 18)) +
  ylab("Frequency") + xlab("Adjusted MODY probability (%)")






############################################################################################

# Look at those with adjusted probability >=75.5%

# If assume missing family history is negative (0)

## With MODY diagnosis
mody_calc_results_local %>% filter(mody_adj_prob_fh0>=75.5) %>% count()
#21


## T1 / T2                                  
mody_calc_results_local %>% filter(mody_adj_prob_fh0>=75.5) %>% count()
#704
704/65172 #1.1

mody_calc_results_local %>% group_by(diabetes_type) %>% count()
# 1 type 1        24113
# 2 type 2        27846
# 3 mixed; type 1  4949
# 4 mixed; type 2  8264

mody_calc_results_local %>% filter(mody_adj_prob_fh0>=75.5) %>% group_by(diabetes_type) %>% count()
# 1 type 1          106
# 2 type 2          365
# 3 mixed; type 1    26
# 4 mixed; type 2   207

106/24113 #0.4%
365/27846 #1.3%
26/4949 #0.5%
207/8264 #2.5%

mody_calc_results_local %>% filter(mody_adj_prob_fh0>=75.5) %>% group_by(diabetes_type_new) %>% count()
#Type 2              572
#Type 1              132
132/704 #18.8% T1

### With no treatment
mody_calc_results_local %>% filter(mody_adj_prob_fh0>=75.5 & no_treatment==1) %>% count()
#430
430/704 #61.1

### Ethnicity
#### Overall
mody_calc_results %>% filter(is.na(ethnicity_5cat) & (diabetes_type=="type 1" | diabetes_type=="mixed; type 1" | diabetes_type=="type 2" | diabetes_type=="mixed; type 2")) %>% count()
#1081
1081/65172 #1.7% missing

mody_calc_results %>% filter(ethnicity_5cat!=0 & (diabetes_type=="type 1" | diabetes_type=="mixed; type 1" | diabetes_type=="type 2" | diabetes_type=="mixed; type 2")) %>% count()
#17016
17016/65172 #26.2% non-white

#### High-scorere
mody_calc_results %>% filter(mody_adj_prob_fh0==75.5 & ethnicity_5cat!=0 & (diabetes_type=="type 1" | diabetes_type=="mixed; type 1" | diabetes_type=="type 2" | diabetes_type=="mixed; type 2")) %>% count()
#319
319/704 #45.3% non-White



# If assume missing family history is positive (1)

## T1 / T2                                  
mody_calc_results_local %>% filter(mody_adj_prob_fh0<75.5 & mody_adj_prob_fh1>=75.5) %>% count()
#442
442/65172 #0.7

mody_calc_results_local %>% filter(diabetes_type!="mody" & diabetes_type!="mixed; mody") %>% group_by(diabetes_type) %>% count()
# 1 type 1        24113
# 2 type 2        27846
# 3 mixed; type 1  4949
# 4 mixed; type 2  8264

mody_calc_results_local %>% filter(mody_adj_prob_fh0<75.5 & mody_adj_prob_fh1>=75.5) %>% group_by(diabetes_type) %>% count()
# 1 type 1          82
# 2 type 2          247
# 3 mixed; type 1    20
# 4 mixed; type 2   93

82/24113 #0.3%
247/27846 #0.9%
20/4949 #0.4%
93/8264 #1.1%

mody_calc_results_local %>% filter(mody_adj_prob_fh0<75.5 & mody_adj_prob_fh1>=75.5) %>% group_by(diabetes_type_new) %>% count()
#Type 2              340
#Type 1              102
102/442 #23.1% T1

### With no treatment
mody_calc_results_local %>% filter(mody_adj_prob_fh0<75.5 & mody_adj_prob_fh1>=75.5 & no_treatment==1) %>% count()
#238
238/442 #53.8%


############################################################################################

# Look at 20 example patients scoring highest adjusted probability

mody <- mody_calc_results %>%
  filter(mody_adj_prob_fh0>=58 & (diabetes_type=="type 1" | diabetes_type=="mixed; type 1" | diabetes_type=="type 2" | diabetes_type=="mixed; type 2")) %>%
  select(patid, dm_diag_age, bmi_post_diag, gender, age_at_index, starts_with("current"), fh_diabetes, hba1c_post_diag, diabetes_type, ethnicity_5cat,  diagnosis_date, earliest_ins, regstartdate, mody_prob_fh0, mody_adj_prob_fh0, contains("gad"), contains("ia2"), contains("c_pep"), ethnicity_5cat) %>%
  collect()

mody <- mody %>% sample_n(20)

clipr::write_clip(mody)


# Look at 20 example patients scoring highest adjusted probability on MODY vs Type 1 equation

mody <- mody_calc_results %>%
  filter(mody_adj_prob_fh0==49.4 & (diabetes_type=="type 1" | diabetes_type=="mixed; type 1" | diabetes_type=="type 2" | diabetes_type=="mixed; type 2")) %>%
  select(patid, dm_diag_age, bmi_post_diag, gender, age_at_index, starts_with("current"), fh_diabetes, diabetes_type, mody_prob_fh0, mody_adj_prob_fh0, contains("gad"), contains("ia2"), contains("c_pep"), diagnosis_date, earliest_ins, regstartdate, ethnicity_5cat, hba1c_post_diag) %>%
  collect()

mody <- mody %>% sample_n(20)


# Look at 20 where family history takes them over limit
## Using time to insulin >6 months if not known

mody <- mody_calc_results %>%
  filter(mody_adj_prob_fh0<75.5 & mody_adj_prob_fh1==75.5 & (diabetes_type=="type 1" | diabetes_type=="mixed; type 1" | diabetes_type=="type 2" | diabetes_type=="mixed; type 2")) %>%
  select(patid, dm_diag_age, bmi_post_diag, gender, age_at_index, starts_with("current"), fh_diabetes, diabetes_type, mody_prob_fh0, mody_adj_prob_fh0, mody_prob_fh1, mody_adj_prob_fh1, contains("gad"), contains("ia2"), contains("c_pep"), diagnosis_date, earliest_ins, regstartdate, ethnicity_5cat, hba1c_post_diag) %>%
  collect()

mody <- mody %>% sample_n(20)


############################################################################################

# Counts reaching different adjusted probability thresholds

## 75.5
mody_calc_results %>% filter(mody_adj_prob_fh0>=75.5) %>% count()
#1408
(1408/9900000)*1000 #0.14
(1408/9900000)*7900 #1.1
(1408/9900000)*15800 #2.2

mody_calc_results %>% filter(mody_adj_prob_fh0<75.5 & mody_adj_prob_fh1>=75.5) %>% count()
#554
(554/9900000)*1000 #0.056
(554/9900000)*7900 #0.4
(554/9900000)*15800 #0.9


## 62.4%
mody_calc_results %>% filter(mody_adj_prob_fh0>=62.4) %>% count()
#2097
(2097/9900000)*1000 #0.21
(2097/9900000)*7900 #1.7
(2097/9900000)*15800 #3.3

mody_calc_results %>% filter(mody_adj_prob_fh0<62.4 & mody_adj_prob_fh1>=62.4) %>% count()
#797
(797/9900000)*1000 #0.081
(797/9900000)*7900 #0.6
(797/9900000)*15800 #1.3


## 58.0%
mody_calc_results %>% filter(mody_adj_prob_fh0>=58) %>% count()
#2751
(2751/65172)*0.00724*1000 #0.31
(2751/9900000)*7900 #2.2
(2751/9900000)*15800 #4.4

mody_calc_results %>% filter(mody_adj_prob_fh0<58 & mody_adj_prob_fh1>=58) %>% count()
#1037
(1037/9900000)*1000 #0.10
(1037/9900000)*7900 #0.8
(1037/9900000)*15800 #1.7


## 45.5%
mody_calc_results %>% filter(mody_adj_prob_fh0>=45.5) %>% count()
#3748
(3748/9900000)*1000 #0.38
(3748/9900000)*7900 #3.0
(3748/9900000)*15800 #6.0

mody_calc_results %>% filter(mody_adj_prob_fh0<45.5 & mody_adj_prob_fh1>=45.5) %>% count()
#2123
(2123/9900000)*1000 #0.21
(2123/9900000)*7900 #1.7
(2123/9900000)*15800 #3.4



############################################################################################

# Look at ethnicity overall and in high scorers

mody_calc_results_local <- mody_calc_results %>% filter(diabetes_type!="mody" & diabetes_type!="mixed; mody") %>% select(ethnicity_5cat, current_insulin, current_mfn, current_su, current_dpp4, current_sglt2, current_glp1, current_tzd, mody_adj_prob_fh0) %>% collect()

## Overall
prop.table(table(mody_calc_results_local$ethnicity_5cat, useNA="always"))

## T2 equation
prop.table(table((mody_calc_results_local %>% filter(!(current_insulin==1 & current_mfn==0 & current_su==0 & current_dpp4==0 & current_sglt2==0 & current_glp1==0 & current_tzd==0)))$ethnicity_5cat, useNA="always"))

## Adjusted prob 75.5%
prop.table(table((mody_calc_results_local %>% filter(mody_adj_prob_fh0==75.5))$ethnicity_5cat, useNA="always"))

## Adjusted prob >=62.4
prop.table(table((mody_calc_results_local %>% filter(mody_adj_prob_fh0==62.4))$ethnicity_5cat, useNA="always"))

## Adjusted prob >=58.0
prop.table(table((mody_calc_results_local %>% filter(mody_adj_prob_fh0==58))$ethnicity_5cat, useNA="always"))

