
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

cohort %>% filter(dm_diag_age>=1 & dm_diag_age<=35) %>% count()
#87708


cohort %>% filter(dm_diag_age>=1 & dm_diag_age<=35 & (diabetes_type=="unspecified" | diabetes_type=="unspecified_with_primis")) %>% count()
#12544
12544/87708 #14.3%
87708-12544 #75164
75164/87708 #85.7

cohort %>% filter(dm_diag_age>=1 & dm_diag_age<=35 & (diabetes_type=="type 2" | diabetes_type=="mixed; type 2" | diabetes_type=="type 1" | diabetes_type=="mixed; type 1")) %>% count()
#64919
64919/75164 #86.4%

cohort %>% filter(dm_diag_age>=1 & dm_diag_age<=35 & (diabetes_type=="type 1" | diabetes_type=="mixed; type 1")) %>% count()
#30692
64919-30692 #34227

cohort %>% filter(dm_diag_age>=1 & dm_diag_age<=35 & (diabetes_type=="type 2" | diabetes_type=="mixed; type 2" | diabetes_type=="type 1" | diabetes_type=="mixed; type 1") & is.na(diagnosis_date)) %>% count()
#2874
2874/64919 #4.4

cohort %>% filter(dm_diag_age>=1 & dm_diag_age<=35 & (diabetes_type=="type 1" | diabetes_type=="mixed; type 1") & is.na(diagnosis_date)) %>% count()
#1140
2874-1140 #1734

cohort %>% filter(dm_diag_age>=1 & dm_diag_age<=35 & (diabetes_type=="type 2" | diabetes_type=="mixed; type 2" | diabetes_type=="type 1" | diabetes_type=="mixed; type 1") & !is.na(diagnosis_date)) %>% count()
#62045

cohort %>% filter(dm_diag_age>=1 & dm_diag_age<=35 & (diabetes_type=="type 1" | diabetes_type=="mixed; type 1") & !is.na(diagnosis_date)) %>% count()
#29552
62045-29552 #32493


# Define MODY cohort: patients diagnosed with a current Type 1 or Type 2 diagnosis, diagnosed aged 1-35, with valid diagnosis date and BMI/HbA1c before diagnosis

mody_calc_cohort <- cohort %>%
  filter(dm_diag_age>=1 & dm_diag_age<=35 & (diabetes_type=="type 1" | diabetes_type=="type 2" | diabetes_type=="mixed; type 1" | diabetes_type=="mixed; type 2") & !is.na(diagnosis_date)) %>%
  mutate(hba1c_post_diag=ifelse(hba1cdate>=diagnosis_date, hba1c, NA),
         hba1c_post_diag_datediff=ifelse(!is.na(hba1c_post_diag), hba1cindexdiff, NA),
         age_at_bmi=datediff(bmidate, dob)/365.25,
         bmi_post_diag=ifelse(bmidate>=diagnosis_date & age_at_bmi>=18, bmi, NA),
         bmi_post_diag_datediff=ifelse(!is.na(bmi_post_diag), bmiindexdiff, NA),
         insoha=ifelse(current_oha==1 | current_insulin==1, 1L, 0L)) %>%
  filter(!is.na(bmi_post_diag) & !is.na(hba1c_post_diag)) %>%
  analysis$cached("mody_calc_cohort", unique_indexes="patid")

mody_calc_cohort %>% count()
#60243
62045-60243 #1802
1802/62045 #2.9

mody_calc_cohort %>% group_by(diabetes_type) %>% count()
# type 1          23756
# type 2          24073
# mixed; type 2    7650
# mixed; type 1    4764
23756+4764 #28520
24073+7650 #31723

29552-28520 #1032 
32493-31723 #770


############################################################################################

# Look at variables

mody_calc_cohort_local <- mody_calc_cohort %>%
  select(diabetes_type, dm_diag_age, current_insulin, hba1c_post_diag_datediff, bmi_post_diag_datediff) %>%
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

ggplot ((mody_vars %>% filter(hba1c_post_diag_datediff_yrs>-3)), aes(x=hba1c_post_diag_datediff_yrs, fill=diabetes_type)) + 
  geom_histogram(aes(y = after_stat(count / sum(count))), binwidth=0.05) +
  scale_y_continuous(labels = scales::percent) +
  xlab("Years from HbA1c to current date") +
  ylab("Percentage")

