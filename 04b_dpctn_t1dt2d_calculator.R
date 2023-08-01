
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

cohort %>% filter(dm_diag_age>=18 & dm_diag_age<=50) %>% count()
#256690

cohort %>% filter(dm_diag_age>=18 & dm_diag_age<=50 & (diabetes_type=="unspecified" | diabetes_type=="unspecified_with_primis")) %>% count()
#32705
32705/256690 #12.7
256690-32705 #223985

cohort %>% filter(dm_diag_age>=18 & dm_diag_age<=50 & (diabetes_type=="type 2" | diabetes_type=="mixed; type 2" | diabetes_type=="type 1" | diabetes_type=="mixed; type 1")) %>% count()
#208236
208236/223985 #93.0%

cohort %>% filter(dm_diag_age>=18 & dm_diag_age<=50 & (diabetes_type=="type 1" | diabetes_type=="mixed; type 1")) %>% count()
#21747
208236-21747 #186489

cohort %>% filter(dm_diag_age>=18 & dm_diag_age<=50 & (diabetes_type=="type 2" | diabetes_type=="mixed; type 2" | diabetes_type=="type 1" | diabetes_type=="mixed; type 1") & is.na(diagnosis_date)) %>% count()
#10952
10952/208236 #5.3

cohort %>% filter(dm_diag_age>=18 & dm_diag_age<=50 & (diabetes_type=="type 1" | diabetes_type=="mixed; type 1") & is.na(diagnosis_date)) %>% count()
#1479
10952-1479 #9473

cohort %>% filter(dm_diag_age>=18 & dm_diag_age<=50 & (diabetes_type=="type 2" | diabetes_type=="mixed; type 2" | diabetes_type=="type 1" | diabetes_type=="mixed; type 1") & !is.na(diagnosis_date)) %>% count()
#197284

cohort %>% filter(dm_diag_age>=18 & dm_diag_age<=50 & (diabetes_type=="type 1" | diabetes_type=="mixed; type 1") & !is.na(diagnosis_date)) %>% count()
#20268
197284-20268



# Define T1DT2D cohort: patients diagnosed with a current Type 1 or Type 2 diagnosis or unspecified type, diagnosed aged 18-50
## At the moment don't have T1/T2 and T2/gestational people

t1dt2d_calc_cohort <- cohort %>%
  filter(dm_diag_age>=18 & dm_diag_age<=50 & (diabetes_type=="type 1" | diabetes_type=="type 2" | diabetes_type=="mixed; type 1" | diabetes_type=="mixed; type 2")) %>%
  mutate(age_at_bmi=datediff(bmidate, dob)/365.25,
         bmi_post_diag=ifelse(bmidate>=diagnosis_date & age_at_bmi>=18, bmi, NA),
         bmi_post_diag_datediff=ifelse(!is.na(bmi_post_diag), bmiindexdiff, NA),
         totalchol_post_diag=ifelse(totalcholesteroldate>=diagnosis_date, totalcholesterol, NA),
         totalchol_post_diag_datediff=ifelse(!is.na(totalchol_post_diag), totalcholesterolindexdiff, NA),
         hdl_post_diag=ifelse(hdldate>=diagnosis_date, hdl, NA),
         hdl_post_diag_datediff=ifelse(!is.na(hdl_post_diag), hdlindexdiff, NA),
         triglyceride_post_diag=ifelse(triglyceridedate>=diagnosis_date, triglyceride, NA),
         triglyceride_post_diag_datediff=ifelse(!is.na(triglyceride_post_diag), triglycerideindexdiff, NA)) %>%
  filter(!is.na(bmi_post_diag)) %>%
  analysis$cached("t1dt2d_calc_cohort", unique_indexes="patid")


t1dt2d_calc_cohort %>% count()
#194404
197284-194404 #2880
2880/197284 #1.5
  
t1dt2d_calc_cohort %>% group_by(diabetes_type) %>% count()
14486+5474 #19960
161010+13434 #174444
19960/194404 #10.3%
20268-19960 #308

t1dt2d_calc_cohort %>% filter(!is.na(totalchol_post_diag) & !is.na(hdl_post_diag) & !is.na(triglyceride_post_diag)) %>% count()
#178346
178346/194404 #91.7

t1dt2d_calc_cohort %>% filter(!is.na(totalchol_post_diag) & !is.na(hdl_post_diag) & !is.na(triglyceride_post_diag)) %>% group_by(diabetes_type) %>% count()
13033+5179 #18212
147496+12638 #160134
18212/178346 #10.2%


