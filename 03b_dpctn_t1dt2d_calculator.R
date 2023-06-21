
# Apply the T1D T2D calculator to everyone in prevalent cohort diagnosed aged 18-50 years

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

cohort %>% filter(dm_diag_age>=18 & dm_diag_age<=50) %>% count()
#256166

cohort %>% filter(dm_diag_age>=18 & dm_diag_age<=50 & (diabetes_type=="unspecified" | diabetes_type=="unspecified_with_primis")) %>% count()
#32697

cohort %>% filter(dm_diag_age>=18 & dm_diag_age<=50 & (diabetes_type=="type 2" | diabetes_type=="mixed; type 2" | diabetes_type=="type 1" | diabetes_type=="mixed; type 1")) %>% count()
#207722

cohort %>% filter(dm_diag_age>=18 & dm_diag_age<=50 & (diabetes_type=="type 1" | diabetes_type=="mixed; type 1")) %>% count()
#21646

cohort %>% filter(dm_diag_age>=18 & dm_diag_age<=50 & (diabetes_type=="type 2" | diabetes_type=="mixed; type 2" | diabetes_type=="type 1" | diabetes_type=="mixed; type 1") & is.na(diagnosis_date)) %>% count()
#10936

cohort %>% filter(dm_diag_age>=18 & dm_diag_age<=50 & (diabetes_type=="type 1" | diabetes_type=="mixed; type 1") & is.na(diagnosis_date)) %>% count()
#1477
10936-1477

cohort %>% filter(dm_diag_age>=18 & dm_diag_age<=50 & (diabetes_type=="type 2" | diabetes_type=="mixed; type 2" | diabetes_type=="type 1" | diabetes_type=="mixed; type 1") & !is.na(diagnosis_date)) %>% count()
#196786

cohort %>% filter(dm_diag_age>=18 & dm_diag_age<=50 & (diabetes_type=="type 1" | diabetes_type=="mixed; type 1") & !is.na(diagnosis_date)) %>% count()
#20169
196786-20169



# Define T1DT2D cohort: patients diagnosed with a current Type 1 or Type 2 diagnosis or unspecified type, diagnosed aged 18-50
## At the moment don't have T1/T2 and T2/gestational people

t1dt2d_cohort <- cohort %>%
  filter(dm_diag_age>=18 & dm_diag_age<=50 & (diabetes_type=="type 1" | diabetes_type=="type 2" | diabetes_type=="mixed; type 1" | diabetes_type=="mixed; type 2")) %>%
  mutate(age_at_bmi=datediff(bmidate, dob)/365.25,
         bmi_post_diag=ifelse(bmidate>=diagnosis_date & age_at_bmi>=18, bmi, NA),
         bmi_post_diag_datediff=ifelse(!is.na(bmi_post_diag), bmiindexdiff, NA),
         totalchol_post_diag=ifelse(totalcholesteroldate>=diagnosis_date, totalcholesterol, NA),
         hdl_post_diag=ifelse(hdldate>=diagnosis_date, hdl, NA),
         triglyceride_post_diag=ifelse(triglyceridedate>=diagnosis_date, triglyceride, NA)) %>%
  filter(!is.na(bmi_post_diag)) %>%
  analysis$cached("t1dt2d_cohort", unique_indexes="patid")

t1dt2d_cohort %>% count()

t1dt2d_cohort %>% group_by(diabetes_type) %>% count()


t1dt2d_cohort %>% filter(!is.na(totalchol_post_diag) & !is.na(hdl_post_diag) & !is.na(triglyceride_post_diag)) %>% count()
#177857

t1dt2d_cohort %>% filter(!is.na(totalchol_post_diag) & !is.na(hdl_post_diag) & !is.na(triglyceride_post_diag)) %>% group_by(diabetes_type) %>% count()


############################################################################################

# Look at time to BMI

t1dt2d_vars <- t1dt2d_cohort %>%
  select(diabetes_type, bmi_post_diag_datediff) %>%
  collect() %>%
  mutate(bmi_post_diag_datediff_yrs=as.numeric(bmi_post_diag_datediff)/365.25) %>%
  mutate(diabetes_type=factor(diabetes_type, levels=c("type 1", "type 2", "mixed; type 1", "mixed; type 2")))


