
# Apply the T1D T2D calculator to everyone in prevalent cohort diagnosed aged 18-50 years

############################################################################################

# Setup
library(tidyverse)
library(aurum)
library(flextable)
rm(list=ls())

cprd = CPRDData$new(cprdEnv = "test-remote",cprdConf = "~/.aurum.yaml")

analysis = cprd$analysis("dpctn")


############################################################################################

# Get cohort info with diagnosis dates

cohort <- cohort %>% analysis$cached("cohort_with_diag_dates")


############################################################################################

# Define T1DT2D cohort: patients diagnosed with a current Type 1 or Type 2 diagnosis or unspecified type, diagnosed aged 18-50
## At the moment don't have T1/T2 and T2/gestational people

t1dt2d_cohort <- cohort %>%
  filter(dm_diag_age>=18 & dm_diag_age<=50 & (class=="type 1" | class=="type 2" | class=="unspecified")) %>%
  mutate(bmi_2_years=ifelse(bmiindexdiff>=-731, bmi, NA),
         bmi_2_years_datediff=ifelse(!is.na(bmi_2_years), -bmiindexdiff, NA),
         
         totalchol_2_years=ifelse(totalcholesterolindexdiff>=-731, totalcholesterol, NA),
         totalchol_2_years_datediff=ifelse(!is.na(totalchol_2_years), -totalcholesterolindexdiff, NA),
         
         hdl_2_years=ifelse(hdlindexdiff>=-731, hdl, NA),
         hdl_2_years_datediff=ifelse(!is.na(hdl_2_years), hdlindexdiff, NA),
         
         triglyceride_2_years=ifelse(triglycerideindexdiff>=-731, triglyceride, NA),
         triglyceride_2_years_datediff=ifelse(!is.na(triglyceride_2_years), -triglycerideindexdiff, NA),
         
         bmi_post_diag=ifelse(bmidate>=dm_diag_date, bmi, NA),
         bmi_post_diag_datediff=ifelse(!is.na(bmi_post_diag), -bmiindexdiff, NA),
         
         totalchol_post_diag=ifelse(totalcholesteroldate>=dm_diag_date, totalcholesterol, NA),
         totalchol_post_diag_datediff=ifelse(!is.na(totalchol_post_diag), -totalcholesterolindexdiff, NA),
         
         hdl_post_diag=ifelse(hdldate>=dm_diag_date, hdl, NA),
         hdl_post_diag_datediff=ifelse(!is.na(hdl_post_diag), -hdlindexdiff, NA),
         
         triglyceride_post_diag=ifelse(triglyceridedate>=dm_diag_date, triglyceride, NA),
         triglyceride_post_diag_datediff=ifelse(!is.na(triglyceride_post_diag), -triglycerideindexdiff, NA)) %>%
  
  analysis$cached("t1dt2d_cohort", unique_indexes="patid")

t1dt2d_cohort %>% group_by(class) %>% count()


############################################################################################

# Look at missing variables

t1dt2d_cohort_local <- collect(t1dt2d_cohort %>%
                               select(class, dm_diag_age, age_at_index, bmi_2_years, bmi_post_diag, totalchol_2_years, totalchol_post_diag, hdl_2_years, hdl_post_diag, triglyceride_2_years, triglyceride_post_diag, bmi_2_years_datediff, bmi_post_diag_datediff, totalchol_2_years_datediff, totalchol_post_diag_datediff, hdl_2_years_datediff, hdl_post_diag_datediff, triglyceride_2_years_datediff, triglyceride_post_diag_datediff)) %>%
  mutate(bmi_2_years_datediff=as.numeric(bmi_2_years_datediff),
         bmi_post_diag_datediff=as.numeric(bmi_post_diag_datediff),
         totalchol_2_years_datediff=as.numeric(totalchol_2_years_datediff),
         totalchol_post_diag_datediff=as.numeric(totalchol_post_diag_datediff),
         hdl_2_years_datediff=as.numeric(hdl_2_years_datediff),
         hdl_post_diag_datediff=as.numeric(hdl_post_diag_datediff),
         triglyceride_2_years_datediff=as.numeric(triglyceride_2_years_datediff),
         triglyceride_post_diag_datediff=as.numeric(triglyceride_post_diag_datediff))
  
 
as_flextable(summarizor(t1dt2d_cohort_local, by="class", overall_label="overall"))


t1dt2d_cohort_local <- t1dt2d_cohort_local %>%
  mutate(missing_any_var=ifelse(is.na(bmi_post_diag) | is.na(totalchol_post_diag) | is.na(hdl_post_diag) | is.na(triglyceride_post_diag), 1, 0))

table(t1dt2d_cohort_local$class, t1dt2d_cohort_local$missing_any_var)

prop.table(table(t1dt2d_cohort_local$class, t1dt2d_cohort_local$missing_any_var), margin=1)


t1dt2d_cohort <- t1dt2d_cohort %>%
  mutate(with_gad=ifelse(!is.na(earliest_negative_gad) | !is.na(earliest_positive_gad), 1, 0),
         with_ia2=ifelse(!is.na(earliest_negative_ia2) | !is.na(earliest_positive_ia2), 1, 0))

t1dt2d_cohort %>% 
  group_by(class) %>%
  summarise(count=n())


############################################################################################

# Calculate scores with and without lipids

t1dt2d_scores <- t1dt2d_cohort %>%
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
  analysis$cached("t1dt2d_scores", unique_indexes="patid")

t1dt2d_scores_local <- collect(t1dt2d_scores %>% select(class, clinical_pred_prob, lipid_pred_prob))

## Age + BMI model
ggplot (t1dt2d_scores_local, aes(x=clinical_pred_prob, fill=class)) + 
  geom_histogram(aes(y = after_stat(count / sum(count))), binwidth=0.01) +
  scale_y_continuous(labels = scales::percent)


## Lipid model
ggplot (t1dt2d_scores_local, aes(x=lipid_pred_prob, fill=class)) + 
  geom_histogram(aes(y = after_stat(count / sum(count))), binwidth=0.01) +
  scale_y_continuous(labels = scales::percent)