############################################################################################

# Look at time to BMI

t1dt2d_vars <- t1dt2d_calc_cohort %>%
  select(diabetes_type, bmi_post_diag_datediff, totalchol_post_diag_datediff, hdl_post_diag_datediff, triglyceride_post_diag_datediff) %>%
  collect() %>%
  mutate(bmi_post_diag_datediff_yrs=as.numeric(bmi_post_diag_datediff)/365.25,
         totalchol_post_diag_datediff_yrs=as.numeric(totalchol_post_diag_datediff)/365.25,
         hdl_post_diag_datediff_yrs=as.numeric(hdl_post_diag_datediff)/365.25,
         triglyceride_post_diag_datediff_yrs=as.numeric(triglyceride_post_diag_datediff)/365.25) %>%
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

# Run T1DT2D calculator

t1dt2d_calc_results <- t1dt2d_calc_cohort %>%
  
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
  select(diabetes_type, ethnicity_5cat, sex, dm_diag_age, bmi_post_diag, clinical_pred_prob, totalchol_post_diag, hdl_post_diag, triglyceride_post_diag, lipid_pred_prob, current_insulin, current_oha, type2_code_count, days_since_type_code, age_at_index) %>%
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

table(t1dt2d_calc_results_local$diabetes_type_new)
prop.table(table(t1dt2d_calc_results_local$diabetes_type_new))

table(t1dt2d_calc_results_local$diabetes_type_new, t1dt2d_calc_results_local$current_insulin)
prop.table(table(t1dt2d_calc_results_local$diabetes_type_new, t1dt2d_calc_results_local$current_insulin), margin=1)

table(t1dt2d_calc_results_local$diabetes_type_new, t1dt2d_calc_results_local$no_treatment)
prop.table(table(t1dt2d_calc_results_local$diabetes_type_new, t1dt2d_calc_results_local$no_treatment), margin=1)

t1dt2d_calc_results_local %>% group_by(diabetes_type_new) %>% summarise(mean_clinical_pred_prob=mean(clinical_pred_prob), clin_count=n())

t1dt2d_calc_results_local %>% filter(clinical_pred_prob<0.1) %>% count()
t1dt2d_calc_results_local %>% filter(clinical_pred_prob<0.1) %>% group_by(diabetes_type_new) %>% count()
prop.table(table((t1dt2d_calc_results_local %>% filter(clinical_pred_prob<0.1))$diabetes_type_new))

t1dt2d_calc_results_local %>% filter(clinical_pred_prob>=0.1 & clinical_pred_prob<=0.9) %>% count()
prop.table(table((t1dt2d_calc_results_local %>% filter(clinical_pred_prob>=0.1 & clinical_pred_prob<=0.9))$diabetes_type_new))

t1dt2d_calc_results_local %>% filter(clinical_pred_prob>0.9) %>% count()
t1dt2d_calc_results_local %>% filter(clinical_pred_prob>0.9) %>% group_by(diabetes_type_new) %>% count()
prop.table(table((t1dt2d_calc_results_local %>% filter(clinical_pred_prob>0.9))$diabetes_type_new))


t1dt2d_calc_results_local %>% filter(clinical_pred_prob<0.1 & diabetes_type_new=="Type 1" & no_treatment==1) %>% count()
t1dt2d_calc_results_local %>% filter(clinical_pred_prob<0.1 & diabetes_type_new=="Type 1" & current_insulin==0) %>% count()

t1dt2d_calc_results_local %>% filter(clinical_pred_prob>0.9 & diabetes_type_new=="Type 2" & no_treatment==1) %>% count()
t1dt2d_calc_results_local %>% filter(clinical_pred_prob>0.9 & diabetes_type_new=="Type 2" & current_insulin==0 ) %>% count()








t1dt2d_calc_results_local %>% filter(clinical_pred_prob<0.05) %>% count()
t1dt2d_calc_results_local %>% filter(clinical_pred_prob<0.05) %>% group_by(diabetes_type_new) %>% count()
prop.table(table((t1dt2d_calc_results_local %>% filter(clinical_pred_prob<0.05))$diabetes_type_new))

