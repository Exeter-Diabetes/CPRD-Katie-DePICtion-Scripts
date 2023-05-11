
# Apply the MODY calculator to everyone in prevalent cohort diagnosed <35 years of age

############################################################################################

# Setup
library(tidyverse)
library(aurum)
library(EHRBiomarkr)
library(flextable)
rm(list=ls())

cprd = CPRDData$new(cprdEnv = "test-remote",cprdConf = "~/.aurum.yaml")

analysis = cprd$analysis("dpctn_prevalent")


############################################################################################

# Get cohort info with diagnosis dates
cohort <- cohort %>% analysis$cached("cohort_diag_dates")

# Add in categories from code counts and other work looking at those with no type-specific codes - might want to change later
code_counts <- code_counts %>% analysis$cached("code_counts")

analysis = cprd$analysis("dpctn_data_qual")
unspec_data_all <- unspec_data_all %>% analysis$cached("unspec_data_all")
analysis = cprd$analysis("dpctn_prevalent")

code_categories <- code_counts %>%
  left_join((unspec_data_all %>% filter(unspec=="unspec_only") %>% select(patid, with_high_hba1c, oha_ever, ins_ever, other_codes)), by="patid") %>%
  mutate(code_category=ifelse(non_qof_t2>0 & non_qof_t1==0 & non_qof_gestational==0 & non_qof_malnutrition==0 & non_qof_mody==0 & non_qof_other_excl==0 & non_qof_other_gene==0 & non_qof_secondary==0, "type_2",
                              ifelse(non_qof_t1>0 & non_qof_t2==0 & non_qof_gestational==0 & non_qof_malnutrition==0 & non_qof_mody==0 & non_qof_other_excl==0 & non_qof_other_gene==0 & non_qof_secondary==0, "type_1",
                                     ifelse(non_qof_t1>0 & non_qof_t2>0 & non_qof_gestational==0 & non_qof_malnutrition==0 & non_qof_mody==0 & non_qof_other_excl==0 & non_qof_other_gene==0 & non_qof_secondary==0, "type_1_2",
                                            ifelse(non_qof_t1==0 & non_qof_t2==0 & (non_qof_gestational>0 | non_qof_malnutrition>0 | non_qof_mody>0 | non_qof_other_excl>0 | non_qof_other_gene>0 | non_qof_secondary>0), "exclusion_type",
                                                   ifelse((non_qof_t1>0 | non_qof_t2>0) & (non_qof_gestational>0 | non_qof_malnutrition>0 | non_qof_mody>0 | non_qof_other_excl>0 | non_qof_other_gene>0 | non_qof_secondary>0), "weird_mix",
                                                          ifelse(non_qof_t1==0 & non_qof_t2==0 & non_qof_gestational==0 & non_qof_malnutrition==0 & non_qof_mody==0 & non_qof_other_excl==0 & non_qof_other_gene==0 & non_qof_secondary==0 & (!is.na(with_high_hba1c) & with_high_hba1c==1) | (!is.na(oha_ever) & oha_ever==1) | (!is.na(ins_ever) & ins_ever==1), "unspec_but_evidence",
                                                                 ifelse(non_qof_t1==0 & non_qof_t2==0 & non_qof_gestational==0 & non_qof_malnutrition==0 & non_qof_mody==0 & non_qof_other_excl==0 & non_qof_other_gene==0 & non_qof_secondary==0 & with_high_hba1c==0 & oha_ever==0 & ins_ever==0 & is.na(other_codes), "unspec_seen_dm_clinic_only",
                                                                        ifelse(non_qof_t1==0 & non_qof_t2==0 & non_qof_gestational==0 & non_qof_mody==0 & non_qof_other_excl==0 & non_qof_other_gene==0 & non_qof_secondary==0 & with_high_hba1c==0 & oha_ever==0 & ins_ever==0 & other_codes==1, "unspec_other", NA)))))))))
                                                                        

cohort <- cohort %>%
  inner_join((code_categories %>% select(patid, starts_with("non_qof"), code_category)), by="patid") %>%
  analysis$cached("cohort_with_code_categories", unique_indexes="patid")

cohort %>% group_by(code_category) %>% summarise(count=n())
# Numbers match 20230301 powerpoint


############################################################################################

