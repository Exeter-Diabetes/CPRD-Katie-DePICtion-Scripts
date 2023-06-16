
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
#87455

cohort %>% filter(dm_diag_age>=1 & dm_diag_age<=35 & (diabetes_type=="unspecified" | diabetes_type=="unspecified_with_primis")) %>% count()
#12538

cohort %>% filter(dm_diag_age>=1 & dm_diag_age<=35 & (diabetes_type=="type 2" | diabetes_type=="mixed; type 2" | diabetes_type=="type 1" | diabetes_type=="mixed; type 1")) %>% count()
#64674

cohort %>% filter(dm_diag_age>=1 & dm_diag_age<=35 & (diabetes_type=="type 1" | diabetes_type=="mixed; type 1")) %>% count()
#30543

cohort %>% filter(dm_diag_age>=1 & dm_diag_age<=35 & (diabetes_type=="type 2" | diabetes_type=="mixed; type 2" | diabetes_type=="type 1" | diabetes_type=="mixed; type 1") & is.na(diagnosis_date)) %>% count()
#2870

cohort %>% filter(dm_diag_age>=1 & dm_diag_age<=35 & (diabetes_type=="type 1" | diabetes_type=="mixed; type 1") & is.na(diagnosis_date)) %>% count()
#1139
2870-1139

cohort %>% filter(dm_diag_age>=1 & dm_diag_age<=35 & (diabetes_type=="type 2" | diabetes_type=="mixed; type 2" | diabetes_type=="type 1" | diabetes_type=="mixed; type 1") & !is.na(diagnosis_date)) %>% count()
#61804

cohort %>% filter(dm_diag_age>=1 & dm_diag_age<=35 & (diabetes_type=="type 1" | diabetes_type=="mixed; type 1") & !is.na(diagnosis_date)) %>% count()
#29404
61804-29404


# Define MODY cohort: patients diagnosed with a current Type 1 or Type 2 diagnosis, diagnosed aged 1-35, with valid diagnosis date and BMI/HbA1c before diagnosis

mody_cohort <- cohort %>%
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
  analysis$cached("mody_cohort", unique_indexes="patid")

mody_cohort %>% count()
#60002

mody_cohort %>% group_by(diabetes_type) %>% count()
# type 1          23639
# type 2          23999
# mixed; type 2    7631
# mixed; type 1    4733


############################################################################################

# Look at variables

mody_vars <- mody_cohort %>%
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
  mutate(time_to_ins_yrs=as.numeric(difftime(earliest_ins, diagnosis_date, units="days"))/365.25) %>%
  select(diabetes_type, diagnosis_date, earliest_ins, time_to_ins_yrs)

ggplot (time_to_ins, aes(x=time_to_ins_yrs, fill=diabetes_type)) + 
  geom_histogram(aes(y = after_stat(count / sum(count))), binwidth=1) +
  scale_y_continuous(labels = scales::percent) +
  xlab("Years from diagnosis to earliest insulin script") +
  ylab("Percentage")


############################################################################################


# Run MODY calculator

