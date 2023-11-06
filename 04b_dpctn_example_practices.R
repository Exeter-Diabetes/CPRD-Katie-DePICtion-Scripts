
# Apply the T1D T2D calculator to everyone in prevalent cohort diagnosed aged 18-50 years

############################################################################################

# Setup
library(tidyverse)
library(aurum)
rm(list=ls())

cprd = CPRDData$new(cprdEnv = "test-remote",cprdConf = "~/.aurum.yaml")

analysis = cprd$analysis("dpctn_final")


############################################################################################

# Get tables of MODY and T1DT2D results

cohort_interim_1 <- cohort_interim_1 %>% analysis$cached("cohort_interim_1")
# All patient registered on 01/02/2020

cohort <- cohort %>% analysis$cached("cohort")

mody_calc_results <- mody_calc_results %>% analysis$cached("mody_calc_results")
#currently doesn't have MODY people in it

t1dt2d_cohort_with_flags <- t1dt2d_cohort_with_flags %>% analysis$cached("t1dt2d_cohort_with_flags")
          
t1dt2d_calc_results <- t1dt2d_calc_results %>% analysis$cached("t1dt2d_calc_results")


############################################################################################

# Find all practice IDs to analyse - as want to include those with no flagged patients
## Include all with at least 500 diabetes patients diagnosed at any age on 01/02/2020

all_pracids <- cohort_interim_1 %>% group_by(pracid) %>% summarise(pt_count=n()) %>% filter(pt_count>=500) %>% select(pracid) %>% analysis$cached("all_pracids", unique_indexes="pracid")
all_pracids %>% count()
#642

# Just keep people flagged based on these thresholds to look at distribution of counts by practice:
## T1D probability <10%
## T2D probability >50%
## MODY probability >=58%

all_flagged_ids_any_prac <- (mody_calc_results %>% filter(mody_adj_prob_fh0>=58 | (mody_adj_prob_fh0<58 & mody_adj_prob_fh1>=58)) %>% select(patid, pracid)) %>%
  union_all(t1dt2d_cohort_with_flags %>% filter(!is.na(flag) & flag!="t2_no_current_ins") %>% select(patid, pracid)) %>%
  union_all(t1dt2d_calc_results %>% filter(((diabetes_type=="type 1" | diabetes_type=="mixed; type 1") & lipid_pred_prob<0.1)|((diabetes_type=="type 2" | diabetes_type=="mixed; type 2") & lipid_pred_prob>0.5)) %>% select(patid, pracid)) %>%
  distinct(pracid, patid) %>%
  analysis$cached("all_flagged_ids_any_prac")

all_flagged_ids <- all_pracids %>%
  left_join(all_flagged_ids_any_prac, by="pracid") %>%
  analysis$cached("all_flagged_ids")

    
practice_counts <- all_flagged_ids %>% group_by(pracid) %>% summarise(patient_count=sum(!is.na(patid))) %>% collect() %>% mutate(patient_count=as.integer(patient_count))

ggplot(practice_counts, aes(x=patient_count)) + 
  geom_histogram(binwidth=2) +
  theme(text = element_text(size = 22))
  
quantile(practice_counts$patient_count, probs=seq(0, 1, by=0.1))

quantile(practice_counts$patient_count, probs=c(0.25, 0.75))



## All practices (need to do locally in R to get percentiles)

