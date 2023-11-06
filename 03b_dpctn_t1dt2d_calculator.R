
# Apply the T1D T2D calculator to everyone in prevalent cohort diagnosed aged 18-50 years

############################################################################################

# Setup
library(tidyverse)
library(aurum)
library(EHRBiomarkr)
library(flextable)
rm(list=ls())

cprd = CPRDData$new(cprdEnv = "test-remote",cprdConf = "~/.aurum.yaml")
codesets = cprd$codesets()
codes = codesets$getAllCodeSetVersion(v = "31/10/2021")

analysis = cprd$analysis("dpctn_final")


############################################################################################

# Get cohort info

cohort <- cohort %>% analysis$cached("cohort")


############################################################################################

# Look at cohort size

cohort %>% filter(dm_diag_age>=18 & dm_diag_age<51) %>% count()
#274086

cohort %>% filter(dm_diag_age>=18 & dm_diag_age<51 & (diabetes_type=="unspecified" | diabetes_type=="unspecified_with_primis")) %>% count()
#34705
34705/274086 #12.7
274086-34705 #239381

cohort %>% filter(dm_diag_age>=18 & dm_diag_age<51 & (diabetes_type=="type 2" | diabetes_type=="mixed; type 2" | diabetes_type=="type 1" | diabetes_type=="mixed; type 1")) %>% count()
#223599
223599/239381 #93.4% of specified = T1 or T2

cohort %>% filter(dm_diag_age>=18 & dm_diag_age<51 & (diabetes_type=="type 1" | diabetes_type=="mixed; type 1")) %>% count()
#22007
223599-22007 #201592

cohort %>% filter(dm_diag_age>=18 & dm_diag_age<51 & (diabetes_type=="type 2" | diabetes_type=="mixed; type 2" | diabetes_type=="type 1" | diabetes_type=="mixed; type 1") & is.na(diagnosis_date)) %>% count()
#11617
11617/223599 #5.2

cohort %>% filter(dm_diag_age>=18 & dm_diag_age<51 & (diabetes_type=="type 1" | diabetes_type=="mixed; type 1") & is.na(diagnosis_date)) %>% count()
#1496
11617-1496 #10121

cohort %>% filter(dm_diag_age>=18 & dm_diag_age<51 & (diabetes_type=="type 2" | diabetes_type=="mixed; type 2" | diabetes_type=="type 1" | diabetes_type=="mixed; type 1") & !is.na(diagnosis_date)) %>% count()
#211982

cohort %>% filter(dm_diag_age>=18 & dm_diag_age<51 & (diabetes_type=="type 1" | diabetes_type=="mixed; type 1") & !is.na(diagnosis_date)) %>% count()
#20511
211982-20511 #191471



# Define T1DT2D cohort: patients diagnosed with a current Type 1 or Type 2 diagnosis, diagnosed aged 18-50

t1dt2d_cohort <- cohort %>%
  filter(dm_diag_age>=18 & dm_diag_age<51 & (diabetes_type=="type 1" | diabetes_type=="type 2" | diabetes_type=="mixed; type 1" | diabetes_type=="mixed; type 2") & !is.na(diagnosis_date)) %>%
  mutate(age_at_bmi=datediff(bmidate, dob)/365.25,
         hba1c_post_diag=ifelse(hba1cdate>=diagnosis_date, hba1c, NA), #not needed for calc
         hba1c_post_diag_datediff=ifelse(!is.na(hba1c_post_diag), hba1cindexdiff, NA), #not needed for calc
         bmi_post_diag=ifelse(bmidate>=diagnosis_date & age_at_bmi>=18, bmi, NA),
         bmi_post_diag_datediff=ifelse(!is.na(bmi_post_diag), bmiindexdiff, NA),
         totalchol_post_diag=ifelse(totalcholesteroldate>=diagnosis_date, totalcholesterol, NA),
         totalchol_post_diag_datediff=ifelse(!is.na(totalchol_post_diag), totalcholesterolindexdiff, NA),
         hdl_post_diag=ifelse(hdldate>=diagnosis_date, hdl, NA),
         hdl_post_diag_datediff=ifelse(!is.na(hdl_post_diag), hdlindexdiff, NA),
         triglyceride_post_diag=ifelse(triglyceridedate>=diagnosis_date, triglyceride, NA),
         triglyceride_post_diag_datediff=ifelse(!is.na(triglyceride_post_diag), triglycerideindexdiff, NA)) %>%
  analysis$cached("t1dt2d_cohort", unique_indexes="patid")


