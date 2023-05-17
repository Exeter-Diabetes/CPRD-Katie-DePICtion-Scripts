
# Apply the MODY calculator to everyone in prevalent cohort diagnosed aged 1-35 years

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

# Define MODY cohort: patients diagnosed with a current Type 1 or Type 2 diagnosis or unspecified type, diagnosed aged 1-35
## At the moment don't have T1/T2 and T2/gestational people

mody_cohort <- cohort %>%
  filter(dm_diag_age>=1 & dm_diag_age<=35 & (class=="type 1" | class=="type 2" | class=="unspecified")) %>%
  mutate(hba1c_2_years=ifelse(hba1cindexdiff>=-731, hba1c, NA),
         hba1c_2_years_datediff=ifelse(!is.na(hba1c_2_years), hba1cindexdiff, NA),
         bmi_2_years=ifelse(bmiindexdiff>=-731, bmi, NA),
         bmi_2_years_datediff=ifelse(!is.na(bmi_2_years), bmiindexdiff, NA),
         hba1c_post_diag=ifelse(hba1cdate>=dm_diag_date, hba1c, NA),
         hba1c_post_diag_datediff=ifelse(!is.na(hba1c_post_diag), hba1cindexdiff, NA),
         bmi_post_diag=ifelse(bmidate>=dm_diag_date, bmi, NA),
         bmi_post_diag_datediff=ifelse(!is.na(bmi_post_diag), bmiindexdiff, NA),
         insulin_6_months=ifelse(!is.na(time_to_ins_days) & time_to_ins_days<=183, 1,
                                 ifelse((!is.na(time_to_ins_days) & time_to_ins_days>183) | ins_ever==0, 0, NA)),
         insoha=ifelse(current_oha_6m==1 | current_ins_6m==1, 1L, 0L)) %>%
  analysis$cached("mody_cohort", unique_indexes="patid")

mody_cohort %>% group_by(class) %>% count()


############################################################################################

# Look at missing variables

mody_cohort_local <- collect(mody_cohort %>%
                               select(class, dm_diag_age, age_at_index, fh_diabetes, starts_with("hba1c"), starts_with("bmi"), ins_ever, insulin_6_months, insoha)) %>%
  mutate(fh_diabetes=as.factor(fh_diabetes),
         insulin_6_months=as.factor(insulin_6_months),
         insoha=as.factor(insoha),
         bmi_2_years_datediff=-bmi_2_years_datediff,
         bmi_post_diag_datediff=-bmi_post_diag_datediff,
         hba1c_2_years_datediff=-hba1c_2_years_datediff,
         hba1c_post_diag_datediff=-hba1c_post_diag_datediff)
  
as_flextable(summarizor(mody_cohort_local, by="class", overall_label="overall"))

mody_cohort_local <- mody_cohort_local %>%
  mutate(missing_any_var=ifelse(is.na(bmi_post_diag_datediff) | is.na(hba1c_post_diag_datediff) | is.na(fh_diabetes) | is.na(insulin_6_months), 1, 0))

table(mody_cohort_local$class, mody_cohort_local$missing_any_var)

prop.table(table(mody_cohort_local$class, mody_cohort_local$missing_any_var), margin=1)


############################################################################################

# Find small subset with complete variables and calculate MODY probability

complete_mody_cohort <- mody_cohort %>%
  filter(!is.na(fh_diabetes) & !is.na(bmi_post_diag) & !is.na(hba1c_post_diag) & !is.na(insulin_6_months)) %>%
  
  mutate(hba1c_post_diag_perc=(0.09148*hba1c_post_diag)+2.152,
         
         mody_logOR=ifelse(insulin_6_months==1,
                           1.8196 + (3.1404*fh_diabetes) - (0.0829*age_at_index) - (0.6598*hba1c_post_diag_perc) + (0.1011*dm_diag_age) + (1.3131*gender),
                           19.28 - (0.3154*dm_diag_age) - (0.2324*bmi_post_diag) - (0.6276*hba1c_post_diag_perc) + (1.7473*fh_diabetes) - (0.0352*age_at_index) - (0.9952*insoha) + (0.6943*gender)),
         
         mody_prob=exp(mody_logOR)/(1+exp(mody_logOR)),
         
         mody_adj_prob=ifelse(insulin_6_months==1, case_when(
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
         ))) %>%
  
  analysis$cached("complete_mody_cohort", unique_indexes="patid")

complete_case_score <- collect(complete_mody_cohort %>% select(class, insulin_6_months, fh_diabetes, dm_diag_age, age_at_index, bmi_post_diag, hba1c_post_diag, hba1c_post_diag_perc, insoha, mody_prob, mody_adj_prob)) %>%
  mutate(mody_prob=as.numeric(mody_prob),
         mody_adj_prob=as.numeric(mody_adj_prob),
         fh_diabetes=as.factor(fh_diabetes),
         insulin_6_months=as.factor(insulin_6_months),
         insoha=as.factor(insoha))
#14,026

table(complete_case_score$class)

as_flextable(summarizor((complete_case_score %>% select(class, dm_diag_age, age_at_index, bmi_post_diag, hba1c_post_diag, fh_diabetes, insulin_6_months, insoha)), by="class", overall_label="overall"))


## Histogram of unadjusted
ggplot (complete_case_score, aes(x=mody_prob)) + 
  geom_histogram(aes(y = after_stat(count / sum(count))), binwidth=0.01) +
  scale_y_continuous(labels = scales::percent)

## Histogram of adjusted
ggplot (complete_case_score, aes(x=mody_adj_prob)) + 
  geom_histogram(aes(y = after_stat(count / sum(count))), binwidth=2) +
  scale_y_continuous(labels = scales::percent)

## Histogram of adjusted - coloured by code category
ggplot (complete_case_score, aes(x=mody_adj_prob, fill=class)) + 
  geom_histogram(aes(y = after_stat(count / sum(count))), binwidth=2) +
  scale_y_continuous(labels = scales::percent)

complete_case_score <- complete_case_score %>% mutate(new_class=paste0(class," ins_6_mos=",insulin_6_months))

## Histogram of adjusted - coloured by code category
ggplot (complete_case_score, aes(x=mody_adj_prob, fill=new_class)) + 
  geom_histogram(aes(y = after_stat(count / sum(count))), binwidth=2) +
  scale_y_continuous(labels = scales::percent)