flagged_patients <- cprd$tables$patient %>%
  select(patid, pracid) %>%
  left_join((t1dt2d_cohort_with_flags %>% filter(!is.na(flag) & flag!="t2_no_current_ins") %>% select(patid, flag, flag2)), by="patid") %>%
  left_join((t1dt2d_calc_results %>% filter((diabetes_type=="type 1" | diabetes_type=="mixed; type 1") & lipid_pred_prob<0.05) %>% mutate(t1_under5percent=1L) %>% select(patid, t1_under5percent)), by="patid") %>%
  left_join((t1dt2d_calc_results %>% filter((diabetes_type=="type 1" | diabetes_type=="mixed; type 1") & lipid_pred_prob<0.1) %>% mutate(t1_under10percent=1L) %>% select(patid, t1_under10percent)), by="patid") %>%
  left_join((t1dt2d_calc_results %>% filter((diabetes_type=="type 2" | diabetes_type=="mixed; type 2") & lipid_pred_prob>0.7) %>% mutate(t2_over70percent=1L) %>% select(patid, t2_over70percent)), by="patid") %>%
  left_join((t1dt2d_calc_results %>% filter((diabetes_type=="type 2" | diabetes_type=="mixed; type 2") & lipid_pred_prob>0.5) %>% mutate(t2_over50percent=1L) %>% select(patid, t2_over50percent)), by="patid") %>%
  left_join((mody_calc_results %>% filter(mody_adj_prob_fh0>=75.5) %>% mutate(mody_fh0_755=1L) %>% select(patid, mody_fh0_755)), by="patid") %>%
  left_join((mody_calc_results %>% filter(mody_adj_prob_fh0<75.5 & mody_adj_prob_fh1>=75.5) %>% mutate(mody_fh1_755=1L) %>% select(patid, mody_fh1_755)), by="patid") %>%
  left_join((mody_calc_results %>% filter(mody_adj_prob_fh0>=58) %>% mutate(mody_fh0_58=1L) %>% select(patid, mody_fh0_58)), by="patid") %>%
  left_join((mody_calc_results %>% filter(mody_adj_prob_fh0<58 & mody_adj_prob_fh1>=58) %>% mutate(mody_fh1_58=1L) %>% select(patid, mody_fh1_58)), by="patid") %>%
  left_join((mody_calc_results %>% filter(mody_adj_prob_fh0>=45.5) %>% mutate(mody_fh0_455=1L) %>% select(patid, mody_fh0_455)), by="patid") %>%
  left_join((mody_calc_results %>% filter(mody_adj_prob_fh0<45.5 & mody_adj_prob_fh1>=45.5) %>% mutate(mody_fh1_455=1L) %>% select(patid, mody_fh1_455)), by="patid") %>%
  filter((!is.na(flag) & flag!="t2_no_current_ins") | t1_under5percent==1 | t1_under10percent==1 | t2_over70percent==1 | t2_over50percent==1 | mody_fh0_755==1 | mody_fh1_755==1 | mody_fh0_58==1 | mody_fh1_58==1 | mody_fh0_455==1 | mody_fh1_455==1)

flagged_patients <- all_pracids %>% left_join(flagged_patients, by="pracid") %>% collect()


quantile((flagged_patients %>% filter(flag=="t2_ins_under_3_yrs") %>% group_by(pracid) %>% summarise(count=sum(!is.na(patid))))$count, probs=c(0.5, 0.25, 0.75))
quantile((flagged_patients %>% filter(flag2=="t2_ins_under_1_yrs") %>% group_by(pracid) %>% summarise(count=sum(!is.na(patid))))$count, probs=c(0.5, 0.25, 0.75))
quantile((flagged_patients %>% filter(flag2=="t2_ins_under_1_yrs" | flag2=="t2_ins_1_2_yrs") %>% group_by(pracid) %>% summarise(count=sum(!is.na(patid))))$count, probs=c(0.5, 0.25, 0.75))
quantile((flagged_patients %>% filter((diabetes_type=="type 2" | diabetes_type=="mixed; type 2") & (datediff(as.Date("2020-02-01"), diagnosis_date))/365.25<3) %>% group_by(pracid) %>% summarise(count=sum(!is.na(patid))))$count, probs=c(0.5, 0.25, 0.75))
quantile((flagged_patients %>% filter(flag=="t1_no_current_ins") %>% group_by(pracid) %>% summarise(count=sum(!is.na(patid))))$count, probs=c(0.5, 0.25, 0.75))
quantile((flagged_patients %>% filter(flag=="t1_non_mfn_oha") %>% group_by(pracid) %>% summarise(count=sum(!is.na(patid))))$count, probs=c(0.5, 0.25, 0.75))
quantile((flagged_patients %>% filter(flag=="t1_ins_over_5_yrs") %>% group_by(pracid) %>% summarise(count=sum(!is.na(patid))))$count, probs=c(0.5, 0.25, 0.75))
quantile((flagged_patients %>% filter(!is.na(flag) & flag!="t2_no_current_ins") %>% group_by(pracid) %>% summarise(count=sum(!is.na(patid))))$count, probs=c(0.5, 0.25, 0.75))

quantile((flagged_patients %>% filter(t1_under5percent==1) %>% group_by(pracid) %>% summarise(count=sum(!is.na(patid))))$count, probs=c(0.5, 0.25, 0.75))
quantile((flagged_patients %>% filter(t1_under10percent==1) %>% group_by(pracid) %>% summarise(count=sum(!is.na(patid))))$count, probs=c(0.5, 0.25, 0.75))
quantile((flagged_patients %>% filter(t2_over70percent==1) %>% group_by(pracid) %>% summarise(count=sum(!is.na(patid))))$count, probs=c(0.5, 0.25, 0.75))
quantile((flagged_patients %>% filter(t2_over50percent==1) %>% group_by(pracid) %>% summarise(count=sum(!is.na(patid))))$count, probs=c(0.5, 0.25, 0.75))