# Define MODY calculator cohort: only those diagnosed <35 years of age and >0 - will be looking into issues in the future
## Add variable for whether on insulin within 6 months of diagnosis - set to missing if diagnosed before registration and not on insulin within 6 months but on insulin eventually
## Add variable for whether currently treated with OHA/insulin (1) or diet alone (0) - use 6 months for now

raw_mody_cohort <- cohort %>%
  filter(raw_age_at_diagnosis_date<35) %>%
  mutate(raw_ins_within_6_months=ifelse(!is.na(raw_time_to_insulin_yrs) & raw_time_to_insulin_yrs<=0.5, 1,
                                        ifelse(ins_ever==0 | (!is.na(raw_time_to_insulin_yrs) & raw_time_to_insulin_yrs>0.5 & raw_diagnosis_date>=regstartdate), 0, NA)),
         insoha=ifelse(current_oha_6m==1 | current_ins_6m==1, 1L, 0L))

# clean_mody_cohort <- cohort %>%
#   filter(clean_age_at_diagnosis_date<35) %>%
#   mutate(clean_ins_within_6_months=ifelse(!is.na(clean_time_to_insulin_yrs) & clean_time_to_insulin_yrs<=0.5, 1,
#                                         ifelse(ins_ever==0 | (!is.na(clean_time_to_insulin_yrs) & clean_time_to_insulin_yrs>0.5 & raw_diagnosis_date>=regstartdate), 0, NA)),
#          insoha=ifelse(current_oha_6m==1 | current_ins_6m==1, 1L, 0L))


############################################################################################

# Look at missing variables

raw_mody_cohort_local <- collect(raw_mody_cohort %>% select(code_category, fh_diabetes, hba1c_6m, hba1c_2yrs, bmi, raw_ins_within_6_months)) %>%
  mutate(code_category=factor(code_category, levels=c("unspec_but_evidence", "unspec_seen_dm_clinic_only", "unspec_other", "type_2", "type_1", "exclusion_type", "type_1_2", "weird_mix")),
         fh_diabetes=factor(fh_diabetes),
         raw_ins_within_6_months=factor(raw_ins_within_6_months),
         missing_any_hba1c_6m=factor(ifelse(is.na(fh_diabetes) | is.na(hba1c_6m) | is.na(bmi) | is.na(raw_ins_within_6_months), 1, 0)),
         missing_any_hba1c_2yrs=factor(ifelse(is.na(fh_diabetes) | is.na(hba1c_2yrs) | is.na(bmi) | is.na(raw_ins_within_6_months), 1, 0)),
         missing_any_except_fh_hba1c_2_yrs=factor(ifelse(is.na(hba1c_2yrs) | is.na(bmi) | is.na(raw_ins_within_6_months), 1, 0)))

as_flextable(summarizor(raw_mody_cohort_local, by="code_category", overall_label="overall"))

raw_mody_cohort_local <- raw_mody_cohort_local %>%
  filter(code_category!="unspec_seen_dm_clinic_only")

as_flextable(summarizor(raw_mody_cohort_local, by="code_category", overall_label="overall"))


# clean_mody_cohort_local <- collect(clean_mody_cohort %>% select(code_category, fh_diabetes, hba1c_6m, hba1c_2yrs, bmi, clean_ins_within_6_months)) %>%
#   mutate(code_category=factor(code_category, levels=c("unspec_but_evidence", "unspec_seen_dm_clinic_only", "unspec_other", "type_2", "type_1", "exclusion_type", "type_1_2", "weird_mix")),
#          fh_diabetes=factor(fh_diabetes),
#          clean_ins_within_6_months=factor(clean_ins_within_6_months),
#          missing_any_hba1c_6m=factor(ifelse(is.na(fh_diabetes) | is.na(hba1c_6m) | is.na(bmi) | is.na(clean_ins_within_6_months), 1, 0)),
#          missing_any_hba1c_2yrs=factor(ifelse(is.na(fh_diabetes) | is.na(hba1c_2yrs) | is.na(bmi) | is.na(clean_ins_within_6_months), 1, 0)))
# 
# as_flextable(summarizor(clean_mody_cohort_local, by="code_category", overall_label="overall"))


############################################################################################