t1dt2d_calc_results_local %>% filter(clinical_pred_prob>=0.05 & clinical_pred_prob<=0.95) %>% count()
prop.table(table((t1dt2d_calc_results_local %>% filter(clinical_pred_prob>=0.05 & clinical_pred_prob<=0.95))$diabetes_type_new))

t1dt2d_calc_results_local %>% filter(clinical_pred_prob>0.95) %>% count()
t1dt2d_calc_results_local %>% filter(clinical_pred_prob>0.95) %>% group_by(diabetes_type_new) %>% count()
prop.table(table((t1dt2d_calc_results_local %>% filter(clinical_pred_prob>0.95))$diabetes_type_new))


t1dt2d_calc_results_local %>% filter(clinical_pred_prob<0.05 & diabetes_type_new=="Type 1" & no_treatment==1) %>% count()
t1dt2d_calc_results_local %>% filter(clinical_pred_prob<0.05 & diabetes_type_new=="Type 1" & current_insulin==0) %>% count()

t1dt2d_calc_results_local %>% filter(clinical_pred_prob>0.95 & diabetes_type_new=="Type 2" & no_treatment==1) %>% count()
t1dt2d_calc_results_local %>% filter(clinical_pred_prob>0.95 & diabetes_type_new=="Type 2" & current_insulin==0 ) %>% count()





t1dt2d_calc_results_local %>% filter(diabetes_type_new=="Type 1" & age_at_index-dm_diag_age < 3 & current_insulin==1) %>% count()
t1dt2d_calc_results_local %>% filter(diabetes_type_new=="Type 2" & age_at_index-dm_diag_age < 3 & current_insulin==1) %>% count()

t1dt2d_calc_results_local %>% filter(diabetes_type_new=="Type 2" & clinical_pred_prob<0.1 & age_at_index-dm_diag_age < 3 & current_insulin==1) %>% count()
t1dt2d_calc_results_local %>% filter(diabetes_type_new=="Type 1" & clinical_pred_prob<0.1 & age_at_index-dm_diag_age < 3 & current_insulin==1) %>% count()

t1dt2d_calc_results_local %>% filter(diabetes_type_new=="Type 1" & clinical_pred_prob>0.9 & age_at_index-dm_diag_age < 3 & current_insulin==1) %>% count()
t1dt2d_calc_results_local %>% filter(diabetes_type_new=="Type 2" & clinical_pred_prob>0.9 & age_at_index-dm_diag_age < 3 & current_insulin==1) %>% count()





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



## Look at time to insulin by deciles of model

t1dt2d_calc_results_local <- t1dt2d_calc_results_local %>%
  mutate(clinical_pred_prob_group=ifelse(clinical_pred_prob<=0.1, "0-0.1",
                                         ifelse(clinical_pred_prob<=0.2, "0.1-0.2",
                                                ifelse(clinical_pred_prob<=0.3, "0.2-0.3",
                                                       ifelse(clinical_pred_prob<=0.4, "0.3-0.4",
                                                              ifelse(clinical_pred_prob<=0.5, "0.4-0.5",
                                                                     ifelse(clinical_pred_prob<=0.6, "0.5-0.6",
                                                                            ifelse(clinical_pred_prob<=0.7, "0.6-0.7",
                                                                                   ifelse(clinical_pred_prob<=0.8, "0.7-0.8",
                                                                                          ifelse(clinical_pred_prob<=0.9, "0.8-0.9", "0.9-1"))))))))))
         
         
prop.table(table(t1dt2d_calc_results_local$clinical_pred_prob_group, t1dt2d_calc_results_local$insulin_6_months), margin=2)                                                      
table(t1dt2d_calc_results_local$clinical_pred_prob_group, t1dt2d_calc_results_local$insulin_6_months)


############################################################################################

# Additional variables for studying those with high/low T1 probability

index_date <- as.Date("2020-02-01")


## Bolus/mix insulin in past 6 months

analysis = cprd$analysis("all_patid")

clean_insulin_prodcodes <- cprd$tables$drugIssue %>%
  inner_join(codes$insulin, by="prodcodeid") %>%
  inner_join(cprd$tables$validDateLookup, by="patid") %>%
  filter(issuedate>=min_dob & issuedate<=gp_ons_end_date) %>%
  select(patid, date=issuedate, dosageid, quantity, quantunitid, duration) %>%
  analysis$cached("clean_insulin_prodcodes", indexes=c("patid", "date"))

analysis = cprd$analysis("dpctn_final")

