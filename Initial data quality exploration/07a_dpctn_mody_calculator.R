
# Apply the MODY calculator to everyone in prevalent cohort diagnosed aged 1-35 years
## Just looking at missing variables in this script

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
## Need to remove BMI if <18 years of age

mody_cohort <- cohort %>%
  filter(dm_diag_age>=1 & dm_diag_age<=35 & (class=="type 1" | class=="type 2" | class=="unspecified" | class=="unspecified_with_primis" | class=="mixed; type 1" | class=="mixed; type 2")) %>%
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
  analysis$cached("mody_cohort_interim_1", unique_indexes="patid")


mody_cohort %>% count()
#76755

mody_cohort %>% group_by(class) %>% count()
# type 1                      25514
# type 2                      26175
# unspecified                 11799
# unspecified_with_primis     837
# mixed; type 2               7654
# mixed; type 1               4776


## Check proportion where BMI is for aged <18

mody_cohort %>% mutate(age_at_bmi=datediff(bmidate, dob)/365.25) %>% filter(age_at_bmi<18) %>% count()
#1247
1247/76755 #1.6%


mody_cohort %>% mutate(age_at_bmi=datediff(bmidate, dob)/365.25) %>% filter(age_at_bmi<18) %>% group_by(class) %>% count()
# type 1                      483 #1.9%
# type 2                      45 #0.2%
# unspecified                 682 #5.8%
# unspecified_with_primis     28 #3.3%
# mixed; type 1               5 #0.06%
# mixed; type 2               4 #0.08%


## Remake without BMI for <18 years

mody_cohort <- mody_cohort %>%
  mutate(age_at_bmi=datediff(bmidate, dob)/365.25,
         bmi_2_years=ifelse(age_at_bmi<18, NA, bmi_2_years),
         bmi_2_years_datediff=ifelse(age_at_bmi<18, NA, bmi_2_years_datediff),
         bmi_post_diag=ifelse(age_at_bmi<18, NA, bmi_post_diag),
         bmi_post_diag_datediff=ifelse(age_at_bmi<18, NA, bmi_post_diag_datediff)) %>%
  analysis$cached("mody_cohort", unique_indexes="patid")


############################################################################################

# Check that separate weight and height measurements don't add

mody_cohort %>% filter(is.na(bmi_post_diag)) %>% count()
#6982
6982/76755 #9.1%


mody_cohort %>%
  mutate(weight_post_diag=ifelse(weightdate>=dm_diag_date, weight, NA)) %>%
  filter(is.na(bmi_post_diag) & !is.na(height) & !is.na(weight_post_diag)) %>%
  count()
#1464
1464/76755 #1.9%
  
mody_cohort %>%
  mutate(weight_post_diag=ifelse(weightdate>=dm_diag_date, weight, NA),
         age_at_weight=datediff(weightdate, dob)/365.25,
         age_at_height=datediff(heightdate, dob)/365.25) %>%
  filter(is.na(bmi_post_diag) & !is.na(height) & !is.na(weight_post_diag) & age_at_weight>=18 & age_at_height>=18) %>%
  count()
#653
653/76755 #0.9%


############################################################################################

# Look at missing variables

mody_cohort_local <- collect(mody_cohort %>%
                               select(class, language, dm_diag_age, age_at_index, fh_diabetes, starts_with("hba1c"), starts_with("bmi"), ins_ever, insulin_6_months, insoha)) %>%
  mutate(fh_diabetes=as.factor(fh_diabetes),
         insulin_6_months=as.factor(insulin_6_months),
         insoha=as.factor(insoha),
         ins_ever=as.factor(ins_ever),
         bmi_2_years_datediff=-(as.numeric(bmi_2_years_datediff)),
         bmi_post_diag_datediff=-(as.numeric(bmi_post_diag_datediff)),
         hba1c_2_years_datediff=-(as.numeric(hba1c_2_years_datediff)),
         hba1c_post_diag_datediff=-(as.numeric(hba1c_post_diag_datediff)))


n_format <- function(n, percent) {
  z <- character(length = length(n))
  wcts <- !is.na(n)
  z[wcts] <- sprintf("%.0f (%.01f%%)",
                     n[wcts], percent[wcts] * 100)
  z
}

stat_format <- function(stat, num1, num2,
                        num1_mask = "%.01f",
                        num2_mask = "(%.01f)") {
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

z <- summarizor(mody_cohort_local, by="class", overall_label="overall")

tab_2 <- tabulator(z,
                   rows = c("variable", "stat"),
                   columns = "class",
                   `Est.` = as_paragraph(
                     as_chunk(stat_format(stat, value1, value2))),
                   `N` = as_paragraph(as_chunk(n_format(cts, percent)))
)

as_flextable(tab_2, separate_with = "variable")