quantile((flagged_patients %>% filter(mody_fh0_755==1) %>% group_by(pracid) %>% summarise(count=sum(!is.na(patid))))$count, probs=c(0.5, 0.25, 0.75))
quantile((flagged_patients %>% filter(mody_fh1_755==1) %>% group_by(pracid) %>% summarise(count=sum(!is.na(patid))))$count, probs=c(0.5, 0.25, 0.75))
quantile((flagged_patients %>% filter(mody_fh0_58==1) %>% group_by(pracid) %>% summarise(count=sum(!is.na(patid))))$count, probs=c(0.5, 0.25, 0.75))
quantile((flagged_patients %>% filter(mody_fh1_58==1) %>% group_by(pracid) %>% summarise(count=sum(!is.na(patid))))$count, probs=c(0.5, 0.25, 0.75))
quantile((flagged_patients %>% filter(mody_fh0_455==1) %>% group_by(pracid) %>% summarise(count=sum(!is.na(patid))))$count, probs=c(0.5, 0.25, 0.75))
quantile((flagged_patients %>% filter(mody_fh1_455==1) %>% group_by(pracid) %>% summarise(count=sum(!is.na(patid))))$count, probs=c(0.5, 0.25, 0.75))


quantile((flagged_patients %>% filter((!is.na(flag) & flag!="t2_no_current_ins") | t1_under10percent==1 | t2_over70percent==1 | mody_fh0_58==1 | mody_fh1_58==1) %>% group_by(pracid) %>% summarise(count=sum(!is.na(patid))))$count, probs=c(0.5, 0.25, 0.75))


# Look at practices with loads of patients flagged

practice_counts <- flagged_patients %>% group_by(pracid) %>% summarise(pt_count=sum(!is.na(patid)))

practice_counts %>% filter(pt_count<10) %>% count()
#65
practice_counts %>% filter(pt_count<10) %>% inner_join(cohort_interim_1, copy=TRUE) %>% group_by(pracid) %>% summarise(total_pt_count=n()) %>% ungroup() %>% summarise(mean=mean(total_pt_count))
#623
practice_counts %>% filter(pt_count<10) %>% summarise(mean=mean(pt_count))
#7.3
7.3/623
#1.2%


practice_counts %>% filter(pt_count>9 & pt_count<20) %>% count()
#301
practice_counts %>% filter(pt_count>9 & pt_count<20) %>% inner_join(cohort_interim_1, copy=TRUE) %>% group_by(pracid) %>% summarise(total_pt_count=n()) %>% ungroup() %>% summarise(mean=mean(total_pt_count))
#750
practice_counts %>% filter(pt_count>9 & pt_count<20) %>% summarise(mean=mean(pt_count))
#14.9
14.9/750
#2.0%


practice_counts %>% filter(pt_count>19 & pt_count<30) %>% count()
#189
practice_counts %>% filter(pt_count>19 & pt_count<30) %>% inner_join(cohort_interim_1, copy=TRUE) %>% group_by(pracid) %>% summarise(total_pt_count=n()) %>% ungroup() %>% summarise(mean=mean(total_pt_count))
#858
practice_counts %>% filter(pt_count>19 & pt_count<30) %>% summarise(mean=mean(pt_count))
#23.2
23.2/858
#2.7%


practice_counts %>% filter(pt_count>29 & pt_count<40) %>% count()
#60
practice_counts %>% filter(pt_count>29 & pt_count<40) %>% inner_join(cohort_interim_1, copy=TRUE) %>% group_by(pracid) %>% summarise(total_pt_count=n()) %>% ungroup() %>% summarise(mean=mean(total_pt_count))
#1197
practice_counts %>% filter(pt_count>29 & pt_count<40) %>% summarise(mean=mean(pt_count))
#33.5
33.5/1197
#2.8%


practice_counts %>% filter(pt_count>39) %>% count()
#27
practice_counts %>% filter(pt_count>39) %>% inner_join(cohort_interim_1, copy=TRUE) %>% group_by(pracid) %>% summarise(total_pt_count=n()) %>% ungroup() %>% summarise(mean=mean(total_pt_count))
#1960
practice_counts %>% filter(pt_count>39) %>% summarise(mean=mean(pt_count))
#54.8
54.8/1960
#2.8%


practice_counts %>% filter(pt_count>59) %>% count()
#6
practice_counts %>% filter(pt_count>59) %>% inner_join(cohort_interim_1, copy=TRUE) %>% group_by(pracid) %>% summarise(total_pt_count=n()) %>% ungroup() %>% summarise(mean=mean(total_pt_count))
#2689
practice_counts %>% filter(pt_count>59) %>% summarise(mean=mean(pt_count))
#78.8
78.8/2689
#2.9%





