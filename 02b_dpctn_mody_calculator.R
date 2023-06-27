
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

cohort %>% filter(dm_diag_age>=18 & dm_diag_age<=35) %>% count()
#68302

cohort %>% filter(dm_diag_age>=18 & dm_diag_age<=35 & (diabetes_type=="unspecified" | diabetes_type=="unspecified_with_primis")) %>% count()
#10645
10645/68302 #15.6%
68302-10645 #57657

cohort %>% filter(dm_diag_age>=18 & dm_diag_age<=35 & (diabetes_type=="type 2" | diabetes_type=="mixed; type 2" | diabetes_type=="type 1" | diabetes_type=="mixed; type 1")) %>% count()
#47684
47684/57657 #82.7%

cohort %>% filter(dm_diag_age>=18 & dm_diag_age<=35 & (diabetes_type=="type 1" | diabetes_type=="mixed; type 1")) %>% count()
#14851
47684-14851 #32833

cohort %>% filter(dm_diag_age>=18 & dm_diag_age<=35 & (diabetes_type=="type 2" | diabetes_type=="mixed; type 2" | diabetes_type=="type 1" | diabetes_type=="mixed; type 1") & is.na(diagnosis_date)) %>% count()
#2654
2654/47684 #5.6

cohort %>% filter(dm_diag_age>=18 & dm_diag_age<=35 & (diabetes_type=="type 1" | diabetes_type=="mixed; type 1") & is.na(diagnosis_date)) %>% count()
#950
2654-950

cohort %>% filter(dm_diag_age>=18 & dm_diag_age<=35 & (diabetes_type=="type 2" | diabetes_type=="mixed; type 2" | diabetes_type=="type 1" | diabetes_type=="mixed; type 1") & !is.na(diagnosis_date)) %>% count()
#45030

cohort %>% filter(dm_diag_age>=18 & dm_diag_age<=35 & (diabetes_type=="type 1" | diabetes_type=="mixed; type 1") & !is.na(diagnosis_date)) %>% count()
#13901
45030-13901


# Define MODY cohort: patients diagnosed with a current Type 1 or Type 2 diagnosis, diagnosed aged 1-35, with valid diagnosis date and BMI/HbA1c before diagnosis

mody_calc_cohort <- cohort %>%
  filter(dm_diag_age>=18 & dm_diag_age<=35 & (diabetes_type=="type 1" | diabetes_type=="type 2" | diabetes_type=="mixed; type 1" | diabetes_type=="mixed; type 2") & !is.na(diagnosis_date)) %>%
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
#44032
45030-44032 #998
998/45030 #2.2

mody_calc_cohort %>% group_by(diabetes_type) %>% count()
# type 1          10566
# type 2          23261
# mixed; type 2    7155
# mixed; type 1    3050
10566+3050 #13616
23261+7155 #30416

13901-13616 #285 
31129-30416 #713


############################################################################################

# Look at variables

mody_vars <- mody_calc_cohort %>%
  select(diabetes_type, hba1c_post_diag_datediff, bmi_post_diag_datediff, diagnosis_date, regstartdate, earliest_ins,  time_to_ins_days, insulin_6_months, fh_diabetes, current_ins_6m, regstartdate) %>%
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



## Time to insulin

prop.table(table(mody_vars$diabetes_type, mody_vars$insulin_6_months), margin=1)
prop.table(table(mody_vars$insulin_6_months))

prop.table(table(mody_vars$diabetes_type, mody_vars$insulin_6_months, useNA="always"), margin=1)
prop.table(table(mody_vars$insulin_6_months, useNA="always"))

prop.table(table(mody_vars$diabetes_type, mody_vars$current_ins_6m), margin=1)
prop.table(table(mody_vars$current_ins_6m))

mody_vars <- mody_vars %>%
  mutate(insulin_6_months_no_missing=ifelse(!is.na(insulin_6_months), insulin_6_months, current_ins_6m))

prop.table(table(mody_vars$diabetes_type, mody_vars$insulin_6_months_no_missing), margin=1)
prop.table(table(mody_vars$insulin_6_months_no_missing))