t1dt2d_cohort %>% count()
#223599
  

############################################################################################

# Add flags for those to be identified before T1DT2D calculator is run

t1dt2d_cohort_with_flags <- t1dt2d_cohort %>%
  mutate(flag=ifelse((diabetes_type=="type 1" | diabetes_type=="mixed; type 1") & current_insulin==0, "t1_no_current_ins",
                     ifelse((diabetes_type=="type 1" | diabetes_type=="mixed; type 1") & !is.na(earliest_ins) & (datediff(earliest_ins, pmax(diagnosis_date, regstartdate, na.rm=TRUE)))/365.25>5 & year(pmax(diagnosis_date, regstartdate, na.rm=TRUE))>=1995, "t1_ins_over_5_yrs",
                            ifelse((diabetes_type=="type 1" | diabetes_type=="mixed; type 1") & (current_dpp4==1 | current_tzd==1 | current_su==1 | current_sglt2==1 | current_glp1==1), "t1_non_mfn_oha",
                                   ifelse((diabetes_type=="type 2" | diabetes_type=="mixed; type 2") & current_insulin==0, "t2_no_current_ins",
                                          ifelse((diabetes_type=="type 2" | diabetes_type=="mixed; type 2") & current_insulin==1 & (datediff(earliest_ins, diagnosis_date))/365.25<=3, "t2_ins_under_3_yrs", NA))))),
         flag2=ifelse(is.na(flag) | flag!="t2_ins_under_3_yrs", NA, ifelse((datediff(earliest_ins, diagnosis_date))/365.25<=1, "t2_ins_under_1_yrs", ifelse((datediff(earliest_ins, diagnosis_date))/365.25<=2, "t2_ins_1_2_yrs", "t2_ins_2_3_yrs")))) %>%
  analysis$cached("t1dt2d_cohort_with_flags", unique_index="patid")
          
           
t1dt2d_cohort_with_flags %>% group_by(flag) %>% count()

#1 t2_no_current_ins   157097
#2 NA                   57645
#3 t2_ins_under_3_yrs    7083
#4 t1_no_current_ins      775
#5 t1_non_mfn_oha         638
#6 t1_ins_over_5_yrs      361


t1dt2d_cohort_with_flags %>% group_by(flag, flag2) %>% count()

#1 t2_no_current_ins  NA                  157097
#2 NA                 NA                   57645
#3 t2_ins_under_3_yrs t2_ins_under_1_yrs    3717
#4 t2_ins_under_3_yrs t2_ins_1_2_yrs        1598
#5 t2_ins_under_3_yrs t2_ins_2_3_yrs        1768
#6 t1_no_current_ins  NA                     775
#7 t1_non_mfn_oha     NA                     638
#8 t1_ins_over_5_yrs  NA                     361


t1dt2d_cohort_with_flags %>% filter((diabetes_type=="type 2" | diabetes_type=="mixed; type 2") & (datediff(as.Date("2020-02-01"), diagnosis_date))/365.25<3 & current_insulin==0) %>% count()
#22228

7083+775+638+361 #8857

(7083/9900000)*1000 #0.72
(3717/9900000)*1000 #0.38
((1598+3717)/9900000)*1000 #0.54
(775/9900000)*1000 #0.078
(638/9900000)*1000 #0.064
(361/9900000)*1000 #0.036
(8857/9900000)*1000 #0.89
(22228/9900000)*1000 #2.2

(7083/9900000)*7900 #5.7
(3717/9900000)*7900 #3.0
((1598+3717)/9900000)*7900 #4.2
(775/9900000)*7900 #0.6
(638/9900000)*7900 #0.5
(361/9900000)*7900 #0.3
(8857/9900000)*7900 #7.1
(22228/9900000)*7900 #17.7

(7083/9900000)*15800 #11.3
(3717/9900000)*15800 #5.9
((1598+3717)/9900000)*15800 #8.5
(775/9900000)*15800 #1.2
(638/9900000)*15800 #0.8
(361/9900000)*15800 #0.6
(22228/9900000)*15800 #36.7



## T1s
1065/22007 #4.8%
328/22007 #1.5%
522/22007 #2.4%
(22007-1065-328-522)/22007 #91.3% no flag

