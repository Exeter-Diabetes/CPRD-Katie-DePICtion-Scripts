
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
         insulin_6_months2=ifelse(is.na(earliest_ins), 0L,
                                  ifelse(datediff(earliest_ins, dm_diag_date)>183 & datediff(regstartdate, dm_diag_date)>183 & datediff(earliest_ins, regstartdate)<=183, NA,
                                  ifelse(datediff(earliest_ins, dm_diag_date)<=183, 1L, 0L))),
         insoha=ifelse(current_oha_6m==1 | current_ins_6m==1, 1L, 0L)) %>%
  analysis$cached("mody_cohort_interim_1", unique_indexes="patid")


mody_cohort %>% count()
#74523

mody_cohort %>% group_by(class) %>% count()
# type 1                      24765
# type 2                      25222
# unspecified                 11667
# unspecified_with_primis     798
# mixed; type 1               4630
# mixed; type 2               7441

## Check proportion where BMI is for aged <18

mody_cohort %>% mutate(age_at_bmi=datediff(bmidate, dob)/365.25) %>% filter(age_at_bmi<18) %>% count()
#1234
1234/74523 #1.7%


mody_cohort %>% mutate(age_at_bmi=datediff(bmidate, dob)/365.25) %>% filter(age_at_bmi<18) %>% group_by(class) %>% count()
# type 1                      473 #1.9%
# type 2                      44 #0.2%
# unspecified                 682 #5.8%
# unspecified_with_primis     26 #3.3%
# mixed; type 1               5 #0.1%
# mixed; type 2               4 #0.05%


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
#6918
6918/74523 #9.3%


mody_cohort %>%
  mutate(weight_post_diag=ifelse(weightdate>=dm_diag_date, weight, NA)) %>%
  filter(is.na(bmi_post_diag) & !is.na(height) & !is.na(weight_post_diag)) %>%
  count()
#1436
1436/74523 #1.9%
  
mody_cohort %>%
  mutate(weight_post_diag=ifelse(weightdate>=dm_diag_date, weight, NA),
         age_at_weight=datediff(weightdate, dob)/365.25,
         age_at_height=datediff(heightdate, dob)/365.25) %>%
  filter(is.na(bmi_post_diag) & !is.na(height) & !is.na(weight_post_diag) & age_at_weight>=18 & age_at_height>=18) %>%
  count()
#637
637/74523 #0.9%


############################################################################################

# Look at missing variables

mody_cohort_local <- collect(mody_cohort %>%
                               select(class, language, dm_diag_age, age_at_index, fh_diabetes, starts_with("hba1c"), starts_with("bmi"), ins_ever, insulin_6_months, insulin_6_months2, insoha)) %>%
  mutate(fh_diabetes=as.factor(fh_diabetes),
         insulin_6_months=as.factor(insulin_6_months),
         insulin_6_months2=as.factor(insulin_6_months2),
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


###########################################################################################################################

# Time to insulin in those diagnosed under 18 with Type 1 - doesn't look right

## Run MODY calculator just for those with non-missing family history

mody_calc_results <- mody_cohort %>%
  
  mutate(insulin_6_months_no_missing=ifelse(!is.na(insulin_6_months), insulin_6_months, current_ins_6m),
         
         hba1c_post_diag_perc=(0.09148*hba1c_post_diag)+2.152,
         
         mody_logOR=ifelse(is.na(fh_diabetes), NA,
                           ifelse(insulin_6_months_no_missing==1, 1.8196 + (3.1404*fh_diabetes) - (0.0829*age_at_index) - (0.6598*hba1c_post_diag_perc) + (0.1011*dm_diag_age) + (1.3131*gender),
                                  19.28 - (0.3154*dm_diag_age) - (0.2324*bmi_post_diag) - (0.6276*hba1c_post_diag_perc) + (1.7473*fh_diabetes) - (0.0352*age_at_index) - (0.9952*insoha) + (0.6943*gender))),
         
         mody_prob=exp(mody_logOR)/(1+exp(mody_logOR)),
         
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
         ))) %>%
  
  analysis$cached("mody_calc_results", unique_indexes="patid")


## Look at time to insulin in those not missing family history