mody_calc_results <- mody_cohort %>%
  filter(!is.na(hba1c_post_diag) & !is.na(bmi_post_diag)) %>%
  
  mutate(insulin_6_months_no_missing=ifelse(is.na(insulin_6_months), current_ins_6m, insulin_6_months),
         fh_diabetes_no_missing1=ifelse(is.na(fh_diabetes), 1L, fh_diabetes),
         fh_diabetes_no_missing0=ifelse(is.na(fh_diabetes), 0L, fh_diabetes),
         
         hba1c_post_diag_perc=(0.09148*hba1c_post_diag)+2.152,
         
         mody_logOR=ifelse(is.na(insulin_6_months) | is.na(fh_diabetes), NA,
                           ifelse(insulin_6_months==1, 1.8196 + (3.1404*fh_diabetes) - (0.0829*age_at_index) - (0.6598*hba1c_post_diag_perc) + (0.1011*dm_diag_age) + (1.3131*gender), 19.28 - (0.3154*dm_diag_age) - (0.2324*bmi_post_diag) - (0.6276*hba1c_post_diag_perc) + (1.7473*fh_diabetes) - (0.0352*age_at_index) - (0.9952*insoha) + (0.6943*gender))),
         
         mody_logOR_current_ins=ifelse(is.na(fh_diabetes), NA,
                           ifelse(insulin_6_months_no_missing==1, 1.8196 + (3.1404*fh_diabetes) - (0.0829*age_at_index) - (0.6598*hba1c_post_diag_perc) + (0.1011*dm_diag_age) + (1.3131*gender), 19.28 - (0.3154*dm_diag_age) - (0.2324*bmi_post_diag) - (0.6276*hba1c_post_diag_perc) + (1.7473*fh_diabetes) - (0.0352*age_at_index) - (0.9952*insoha) + (0.6943*gender))),
         
         mody_logOR_no_missing_fh1=ifelse(insulin_6_months_no_missing==1, 1.8196 + (3.1404*fh_diabetes_no_missing1) - (0.0829*age_at_index) - (0.6598*hba1c_post_diag_perc) + (0.1011*dm_diag_age) + (1.3131*gender), 19.28 - (0.3154*dm_diag_age) - (0.2324*bmi_post_diag) - (0.6276*hba1c_post_diag_perc) + (1.7473*fh_diabetes_no_missing1) - (0.0352*age_at_index) - (0.9952*insoha) + (0.6943*gender)),
         
         mody_logOR_no_missing_fh0=ifelse(insulin_6_months_no_missing==1, 1.8196 + (3.1404*fh_diabetes_no_missing0) - (0.0829*age_at_index) - (0.6598*hba1c_post_diag_perc) + (0.1011*dm_diag_age) + (1.3131*gender), 19.28 - (0.3154*dm_diag_age) - (0.2324*bmi_post_diag) - (0.6276*hba1c_post_diag_perc) + (1.7473*fh_diabetes_no_missing0) - (0.0352*age_at_index) - (0.9952*insoha) + (0.6943*gender)),
         
         mody_prob=exp(mody_logOR)/(1+exp(mody_logOR)),
         mody_prob_current_ins=exp(mody_logOR_current_ins)/(1+exp(mody_logOR_current_ins)),
         mody_prob_no_missing_fh1=exp(mody_logOR_no_missing_fh1)/(1+exp(mody_logOR_no_missing_fh1)),
         mody_prob_no_missing_fh0=exp(mody_logOR_no_missing_fh0)/(1+exp(mody_logOR_no_missing_fh0)),
         
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
         )),
         
         mody_adj_prob_current_ins=ifelse(insulin_6_months_no_missing==1, case_when(
           mody_prob_current_ins < 0.1 ~ 0.7,
           mody_prob_current_ins < 0.2 ~ 1.9,
           mody_prob_current_ins < 0.3 ~ 2.6,
           mody_prob_current_ins < 0.4 ~ 4.0,
           mody_prob_current_ins < 0.5 ~ 4.9,
           mody_prob_current_ins < 0.6 ~ 6.4,
           mody_prob_current_ins < 0.7 ~ 7.2,
           mody_prob_current_ins < 0.8 ~ 8.2,
           mody_prob_current_ins < 0.9 ~ 12.6,
           mody_prob_current_ins < 1.0 ~ 49.4
         ),
         case_when(
           mody_prob_current_ins < 0.1 ~ 4.6,
           mody_prob_current_ins < 0.2 ~ 15.1,
           mody_prob_current_ins < 0.3 ~ 21.0,
           mody_prob_current_ins < 0.4 ~ 24.4,
           mody_prob_current_ins < 0.5 ~ 32.9,
           mody_prob_current_ins < 0.6 ~ 35.8,
           mody_prob_current_ins < 0.7 ~ 45.5,
           mody_prob_current_ins < 0.8 ~ 58.0,
           mody_prob_current_ins < 0.9 ~ 62.4,
           mody_prob_current_ins < 1.0 ~ 75.5
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
  
mody_calc_results %>% count()

mody_calc_results %>% group_by(diabetes_type) %>% count()
  

############################################################################################

# Cohort characteristics

mody_cohort_local <- collect(mody_calc_results %>%
                               select(diabetes_type, dm_diag_age, age_at_index, hba1c_post_diag, bmi_post_diag, insulin_6_months, insoha, current_ins_6m, fh_diabetes, insulin_6_months_no_missing, mody_prob, mody_adj_prob, mody_prob_current_ins, mody_adj_prob_current_ins, mody_prob_no_missing_fh1, mody_adj_prob_no_missing_fh1, mody_prob_no_missing_fh0, mody_adj_prob_no_missing_fh0)) %>%
  mutate(fh_diabetes=as.factor(fh_diabetes),
         insulin_6_months=as.factor(insulin_6_months),
         insoha=as.factor(insoha),
         current_ins_6m=as.factor(current_ins_6m),
         mody_prob=mody_prob*100,
         mody_prob_current_ins=mody_prob_current_ins*100,
         mody_prob_no_missing_fh1=mody_prob_no_missing_fh1*100,
         mody_prob_no_missing_fh0=mody_prob_no_missing_fh0*100)
  
n_format <- function(n, percent) {
  z <- character(length = length(n))
  wcts <- !is.na(n)
  z[wcts] <- sprintf("%.0f (%.01f%%)",
                     n[wcts], percent[wcts] * 100)
  z
}

stat_format <- function(stat, num1, num2,
                        num1_mask = "%.001f",
                        num2_mask = "(%.001f)") {
  z_num <- character(length = length(num1))
  
  is_mean_sd <- !is.na(num1) & !is.na(num2) & stat %in% "mean_sd"
  is_median_iqr <- !is.na(num1) & !is.na(num2) &
    stat %in% "median_iqr"
  is_range <- !is.na(num1) & !is.na(num2) & stat %in% "range"
  is_num_1 <- !is.na(num1) & is.na(num2)
  
  z_num[is_num_1] <- sprintf(num1_mask, num1[is_num_1])
  
  z_num[is_mean_sd] <- paste0(
    sprintf(num1_mask, num1[is_mean_sd]),
    " ",
    sprintf(num2_mask, num2[is_mean_sd])
  )
  z_num[is_median_iqr] <- paste0(
    sprintf(num1_mask, num1[is_median_iqr]),
    " ",
    sprintf(num2_mask, num2[is_median_iqr])
  )
  z_num[is_range] <- paste0(
    "[",
    sprintf(num1_mask, num1[is_range]),
    " - ",
    sprintf(num1_mask, num2[is_range]),
    "]"
  )
  
  z_num
}

z <- summarizor(mody_cohort_local, by="diabetes_type", overall_label="overall")

tab_2 <- tabulator(z,
                   rows = c("variable", "stat"),
                   columns = "diabetes_type",
                   `Est.` = as_paragraph(
                     as_chunk(stat_format(stat, value1, value2))),
                   `N` = as_paragraph(as_chunk(n_format(cts, percent)))
)

as_flextable(tab_2, separate_with = "variable")


## Overall excluding unspecified groups

mody_cohort_local2 <- collect(mody_calc_results %>%
                               filter(diabetes_type!="unspecified" & diabetes_type!="unspecified_with_primis") %>%
                               select(diabetes_type, dm_diag_age, age_at_index, hba1c_post_diag, bmi_post_diag, insulin_6_months, insoha, current_ins_6m, fh_diabetes, insulin_6_months_no_missing, mody_prob, mody_adj_prob, mody_prob_current_ins, mody_adj_prob_current_ins, mody_prob_no_missing_fh1, mody_adj_prob_no_missing_fh1, mody_prob_no_missing_fh0, mody_adj_prob_no_missing_fh0)) %>%
  mutate(fh_diabetes=as.factor(fh_diabetes),
         insulin_6_months=as.factor(insulin_6_months),
         insoha=as.factor(insoha),
         current_ins_6m=as.factor(current_ins_6m),
         mody_prob=mody_prob*100,
         mody_prob_current_ins=mody_prob_current_ins*100,
         mody_prob_no_missing_fh1=mody_prob_no_missing_fh1*100,
         mody_prob_no_missing_fh0=mody_prob_no_missing_fh0*100)

n_format <- function(n, percent) {
  z <- character(length = length(n))
  wcts <- !is.na(n)
  z[wcts] <- sprintf("%.0f (%.01f%%)",
                     n[wcts], percent[wcts] * 100)
  z
}

stat_format <- function(stat, num1, num2,
                        num1_mask = "%.001f",
                        num2_mask = "(%.001f)") {
  z_num <- character(length = length(num1))
  
  is_mean_sd <- !is.na(num1) & !is.na(num2) & stat %in% "mean_sd"
  is_median_iqr <- !is.na(num1) & !is.na(num2) &
    stat %in% "median_iqr"
  is_range <- !is.na(num1) & !is.na(num2) & stat %in% "range"
  is_num_1 <- !is.na(num1) & is.na(num2)
  
  z_num[is_num_1] <- sprintf(num1_mask, num1[is_num_1])
  
  z_num[is_mean_sd] <- paste0(
    sprintf(num1_mask, num1[is_mean_sd]),
    " ",
    sprintf(num2_mask, num2[is_mean_sd])
  )
  z_num[is_median_iqr] <- paste0(
    sprintf(num1_mask, num1[is_median_iqr]),
    " ",
    sprintf(num2_mask, num2[is_median_iqr])
  )
  z_num[is_range] <- paste0(
    "[",
    sprintf(num1_mask, num1[is_range]),
    " - ",
    sprintf(num1_mask, num2[is_range]),
    "]"
  )
  
  z_num
}

z <- summarizor(mody_cohort_local2, by="diabetes_type", overall_label="overall")

tab_2 <- tabulator(z,
                   rows = c("variable", "stat"),
                   columns = "diabetes_type",
                   `Est.` = as_paragraph(
                     as_chunk(stat_format(stat, value1, value2))),
                   `N` = as_paragraph(as_chunk(n_format(cts, percent)))
)

as_flextable(tab_2, separate_with = "variable")


############################################################################################

# Look at top 10% when current insulin used and family history set to 0 or 1

## Family history==1

quantile(mody_cohort_local$mody_adj_prob_no_missing_fh1, .9)
#58%

top10_fh1 <- mody_cohort_local %>%
  filter(mody_adj_prob_no_missing_fh1>=58)

top10_fh1 %>% count()
#6688

top10_fh1 %>% filter(is.na(fh_diabetes)) %>% count()
#4139
4139/6688 #61.9%

top10_fh1 %>% group_by(diabetes_type) %>% count()

prop.table(table(top10_fh1$diabetes_type))


## Family history==0

quantile(mody_cohort_local$mody_adj_prob_no_missing_fh0, .9)
#45.5%

top10_fh0 <- mody_cohort_local %>%
  filter(mody_adj_prob_no_missing_fh0>=45.5)

top10_fh0 %>% count()
#6657

top10_fh0 %>% filter(is.na(fh_diabetes)) %>% count()
#2870
2870/6657 #43.1%

top10_fh0 %>% group_by(diabetes_type) %>% count()

prop.table(table(top10_fh0$diabetes_type))



############################################################################################

mody_mody_cohort <- cohort %>%
  filter(dm_diag_age>=1 & dm_diag_age<=35 & diabetes_type=="mody") %>%
  mutate(hba1c_post_diag=ifelse(hba1cdate>=diagnosis_date, hba1c, NA),
         age_at_bmi=datediff(bmidate, dob)/365.25,
         bmi_post_diag=ifelse(bmidate>=diagnosis_date & age_at_bmi>=18, bmi, NA),
         insulin_6_months=ifelse(!is.na(time_to_ins_days) & time_to_ins_days<=183, 1,
                                 ifelse((!is.na(time_to_ins_days) & time_to_ins_days>183) | ins_ever==0, 0, NA)),
         insoha=ifelse(current_oha_6m==1 | current_ins_6m==1, 1L, 0L)) %>%
  analysis$cached("mody_mody_cohort", unique_indexes="patid")

mody_mody_cohort %>% count()

mody_mody_cohort %>% filter(!is.na(hba1c_post_diag) & !is.na(bmi_post_diag) & !is.na(fh_diabetes)) %>% count()


mody_mody_cohort






############################################################################################




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
#14,013

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