## T2s
158525/201592 #78.6%
(201592-158525)/201592 #21.4% no flag

t1dt2d_cohort_with_flags %>% filter(is.na(flag)) %>% count()
#63,159

22228/63159


test <- t1dt2d_cohort_with_flags %>% filter(flag=="t2_ins_under_3_yrs") %>% collect()
table(test$diabetes_type)

test <- test %>% filter(diabetes_type=="mixed; type 2")
test %>% count()
#1636

all_patid_code_counts <- all_patid_code_counts %>% analysis$cached("all_patid_code_counts")

test2 <- test %>% select(patid) %>% inner_join(all_patid_code_counts, by="patid", copy=TRUE)

test2 <- test2 %>% filter(!(malnutrition==0 & mody==0 & `other unspec`==0 & `other/unspec genetic inc syndromic`==0 & secondary==0 & `type 1`==0))
#only 1212 with codes other than gestation


test2 %>% filter(`type 1`>0) %>% count()
#1132

test2 %>% filter(malnutrition==0 & mody==0 & `other unspec`==0 & `other/unspec genetic inc syndromic`==0 & secondary==0 & `type 1`>0) %>% count()
#1119

# How many people have multiple Type 1 and only 1 Type 2 code
test2 %>% filter(`type 1`>1 & `type 2`==1) %>% count()
#138

test2 %>% filter(`type 1`==1 & `type 2`==1) %>% count()
#38


############################################################################################


# Look at time to BMI in those with no flags (i.e. who will have calculator run on them)

t1dt2d_vars <- t1dt2d_cohort_with_flags %>%
  filter(is.na(flag)) %>%
  select(diabetes_type, bmi_post_diag_datediff, totalchol_post_diag_datediff, hdl_post_diag_datediff, triglyceride_post_diag_datediff) %>%
  collect() %>%
  mutate(bmi_post_diag_datediff_yrs=as.numeric(bmi_post_diag_datediff)/365.25,
         totalchol_post_diag_datediff_yrs=as.numeric(totalchol_post_diag_datediff)/365.25,
         hdl_post_diag_datediff_yrs=as.numeric(hdl_post_diag_datediff)/365.25,
         triglyceride_post_diag_datediff_yrs=as.numeric(triglyceride_post_diag_datediff)/365.25) %>%
  mutate(diabetes_type=factor(diabetes_type, levels=c("type 1", "type 2", "mixed; type 1", "mixed; type 2")))

t1dt2d_vars %>% count()
#63,159

t1dt2d_vars %>% filter(is.na(bmi_post_diag_datediff)) %>% count()
#3,896


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



## Time to total chol

ggplot ((t1dt2d_vars %>% filter(totalchol_post_diag_datediff_yrs>-3)), aes(x=totalchol_post_diag_datediff_yrs, fill=diabetes_type)) + 
  geom_histogram(aes(y = after_stat(count / sum(count))), binwidth=0.05) +
  scale_y_continuous(labels = scales::percent) +
  xlab("Years from total cholesterol to current date") +
  ylab("Percentage")


## Time to HDL

ggplot ((t1dt2d_vars %>% filter(hdl_post_diag_datediff_yrs>-3)), aes(x=hdl_post_diag_datediff_yrs, fill=diabetes_type)) + 
  geom_histogram(aes(y = after_stat(count / sum(count))), binwidth=0.05) +
  scale_y_continuous(labels = scales::percent) +
  xlab("Years from HDL to current date") +
  ylab("Percentage")


## Time to triglyceride

ggplot ((t1dt2d_vars %>% filter(triglyceride_post_diag_datediff_yrs>-3)), aes(x=triglyceride_post_diag_datediff_yrs, fill=diabetes_type)) + 
  geom_histogram(aes(y = after_stat(count / sum(count))), binwidth=0.05) +
  scale_y_continuous(labels = scales::percent) +
  xlab("Years from triglyceride to current date") +
  ylab("Percentage")


############################################################################################

# Run T1DT2D calculators: age and bmi model and lipid model