bolus_mix_insulin <- clean_insulin_prodcodes %>%
  filter((insulin_cat=="Bolus insulin" | insulin_cat=="Mix insulin") & date<=index_date) %>%
  group_by(patid) %>%
  summarise(latest_ins=max(date, na.rm=TRUE)) %>%
  ungroup() %>%
  mutate(indexdatediff=datediff(latest_ins, index_date),
         current_bolus_mix_ins_6m=ifelse(indexdatediff>=-183, 1L, NA)) %>%
  select(patid, current_bolus_mix_ins_6m) %>%
  analysis$cached("current_bolus_mix_ins_6m", unique_indexes="patid")


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
  left_join(bolus_mix_insulin, by="patid") %>%
  mutate(current_bolus_mix_ins_6m=ifelse(is.na(current_bolus_mix_ins_6m), 0L, 1L)) %>%
  left_join(primary_hypo_history, by="patid") %>%
  mutate(primary_hypo_history=ifelse(!is.na(primary_hypo_history) & with_hes==1, 1L,
                                     ifelse(is.na(primary_hypo_history) & with_hes==1, 0L, NA))) %>%
  left_join(highest_hba1c_ever, by="patid") %>%
  mutate(ins_before_oha=ifelse(is.na(earliest_ins), 0L,
                               ifelse(!is.na(earliest_ins) & is.na(earliest_oha), 1L,
                                      ifelse(!is.na(earliest_ins) & !is.na(earliest_oha) & earliest_ins<earliest_oha, 1L, 0L)))) %>%
  analysis$cached("t1dt2d_calc_results_with_extra_vars", unique_indexes="patid")


local_vars <- t1dt2d_calc_results_with_extra_vars %>%
  mutate(insulin_6_months=ifelse(is.na(earliest_ins), 0L,
                                 ifelse(datediff(earliest_ins, diagnosis_date)>183 & datediff(regstartdate, diagnosis_date)>183 & datediff(earliest_ins, regstartdate)<=183, NA,
                                        ifelse(datediff(earliest_ins, diagnosis_date)<=183, 1L, 0L))),
         new_diabetes_type=ifelse(diabetes_type=="type 1" | diabetes_type=="mixed; type 1", "type 1", "type 2"),
         mixed=ifelse(diabetes_type=="mixed; type 1" | diabetes_type=="mixed; type 2", 1L, 0L),
         model_cat=ifelse(clinical_pred_prob>0.9 & new_diabetes_type=="type 1", "concordant_type_1",
                          ifelse(clinical_pred_prob>0.9 & new_diabetes_type=="type 2", "discordant_type_2",
                                 ifelse(clinical_pred_prob<0.1 & new_diabetes_type=="type 1", "discordant_type_1",
                                        ifelse(clinical_pred_prob<0.1 & new_diabetes_type=="type 2", "concordant_type_2", "other"))))) %>%
  select(model_cat, new_diabetes_type, mixed, dm_diag_age, bmi_post_diag, insulin_6_months, current_ins_6m, current_bolus_mix_ins_6m, primary_hypo_history, highest_hba1c, with_hes, type1_code_count, type2_code_count, ins_before_oha, days_since_type_code,enterdate_datediff, current_dpp4glp1sutzd_6m) %>%
  collect() %>%
  mutate(insulin_6_months=factor(insulin_6_months),
         current_ins_6m=factor(current_ins_6m),
         current_bolus_mix_ins_6m=factor(current_bolus_mix_ins_6m),
         primary_hypo_history=factor(primary_hypo_history),
         ins_before_oha=factor(ins_before_oha),
         current_dpp4glp1sutzd_6m=factor(current_dpp4glp1sutzd_6m),
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
z <- summarizor((local_vars %>% select(new_diabetes_type, mixed, dm_diag_age, bmi_post_diag, current_ins_6m, current_bolus_mix_ins_6m, highest_hba1c, type1_code_count, type2_code_count, ins_before_oha, days_since_type_code, enterdate_datediff, current_dpp4glp1sutzd_6m)), by="new_diabetes_type")

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
z <- summarizor((local_vars %>% select(model_cat, dm_diag_age, mixed, bmi_post_diag, current_ins_6m, current_bolus_mix_ins_6m, highest_hba1c, type1_code_count, type2_code_count, ins_before_oha, days_since_type_code, enterdate_datediff, current_dpp4glp1sutzd_6m)), by="model_cat")

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
