mody_vars <- mody_vars %>%
  mutate(hba1c_in_6_mos=hba1c_post_diag_datediff_yrs>=-0.5,
         hba1c_in_1_yr=hba1c_post_diag_datediff_yrs>=-1,
         hba1c_in_2_yrs=hba1c_post_diag_datediff_yrs>=-2,
         hba1c_in_5_yrs=hba1c_post_diag_datediff_yrs>=-5)

prop.table(table(mody_vars$hba1c_in_6_mos))
prop.table(table(mody_vars$diabetes_type, mody_vars$hba1c_in_6_mos), margin=1)

prop.table(table(mody_vars$hba1c_in_1_yr))
prop.table(table(mody_vars$diabetes_type, mody_vars$hba1c_in_1_yr), margin=1)

prop.table(table(mody_vars$hba1c_in_2_yrs))
prop.table(table(mody_vars$diabetes_type, mody_vars$hba1c_in_2_yrs), margin=1)

prop.table(table(mody_vars$hba1c_in_5_yrs))
prop.table(table(mody_vars$diabetes_type, mody_vars$hba1c_in_5_yrs), margin=1)



## Time to BMI

ggplot ((mody_vars %>% filter(bmi_post_diag_datediff_yrs>-3)), aes(x=bmi_post_diag_datediff_yrs, fill=diabetes_type)) + 
  geom_histogram(aes(y = after_stat(count / sum(count))), binwidth=0.05) +
  scale_y_continuous(labels = scales::percent) +
  xlab("Years from BMI to current date") +
  ylab("Percentage")


mody_vars <- mody_vars %>%
  mutate(bmi_in_6_mos=bmi_post_diag_datediff_yrs>=-0.5,
         bmi_in_1_yr=bmi_post_diag_datediff_yrs>=-1,
         bmi_in_2_yrs=bmi_post_diag_datediff_yrs>=-2,
         bmi_in_5_yrs=bmi_post_diag_datediff_yrs>=-5)

prop.table(table(mody_vars$bmi_in_6_mos))
prop.table(table(mody_vars$diabetes_type, mody_vars$bmi_in_6_mos), margin=1)

prop.table(table(mody_vars$bmi_in_1_yr))
prop.table(table(mody_vars$diabetes_type, mody_vars$bmi_in_1_yr), margin=1)

prop.table(table(mody_vars$bmi_in_2_yrs))
prop.table(table(mody_vars$diabetes_type, mody_vars$bmi_in_2_yrs), margin=1)

prop.table(table(mody_vars$bmi_in_5_yrs))
prop.table(table(mody_vars$diabetes_type, mody_vars$bmi_in_5_yrs), margin=1)



## Current insulin

prop.table(table(mody_vars$current_ins_6m))
prop.table(table(mody_vars$diabetes_type, mody_vars$current_ins_6m), margin=1)



## Family history

prop.table(table(mody_vars$diabetes_type, mody_vars$fh_diabetes), margin=1)
prop.table(table(mody_vars$fh_diabetes))

prop.table(table(mody_vars$diabetes_type, mody_vars$fh_diabetes, useNA="always"), margin=1)
prop.table(table(mody_vars$fh_diabetes, useNA="always"))



## Time since last type code

mody_vars %>% summarise(median_time=median(days_since_type_code))
mody_vars %>% group_by(diabetes_type) %>% summarise(median_time=median(days_since_type_code))



## MODY code history

mody_vars <- mody_vars %>%
  mutate(mody_code_hist=mody_code_count>1)

table(mody_vars$diabetes_type, mody_vars$mody_code_hist)
table(mody_vars$mody_code_hist)

prop.table(table(mody_vars$diabetes_type, mody_vars$mody_code_hist), margin=1)
prop.table(table(mody_vars$mody_code_hist))


rm(time_to_ins, mody_vars)


############################################################################################

# Run MODY calculator

## First add in MODY group
## For those diagnosed >=18, run both branches of model