t1dt2d_calc_results <- t1dt2d_cohort_with_flags %>%
  
  filter(is.na(flag)) %>%
  
  mutate(femalesex=ifelse(gender==2, 1, ifelse(gender==1, 0, NA)),
         
         clinical_pred_score=37.94+(-5.09*log(dm_diag_age))+(-6.34*log(bmi_post_diag)),
         clinical_pred_prob=exp(clinical_pred_score)/(1+exp(clinical_pred_score)),
         
         lipid_pred_score=9.0034272-(0.1915482*bmi_post_diag)-(0.1686227*dm_diag_age)+(0.3026012*femalesex)-(0.2269216*totalchol_post_diag)+(1.540850*hdl_post_diag)-(0.2784059*triglyceride_post_diag),
         lipid_pred_prob=exp(lipid_pred_score)/(1+exp(lipid_pred_score))) %>%
  analysis$cached("t1dt2d_calc_results", unique_indexes="patid")
    
    
t1dt2d_calc_results_local <- t1dt2d_calc_results %>%
  select(diabetes_type, ethnicity_5cat, femalesex, dm_diag_age, bmi_post_diag, clinical_pred_prob, totalchol_post_diag, hdl_post_diag, triglyceride_post_diag, lipid_pred_prob, current_insulin, current_oha, type2_code_count, days_since_type_code, age_at_index) %>%
  collect() %>%
  mutate(diabetes_type=factor(diabetes_type, levels=c("type 1", "type 2", "mixed; type 1", "mixed; type 2")),
         diabetes_type_new=factor(ifelse(diabetes_type=="type 1" | diabetes_type=="mixed; type 1", "Type 1",
                                         ifelse(diabetes_type=="type 2" | diabetes_type=="mixed; type 2", "Type 2", NA)), levels=c("Type 2", "Type 1")),
         no_treatment=ifelse(current_insulin==0 & current_oha==0, 1, 0))
  
  
ggplot(t1dt2d_calc_results_local, aes(clinical_pred_prob*100, fill=diabetes_type_new)) +
  geom_histogram(
    aes(y=after_stat(c(
      count[group==1]/sum(count[group==1]),
      count[group==2]/sum(count[group==2])
    )*100)),
    binwidth=1
  ) +
  scale_fill_manual(values=c("#F8766D", "#7CAE00")) +
  guides(fill=guide_legend(title="Diabetes type")) +
  theme(text = element_text(size = 22)) +
  ylab("Percentage by diabetes type") + xlab("T1D model probability (%)")


# Mean scores per group

## Clinical model
### All
a <- t1dt2d_calc_results_local %>% group_by(diabetes_type) %>% summarise(mean_clinical_pred_prob=mean(clinical_pred_prob), clin_count=n())
b <- t1dt2d_calc_results_local %>% summarise(mean_clinical_pred_prob=mean(clinical_pred_prob), clin_count=n()) %>% mutate(diabetes_type="overall")

### White
c <- t1dt2d_calc_results_local %>% filter(!is.na(ethnicity_5cat) & ethnicity_5cat==0) %>% group_by(diabetes_type) %>% summarise(mean_clinical_pred_prob_w=mean(clinical_pred_prob), clin_count_w=n())
d <- t1dt2d_calc_results_local %>% filter(!is.na(ethnicity_5cat) & ethnicity_5cat==0) %>% summarise(mean_clinical_pred_prob_w=mean(clinical_pred_prob), clin_count_w=n()) %>% mutate(diabetes_type="overall")

### Non-White
e <- t1dt2d_calc_results_local %>% filter(!is.na(ethnicity_5cat) & ethnicity_5cat!=0) %>% group_by(diabetes_type) %>% summarise(mean_clinical_pred_prob_nw=mean(clinical_pred_prob), clin_count_nw=n())
f <- t1dt2d_calc_results_local %>% filter(!is.na(ethnicity_5cat) & ethnicity_5cat!=0) %>% summarise(mean_clinical_pred_prob_nw=mean(clinical_pred_prob), clin_count_nw=n()) %>% mutate(diabetes_type="overall")


## Lipid model
### All

t1dt2d_calc_results_local_lipid <- t1dt2d_calc_results_local %>% filter(!is.na(lipid_pred_prob))

g <- t1dt2d_calc_results_local_lipid %>% group_by(diabetes_type) %>% summarise(mean_lipid_pred_prob=mean(lipid_pred_prob), lipid_count=n())
h <- t1dt2d_calc_results_local_lipid %>% summarise(mean_lipid_pred_prob=mean(lipid_pred_prob), lipid_count=n()) %>% mutate(diabetes_type="overall")

