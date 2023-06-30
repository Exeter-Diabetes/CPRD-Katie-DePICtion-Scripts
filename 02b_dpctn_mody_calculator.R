
# Apply the MODY calculator to everyone in prevalent cohort diagnosed aged 1-35 years

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
         insulin_6_months=ifelse(is.na(earliest_ins), 0L,
                                  ifelse(datediff(earliest_ins, diagnosis_date)>183 & datediff(regstartdate, diagnosis_date)>183 & datediff(earliest_ins, regstartdate)<=183, NA,
                                         ifelse(datediff(earliest_ins, diagnosis_date)<=183, 1L, 0L))),
         insoha=ifelse(current_oha_6m==1 | current_ins_6m==1, 1L, 0L)) %>%
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

mody_vars <- mody_calc_cohort %>%
  select(diabetes_type, hba1c_post_diag_datediff, bmi_post_diag_datediff, diagnosis_date, regstartdate, earliest_ins,  time_to_ins_days, insulin_6_months, fh_diabetes, current_ins_6m, regstartdate, dm_diag_age, mody_code_count) %>%
  collect() %>%
  mutate(hba1c_post_diag_datediff_yrs=as.numeric(hba1c_post_diag_datediff)/365.25,
         bmi_post_diag_datediff_yrs=as.numeric(bmi_post_diag_datediff)/365.25,
         diabetes_type=factor(diabetes_type, levels=c("type 1", "type 2", "mixed; type 1", "mixed; type 2")))


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




## Time to insulin from diagnosis - regardless of whether before or after reg

time_to_ins <- mody_vars %>%
  filter(current_ins_6m==1) %>%
  mutate(time_to_ins_yrs=as.numeric(difftime(earliest_ins, diagnosis_date, units="days"))/365.25,
         diagnosed_under_18=dm_diag_age<18) %>%
  select(diabetes_type, diagnosis_date, earliest_ins, time_to_ins_yrs, diagnosed_under_18)

ggplot ((time_to_ins %>% filter(time_to_ins_yrs>0 & time_to_ins_yrs<50)), aes(x=time_to_ins_yrs, fill=diabetes_type)) + 
  geom_histogram(aes(y = after_stat(count / sum(count))), binwidth=1) +
  scale_y_continuous(labels = scales::percent) +
  xlab("Years from diagnosis to earliest insulin script") +
  ylab("Percentage")

ggplot ((time_to_ins %>% filter(time_to_ins_yrs>0 & time_to_ins_yrs<50)), aes(x=time_to_ins_yrs, fill=diagnosed_under_18)) + 
  geom_histogram(aes(y = after_stat(count / sum(count))), binwidth=1) +
  scale_y_continuous(labels = scales::percent) +
  xlab("Years from diagnosis to earliest insulin script") +
  ylab("Percentage")





## Family history

prop.table(table(mody_vars$diabetes_type, mody_vars$fh_diabetes), margin=1)
prop.table(table(mody_vars$fh_diabetes))

prop.table(table(mody_vars$diabetes_type, mody_vars$fh_diabetes, useNA="always"), margin=1)
prop.table(table(mody_vars$fh_diabetes, useNA="always"))



## MODY code history

mody_vars <- mody_vars %>%
  mutate(mody_code_hist=mody_code_count>1)

table(mody_vars$diabetes_type, mody_vars$mody_code_hist)
table(mody_vars$mody_code_hist)

prop.table(table(mody_vars$diabetes_type, mody_vars$mody_code_hist), margin=1)
prop.table(table(mody_vars$mody_code_hist))



############################################################################################


# Run MODY calculator