mody_diag <- cohort %>%
  filter(dm_diag_age>=1 & dm_diag_age<=35 & (diabetes_type=="mody" | diabetes_type=="mixed; mody") & !is.na(diagnosis_date)) %>%
  mutate(hba1c_post_diag=ifelse(hba1cdate>=diagnosis_date, hba1c, NA),
         hba1c_post_diag_datediff=ifelse(!is.na(hba1c_post_diag), hba1cindexdiff, NA),
         age_at_bmi=datediff(bmidate, dob)/365.25,
         bmi_post_diag=ifelse(bmidate>=diagnosis_date & age_at_bmi>=18, bmi, NA),
         bmi_post_diag_datediff=ifelse(!is.na(bmi_post_diag), bmiindexdiff, NA),
         insoha=ifelse(current_oha==1 | current_insulin==1, 1L, 0L)) %>%
  filter(!is.na(bmi_post_diag) & !is.na(hba1c_post_diag))


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
#863
863/62045 #1.4
863/60043 #1.4


mody_calc_results_local %>% filter(diabetes_type!="mody" & diabetes_type!="mixed; mody") %>% group_by(diabetes_type) %>% count()
# 1 type 1        23756
# 2 type 2        24073
# 3 mixed; type 1  4764
# 4 mixed; type 2  7650

mody_calc_results_local %>% filter(diabetes_type!="mody" & diabetes_type!="mixed; mody" & (mody_prob_fh0_over18ins0>95 | mody_prob_fh0_over18ins1>95)) %>% group_by(diabetes_type) %>% count()
# 1 type 1          356
# 2 type 2          294
# 3 mixed; type 1    51
# 4 mixed; type 2   162

356/23756 #1.5%
294/24073 #1.2%
51/4764 #1.1%
162/7650 #2.1%


### With no treatment
mody_calc_results_local %>% filter(diabetes_type!="mody" & diabetes_type!="mixed; mody" & (mody_prob_fh0_over18ins0>95 | mody_prob_fh0_over18ins1>95) & no_treatment==1) %>% count()
#273
273/863 #31.6


mody_calc_results_local %>% filter(diabetes_type!="mody" & diabetes_type!="mixed; mody" & (mody_prob_fh0_over18ins0>95 | mody_prob_fh0_over18ins1>95)) %>% group_by(diabetes_type_new) %>% count()
#Type 2              456
#Type 1              407
407/863



## Both probabilities over 95% if assume missing family history is 1
mody_calc_results_local %>% filter(diabetes_type!="mody" & diabetes_type!="mixed; mody" & mody_prob_fh0_over18ins0<95 & mody_prob_fh0_over18ins1<95 & (mody_prob_fh1_over18ins0>95 | mody_prob_fh1_over18ins1>95)) %>% count()
#1150
1150/62045 #1.9

mody_calc_results_local %>% filter(diabetes_type!="mody" & diabetes_type!="mixed; mody" & mody_prob_fh0_over18ins0<95 & mody_prob_fh0_over18ins1<95 & (mody_prob_fh1_over18ins0>95 | mody_prob_fh1_over18ins1>95) & no_treatment==1) %>% count()
#186
186/1150 #16


mody_calc_results_local %>% filter(diabetes_type!="mody" & diabetes_type!="mixed; mody" & mody_prob_fh0_over18ins0<95 & mody_prob_fh0_over18ins1<95 & (mody_prob_fh1_over18ins0>95 | mody_prob_fh1_over18ins1>95)) %>% group_by(diabetes_type_new) %>% count()
#Type 2              353
#Type 1              797
797/1150



## High on 1 model only
mody_calc_results_local %>% filter(diabetes_type!="mody" & diabetes_type!="mixed; mody" & ((mody_prob_fh0_over18ins0>95 & mody_prob_fh0_over18ins1<=95) | (mody_prob_fh0_over18ins0<=95 & mody_prob_fh0_over18ins1>95))) %>% count()
#458

mody_calc_results_local %>% filter(diabetes_type!="mody" & diabetes_type!="mixed; mody" & (mody_prob_fh0_over18ins0>95 & mody_prob_fh0_over18ins1<=95)) %>% count()
#273

mody_calc_results_local %>% filter(diabetes_type!="mody" & diabetes_type!="mixed; mody" & (mody_prob_fh0_over18ins0<=95 & mody_prob_fh0_over18ins1>95)) %>% count()
#185

mody_calc_results_local %>% filter(diabetes_type!="mody" & diabetes_type!="mixed; mody" & (mody_prob_fh0_over18ins0>95 & mody_prob_fh0_over18ins1<=95) & current_dpp4glp1sutzd==1) %>% count()
#7 - not many