mody_calc_results_local <- mody_calc_results %>%
  filter(!is.na(fh_diabetes) & class=="type 1") %>%
  select(class, dm_diag_date, dm_diag_age, insulin_6_months, insulin_6_months_no_missing, current_ins_6m, mody_prob) %>%
  collect() %>%
  mutate(diagnosis_under_18=factor(ifelse(dm_diag_age<18, "under18", "18andover"), levels=c("under18", "18andover")),
         insulin_6_months=factor(insulin_6_months, levels=c(1,0)),
         insulin_6_months_no_missing=factor(insulin_6_months_no_missing, levels=c(1,0)),
         current_ins_6m=factor(current_ins_6m, levels=c(1,0)))


prop.table(table(mody_calc_results_local$insulin_6_months, mody_calc_results_local$diagnosis_under_18), margin=2)

prop.table(table(mody_calc_results_local$current_ins_6m, mody_calc_results_local$diagnosis_under_18), margin=2)

prop.table(table(mody_calc_results_local$insulin_6_months_no_missing, mody_calc_results_local$diagnosis_under_18), margin=2)


mody_calc_results_local <- mody_calc_results_local %>%
  mutate(diag_year=format(dm_diag_date,"%Y"),
         diag_year_grouped=ifelse(diag_year>=1960 & diag_year<1970, "1960-1969",
                                  ifelse(diag_year>=1970 & diag_year<1980, "1970-1999",
                                         ifelse(diag_year>=1980 & diag_year<1990, "1980-1989",
                                                ifelse(diag_year>=1990 & diag_year<2000, "1990-1999",
                                                       ifelse(diag_year>=2000 & diag_year<2010, "2000-2009",
                                                              ifelse(diag_year>=2010 & diag_year<2021, "2010-2020", NA)))))))

table(mody_calc_results_local$diag_year_grouped, mody_calc_results_local$diagnosis_under_18)

mody_calc_results_local %>% filter(!is.na(insulin_6_months)) %>% group_by(diagnosis_under_18, diag_year_grouped) %>% summarise(count_6_months=sum(insulin_6_months=="1"), count=n()) %>% mutate(prop=count_6_months/count)

prop.table(table(mody_calc_results_local$insulin_6_months, mody_calc_results_local$diagnosis_under_18, mody_calc_results_local$diag_year_grouped), margin=2)





## Earliest type-specific code

earliest_latest_codes_long <- earliest_latest_codes_long %>% analysis$cached("earliest_latest_codes_long")

all_patid_earliest_type_1_code <- earliest_latest_codes_long %>%
  filter(category=="type_1") %>%
  select(patid, earliest_type_1=earliest) %>%
  analysis$cached("all_patid_earliest_type_1_code", unique_indexes="patid")


mody_calc_results_local <- mody_calc_results %>%
  left_join(all_patid_earliest_type_1_code, by="patid") %>%
  mutate(earliest_type_1_6m=ifelse(!is.na(earliest_type_1) & datediff(earliest_type_1, dm_diag_date)<=183, "yes",
                                   ifelse(!is.na(earliest_type_1), "no", NA))) %>%
  filter(!is.na(fh_diabetes) & class=="type 1") %>%
  select(class, dm_diag_age, insulin_6_months, insulin_6_months_no_missing, current_ins_6m, earliest_type_1_6m, mody_prob) %>%
  collect() %>%
  mutate(diagnosis_under_18=factor(ifelse(dm_diag_age<18, "under18", "18andover"), levels=c("under18", "18andover")),
         insulin_6_months=factor(insulin_6_months, levels=c(1,0)),
         insulin_6_months_no_missing=factor(insulin_6_months_no_missing, levels=c(1,0)),
         current_ins_6m=factor(current_ins_6m, levels=c(1,0)),
         earliest_type_1_6m=factor(earliest_type_1_6m, levels=c("yes","no")))

prop.table(table(mody_calc_results_local$earliest_type_1_6m, mody_calc_results_local$diagnosis_under_18), margin=2)


test <- mody_calc_results_local %>%
  filter(mody_prob>0.95)

prop.table(table(test$diagnosis_under_18))

prop.table(table(test$insulin_6_months, test$diagnosis_under_18), margin=2)

prop.table(table(test$insulin_6_months_no_missing, test$diagnosis_under_18), margin=2)




