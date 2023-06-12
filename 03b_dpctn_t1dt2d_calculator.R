
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

# Define T1DT2D cohort: patients diagnosed with a current Type 1 or Type 2 diagnosis or unspecified type, diagnosed aged 18-50
## At the moment don't have T1/T2 and T2/gestational people

t1dt2d_cohort <- cohort %>%
  filter(dm_diag_age>=18 & dm_diag_age<=50 & (diabetes_type=="type 1" | diabetes_type=="type 2" | diabetes_type=="unspecified" | diabetes_type=="unspecified_with_primis" | diabetes_type=="mixed; type 1" | diabetes_type=="mixed; type 2")) %>%
  mutate(age_at_bmi=datediff(bmidate, dob)/365.25,
         bmi_post_diag=ifelse(bmidate>=diagnosis_date & age_at_bmi>=18, bmi, NA),
         totalchol_post_diag=ifelse(totalcholesteroldate>=diagnosis_date, totalcholesterol, NA),
         hdl_post_diag=ifelse(hdldate>=diagnosis_date, hdl, NA),
         triglyceride_post_diag=ifelse(triglyceridedate>=diagnosis_date, triglyceride, NA)) %>%
  analysis$cached("t1dt2d_cohort", unique_indexes="patid")

t1dt2d_cohort %>% count()

t1dt2d_cohort %>% group_by(diabetes_type) %>% count()



############################################################################################

# Run T1DT2D calculator

t1dt2d_calc_results <- t1dt2d_cohort %>%
  filter(!is.na(bmi_post_diag)) %>%
  
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
    
    
t1dt2d_calc_results %>% count()

t1dt2d_calc_results %>% group_by(diabetes_type) %>% count()


#Cohort characteristics

t1dt2d_scores_local <- collect(t1dt2d_calc_results %>% select(diabetes_type, dm_diag_age, age_at_index, bmi_post_diag, totalchol_post_diag, hdl_post_diag, triglyceride_post_diag, clinical_pred_prob, lipid_pred_prob)) %>%
  mutate(clinical_pred_prob=clinical_pred_prob*100,
         lipid_pred_prob=lipid_pred_prob*100)


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

z <- summarizor(t1dt2d_scores_local, by="diabetes_type", overall_label="overall")

tab_2 <- tabulator(z,
                   rows = c("variable", "stat"),
                   columns = "diabetes_type",
                   `Est.` = as_paragraph(
                     as_chunk(stat_format(stat, value1, value2))),
                   `N` = as_paragraph(as_chunk(n_format(cts, percent)))
)

as_flextable(tab_2, separate_with = "variable")


## Overall excluding unspecified groups

t1dt2d_scores_local2 <- collect(t1dt2d_calc_results %>% filter(diabetes_type!="unspecified" & diabetes_type!="unspecified_with_primis") %>% select(diabetes_type, dm_diag_age, age_at_index, bmi_post_diag, totalchol_post_diag, hdl_post_diag, triglyceride_post_diag, clinical_pred_prob, lipid_pred_prob)) %>%
  mutate(clinical_pred_prob=clinical_pred_prob*100,
         lipid_pred_prob=lipid_pred_prob*100)


z <- summarizor(t1dt2d_scores_local2, by="diabetes_type", overall_label="overall")

tab_2 <- tabulator(z,
                   rows = c("variable", "stat"),
                   columns = "diabetes_type",
                   `Est.` = as_paragraph(
                     as_chunk(stat_format(stat, value1, value2))),
                   `N` = as_paragraph(as_chunk(n_format(cts, percent)))
)

as_flextable(tab_2, separate_with = "variable")



## Age + BMI model
ggplot (t1dt2d_scores_local, aes(x=clinical_pred_prob, fill=diabetes_type)) + 
  geom_histogram(aes(y = after_stat(count / sum(count))), binwidth=0.01) +
  scale_y_continuous(labels = scales::percent)