### White
i <- t1dt2d_calc_results_local_lipid %>% filter(!is.na(ethnicity_5cat) & ethnicity_5cat==0) %>% group_by(diabetes_type) %>% summarise(mean_lipid_pred_prob_w=mean(lipid_pred_prob), lipid_count_w=n())
j <- t1dt2d_calc_results_local_lipid %>% filter(!is.na(ethnicity_5cat) & ethnicity_5cat==0) %>% summarise(mean_lipid_pred_prob_w=mean(lipid_pred_prob), lipid_count_w=n()) %>% mutate(diabetes_type="overall")

### Non-White
k <- t1dt2d_calc_results_local_lipid %>% filter(!is.na(ethnicity_5cat) & ethnicity_5cat!=0) %>% group_by(diabetes_type) %>% summarise(mean_lipid_pred_prob_nw=mean(lipid_pred_prob), lipid_count_nw=n())
l <- t1dt2d_calc_results_local_lipid %>% filter(!is.na(ethnicity_5cat) & ethnicity_5cat!=0) %>% summarise(mean_lipid_pred_prob_nw=mean(lipid_pred_prob, na.rm=TRUE), lipid_count_nw=n()) %>% mutate(diabetes_type="overall")

### Missing in all
t1dt2d_calc_results_local <- t1dt2d_calc_results_local %>%
  mutate(missing_lipid=is.na(lipid_pred_prob))

prop.table(table(t1dt2d_calc_results_local$missing_lipid))

prop.table(table(t1dt2d_calc_results_local$diabetes_type, t1dt2d_calc_results_local$missing_lipid))

table <- (rbind(a, b)) %>%
  inner_join((rbind(c, d)), by="diabetes_type") %>%
  inner_join((rbind(e, f)), by="diabetes_type") %>%
  inner_join((rbind(g, h)), by="diabetes_type") %>%
  inner_join((rbind(i, j)), by="diabetes_type") %>%
  inner_join((rbind(k, l)), by="diabetes_type")




## Plot distribution

ggplot(t1dt2d_calc_results_local, aes(x=clinical_pred_prob*100, fill=diabetes_type, color=diabetes_type)) +
  geom_histogram(binwidth=1) +
  xlab("Clinical prediction model probability (%)")

ggplot(t1dt2d_calc_results_local, aes(x=lipid_pred_prob*100, fill=diabetes_type, color=diabetes_type)) +
  geom_histogram(binwidth=1) +
  xlab("Lipid prediction model probability (%)")


############################################################################################

# Additional variables for studying those with high/low T1 probability

index_date <- as.Date("2020-02-01")


## Hypoglycaemia in HES

primary_hypo_history <- cprd$tables$hesDiagnosisEpi %>%
  inner_join(codes$icd10_hypoglycaemia, by=c("ICD"="icd10")) %>%
  filter(d_order==1 & epistart<=index_date) %>%
  distinct(patid) %>%
  mutate(primary_hypo_history=1L) %>%
  analysis$cached("primary_hypo_history", unique_indexes="patid")


## Highest HbA1c ever

analysis = cprd$analysis("all_patid")

clean_hba1c_medcodes <- cprd$tables$observation %>%
  inner_join(codes$hba1c, by="medcodeid") %>%
  filter(year(obsdate)>=1990) %>%
  mutate(testvalue=ifelse(testvalue<=20, ((testvalue-2.152)/0.09148), testvalue)) %>%
  clean_biomarker_values(testvalue, "hba1c") %>%
  clean_biomarker_units(numunitid, "hba1c") %>%
  group_by(patid, obsdate) %>%
  summarise(testvalue=mean(testvalue, na.rm=TRUE)) %>%
  ungroup() %>%
  inner_join(cprd$tables$validDateLookup, by="patid") %>%
  filter(obsdate>=min_dob & obsdate<=gp_ons_end_date) %>%
  select(patid, date=obsdate, testvalue) %>%
  analysis$cached("clean_hba1c_medcodes", indexes=c("patid", "date", "testvalue"))

analysis = cprd$analysis("dpctn_final")

highest_hba1c_ever <- clean_hba1c_medcodes %>%
  filter(date<=index_date) %>%
  group_by(patid) %>%
  summarise(highest_hba1c=max(testvalue, na.rm=TRUE)) %>%
  ungroup() %>%
  analysis$cached("highest_hba1c_ever", unique_indexes="patid")


# Combine and add in ins before OHA