# Patients in example practices

all_flagged_ids %>% collect() %>% distinct(pracid) %>% sample_n(1)
#21025

cohort_interim_1 %>% filter(pracid==21025) %>% count()
#1,070

example <- all_flagged_ids %>%
  filter(pracid==21025) %>%
  select(patid) %>%
  inner_join(flagged_patients, by="patid", copy=TRUE) %>%
  inner_join(cohort, by="patid", copy=TRUE) %>%
  mutate(hba1c_post_diag=ifelse(hba1cdate>=diagnosis_date, hba1c, NA),
         age_at_bmi=datediff(bmidate, dob)/365.25,
         bmi_post_diag=ifelse(bmidate>=diagnosis_date & age_at_bmi>=18, bmi, NA)) %>%
  select(patid, flag, flag2, t1_under5percent, t1_under10percent, t2_over70percent, t2_over50percent, mody_fh0_755, mody_fh1_755, mody_fh0_58, mody_fh1_58, diabetes_type, dm_diag_age, bmi_post_diag, gender, age_at_index, starts_with("current"), fh_diabetes, hba1c_post_diag, ethnicity_5cat, diagnosis_date, earliest_ins, regstartdate, bmi, hba1c) %>%
  left_join((t1dt2d_calc_results %>% select(patid, lipid_pred_prob)), by="patid", copy=TRUE) %>%
  left_join((mody_calc_results %>% select(patid, mody_adj_prob_fh0, mody_adj_prob_fh1)), by="patid", copy=TRUE) %>%
  collect()

clipr::write_clip(example)



all_flagged_ids %>% collect() %>% distinct(pracid) %>% sample_n(1)
#20519

cohort_interim_1 %>% filter(pracid==20519) %>% count()
#671

example <- all_flagged_ids %>%
  filter(pracid==20519) %>%
  select(patid) %>%
  inner_join(flagged_patients, by="patid", copy=TRUE) %>%
  inner_join(cohort, by="patid", copy=TRUE) %>%
  mutate(hba1c_post_diag=ifelse(hba1cdate>=diagnosis_date, hba1c, NA),
         age_at_bmi=datediff(bmidate, dob)/365.25,
         bmi_post_diag=ifelse(bmidate>=diagnosis_date & age_at_bmi>=18, bmi, NA)) %>%
  select(patid, flag, flag2, t1_under5percent, t1_under10percent, t2_over70percent, t2_over50percent, mody_fh0_755, mody_fh1_755, mody_fh0_58, mody_fh1_58, diabetes_type, dm_diag_age, bmi_post_diag, gender, age_at_index, starts_with("current"), fh_diabetes, hba1c_post_diag, ethnicity_5cat, diagnosis_date, earliest_ins, regstartdate, bmi, hba1c) %>%
  left_join((t1dt2d_calc_results %>% select(patid, lipid_pred_prob)), by="patid", copy=TRUE) %>%
  left_join((mody_calc_results %>% select(patid, mody_adj_prob_fh0, mody_adj_prob_fh1)), by="patid", copy=TRUE) %>%
  collect()

clipr::write_clip(example)



all_flagged_ids %>% collect() %>% distinct(pracid) %>% sample_n(1)
#20592

cohort_interim_1 %>% filter(pracid==20592) %>% count()
#1334

example <- all_flagged_ids %>%
  filter(pracid==20592) %>%
  select(patid) %>%
  inner_join(flagged_patients, by="patid", copy=TRUE) %>%
  inner_join(cohort, by="patid", copy=TRUE) %>%
  mutate(hba1c_post_diag=ifelse(hba1cdate>=diagnosis_date, hba1c, NA),
         age_at_bmi=datediff(bmidate, dob)/365.25,
         bmi_post_diag=ifelse(bmidate>=diagnosis_date & age_at_bmi>=18, bmi, NA)) %>%
  select(patid, flag, flag2, t1_under5percent, t1_under10percent, t2_over70percent, t2_over50percent, mody_fh0_755, mody_fh1_755, mody_fh0_58, mody_fh1_58, diabetes_type, dm_diag_age, bmi_post_diag, gender, age_at_index, starts_with("current"), fh_diabetes, hba1c_post_diag, ethnicity_5cat, diagnosis_date, earliest_ins, regstartdate, bmi, hba1c) %>%
  left_join((t1dt2d_calc_results %>% select(patid, lipid_pred_prob)), by="patid", copy=TRUE) %>%
  left_join((mody_calc_results %>% select(patid, mody_adj_prob_fh0, mody_adj_prob_fh1)), by="patid", copy=TRUE) %>%
  collect()

clipr::write_clip(example)