time_to_ins <- mody_vars %>%
  filter(is.na(insulin_6_months) & current_ins_6m==1) %>%
  mutate(time_to_ins_yrs=as.numeric(difftime(earliest_ins, diagnosis_date, units="days"))/365.25,
         time_to_reg_yrs=as.numeric(difftime(regstartdate, diagnosis_date, units="days"))/365.25) %>%
  select(diabetes_type, diagnosis_date, earliest_ins, time_to_ins_yrs, time_to_reg_yrs)

ggplot (time_to_ins, aes(x=time_to_ins_yrs, fill=diabetes_type)) + 
  geom_histogram(aes(y = after_stat(count / sum(count))), binwidth=1) +
  scale_y_continuous(labels = scales::percent) +
  xlab("Years from diagnosis to earliest insulin script") +
  ylab("Percentage")

ggplot (time_to_ins, aes(x=time_to_reg_yrs, fill=diabetes_type)) + 
  geom_histogram(aes(y = after_stat(count / sum(count))), binwidth=1) +
  scale_y_continuous(labels = scales::percent) +
  xlab("Years from diagnosis to registration start") +
  ylab("Percentage")



## Family history

prop.table(table(mody_vars$diabetes_type, mody_vars$fh_diabetes), margin=1)
prop.table(table(mody_vars$fh_diabetes))

prop.table(table(mody_vars$diabetes_type, mody_vars$fh_diabetes, useNA="always"), margin=1)
prop.table(table(mody_vars$fh_diabetes, useNA="always"))


############################################################################################


# Run MODY calculator