t1dt2d_calc_results_with_extra_vars <- t1dt2d_calc_results %>%
  left_join(primary_hypo_history, by="patid") %>%
  mutate(primary_hypo_history=ifelse(!is.na(primary_hypo_history) & with_hes==1, 1L,
                                     ifelse(is.na(primary_hypo_history) & with_hes==1, 0L, NA))) %>%
  left_join(highest_hba1c_ever, by="patid") %>%
  mutate(ins_before_oha=ifelse(is.na(earliest_ins), 0L,
                               ifelse(!is.na(earliest_ins) & is.na(earliest_oha), 1L,
                                      ifelse(!is.na(earliest_ins) & !is.na(earliest_oha) & earliest_ins<earliest_oha, 1L, 0L)))) %>%
  analysis$cached("t1dt2d_calc_results_with_extra_vars", unique_indexes="patid")


local_vars <- t1dt2d_calc_results_with_extra_vars %>%
  mutate(new_diabetes_type=ifelse(diabetes_type=="type 1" | diabetes_type=="mixed; type 1", "type 1", "type 2"),
         mixed=ifelse(diabetes_type=="mixed; type 1" | diabetes_type=="mixed; type 2", 1L, 0L),
         model_cat=ifelse(clinical_pred_prob>0.9 & new_diabetes_type=="type 1", "concordant_type_1",
                          ifelse(clinical_pred_prob>0.9 & new_diabetes_type=="type 2", "discordant_type_2",
                                 ifelse(clinical_pred_prob<0.1 & new_diabetes_type=="type 1", "discordant_type_1",
                                        ifelse(clinical_pred_prob<0.1 & new_diabetes_type=="type 2", "concordant_type_2", "other"))))) %>%
  select(model_cat, new_diabetes_type, mixed, dm_diag_age, bmi_post_diag, current_insulin, primary_hypo_history, highest_hba1c, with_hes, type1_code_count, type2_code_count, ins_before_oha, days_since_type_code, enterdate_datediff, current_dpp4, current_su, current_tzd, current_glp1, current_sglt2, current_bolusmix_insulin) %>%
  collect() %>%
  mutate(current_insulin=factor(current_insulin),
         primary_hypo_history=factor(primary_hypo_history),
         ins_before_oha=factor(ins_before_oha),
         current_dpp4=factor(current_dpp4),
         current_su=factor(current_su),
         current_tzd=factor(current_tzd),
         current_glp1=factor(current_glp1),
         current_sglt2=factor(current_sglt2),
         current_bolusmix_insulin=factor(current_bolusmix_insulin),
         mixed=factor(mixed))
         
  



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


## Overall

### Most variables
z <- summarizor((local_vars %>% select(new_diabetes_type, mixed, dm_diag_age, bmi_post_diag, current_insulin, current_bolusmix_insulin, highest_hba1c, type1_code_count, type2_code_count, ins_before_oha, days_since_type_code, enterdate_datediff, current_dpp4sutzd, current_glp1, current_sglt2)), by="new_diabetes_type")

tab_2 <- tabulator(z,
                   rows = c("variable", "stat"),
                   columns = "new_diabetes_type",
                   `Est.` = as_paragraph(
                     as_chunk(stat_format(stat, value1, value2))),
                   `N` = as_paragraph(as_chunk(n_format(cts, percent)))
)

as_flextable(tab_2, separate_with = "variable")


### Hypos in HES
z <- summarizor((local_vars %>% filter(with_hes==1) %>% select(new_diabetes_type, dm_diag_age, primary_hypo_history)), by="new_diabetes_type")

tab_2 <- tabulator(z,
                   rows = c("variable", "stat"),
                   columns = "new_diabetes_type",
                   `Est.` = as_paragraph(
                     as_chunk(stat_format(stat, value1, value2))),
                   `N` = as_paragraph(as_chunk(n_format(cts, percent)))
)

as_flextable(tab_2, separate_with = "variable")



## Low and high scorers

### Most variables
z <- summarizor((local_vars %>% select(model_cat, mixed, dm_diag_age, bmi_post_diag, current_insulin, current_bolusmix_insulin, highest_hba1c, type1_code_count, type2_code_count, ins_before_oha, days_since_type_code, enterdate_datediff, current_dpp4sutzd, current_glp1, current_sglt2)), by="model_cat")

tab_2 <- tabulator(z,
                   rows = c("variable", "stat"),
                   columns = "model_cat",
                   `Est.` = as_paragraph(
                     as_chunk(stat_format(stat, value1, value2))),
                   `N` = as_paragraph(as_chunk(n_format(cts, percent)))
)