mody_calc_results <- mody_calc_cohort %>%
 
  mutate(fh_diabetes1=ifelse(is.na(fh_diabetes), 1L, fh_diabetes),
         fh_diabetes0=ifelse(is.na(fh_diabetes), 0L, fh_diabetes),
         
         hba1c_post_diag_perc=(0.09148*hba1c_post_diag)+2.152,
         
         mody_logOR=ifelse(is.na(fh_diabetes), NA,
                           ifelse(current_ins_6m==1, 1.8196 + (3.1404*fh_diabetes) - (0.0829*age_at_index) - (0.6598*hba1c_post_diag_perc) + (0.1011*dm_diag_age) + (1.3131*gender),
                                  19.28 - (0.3154*dm_diag_age) - (0.2324*bmi_post_diag) - (0.6276*hba1c_post_diag_perc) + (1.7473*fh_diabetes) - (0.0352*age_at_index) - (0.9952*insoha) + (0.6943*gender))),
         
         mody_logOR_fh1=ifelse(current_ins_6m==1, 1.8196 + (3.1404*fh_diabetes1) - (0.0829*age_at_index) - (0.6598*hba1c_post_diag_perc) + (0.1011*dm_diag_age) + (1.3131*gender), 19.28 - (0.3154*dm_diag_age) - (0.2324*bmi_post_diag) - (0.6276*hba1c_post_diag_perc) + (1.7473*fh_diabetes1) - (0.0352*age_at_index) - (0.9952*insoha) + (0.6943*gender)),
         
         mody_logOR_fh0=ifelse(current_ins_6m==1, 1.8196 + (3.1404*fh_diabetes0) - (0.0829*age_at_index) - (0.6598*hba1c_post_diag_perc) + (0.1011*dm_diag_age) + (1.3131*gender), 19.28 - (0.3154*dm_diag_age) - (0.2324*bmi_post_diag) - (0.6276*hba1c_post_diag_perc) + (1.7473*fh_diabetes0) - (0.0352*age_at_index) - (0.9952*insoha) + (0.6943*gender)),
         
         mody_prob=exp(mody_logOR)/(1+exp(mody_logOR)),
         mody_prob_fh1=exp(mody_logOR_fh1)/(1+exp(mody_logOR_fh1)),
         mody_prob_fh0=exp(mody_logOR_fh0)/(1+exp(mody_logOR_fh0)),
         
         mody_adj_prob=ifelse(current_ins_6m==1, case_when(
           mody_prob < 0.1 ~ 0.7,
           mody_prob < 0.2 ~ 1.9,
           mody_prob < 0.3 ~ 2.6,
           mody_prob < 0.4 ~ 4.0,
           mody_prob < 0.5 ~ 4.9,
           mody_prob < 0.6 ~ 6.4,
           mody_prob < 0.7 ~ 7.2,
           mody_prob < 0.8 ~ 8.2,
           mody_prob < 0.9 ~ 12.6,
           mody_prob < 1.0 ~ 49.4
         ),
         case_when(
           mody_prob < 0.1 ~ 4.6,
           mody_prob < 0.2 ~ 15.1,
           mody_prob < 0.3 ~ 21.0,
           mody_prob < 0.4 ~ 24.4,
           mody_prob < 0.5 ~ 32.9,
           mody_prob < 0.6 ~ 35.8,
           mody_prob < 0.7 ~ 45.5,
           mody_prob < 0.8 ~ 58.0,
           mody_prob < 0.9 ~ 62.4,
           mody_prob < 1.0 ~ 75.5
         )),
         
         mody_adj_prob_fh1=ifelse(current_ins_6m==1, case_when(
           mody_prob_fh1 < 0.1 ~ 0.7,
           mody_prob_fh1 < 0.2 ~ 1.9,
           mody_prob_fh1 < 0.3 ~ 2.6,
           mody_prob_fh1 < 0.4 ~ 4.0,
           mody_prob_fh1 < 0.5 ~ 4.9,
           mody_prob_fh1 < 0.6 ~ 6.4,
           mody_prob_fh1 < 0.7 ~ 7.2,
           mody_prob_fh1 < 0.8 ~ 8.2,
           mody_prob_fh1 < 0.9 ~ 12.6,
           mody_prob_fh1 < 1.0 ~ 49.4
         ),
         case_when(
           mody_prob_fh1 < 0.1 ~ 4.6,
           mody_prob_fh1 < 0.2 ~ 15.1,
           mody_prob_fh1 < 0.3 ~ 21.0,
           mody_prob_fh1 < 0.4 ~ 24.4,
           mody_prob_fh1 < 0.5 ~ 32.9,
           mody_prob_fh1 < 0.6 ~ 35.8,
           mody_prob_fh1 < 0.7 ~ 45.5,
           mody_prob_fh1 < 0.8 ~ 58.0,
           mody_prob_fh1 < 0.9 ~ 62.4,
           mody_prob_fh1 < 1.0 ~ 75.5
         )),
         
         mody_adj_prob_fh0=ifelse(current_ins_6m==1, case_when(
           mody_prob_fh0 < 0.1 ~ 0.7,
           mody_prob_fh0 < 0.2 ~ 1.9,
           mody_prob_fh0 < 0.3 ~ 2.6,
           mody_prob_fh0 < 0.4 ~ 4.0,
           mody_prob_fh0 < 0.5 ~ 4.9,
           mody_prob_fh0 < 0.6 ~ 6.4,
           mody_prob_fh0 < 0.7 ~ 7.2,
           mody_prob_fh0 < 0.8 ~ 8.2,
           mody_prob_fh0 < 0.9 ~ 12.6,
           mody_prob_fh0 < 1.0 ~ 49.4
         ),
         case_when(
           mody_prob_fh0 < 0.1 ~ 4.6,
           mody_prob_fh0 < 0.2 ~ 15.1,
           mody_prob_fh0 < 0.3 ~ 21.0,
           mody_prob_fh0 < 0.4 ~ 24.4,
           mody_prob_fh0 < 0.5 ~ 32.9,
           mody_prob_fh0 < 0.6 ~ 35.8,
           mody_prob_fh0 < 0.7 ~ 45.5,
           mody_prob_fh0 < 0.8 ~ 58.0,
           mody_prob_fh0 < 0.9 ~ 62.4,
           mody_prob_fh0 < 1.0 ~ 75.5
         )),
         
         mody_prob_assume_fh0=ifelse(!is.na(mody_prob), mody_prob, mody_prob_fh1),
         mody_adj_prob_assume_fh0=ifelse(!is.na(mody_adj_prob), mody_adj_prob, mody_adj_prob_fh1),
         
         ) %>%
  
  analysis$cached("mody_calc_results", unique_indexes="patid")
  

