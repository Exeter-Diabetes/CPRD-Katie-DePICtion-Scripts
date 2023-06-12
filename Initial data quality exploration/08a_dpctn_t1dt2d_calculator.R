
# Apply the T1D T2D calculator to everyone in prevalent cohort diagnosed aged 18-50 years
## Just look at missing variables for now

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
  filter(dm_diag_age>=18 & dm_diag_age<=50 & (class=="type 1" | class=="type 2" | class=="unspecified" | class=="unspecified_with_primis" | class=="mixed; type 1" | class=="mixed; type 2")) %>%
  mutate(bmi_2_years=ifelse(bmiindexdiff>=-731, bmi, NA),
         bmi_2_years_datediff=ifelse(!is.na(bmi_2_years), -bmiindexdiff, NA),
         
         totalchol_2_years=ifelse(totalcholesterolindexdiff>=-731, totalcholesterol, NA),
         totalchol_2_years_datediff=ifelse(!is.na(totalchol_2_years), -totalcholesterolindexdiff, NA),
         
         hdl_2_years=ifelse(hdlindexdiff>=-731, hdl, NA),
         hdl_2_years_datediff=ifelse(!is.na(hdl_2_years), -hdlindexdiff, NA),
         
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
  
  analysis$cached("t1dt2d_cohort_interim_1", unique_indexes="patid")


t1dt2d_cohort %>% count()
#237592

t1dt2d_cohort %>% group_by(class) %>% count()
# type 1                    15694
# type 2                   170012
# unspecified               30300
# unspecified_with_primis    2508
# mixed; type 1              5586
# mixed; type 2             13492


## Check proportion where BMI is for aged <18

t1dt2d_cohort %>% mutate(age_at_bmi=datediff(bmidate, dob)/365.25) %>% filter(age_at_bmi<18) %>% count()
#346
346/237592 #0.1%


## Remake without BMI for <18 years

t1dt2d_cohort <- t1dt2d_cohort %>%
  mutate(age_at_bmi=datediff(bmidate, dob)/365.25,
         bmi_2_years=ifelse(age_at_bmi<18, NA, bmi_2_years),
         bmi_2_years_datediff=ifelse(age_at_bmi<18, NA, bmi_2_years_datediff),
         bmi_post_diag=ifelse(age_at_bmi<18, NA, bmi_post_diag),
         bmi_post_diag_datediff=ifelse(age_at_bmi<18, NA, bmi_post_diag_datediff)) %>%
  analysis$cached("t1dt2d_cohort", unique_indexes="patid")


############################################################################################

# Look at missing variables

t1dt2d_cohort_local <- collect(t1dt2d_cohort %>%
                               select(class, language, dm_diag_age, age_at_index, bmi_2_years, bmi_post_diag, totalchol_2_years, totalchol_post_diag, hdl_2_years, hdl_post_diag, triglyceride_2_years, triglyceride_post_diag, bmi_2_years_datediff, bmi_post_diag_datediff, totalchol_2_years_datediff, totalchol_post_diag_datediff, hdl_2_years_datediff, hdl_post_diag_datediff, triglyceride_2_years_datediff, triglyceride_post_diag_datediff)) %>%
  mutate(bmi_2_years_datediff=as.numeric(bmi_2_years_datediff),
         bmi_post_diag_datediff=as.numeric(bmi_post_diag_datediff),
         totalchol_2_years_datediff=as.numeric(totalchol_2_years_datediff),
         totalchol_post_diag_datediff=as.numeric(totalchol_post_diag_datediff),
         hdl_2_years_datediff=as.numeric(hdl_2_years_datediff),
         hdl_post_diag_datediff=as.numeric(hdl_post_diag_datediff),
         triglyceride_2_years_datediff=as.numeric(triglyceride_2_years_datediff),
         triglyceride_post_diag_datediff=as.numeric(triglyceride_post_diag_datediff))
  

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

z <- summarizor(t1dt2d_cohort_local, by="class", overall_label="overall")

tab_2 <- tabulator(z,
                   rows = c("variable", "stat"),
                   columns = "class",
                   `Est.` = as_paragraph(
                     as_chunk(stat_format(stat, value1, value2))),
                   `N` = as_paragraph(as_chunk(n_format(cts, percent)))
)

as_flextable(tab_2, separate_with = "variable")


t1dt2d_cohort <- t1dt2d_cohort %>%
  mutate(with_gad=ifelse(!is.na(earliest_negative_gad) | !is.na(earliest_positive_gad), 1, 0),
         with_ia2=ifelse(!is.na(earliest_negative_ia2) | !is.na(earliest_positive_ia2), 1, 0))

t1dt2d_cohort %>% 
  group_by(class) %>%
  summarise(count=n())

t1dt2d_cohort %>%
  filter(with_gad==1) %>%
  group_by(class) %>%
  summarise(count=n())

t1dt2d_cohort %>%
  filter(with_ia2==1) %>%
  group_by(class) %>%
  summarise(count=n())


############################################################################################

# Check that separate weight and height measurements don't add

t1dt2d_cohort %>% filter(is.na(bmi_post_diag)) %>% count()
#13395
13395/237592 #5.6%


t1dt2d_cohort %>%
  mutate(weight_post_diag=ifelse(weightdate>=dm_diag_date, weight, NA)) %>%
  filter(is.na(bmi_post_diag) & !is.na(height) & !is.na(weight_post_diag)) %>%
  count()
#1941
1941/237592 #0.8%

t1dt2d_cohort %>%
  mutate(weight_post_diag=ifelse(weightdate>=dm_diag_date, weight, NA),
         age_at_weight=datediff(weightdate, dob)/365.25,
         age_at_height=datediff(heightdate, dob)/365.25) %>%
  filter(is.na(bmi_post_diag) & !is.na(height) & !is.na(weight_post_diag) & age_at_weight>=18 & age_at_height>=18) %>%
  count()
#1869
1869/237592 #0.8%

