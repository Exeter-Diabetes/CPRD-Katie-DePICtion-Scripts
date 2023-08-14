
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

cohort <- cohort %>% analysis$cached("cohort_with_flags")


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

# Run MODY calculator

## First add in MODY group
## For those diagnosed >=18, run both branches of model

mody_diag <- cohort %>%
  filter(dm_diag_age>=1 & dm_diag_age<36 & (diabetes_type=="mody" | diabetes_type=="mixed; mody") & !is.na(diagnosis_date)) %>%
  mutate(hba1c_post_diag=ifelse(hba1cdate>=diagnosis_date, hba1c, NA),
         hba1c_post_diag_datediff=ifelse(!is.na(hba1c_post_diag), hba1cindexdiff, NA),
         age_at_bmi=datediff(bmidate, dob)/365.25,
         bmi_post_diag=ifelse(bmidate>=diagnosis_date & age_at_bmi>=18, bmi, NA),
         bmi_post_diag_datediff=ifelse(!is.na(bmi_post_diag), bmiindexdiff, NA),
         insoha=ifelse(current_oha==1 | current_insulin==1, 1L, 0L)) %>%
  filter(!is.na(bmi_post_diag) & !is.na(hba1c_post_diag))

mody_diag %>% group_by(diabetes_type) %>% summarise(count=n())