as_flextable(tab_2, separate_with = "variable")

### Hypos in HES
z <- summarizor((local_vars %>% filter(with_hes==1) %>% select(model_cat, dm_diag_age, primary_hypo_history)), by="model_cat")

tab_2 <- tabulator(z,
                   rows = c("variable", "stat"),
                   columns = "model_cat",
                   `Est.` = as_paragraph(
                     as_chunk(stat_format(stat, value1, value2))),
                   `N` = as_paragraph(as_chunk(n_format(cts, percent)))
)

as_flextable(tab_2, separate_with = "variable")


############################################################################################

# Look at example patients who would be flagged by lipid model

t1s <- t1dt2d_calc_results %>%
  filter(lipid_pred_prob<0.05 & (diabetes_type=="type 1" | diabetes_type=="mixed; type 1")) %>%
  select(patid, dm_diag_age, bmi_post_diag, gender, age_at_index, hba1c_post_diag, totalchol_post_diag, hdl_post_diag, triglyceride_post_diag, starts_with("current"), diagnosis_date, earliest_ins, regstartdate, ethnicity_5cat, lipid_pred_prob, clinical_pred_prob, contains("gad"), contains("ia2"), contains("c_pep"), -current_oha) %>%
  collect()

t1s <- t1s %>% sample_n(20)

t2s <- t1dt2d_calc_results %>%
  filter(lipid_pred_prob>0.5 & (diabetes_type=="type 2" | diabetes_type=="mixed; type 2")) %>%
  select(patid, dm_diag_age, bmi_post_diag, gender, age_at_index, hba1c_post_diag, totalchol_post_diag, hdl_post_diag, triglyceride_post_diag, starts_with("current"), diagnosis_date, earliest_ins, regstartdate, ethnicity_5cat, lipid_pred_prob, clinical_pred_prob, contains("gad"), contains("ia2"), contains("c_pep"), -current_oha) %>%
  collect()

t2s <- t2s %>% sample_n(20)


############################################################################################

# Look at ethnicity overall and in high scorers

## Overall in cohort (not just those going through calculator)
prop.table(table((t1dt2d_cohort %>% select(ethnicity_5cat) %>% collect())$ethnicity_5cat, useNA="always"))

## Eligible for calculator
prop.table(table((t1dt2d_calc_results %>% select(ethnicity_5cat) %>% collect())$ethnicity_5cat, useNA="always"))

## T1 and probability <10%
prop.table(table((t1dt2d_calc_results %>% filter((diabetes_type=="type 1" | diabetes_type=="mixed; type 1") & lipid_pred_prob<0.1) %>% select(ethnicity_5cat) %>% collect())$ethnicity_5cat, useNA="always"))

## T2 and probability >90%
prop.table(table((t1dt2d_calc_results %>% filter((diabetes_type=="type 2" | diabetes_type=="mixed; type 2") & lipid_pred_prob>0.9) %>% select(ethnicity_5cat) %>% collect())$ethnicity_5cat, useNA="always"))


############################################################################################

# Look at high scorers

t1dt2d_calc_results %>% filter((diabetes_type=="type 1" | diabetes_type=="mixed; type 1") & lipid_pred_prob<0.05) %>% count()
#1961
(1961/9900000)*1000 #0.20
(1961/9900000)*7900 #1.6
(1961/9900000)*15800 #3.1

t1dt2d_calc_results %>% filter((diabetes_type=="type 1" | diabetes_type=="mixed; type 1") & lipid_pred_prob<0.1) %>% count()
#3270
(3270/9900000)*1000 #0.33
(3270/9900000)*7900 #2.6
(3270/9900000)*15800 #5.2


t1dt2d_calc_results %>% filter((diabetes_type=="type 2" | diabetes_type=="mixed; type 2") & lipid_pred_prob>0.7) %>% count()
#634
(634/9900000)*1000 #0.064
(634/9900000)*7900 #0.5
(634/9900000)*15800 #1.0

t1dt2d_calc_results %>% filter((diabetes_type=="type 2" | diabetes_type=="mixed; type 2") & lipid_pred_prob>0.5) %>% count()
#1432
(1432/9900000)*1000 #0.14
(1432/9900000)*7900 #1.1
(1432/9900000)*15800 #2.3