# Mean adjusted probability per group

mody_calc_results_local <- mody_calc_results %>%
  collect() %>%
  mutate(diabetes_type=factor(diabetes_type, levels=c("type 1", "type 2", "mixed; type 1", "mixed; type 2")))

## Overall
mody_calc_results_local %>% summarise(mean_adjusted=mean(mody_adj_prob_assume_fh0))
mody_calc_results_local %>% group_by(diabetes_type) %>% summarise(mean_adjusted=mean(mody_adj_prob_assume_fh0))

## Overall non-missing White ethnicity
mody_calc_results_local %>% filter(!is.na(ethnicity_5cat) & ethnicity_5cat==0) %>% summarise(mean_adjusted=mean(mody_adj_prob_assume_fh0), count=n())
mody_calc_results_local %>% filter(!is.na(ethnicity_5cat) & ethnicity_5cat==0) %>% group_by(diabetes_type) %>% summarise(mean_adjusted=mean(mody_adj_prob_assume_fh0), count=n())

## Overall non-missing non-White ethnicity
mody_calc_results_local %>% filter(!is.na(ethnicity_5cat) & ethnicity_5cat!=0) %>% summarise(mean_adjusted=mean(mody_adj_prob_assume_fh0), count=n())
mody_calc_results_local %>% filter(!is.na(ethnicity_5cat) & ethnicity_5cat!=0) %>% group_by(diabetes_type) %>% summarise(mean_adjusted=mean(mody_adj_prob_assume_fh0), count=n())


# Plot distributions
mody_calc_results_local <- mody_calc_results %>%
  collect() %>%
  mutate(diabetes_type=factor(diabetes_type, levels=c("type 1", "type 2", "mixed; type 1", "mixed; type 2")))

ggplot(mody_calc_results_local, aes(x=mody_prob_assume_fh0*100, fill=diabetes_type, color=diabetes_type)) +
  geom_histogram(binwidth=1) +
  xlab("MODY unadjusted probability (%)")

ggplot(mody_calc_results_local, aes(x=mody_prob_assume_fh0*100, fill=current_ins_6m, color=current_ins_6m)) +
  geom_histogram(binwidth=1) +
  xlab("MODY unadjusted probability (%)")



############################################################################################

# Look at those with unadjusted probability >95%

mody_calc_results_local %>% count()
                                   
mody_calc_results_local %>% filter(mody_prob_assume_fh0>0.95) %>% count()
#1989
1989/60243 #3.3

mody_calc_results_local %>% filter(mody_prob_assume_fh0>0.95) %>% group_by(diabetes_type) %>% count()
#type 1          804
#type 2          771
#mixed; type 1    119
#mixed; type 2   295


mody_calc_results_local_high <- mody_calc_results_local %>%
  filter(mody_prob_fh0>0.95) %>%
  mutate(mody_code_hist=mody_code_count>1)

table(mody_calc_results_local_high$diabetes_type, mody_calc_results_local_high$mody_code_hist)
table(mody_calc_results_local_high$mody_code_hist)

prop.table(table(mody_calc_results_local_high$diabetes_type, mody_calc_results_local_high$mody_code_hist), margin=1)
prop.table(table(mody_calc_results_local_high$mody_code_hist))



### How many added if treat family history as 1 or 0?

mody_calc_results_local_high %>% filter(is.na(fh_diabetes)) %>% count()
#0



mody_calc_results %>% filter(is.na(fh_diabetes)) %>% group_by(diabetes_type) %>% count()


mody_calc_results %>% filter(is.na(fh_diabetes) & mody_prob_no_missing_fh0>0.95) %>% count()

mody_calc_results %>% filter(is.na(fh_diabetes) & mody_prob_no_missing_fh0>0.95) %>% group_by(diabetes_type) %>% count()




mody_calc_results %>% filter(is.na(fh_diabetes) & mody_prob_no_missing_fh1>0.95 & mody_prob_no_missing_fh0<=0.95) %>% count()

mody_calc_results %>% filter(is.na(fh_diabetes) & mody_prob_no_missing_fh1>0.95 & mody_prob_no_missing_fh0<=0.95) %>% group_by(diabetes_type) %>% count()








############################################################################################