mody_calc_results <- mody_calc_cohort %>%
  
  union(mody_diag) %>%
 
  mutate(fh_diabetes0=ifelse(is.na(fh_diabetes), 0L, fh_diabetes),
         fh_diabetes1=ifelse(is.na(fh_diabetes), 1L, fh_diabetes),
         
         hba1c_post_diag_perc=(0.09148*hba1c_post_diag)+2.152,
         
         mody_logOR_fh0_over18ins0=ifelse(dm_diag_age<18, 1.8196 + (3.1404*fh_diabetes0) - (0.0829*age_at_index) - (0.6598*hba1c_post_diag_perc) + (0.1011*dm_diag_age) + (1.3131*gender),
                                          19.28 - (0.3154*dm_diag_age) - (0.2324*bmi_post_diag) - (0.6276*hba1c_post_diag_perc) + (1.7473*fh_diabetes0) - (0.0352*age_at_index) - (0.9952*insoha) + (0.6943*gender)),
         
         mody_logOR_fh0_over18ins1=ifelse(dm_diag_age<18 | current_insulin==1, 1.8196 + (3.1404*fh_diabetes0) - (0.0829*age_at_index) - (0.6598*hba1c_post_diag_perc) + (0.1011*dm_diag_age) + (1.3131*gender),
                                          19.28 - (0.3154*dm_diag_age) - (0.2324*bmi_post_diag) - (0.6276*hba1c_post_diag_perc) + (1.7473*fh_diabetes0) - (0.0352*age_at_index) - (0.9952*insoha) + (0.6943*gender)),
         
         mody_logOR_fh1_over18ins0=ifelse(dm_diag_age<18, 1.8196 + (3.1404*fh_diabetes1) - (0.0829*age_at_index) - (0.6598*hba1c_post_diag_perc) + (0.1011*dm_diag_age) + (1.3131*gender),
                                          19.28 - (0.3154*dm_diag_age) - (0.2324*bmi_post_diag) - (0.6276*hba1c_post_diag_perc) + (1.7473*fh_diabetes1) - (0.0352*age_at_index) - (0.9952*insoha) + (0.6943*gender)),
         
         mody_logOR_fh1_over18ins1=ifelse(dm_diag_age<18 | current_insulin==1, 1.8196 + (3.1404*fh_diabetes1) - (0.0829*age_at_index) - (0.6598*hba1c_post_diag_perc) + (0.1011*dm_diag_age) + (1.3131*gender),
                                          19.28 - (0.3154*dm_diag_age) - (0.2324*bmi_post_diag) - (0.6276*hba1c_post_diag_perc) + (1.7473*fh_diabetes1) - (0.0352*age_at_index) - (0.9952*insoha) + (0.6943*gender)),
         
         across(contains("mody_logOR"),
                ~ (exp(.)/(1+exp(.)))*100,
                .names="{sub('mody_logOR', 'mody_prob', col)}"),
         
         across(contains("mody_prob"),
                ~ ifelse(dm_diag_age<18, case_when(
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

         

# Mean adjusted probability per group: use fh0 and both ins0 and ins1 - plot ins0 only (assumes family history = 0 if missing, and on insulin within 6 months = 0 if diagnosed >=18 years and currently on insulin)

mody_calc_results_local <- mody_calc_results %>%
  select(diabetes_type, dm_diag_age, current_insulin, current_oha, current_dpp4glp1sutzd, starts_with("mody"), ethnicity_5cat) %>%
  collect() %>%
  mutate(diabetes_type=factor(diabetes_type, levels=c("type 1", "type 2", "mixed; type 1", "mixed; type 2", "mody", "mixed; mody")),
         diabetes_type_new=factor(ifelse(diabetes_type=="type 1" | diabetes_type=="mixed; type 1", "Type 1",
                              ifelse(diabetes_type=="type 2" | diabetes_type=="mixed; type 2", "Type 2", "MODY")), levels=c("MODY", "Type 2", "Type 1")),
         no_treatment=ifelse(current_insulin==0 & current_oha==0, 1, 0),
         diag_under_18=ifelse(dm_diag_age<18, 1, 0),
         current_insulin=as.factor(current_insulin))




# By actual diabetes type including mixed groups separately (for Github repo)- also separate by ethnicity

## Overall
mody_calc_results_local %>% filter(diabetes_type!="mody" & diabetes_type!="mixed; mody") %>% summarise(mean_adjusted=mean(mody_adj_prob_fh0_over18ins0))
mody_calc_results_local %>% group_by(diabetes_type) %>% summarise(mean_adjusted=mean(mody_adj_prob_fh0_over18ins0))

mody_calc_results_local %>% filter(diabetes_type!="mody" & diabetes_type!="mixed; mody") %>% summarise(mean_adjusted=mean(mody_adj_prob_fh0_over18ins1))
mody_calc_results_local %>% group_by(diabetes_type) %>% summarise(mean_adjusted=mean(mody_adj_prob_fh0_over18ins1))

## Overall non-missing White ethnicity
mody_calc_results_local %>% filter(diabetes_type!="mody" & diabetes_type!="mixed; mody" & !is.na(ethnicity_5cat) & ethnicity_5cat==0) %>% summarise(mean_adjusted=mean(mody_adj_prob_fh0_over18ins0), count=n())
mody_calc_results_local %>% filter(!is.na(ethnicity_5cat) & ethnicity_5cat==0) %>% group_by(diabetes_type) %>% summarise(mean_adjusted=mean(mody_adj_prob_fh0_over18ins0), count=n())

mody_calc_results_local %>% filter(diabetes_type!="mody" & diabetes_type!="mixed; mody" & !is.na(ethnicity_5cat) & ethnicity_5cat==0) %>% summarise(mean_adjusted=mean(mody_adj_prob_fh0_over18ins1), count=n())
mody_calc_results_local %>% filter(!is.na(ethnicity_5cat) & ethnicity_5cat==0) %>% group_by(diabetes_type) %>% summarise(mean_adjusted=mean(mody_adj_prob_fh0_over18ins1), count=n())

## Overall non-missing non-White ethnicity
mody_calc_results_local %>% filter(diabetes_type!="mody" & diabetes_type!="mixed; mody" & !is.na(ethnicity_5cat) & ethnicity_5cat!=0) %>% summarise(mean_adjusted=mean(mody_adj_prob_fh0_over18ins0), count=n())
mody_calc_results_local %>% filter(!is.na(ethnicity_5cat) & ethnicity_5cat!=0) %>% group_by(diabetes_type) %>% summarise(mean_adjusted=mean(mody_adj_prob_fh0_over18ins0), count=n())

mody_calc_results_local %>% filter(diabetes_type!="mody" & diabetes_type!="mixed; mody" & !is.na(ethnicity_5cat) & ethnicity_5cat!=0) %>% summarise(mean_adjusted=mean(mody_adj_prob_fh0_over18ins1), count=n())
mody_calc_results_local %>% filter(!is.na(ethnicity_5cat) & ethnicity_5cat!=0) %>% group_by(diabetes_type) %>% summarise(mean_adjusted=mean(mody_adj_prob_fh0_over18ins1), count=n())

# Plot unadjusted probability

ggplot((mody_calc_results_local %>% filter(diabetes_type!="mody" & diabetes_type!="mixed; mody")), aes(x=mody_prob_fh0_over18ins0, fill=diabetes_type, color=diabetes_type)) +
  geom_histogram(binwidth=1) +
  xlab("MODY unadjusted probability (%)")

ggplot((mody_calc_results_local %>% filter(diabetes_type=="mody" | diabetes_type=="mixed; mody")), aes(x=mody_prob_fh0_over18ins0, fill=diabetes_type, color=diabetes_type)) +
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

mody_calc_results_local %>% group_by(diabetes_type_new) %>% summarise(mean_adjusted=mean(mody_adj_prob_fh0_over18ins0))
mody_calc_results_local %>% group_by(diabetes_type_new) %>% summarise(mean_adjusted=mean(mody_adj_prob_fh0_over18ins1))

mody_calc_results_local %>% group_by(diabetes_type_new) %>% summarise(mean_unadjusted=mean(mody_prob_fh0_over18ins0))
mody_calc_results_local %>% group_by(diabetes_type_new) %>% summarise(mean_unadjusted=mean(mody_prob_fh0_over18ins1))

ggplot(mody_calc_results_local, aes(mody_prob_fh0_over18ins0, fill=diabetes_type_new)) +
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
  ylab("Percentage by diabetes type") + xlab("Unadjusted MODY probability (%)")


############################################################################################

# Look at those with unadjusted probability >95%

## With MODY diagnosis
mody_calc_results_local %>% filter((diabetes_type=="mody" | diabetes_type=="mixed; mody") & (mody_prob_fh1_over18ins0>95 | mody_prob_fh1_over18ins1>95)) %>% count()
#23


## Either model probability over 95% if assume missing family history is 0                                   
mody_calc_results_local %>% filter(diabetes_type!="mody" & diabetes_type!="mixed; mody" & (mody_prob_fh0_over18ins0>95 | mody_prob_fh0_over18ins1>95)) %>% count()
#876
876/67084 #1.3
876/65172 #1.3

mody_calc_results_local %>% filter(diabetes_type!="mody" & diabetes_type!="mixed; mody") %>% group_by(diabetes_type) %>% count()
# 1 type 1        24113
# 2 type 2        27846
# 3 mixed; type 1  4949
# 4 mixed; type 2  8264

mody_calc_results_local %>% filter(diabetes_type!="mody" & diabetes_type!="mixed; mody" & (mody_prob_fh0_over18ins0>95 | mody_prob_fh0_over18ins1>95)) %>% group_by(diabetes_type) %>% count()
# 1 type 1          358
# 2 type 2          301
# 3 mixed; type 1    52
# 4 mixed; type 2   165

358/24113 #1.5%
301/27846 #1.1%
52/4949 #1.1%
165/8264 #2.0%


### With no treatment
mody_calc_results_local %>% filter(diabetes_type!="mody" & diabetes_type!="mixed; mody" & (mody_prob_fh0_over18ins0>95 | mody_prob_fh0_over18ins1>95) & no_treatment==1) %>% count()
#273
273/876 #31.2


mody_calc_results_local %>% filter(diabetes_type!="mody" & diabetes_type!="mixed; mody" & (mody_prob_fh0_over18ins0>95 | mody_prob_fh0_over18ins1>95)) %>% group_by(diabetes_type_new) %>% count()
#Type 2              466
#Type 1              410
410/876



## Both probabilities over 95% if assume missing family history is 1
mody_calc_results_local %>% filter(diabetes_type!="mody" & diabetes_type!="mixed; mody" & mody_prob_fh0_over18ins0<95 & mody_prob_fh0_over18ins1<95 & (mody_prob_fh1_over18ins0>95 | mody_prob_fh1_over18ins1>95)) %>% count()
#1174
1174/67084 #1.8

mody_calc_results_local %>% filter(diabetes_type!="mody" & diabetes_type!="mixed; mody" & mody_prob_fh0_over18ins0<95 & mody_prob_fh0_over18ins1<95 & (mody_prob_fh1_over18ins0>95 | mody_prob_fh1_over18ins1>95) & no_treatment==1) %>% count()
#186
186/1174 #16


mody_calc_results_local %>% filter(diabetes_type!="mody" & diabetes_type!="mixed; mody" & mody_prob_fh0_over18ins0<95 & mody_prob_fh0_over18ins1<95 & (mody_prob_fh1_over18ins0>95 | mody_prob_fh1_over18ins1>95)) %>% group_by(diabetes_type_new) %>% count()
#Type 2              366
#Type 1              808
808/1174



## High on 1 model only
mody_calc_results_local %>% filter(diabetes_type!="mody" & diabetes_type!="mixed; mody" & ((mody_prob_fh0_over18ins0>95 & mody_prob_fh0_over18ins1<=95) | (mody_prob_fh0_over18ins0<=95 & mody_prob_fh0_over18ins1>95))) %>% count()
#471
471/876 #54

mody_calc_results_local %>% filter(diabetes_type!="mody" & diabetes_type!="mixed; mody" & (mody_prob_fh0_over18ins0>95 & mody_prob_fh0_over18ins1<=95)) %>% count()
#273

mody_calc_results_local %>% filter(diabetes_type!="mody" & diabetes_type!="mixed; mody" & (mody_prob_fh0_over18ins0<=95 & mody_prob_fh0_over18ins1>95)) %>% count()
#198

mody_calc_results_local %>% filter(diabetes_type!="mody" & diabetes_type!="mixed; mody" & (mody_prob_fh0_over18ins0>95 & mody_prob_fh0_over18ins1<=95) & current_dpp4glp1sutzd==1) %>% count()
#7 - not many



mody_calc_results_local %>% filter(diabetes_type!="mody" & diabetes_type!="mixed; mody" & mody_prob_fh0_over18ins0<=95 & mody_prob_fh0_over18ins1<=95 & ((mody_prob_fh1_over18ins0>95 & mody_prob_fh1_over18ins1<=95) | (mody_prob_fh1_over18ins0<=95 & mody_prob_fh1_over18ins1>95))) %>% count()
#798
798/1174 #68

mody_calc_results_local %>% filter(diabetes_type!="mody" & diabetes_type!="mixed; mody" & mody_prob_fh0_over18ins0<=95 & mody_prob_fh0_over18ins1<=95 & (mody_prob_fh1_over18ins0>95 & mody_prob_fh1_over18ins1<=95)) %>% count()
#544

mody_calc_results_local %>% filter(diabetes_type!="mody" & diabetes_type!="mixed; mody" & mody_prob_fh0_over18ins0<=95 & mody_prob_fh0_over18ins1<=95 & (mody_prob_fh1_over18ins0<=95 & mody_prob_fh1_over18ins1>95)) %>% count()
#254

mody_calc_results_local %>% filter(diabetes_type!="mody" & diabetes_type!="mixed; mody" & mody_prob_fh0_over18ins0<=95 & mody_prob_fh0_over18ins1<=95 & (mody_prob_fh1_over18ins0>95 & mody_prob_fh1_over18ins1<=95) & current_dpp4glp1sutzd==1) %>% count()
#6 - not many


############################################################################################

# Redo for 90%

## With MODY diagnosis
mody_calc_results_local %>% filter((diabetes_type=="mody" | diabetes_type=="mixed; mody") & (mody_prob_fh1_over18ins0>90 | mody_prob_fh1_over18ins1>90)) %>% count()
#44
44/105 #42


## Either probability over 90% if assume missing family history is 0                                   
mody_calc_results_local %>% filter(diabetes_type!="mody" & diabetes_type!="mixed; mody" & (mody_prob_fh0_over18ins0>90 | mody_prob_fh0_over18ins1>90)) %>% count()
#1906
1906/65172 #2.9

mody_calc_results_local %>% filter(diabetes_type!="mody" & diabetes_type!="mixed; mody" & (mody_prob_fh0_over18ins0>90 | mody_prob_fh0_over18ins1>90)) %>% group_by(diabetes_type) %>% count()
# 1 type 1          775
# 2 type 2          619
# 3 mixed; type 1    158
# 4 mixed; type 2   354

775/23756 #3.3%
619/24073 #2.6%
158/4764 #3.3%
354/7650 #4.6%



mody_calc_results_local %>% filter(diabetes_type!="mody" & diabetes_type!="mixed; mody" & (mody_prob_fh0_over18ins0>90 | mody_prob_fh0_over18ins1>90) & no_treatment==1) %>% count()
#475
475/1906 #25

mody_calc_results_local %>% filter(diabetes_type!="mody" & diabetes_type!="mixed; mody" & (mody_prob_fh0_over18ins0>90 | mody_prob_fh0_over18ins1>90)) %>% group_by(diabetes_type_new) %>% count()
#Type 2              973
#Type 1              933
973/1906



## Both probabilities over 90% if assume missing family history is 1
mody_calc_results_local %>% filter(diabetes_type!="mody" & diabetes_type!="mixed; mody" & mody_prob_fh0_over18ins0<90 & mody_prob_fh0_over18ins1<90 & (mody_prob_fh1_over18ins0>90 | mody_prob_fh1_over18ins1>90)) %>% count()
#2339
2339/65172 #3.6

mody_calc_results_local %>% filter(diabetes_type!="mody" & diabetes_type!="mixed; mody" & mody_prob_fh0_over18ins0<90 & mody_prob_fh0_over18ins1<90 & (mody_prob_fh1_over18ins0>90 | mody_prob_fh1_over18ins1>90) & no_treatment==1) %>% count()
#308
308/2339 #13


mody_calc_results_local %>% filter(diabetes_type!="mody" & diabetes_type!="mixed; mody" & mody_prob_fh0_over18ins0<90 & mody_prob_fh0_over18ins1<90 & (mody_prob_fh1_over18ins0>90 | mody_prob_fh1_over18ins1>90)) %>% group_by(diabetes_type_new) %>% count()
#Type 2              768
#Type 1              1571
1571/2339



## High on 1 model only
mody_calc_results_local %>% filter(diabetes_type!="mody" & diabetes_type!="mixed; mody" & ((mody_prob_fh0_over18ins0>90 & mody_prob_fh0_over18ins1<=90) | (mody_prob_fh0_over18ins0<=90 & mody_prob_fh0_over18ins1>90))) %>% count()
#1048
1048/1906 #55

mody_calc_results_local %>% filter(diabetes_type!="mody" & diabetes_type!="mixed; mody" & (mody_prob_fh0_over18ins0>90 & mody_prob_fh0_over18ins1<=90)) %>% count()
#596

mody_calc_results_local %>% filter(diabetes_type!="mody" & diabetes_type!="mixed; mody" & (mody_prob_fh0_over18ins0<=90 & mody_prob_fh0_over18ins1>90)) %>% count()
#452

mody_calc_results_local %>% filter(diabetes_type!="mody" & diabetes_type!="mixed; mody" & (mody_prob_fh0_over18ins0>90 & mody_prob_fh0_over18ins1<=90) & current_dpp4glp1sutzd==1) %>% count()
#18 - not many



mody_calc_results_local %>% filter(diabetes_type!="mody" & diabetes_type!="mixed; mody" & mody_prob_fh0_over18ins0<=90 & mody_prob_fh0_over18ins1<=90 & ((mody_prob_fh1_over18ins0>90 & mody_prob_fh1_over18ins1<=90) | (mody_prob_fh1_over18ins0<=90 & mody_prob_fh1_over18ins1>90))) %>% count()
#1465
1465/2339 #63

mody_calc_results_local %>% filter(diabetes_type!="mody" & diabetes_type!="mixed; mody" & mody_prob_fh0_over18ins0<=90 & mody_prob_fh0_over18ins1<=90 & (mody_prob_fh1_over18ins0>90 & mody_prob_fh1_over18ins1<=90)) %>% count()
#802

mody_calc_results_local %>% filter(diabetes_type!="mody" & diabetes_type!="mixed; mody" & mody_prob_fh0_over18ins0<=90 & mody_prob_fh0_over18ins1<=90 & (mody_prob_fh1_over18ins0<=90 & mody_prob_fh1_over18ins1>90)) %>% count()
#663

mody_calc_results_local %>% filter(diabetes_type!="mody" & diabetes_type!="mixed; mody" & mody_prob_fh0_over18ins0<=90 & mody_prob_fh0_over18ins1<=90 & (mody_prob_fh1_over18ins0>90 & mody_prob_fh1_over18ins1<=90) & current_dpp4glp1sutzd==1) %>% count()
#11 - not many