## Time to BMI

ggplot ((t1dt2d_vars %>% filter(bmi_post_diag_datediff_yrs>-3)), aes(x=bmi_post_diag_datediff_yrs, fill=diabetes_type)) + 
  geom_histogram(aes(y = after_stat(count / sum(count))), binwidth=0.05) +
  scale_y_continuous(labels = scales::percent) +
  xlab("Years from BMI to current date") +
  ylab("Percentage")


t1dt2d_vars <- t1dt2d_vars %>%
  mutate(bmi_in_6_mos=bmi_post_diag_datediff_yrs>=-0.5,
         bmi_in_1_yr=bmi_post_diag_datediff_yrs>=-1,
         bmi_in_2_yrs=bmi_post_diag_datediff_yrs>=-2,
         bmi_in_5_yrs=bmi_post_diag_datediff_yrs>=-5)

prop.table(table(t1dt2d_vars$bmi_in_6_mos))
prop.table(table(t1dt2d_vars$diabetes_type, t1dt2d_vars$bmi_in_6_mos), margin=1)

prop.table(table(t1dt2d_vars$bmi_in_1_yr))
prop.table(table(t1dt2d_vars$diabetes_type, t1dt2d_vars$bmi_in_1_yr), margin=1)

prop.table(table(t1dt2d_vars$bmi_in_2_yrs))
prop.table(table(t1dt2d_vars$diabetes_type, t1dt2d_vars$bmi_in_2_yrs), margin=1)

prop.table(table(t1dt2d_vars$bmi_in_5_yrs))
prop.table(table(t1dt2d_vars$diabetes_type, t1dt2d_vars$bmi_in_5_yrs), margin=1)


############################################################################################

# Run T1DT2D calculator

t1dt2d_calc_results <- t1dt2d_cohort %>%
  
  mutate(sex=ifelse(gender==2, 0, ifelse(gender==1, 1, NA)),
         
         clinical_pred_score=37.94+(-5.09*log(dm_diag_age))+(-6.34*log(bmi_post_diag)),
         clinical_pred_prob=exp(clinical_pred_score)/(1+exp(clinical_pred_score)),
         
         standard_bmi=(bmi_post_diag-29.80365)/6.227818,
         standard_age=(dm_diag_age-35.78659)/9.794054,
         standard_cholesterol=(totalchol_post_diag-4.354878)/.9984224,
         standard_hdl=(hdl_post_diag-1.518598)/0.5607367,
         standard_trigs=(triglyceride_post_diag-1.719634)/1.771004,
         lipid_pred_score=(-1.4963*standard_bmi)+(-1.3358*standard_age)+(standard_cholesterol*-0.2473)+(sex*0.3026)+(0.6999*standard_hdl)+(-0.5322*standard_trigs)-4.0927,
         lipid_pred_prob=exp(lipid_pred_score)/(1+exp(lipid_pred_score))) %>%
  analysis$cached("t1dt2d_calc_results", unique_indexes="patid")
    
    

t1dt2d_calc_results_local <- t1dt2d_calc_results %>%
  select(diabetes_type, sex, dm_diag_age, bmi_post_diag, clinical_pred_prob, totalchol_post_diag, hdl_post_diag, triglyceride_post_diag, lipid_pred_prob) %>%
  collect() %>%
  mutate(diabetes_type=factor(diabetes_type, levels=c("type 1", "type 2", "mixed; type 1", "mixed; type 2")))
  
  
## Plot distribution

ggplot(t1dt2d_calc_results_local, aes(x=clinical_pred_prob, fill=diabetes_type, color=diabetes_type)) +
  geom_histogram(binwidth=0.01) +
  xlab("Clinical prediction model probability")#+
#theme(text = element_text(size = 20))


## Look at those with scores >90%

t1dt2d_calc_results_local %>% filter(clinical_pred_prob>0.9) %>% count()
t1dt2d_calc_results_local %>% filter(clinical_pred_prob>0.9) %>% group_by(diabetes_type) %>% count()