mody_calc_results_local %>% filter(diabetes_type!="mody" & diabetes_type!="mixed; mody" & mody_prob_fh0_over18ins0<=95 & mody_prob_fh0_over18ins1<=95 & ((mody_prob_fh1_over18ins0>95 & mody_prob_fh1_over18ins1<=95) | (mody_prob_fh1_over18ins0<=95 & mody_prob_fh1_over18ins1>95))) %>% count()
#774

mody_calc_results_local %>% filter(diabetes_type!="mody" & diabetes_type!="mixed; mody" & mody_prob_fh0_over18ins0<=95 & mody_prob_fh0_over18ins1<=95 & (mody_prob_fh1_over18ins0>95 & mody_prob_fh1_over18ins1<=95)) %>% count()
#544

mody_calc_results_local %>% filter(diabetes_type!="mody" & diabetes_type!="mixed; mody" & mody_prob_fh0_over18ins0<=95 & mody_prob_fh0_over18ins1<=95 & (mody_prob_fh1_over18ins0<=95 & mody_prob_fh1_over18ins1>95)) %>% count()
#230

mody_calc_results_local %>% filter(diabetes_type!="mody" & diabetes_type!="mixed; mody" & mody_prob_fh0_over18ins0<=95 & mody_prob_fh0_over18ins1<=95 & (mody_prob_fh1_over18ins0>95 & mody_prob_fh1_over18ins1<=95) & current_dpp4glp1sutzd==1) %>% count()
#6 - not many




### Characteristics

mody_calc_results_local_high <- mody_calc_results_local %>%
  filter(diabetes_type!="mody" & diabetes_type!="mixed; mody" & mody_prob_assume_fh0>0.95) %>%
  mutate(mody_code_hist=mody_code_count>1,
         missing_fh=is.na(fh_diabetes))


prop.table(table(mody_calc_results_local_high$diabetes_type, mody_calc_results_local_high$current_ins_6m), margin=1)
prop.table(table(mody_calc_results_local_high$current_ins_6m))

prop.table(table(mody_calc_results_local_high$diabetes_type, mody_calc_results_local_high$missing_fh), margin=1)
prop.table(table(mody_calc_results_local_high$missing_fh))

mody_calc_results_local_high %>% summarise(median_time=median(days_since_type_code))
mody_calc_results_local_high %>% group_by(diabetes_type) %>% summarise(median_time=median(days_since_type_code))

table(mody_calc_results_local_high$diabetes_type, mody_calc_results_local_high$mody_code_hist)
table(mody_calc_results_local_high$mody_code_hist)

prop.table(table(mody_calc_results_local_high$diabetes_type, mody_calc_results_local_high$mody_code_hist), margin=1)
prop.table(table(mody_calc_results_local_high$mody_code_hist))

mody_calc_results_local_high %>% summarise(median_age=median(dm_diag_age))
mody_calc_results_local_high %>% group_by(diabetes_type) %>% summarise(median_age=median(dm_diag_age))

mody_calc_results_local_high %>% summarise(median_age=median(age_at_index))
mody_calc_results_local_high %>% group_by(diabetes_type) %>% summarise(median_age=median(age_at_index))



############################################################################################

# Redo for 90%

mody_calc_results_local %>% filter(diabetes_type!="mody" & diabetes_type!="mixed; mody") %>% count()


## Either probability over 95% if assume missing family history is 0                                   
mody_calc_results_local %>% filter(diabetes_type!="mody" & diabetes_type!="mixed; mody" & (mody_prob_fh0_over18ins0>90 | mody_prob_fh0_over18ins1>90)) %>% count()
#1866
1866/62045 #1.4

mody_calc_results_local %>% filter(diabetes_type!="mody" & diabetes_type!="mixed; mody" & (mody_prob_fh0_over18ins0>90 | mody_prob_fh0_over18ins1>90)) %>% group_by(diabetes_type) %>% count()
# 1 type 1          769
# 2 type 2          593
# 3 mixed; type 1    156
# 4 mixed; type 2   348

769/23756 #3.2%
593/24073 #2.5%
156/4764 #3.3%
348/7650 #4.5%