# Run on small subset with complete variables (use 2 year HbA1c)
## Remove if diagnosis date before birth - will remove in the future

complete_mody_cohort <- raw_mody_cohort %>%
  filter(!is.na(fh_diabetes) & !is.na(hba1c_2yrs) & !is.na(bmi) & !is.na(raw_ins_within_6_months) & raw_age_at_diagnosis_date>=0) %>%
  
  mutate(hba1c_2yrs_perc=(0.09148*hba1c_2yrs)+2.152,
         
         mody_logOR=ifelse(raw_ins_within_6_months==1, 1.8196 + (3.1404*fh_diabetes) - (0.0829*age_at_index) - (0.6598*hba1c_2yrs_perc) + (0.1011*raw_age_at_diagnosis_date) + (1.3131*gender), 19.28 - (0.3154*raw_age_at_diagnosis_date) - (0.2324*bmi) - (0.6276*hba1c_2yrs_perc) + (1.7473*fh_diabetes) - (0.0352*age_at_index) - (0.9952*insoha) + (0.6943*gender)),
         
         mody_prob=exp(mody_logOR)/(1+exp(mody_logOR)),
         
         mody_adj_prob=ifelse(raw_ins_within_6_months==1, case_when(
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

complete_case_score <- collect(complete_mody_cohort %>% select(patid, code_category, non_qof_mody, gender, raw_ins_within_6_months, fh_diabetes, raw_age_at_diagnosis_date, age_at_index, bmi, hba1c_2yrs_perc, insoha, mody_prob, mody_adj_prob)) %>%
  mutate(code_category=factor(code_category, levels=c("unspec_but_evidence", "unspec_seen_dm_clinic_only", "unspec_other", "type_2", "type_1", "exclusion_type", "type_1_2", "weird_mix")))
#21,042


## Histogram of unadjusted
ggplot (complete_case_score, aes(x=mody_prob)) + 
  geom_histogram(aes(y = after_stat(count / sum(count))), binwidth=0.01) +
  scale_y_continuous(labels = scales::percent)

## Histogram of adjusted
ggplot (complete_case_score, aes(x=mody_adj_prob)) + 
  geom_histogram(aes(y = after_stat(count / sum(count))), binwidth=2) +
  scale_y_continuous(labels = scales::percent)

## Histogram of adjusted - coloured by code category
ggplot (complete_case_score, aes(x=mody_adj_prob, fill=code_category)) + 
  geom_histogram(aes(y = after_stat(count / sum(count))), binwidth=2) +
  scale_y_continuous(labels = scales::percent)

### Proportion with insulin within 6 months
complete_case_score %>% group_by(code_category) %>% summarise(with_ins=sum(raw_ins_within_6_months)/n())

### Median adjusted score per code category
complete_case_score %>% group_by(code_category) %>% summarise(median=median(mody_adj_prob))

## Counts and proportions per adjusted score value
flextable(data.frame(table(complete_case_score$mody_adj_prob)))
flextable(data.frame(prop.table(table(complete_case_score$mody_adj_prob))))

## Counts and proportions when remove "unspec_seen_dm_clinic_only" group 
test <- complete_case_score %>% filter(code_category!="unspec_seen_dm_clinic_only")

flextable(data.frame(table(test$mody_adj_prob)))
flextable(data.frame(prop.table(table(test$mody_adj_prob))))

## Look at people with MODY codes
test <- complete_case_score %>% filter(non_qof_mody>1)
table(test$code_category)
test %>% filter(mody_adj_prob==75.5) %>% count()

## Look at people with scores==75.5
test <- complete_case_score %>% filter(mody_adj_prob==75.5)
prop.table(table(test$gender))
summary(test$raw_age_at_diagnosis_date)
summary(test$hba1c_2yrs_perc)
summary(test$bmi)
summary(test$age_at_index)
prop.table(table(test$fh_diabetes))
prop.table(table(test$insoha))


############################################################################################

# Run on subset missing family history only to see impact of setting this to 0 or 1
## Remove if diagnosis date before birth - will remove in the future

mody_cohort_missing_fh <- raw_mody_cohort %>%
  filter(is.na(fh_diabetes) & !is.na(hba1c_2yrs) & !is.na(bmi) & !is.na(raw_ins_within_6_months) & raw_age_at_diagnosis_date>=0) %>%
  
  mutate(hba1c_2yrs_perc=(0.09148*hba1c_2yrs)+2.152,
         
         mody_logOR_noFH=ifelse(raw_ins_within_6_months==1, 1.8196 + (3.1404*0) - (0.0829*age_at_index) - (0.6598*hba1c_2yrs_perc) + (0.1011*raw_age_at_diagnosis_date) + (1.3131*gender), 19.28 - (0.3154*raw_age_at_diagnosis_date) - (0.2324*bmi) - (0.6276*hba1c_2yrs_perc) + (1.7473*0) - (0.0352*age_at_index) - (0.9952*insoha) + (0.6943*gender)),
         
         mody_prob__noFH=exp(mody_logOR_noFH)/(1+exp(mody_logOR_noFH)),
         
         mody_adj_prob__noFH=ifelse(raw_ins_within_6_months==1, case_when(
           mody_prob__noFH < 0.1 ~ 0.7,
           mody_prob__noFH < 0.2 ~ 1.9,
           mody_prob__noFH < 0.3 ~ 2.6,
           mody_prob__noFH < 0.4 ~ 4.0,
           mody_prob__noFH < 0.5 ~ 4.9,
           mody_prob__noFH < 0.6 ~ 6.4,
           mody_prob__noFH < 0.7 ~ 7.2,
           mody_prob__noFH < 0.8 ~ 8.2,
           mody_prob__noFH < 0.9 ~ 12.6,
           mody_prob__noFH < 1.0 ~ 49.4
         ),
         case_when(
           mody_prob__noFH < 0.1 ~ 4.6,
           mody_prob__noFH < 0.2 ~ 15.1,
           mody_prob__noFH < 0.3 ~ 21.0,
           mody_prob__noFH < 0.4 ~ 24.4,
           mody_prob__noFH < 0.5 ~ 32.9,
           mody_prob__noFH < 0.6 ~ 35.8,
           mody_prob__noFH < 0.7 ~ 45.5,
           mody_prob__noFH < 0.8 ~ 58.0,
           mody_prob__noFH < 0.9 ~ 62.4,
           mody_prob__noFH < 1.0 ~ 75.5
         )),
         
         mody_logOR_withFH=ifelse(raw_ins_within_6_months==1, 1.8196 + (3.1404*1) - (0.0829*age_at_index) - (0.6598*hba1c_2yrs_perc) + (0.1011*raw_age_at_diagnosis_date) + (1.3131*gender), 19.28 - (0.3154*raw_age_at_diagnosis_date) - (0.2324*bmi) - (0.6276*hba1c_2yrs_perc) + (1.7473*1) - (0.0352*age_at_index) - (0.9952*insoha) + (0.6943*gender)),
         
         mody_prob__withFH=exp(mody_logOR_withFH)/(1+exp(mody_logOR_withFH)),
         
         mody_adj_prob__withFH=ifelse(raw_ins_within_6_months==1, case_when(
           mody_prob__withFH < 0.1 ~ 0.7,
           mody_prob__withFH < 0.2 ~ 1.9,
           mody_prob__withFH < 0.3 ~ 2.6,
           mody_prob__withFH < 0.4 ~ 4.0,
           mody_prob__withFH < 0.5 ~ 4.9,
           mody_prob__withFH < 0.6 ~ 6.4,
           mody_prob__withFH < 0.7 ~ 7.2,
           mody_prob__withFH < 0.8 ~ 8.2,
           mody_prob__withFH < 0.9 ~ 12.6,
           mody_prob__withFH < 1.0 ~ 49.4
         ),
         case_when(
           mody_prob__withFH < 0.1 ~ 4.6,
           mody_prob__withFH < 0.2 ~ 15.1,
           mody_prob__withFH < 0.3 ~ 21.0,
           mody_prob__withFH < 0.4 ~ 24.4,
           mody_prob__withFH < 0.5 ~ 32.9,
           mody_prob__withFH < 0.6 ~ 35.8,
           mody_prob__withFH < 0.7 ~ 45.5,
           mody_prob__withFH < 0.8 ~ 58.0,
           mody_prob__withFH < 0.9 ~ 62.4,
           mody_prob__withFH < 1.0 ~ 75.5
         ))) %>%
  
  analysis$cached("mody_cohort_missing_fh", unique_indexes="patid")

mody_cohort_missing_fh <- collect(mody_cohort_missing_fh %>% select(patid, code_category, gender, raw_ins_within_6_months, raw_age_at_diagnosis_date, age_at_index, bmi, hba1c_2yrs_perc, insoha, mody_prob__noFH, mody_adj_prob__noFH, mody_prob__withFH, mody_adj_prob__withFH)) %>%
  mutate(raw_ins_within_6_months=factor(raw_ins_within_6_months),
         code_category=factor(code_category, levels=c("unspec_but_evidence", "unspec_seen_dm_clinic_only", "unspec_other", "type_2", "type_1", "exclusion_type", "type_1_2", "weird_mix")))
#28,988

mody_cohort_missing_fh %>% filter(mody_adj_prob__noFH==mody_adj_prob__withFH) %>% count()
#10,168 have same adjusted probability whether or not family history is included

mody_cohort_missing_fh_long <- mody_cohort_missing_fh %>%
  pivot_longer(cols=c(mody_prob__noFH, mody_adj_prob__noFH, mody_prob__withFH, mody_adj_prob__withFH), names_to=c(".value", "FH"), names_sep="__")


## Histogram of with and without family history unadjusted - coloured by family history
ggplot(mody_cohort_missing_fh_long, aes(x=mody_prob, fill=FH)) + 
  geom_histogram(aes(y = after_stat(count / sum(count))), alpha=0.5, position="identity", binwidth=0.02) +
  scale_y_continuous(labels = scales::percent)

## Scatter plot of with vs without family history unadjusted - coloured by insulin within 6 months
ggplot(mody_cohort_missing_fh, aes(x=mody_prob__noFH, y=mody_prob__withFH, color=raw_ins_within_6_months)) + 
  geom_point()


## Histogram of with and without adjusted - coloured by family history
ggplot(mody_cohort_missing_fh_long, aes(x=mody_adj_prob, fill=FH)) + 
  geom_histogram(aes(y = after_stat(count / sum(count))), alpha=0.5, position="identity", binwidth=2) +
  scale_y_continuous(labels = scales::percent)

## Scatter plot of with vs without unadjusted - coloured by insulin within 6 months
ggplot(mody_cohort_missing_fh, aes(x=mody_adj_prob__noFH, y=mody_adj_prob__withFH, color=raw_ins_within_6_months)) + 
  geom_point(size=5, alpha=0.5) +
  geom_abline(colour = "grey20", size =0.6, linetype = "dashed")

## Scatter plot of with vs without unadjusted - coloured by code category
ggplot(mody_cohort_missing_fh, aes(x=mody_adj_prob__noFH, y=mody_adj_prob__withFH, color=code_category)) + 
  geom_point(size=5, alpha=0.5) +
  geom_abline(colour = "grey20", size =0.6, linetype = "dashed")

## Bubble plot of with vs without unadjusted
mody_compact <- mody_cohort_missing_fh %>%
  group_by(mody_adj_prob__noFH, mody_adj_prob__withFH) %>%
  summarise(count=n())

ggplot(mody_compact, aes(x=mody_adj_prob__noFH, y=mody_adj_prob__withFH, size = count)) +
  geom_point(alpha=0.5) +
  scale_size(range = c(1, 10)) +
  geom_abline(colour = "grey20", size =0.6, linetype = "dashed")

mody_compact2 <- mody_cohort_missing_fh %>%
  group_by(mody_adj_prob__noFH, mody_adj_prob__withFH, code_category) %>%
  summarise(count=n()) %>%
  pivot_wider(id_cols=c(mody_adj_prob__noFH, mody_adj_prob__withFH), names_from=code_category, values_from=count, values_fill=list(count=0))


ggplot() +
  geom_scatterpie(aes(x = mody_adj_prob__noFH, y = mody_adj_prob__withFH), data = mody_compact2, cols=c("unspec_but_evidence", "unspec_seen_dm_clinic_only", "unspec_other", "type_2", "type_1", "exclusion_type", "type_1_2", "weird_mix")) +
  coord_fixed() +
  geom_abline(colour = "grey20", size =0.6, linetype = "dashed")