mody_calc_results <- mody_calc_cohort %>%
 
  mutate(insulin_6_months_no_missing=ifelse(!is.na(insulin_6_months), insulin_6_months, current_ins_6m),
         
         fh_diabetes_no_missing1=ifelse(is.na(fh_diabetes), 1L, fh_diabetes),
         fh_diabetes_no_missing0=ifelse(is.na(fh_diabetes), 0L, fh_diabetes),
         
         hba1c_post_diag_perc=(0.09148*hba1c_post_diag)+2.152,
         
         mody_logOR=ifelse(is.na(fh_diabetes), NA,
                           ifelse(insulin_6_months_no_missing==1, 1.8196 + (3.1404*fh_diabetes) - (0.0829*age_at_index) - (0.6598*hba1c_post_diag_perc) + (0.1011*dm_diag_age) + (1.3131*gender),
                                  19.28 - (0.3154*dm_diag_age) - (0.2324*bmi_post_diag) - (0.6276*hba1c_post_diag_perc) + (1.7473*fh_diabetes) - (0.0352*age_at_index) - (0.9952*insoha) + (0.6943*gender))),
         
         mody_logOR_no_missing_fh1=ifelse(insulin_6_months_no_missing==1, 1.8196 + (3.1404*fh_diabetes_no_missing1) - (0.0829*age_at_index) - (0.6598*hba1c_post_diag_perc) + (0.1011*dm_diag_age) + (1.3131*gender), 19.28 - (0.3154*dm_diag_age) - (0.2324*bmi_post_diag) - (0.6276*hba1c_post_diag_perc) + (1.7473*fh_diabetes_no_missing1) - (0.0352*age_at_index) - (0.9952*insoha) + (0.6943*gender)),
         
         mody_logOR_no_missing_fh0=ifelse(insulin_6_months_no_missing==1, 1.8196 + (3.1404*fh_diabetes_no_missing0) - (0.0829*age_at_index) - (0.6598*hba1c_post_diag_perc) + (0.1011*dm_diag_age) + (1.3131*gender), 19.28 - (0.3154*dm_diag_age) - (0.2324*bmi_post_diag) - (0.6276*hba1c_post_diag_perc) + (1.7473*fh_diabetes_no_missing0) - (0.0352*age_at_index) - (0.9952*insoha) + (0.6943*gender)),
         
         mody_prob=exp(mody_logOR)/(1+exp(mody_logOR)),
         mody_prob_no_missing_fh1=exp(mody_logOR_no_missing_fh1)/(1+exp(mody_logOR_no_missing_fh1)),
         mody_prob_no_missing_fh0=exp(mody_logOR_no_missing_fh0)/(1+exp(mody_logOR_no_missing_fh0)),
         
         mody_adj_prob=ifelse(insulin_6_months_no_missing==1, case_when(
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
         
         mody_adj_prob_no_missing_fh1=ifelse(insulin_6_months_no_missing==1, case_when(
           mody_prob_no_missing_fh1 < 0.1 ~ 0.7,
           mody_prob_no_missing_fh1 < 0.2 ~ 1.9,
           mody_prob_no_missing_fh1 < 0.3 ~ 2.6,
           mody_prob_no_missing_fh1 < 0.4 ~ 4.0,
           mody_prob_no_missing_fh1 < 0.5 ~ 4.9,
           mody_prob_no_missing_fh1 < 0.6 ~ 6.4,
           mody_prob_no_missing_fh1 < 0.7 ~ 7.2,
           mody_prob_no_missing_fh1 < 0.8 ~ 8.2,
           mody_prob_no_missing_fh1 < 0.9 ~ 12.6,
           mody_prob_no_missing_fh1 < 1.0 ~ 49.4
         ),
         case_when(
           mody_prob_no_missing_fh1 < 0.1 ~ 4.6,
           mody_prob_no_missing_fh1 < 0.2 ~ 15.1,
           mody_prob_no_missing_fh1 < 0.3 ~ 21.0,
           mody_prob_no_missing_fh1 < 0.4 ~ 24.4,
           mody_prob_no_missing_fh1 < 0.5 ~ 32.9,
           mody_prob_no_missing_fh1 < 0.6 ~ 35.8,
           mody_prob_no_missing_fh1 < 0.7 ~ 45.5,
           mody_prob_no_missing_fh1 < 0.8 ~ 58.0,
           mody_prob_no_missing_fh1 < 0.9 ~ 62.4,
           mody_prob_no_missing_fh1 < 1.0 ~ 75.5
         )),
         
         mody_adj_prob_no_missing_fh0=ifelse(insulin_6_months_no_missing==1, case_when(
           mody_prob_no_missing_fh0 < 0.1 ~ 0.7,
           mody_prob_no_missing_fh0 < 0.2 ~ 1.9,
           mody_prob_no_missing_fh0 < 0.3 ~ 2.6,
           mody_prob_no_missing_fh0 < 0.4 ~ 4.0,
           mody_prob_no_missing_fh0 < 0.5 ~ 4.9,
           mody_prob_no_missing_fh0 < 0.6 ~ 6.4,
           mody_prob_no_missing_fh0 < 0.7 ~ 7.2,
           mody_prob_no_missing_fh0 < 0.8 ~ 8.2,
           mody_prob_no_missing_fh0 < 0.9 ~ 12.6,
           mody_prob_no_missing_fh0 < 1.0 ~ 49.4
         ),
         case_when(
           mody_prob_no_missing_fh0 < 0.1 ~ 4.6,
           mody_prob_no_missing_fh0 < 0.2 ~ 15.1,
           mody_prob_no_missing_fh0 < 0.3 ~ 21.0,
           mody_prob_no_missing_fh0 < 0.4 ~ 24.4,
           mody_prob_no_missing_fh0 < 0.5 ~ 32.9,
           mody_prob_no_missing_fh0 < 0.6 ~ 35.8,
           mody_prob_no_missing_fh0 < 0.7 ~ 45.5,
           mody_prob_no_missing_fh0 < 0.8 ~ 58.0,
           mody_prob_no_missing_fh0 < 0.9 ~ 62.4,
           mody_prob_no_missing_fh0 < 1.0 ~ 75.5
         ))) %>%
  
  analysis$cached("mody_calc_results", unique_indexes="patid")
  

# Mean probability per group -  where family history not missing

## Overall with family history
mody_calc_results %>% filter(!is.na(fh_diabetes)) %>% summarise(mean_adjusted=mean(mody_adj_prob), count=n())
mody_calc_results %>% filter(!is.na(fh_diabetes)) %>% mutate(diabetes_type2=ifelse(diabetes_type=="type 1" | diabetes_type=="mixed; type 1", "type 1", "type 2")) %>% group_by(diabetes_type2) %>% summarise(mean_adjusted=mean(mody_adj_prob), count=n())
mody_calc_results %>% filter(!is.na(fh_diabetes)) %>% group_by(diabetes_type) %>% summarise(mean_adjusted=mean(mody_adj_prob), count=n())

## Overall with family history - non-missing White ethnicity
mody_calc_results %>% filter(!is.na(fh_diabetes) & !is.na(ethnicity_5cat) & ethnicity_5cat==0) %>% summarise(mean_adjusted=mean(mody_adj_prob), count=n())
mody_calc_results %>% filter(!is.na(fh_diabetes) & !is.na(ethnicity_5cat) & ethnicity_5cat==0) %>% group_by(diabetes_type) %>% summarise(mean_adjusted=mean(mody_adj_prob), count=n())

## Overall with family history - non-missing non-White ethnicity
mody_calc_results %>% filter(!is.na(fh_diabetes) & !is.na(ethnicity_5cat) & ethnicity_5cat!=0) %>% summarise(mean_adjusted=mean(mody_adj_prob), count=n())
mody_calc_results %>% filter(!is.na(fh_diabetes) & !is.na(ethnicity_5cat) & ethnicity_5cat!=0) %>% group_by(diabetes_type) %>% summarise(mean_adjusted=mean(mody_adj_prob), count=n())


# Plot means
mody_calc_results_local <- mody_calc_results %>%
  filter(!is.na(fh_diabetes)) %>%
  collect() %>%
  mutate(diabetes_type2=ifelse(diabetes_type=="type 1" | diabetes_type=="mixed; type 1", "type 1", "type 2"),
         diabetes_type=factor(diabetes_type, levels=c("type 1", "type 2", "mixed; type 1", "mixed; type 2")))

total_cohort <- mody_calc_results_local %>%
  union_all(mody_calc_results_local %>% mutate(diabetes_type=paste(diabetes_type2,"overall"))) %>%
  union_all(mody_calc_results_local %>% mutate(diabetes_type="overall")) %>%
  mutate(diabetes_type=factor(diabetes_type, levels=c("type 1 overall", "type 1", "mixed; type 1", "type 2 overall", "type 2", "mixed; type 2", "overall")))

ggplot(total_cohort, aes(x=diabetes_type, y=mody_adj_prob)) + 
  geom_boxplot() +
  theme(text = element_text(size = 20))   


# Plot distributions

ggplot(mody_calc_results_local, aes(x=mody_prob*100, fill=diabetes_type, color=diabetes_type)) +
  geom_histogram(binwidth=1) +
  xlab("MODY unadjusted probability (%)")#+
  #theme(text = element_text(size = 20))
  



############################################################################################

# Look at those with unadjusted probability >95%

mody_calc_results %>% filter(!is.na(fh_diabetes)) %>% count()
                                   
mody_calc_results %>% filter(!is.na(fh_diabetes) & mody_prob>0.95) %>% count()

mody_calc_results %>% filter(!is.na(fh_diabetes) & mody_prob>0.95) %>% group_by(diabetes_type) %>% count()



### How many added if treat family history as 1 or 0?

mody_calc_results %>% filter(is.na(fh_diabetes)) %>% count()

mody_calc_results %>% filter(is.na(fh_diabetes)) %>% group_by(diabetes_type) %>% count()


mody_calc_results %>% filter(is.na(fh_diabetes) & mody_prob_no_missing_fh0>0.95) %>% count()





mody_calc_results %>% filter(is.na(fh_diabetes) & mody_prob_no_missing_fh1>0.95) %>% count()

mody_calc_results %>% filter(is.na(fh_diabetes) & mody_prob_no_missing_fh1>0.95) %>% group_by(diabetes_type) %>% count()








############################################################################################

# Look at time to insulin

mody_calc_results_local <- mody_calc_results %>%
  filter(!is.na(fh_diabetes)) %>%
  select(diabetes_type, dm_diag_age, insulin_6_months, current_ins_6m) %>%
  collect() %>%
  mutate(diagnosis_under_18=factor(ifelse(dm_diag_age<18, "under18", "18andover"), levels=c("under18", "18andover")),
         insulin_6_months=factor(insulin_6_months, levels=c(1,0)),
         current_ins_6m=factor(current_ins_6m, levels=c(1,0)))
         

prop.table(table(mody_calc_results_local$insulin_6_months, mody_calc_results_local$diagnosis_under_18), margin=2)

prop.table(table(mody_calc_results_local$diabetes_type, mody_calc_results_local$diagnosis_under_18), margin=2)

table(mody_calc_results_local$diabetes_type, mody_calc_results_local$diagnosis_under_18)

prop.table(table((mody_calc_results_local %>% filter(diabetes_type=="type 1"))$insulin_6_months, (mody_calc_results_local%>% filter(diabetes_type=="type 1"))$diagnosis_under_18), margin=2)

prop.table(table((mody_calc_results_local %>% filter(diabetes_type=="type 2"))$insulin_6_months, (mody_calc_results_local%>% filter(diabetes_type=="type 2"))$diagnosis_under_18), margin=2)

prop.table(table((mody_calc_results_local %>% filter(diabetes_type=="type 1"))$current_ins_6m, (mody_calc_results_local%>% filter(diabetes_type=="type 1"))$diagnosis_under_18), margin=2)

prop.table(table((mody_calc_results_local %>% filter(diabetes_type=="type 2"))$current_ins_6m, (mody_calc_results_local%>% filter(diabetes_type=="type 2"))$diagnosis_under_18), margin=2)



## Earliest type-specific code

all_patid_clean_dm_codes <- all_patid_clean_dm_codes %>% analysis$cached("all_patid_clean_dm_codes")

all_patid_earliest_type_1_code <- all_patid_clean_dm_codes %>%
  filter(category=="type 1") %>%
  group_by(patid) %>%
  summarise(earliest_type_1=min(date, na.rm=TRUE)) %>%
  ungroup() %>%
  analysis$cached("all_patid_earliest_type_1_code", unique_indexes="patid")


mody_calc_results_local <- mody_calc_results %>%
  left_join(all_patid_earliest_type_1_code, by="patid") %>%
  mutate(earliest_type_1_6m=ifelse(!is.na(earliest_type_1) & datediff(earliest_type_1, diagnosis_date)<=183, "yes",
                                   ifelse(!is.na(earliest_type_1), "no", NA))) %>%
  filter(!is.na(fh_diabetes)) %>%
  select(diabetes_type, diagnosis_date, dm_diag_age, insulin_6_months, insulin_6_months_no_missing, current_ins_6m, earliest_type_1, earliest_type_1_6m, mody_prob) %>%
  collect() %>%
  mutate(diagnosis_under_18=factor(ifelse(dm_diag_age<18, "under18", "18andover"), levels=c("under18", "18andover")),
         insulin_6_months=factor(insulin_6_months, levels=c(1,0)),
         current_ins_6m=factor(current_ins_6m, levels=c(1,0)),
         earliest_type_1_6m=factor(earliest_type_1_6m, levels=c("yes","no")))

prop.table(table((mody_calc_results_local %>% filter(diabetes_type=="type 1"))$earliest_type_1_6m, (mody_calc_results_local%>% filter(diabetes_type=="type 1"))$diagnosis_under_18), margin=2)

mody_calc_results_local <- mody_calc_results_local %>%
  mutate(ins_or_code=ifelse((!is.na(insulin_6_months) & insulin_6_months==1) | (!is.na(earliest_type_1_6m) & earliest_type_1_6m=="yes"), 1, 0)) 

prop.table(table((mody_calc_results_local %>% filter(diabetes_type=="type 1"))$ins_or_code, (mody_calc_results_local%>% filter(diabetes_type=="type 1"))$diagnosis_under_18), margin=2)


test <- mody_calc_results_local %>%
  filter(mody_prob>0.95)

prop.table(table((test %>% filter(diabetes_type=="type 1"))$insulin_6_months, (test %>% filter(diabetes_type=="type 1"))$diagnosis_under_18), margin=2)

prop.table(table((test %>% filter(diabetes_type=="type 1"))$insulin_6_months_no_missing, (test %>% filter(diabetes_type=="type 1"))$diagnosis_under_18), margin=2)

prop.table(table((test %>% filter(diabetes_type=="type 1"))$diagnosis_under_18))