mody_calc_results_local %>% filter(diabetes_type!="mody" & diabetes_type!="mixed; mody" & (mody_prob_fh0_over18ins0>90 | mody_prob_fh0_over18ins1>90) & no_treatment==1) %>% count()
#475
475/1866 #25.5

mody_calc_results_local %>% filter(diabetes_type!="mody" & diabetes_type!="mixed; mody" & (mody_prob_fh0_over18ins0>90 | mody_prob_fh0_over18ins1>90)) %>% group_by(diabetes_type_new) %>% count()
#Type 2              941
#Type 1              925
925/1866

62045-1802-1866
58377/62045

## Both probabilities over 90% if assume missing family history is 1
mody_calc_results_local %>% filter(diabetes_type!="mody" & diabetes_type!="mixed; mody" & mody_prob_fh0_over18ins0<90 & mody_prob_fh0_over18ins1<90 & (mody_prob_fh1_over18ins0>90 | mody_prob_fh1_over18ins1>90)) %>% count()
#2276
2276/62045 #3.7

mody_calc_results_local %>% filter(diabetes_type!="mody" & diabetes_type!="mixed; mody" & mody_prob_fh0_over18ins0<90 & mody_prob_fh0_over18ins1<90 & (mody_prob_fh1_over18ins0>90 | mody_prob_fh1_over18ins1>90) & no_treatment==1) %>% count()
#308
308/2276 #14


mody_calc_results_local %>% filter(diabetes_type!="mody" & diabetes_type!="mixed; mody" & mody_prob_fh0_over18ins0<90 & mody_prob_fh0_over18ins1<90 & (mody_prob_fh1_over18ins0>90 | mody_prob_fh1_over18ins1>90)) %>% group_by(diabetes_type_new) %>% count()
#Type 2              731
#Type 1              1545
1545/2276



## High on 1 model only
mody_calc_results_local %>% filter(diabetes_type!="mody" & diabetes_type!="mixed; mody" & ((mody_prob_fh0_over18ins0>90 & mody_prob_fh0_over18ins1<=90) | (mody_prob_fh0_over18ins0<=90 & mody_prob_fh0_over18ins1>90))) %>% count()
#1008

mody_calc_results_local %>% filter(diabetes_type!="mody" & diabetes_type!="mixed; mody" & (mody_prob_fh0_over18ins0>90 & mody_prob_fh0_over18ins1<=90)) %>% count()
#596

mody_calc_results_local %>% filter(diabetes_type!="mody" & diabetes_type!="mixed; mody" & (mody_prob_fh0_over18ins0<=90 & mody_prob_fh0_over18ins1>90)) %>% count()
#412

mody_calc_results_local %>% filter(diabetes_type!="mody" & diabetes_type!="mixed; mody" & (mody_prob_fh0_over18ins0>90 & mody_prob_fh0_over18ins1<=90) & current_dpp4glp1sutzd==1) %>% count()
#18 - not many



mody_calc_results_local %>% filter(diabetes_type!="mody" & diabetes_type!="mixed; mody" & mody_prob_fh0_over18ins0<=90 & mody_prob_fh0_over18ins1<=90 & ((mody_prob_fh1_over18ins0>90 & mody_prob_fh1_over18ins1<=90) | (mody_prob_fh1_over18ins0<=90 & mody_prob_fh1_over18ins1>90))) %>% count()
#1402

mody_calc_results_local %>% filter(diabetes_type!="mody" & diabetes_type!="mixed; mody" & mody_prob_fh0_over18ins0<=90 & mody_prob_fh0_over18ins1<=90 & (mody_prob_fh1_over18ins0>90 & mody_prob_fh1_over18ins1<=90)) %>% count()
#802

mody_calc_results_local %>% filter(diabetes_type!="mody" & diabetes_type!="mixed; mody" & mody_prob_fh0_over18ins0<=90 & mody_prob_fh0_over18ins1<=90 & (mody_prob_fh1_over18ins0<=90 & mody_prob_fh1_over18ins1>90)) %>% count()
#600

mody_calc_results_local %>% filter(diabetes_type!="mody" & diabetes_type!="mixed; mody" & mody_prob_fh0_over18ins0<=90 & mody_prob_fh0_over18ins1<=90 & (mody_prob_fh1_over18ins0>90 & mody_prob_fh1_over18ins1<=90) & current_dpp4glp1sutzd==1) %>% count()
#11 - not many


