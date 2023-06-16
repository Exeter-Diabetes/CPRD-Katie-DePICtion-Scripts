# CPRD-Katie-DePICtion-Scripts

## Introduction

This repository contains the R scripts used to implement the Exeter Diabetes MODY calculator and T1D/T2D calculator in a CPRD Aurum dataset as part of the DePICtion project. Our [CPRD-Cohort-scripts respository](https://github.com/Exeter-Diabetes/CPRD-Cohort-scripts) has similar scripts for defining different cohorts in this same dataset.

&nbsp;

## Rules for data handling

As a result of the work in the 'Initial data quality exploration' directory in this repository, a number of rules for implementing these calculators and dealing with data quality issues were decided upon. These aim to be pragmatic (easily implemented) so that the MODY and T1D/T2D calculators can easily be run in primary care data, whilst excluding as few patients as possible due to e.g. missing data issues. These calculators aim to identify those whose diabetes type is misclassified: i.e. those with a Type 1 or Type 2 diabetes diagnosis who may have MODY, those with a Type 1 diagnosis who may actually have Type 2, and those with a Type 2 diagnosis who may actually have Type 1. The rules aim to minimise the chance of missing these misclassified cases.

&nbsp;

| Rule purpose | &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Details&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; | Rationale and expected effect | How this is dealt with in our analysis |
| --- | --- | --- | --- |
| Cohort definition | Cohort is everybody with a code for diabetes | This high-sensitivity approach means we include everybody with diabetes, reducing bias which may arise from excluding those with poor quality coding i.e. those who don't have elevated HbA1c measurements in their records. Depending on the codelist used, we may include some people without diabetes who then need to be removed as they will end up with high MODY probabilities. | We have used a very broad codelist, but this identified a large number of individuals with no diabetes type-specific codes who we have not been able to run the calculators on |
| Diabetes type | Diabetes type is determined by codes i.e. if a person has codes for Type 2 diabetes, they are defined as Type 2. If they have codes for multiple types of diabetes, the most recent code is used. If they have no type-specific codes then the clinician needs to check this; the proportion of people with no type-specific codes will vary with the codelist used to define the cohort. | Most recent code is used as their diagnosis may have changed over time. In addition, using most recent code matched the 'gold standard' diagnosis (based on code frequencies - see https://www.jclinepi.com/article/S0895-4356(22)00272-4/fulltext) in 77% of cases for a cohort with both Type 1 and Type 2 codes - see Initial data quality exploration (NB: to be more certain of current diagnosis, those with codes for >1 type of diabetes in the last 5 years can be investigated further). NB: we found that 25% of our gestational diabetes cohort had codes for diabetes (of no specific type) more than 1 year before earliest gestational code or more than 1 year after latest gestational code (excluding 'history of gestational diabetes' codes), suggesting they may have Type 1 or Type 2; we have not applied the calculators to these people | We have implemented these rules, but have only applied the calculators to those with a current diagnosis of Type 1 or Type 2 diabetes (see below flowchart) |
| Diabetes diagnosis date 1 | Diagnosis date is determined as the earliest code for diabetes | There is a minimal time difference (see Initial data quality exploration) if the earliest of a code, an elevated HbA1c, or an OHA/insulin script is used instead | We have implemented this rule |
| Diabetes diagnosis date 2 | Those with diagnoses in their year of birth should be investigated further | We found an excess of diabetes codes in the year of birth compared to later years (<1% of our cohort, see Initial data quality exploration), suggesting miscoding. Patients with this issue should be investigated, especially those with Type 1, those with Type 2 who have a high probability of Type 1 from the T1D/T2D calculator, and those with a high MODY probability (as the effect of this issue is to incorrectly lower the age of diagnosis). | For those with Type 2 (and no codes for other types of diabetes), we have ignored diabetes codes in the year of birth |
| Diabetes diagnosis date 3 | Those with diagnoses between -30 and +90 days (inclusive) of registration start) should be investigated further | We found an excess of diabetes codes around registration start (4% of our cohort, see Initial data quality exploration),  (compared to later years; see Initial data quality exploration), probably reflecting old diagnoses (prior to registration) being recorded as if they were new. Patients with this issue should be investigated, especially those with Type 2, those with Type 1 who have a high probability of Type 1 from the T1D/T2D calculator, and all those on which the MODY calculator is being run (as the effect of this issue is to incorrectly increase the age of diagnosis). | We have excluded individuals with diagnosis dates in this time range |
| Biomarkers 1 | BMI, HbA1c, total cholesterol, HDL, and triglyceride values outside of the normal detectable range (BMI: 15-100 kg/m2 (used for adult measurements only), HbA1c: 20-195 mmol/mol, total cholesterol: 0.5-20 mmol/L, HDL: 0.2-10 mmol/L, triglyceride:0.1-40 mmol/L) should be ignored | | We have implemented this rule |
| Biomarkers 2 | The most recent biomarker values can be used, going back as far as (but not before) diagnosis. BMIs in those aged <18 years should be removed. Separate weight and height measurements should not be used to calculate missing BMIs as they do not add much | This reduces missingness in our Type 1 and Type 2 cohorts (compared to using values within the last 2 years only): HbA1c: 6-7% reduced to 1-2%, BMI: 11-18% reduced to 2-4%, total cholesterol: 4-9% reduced to 2%, HDL: 7-14% reduced to 2-3%, triglycerides: 29-37% reduced to 9-11%. | We implemented this rule but looked at the distribution of time between most recent measurement and index date |
| Additional MODY calculator variable 1 | If whether the patient began insulin within 6 months of diagnosis is missing, use whether they are on insulin now | Missingness was very high for this variable in our Type 1 cohort (66%) as most were diagnosed prior to registration | We implemented this rule but looked at the level of missingness |
| Additional MODY calculator variable 2 | If family history of diabetes is missing, assume they do have a family history, and then investigate this for those who score highly on the MODY calculator | Missingness was high for this variable in our Type 1 and Type 2 cohorts (48-69%) | We implemented this rule |

&nbsp;

## Cohort definition

Using the above rules, we defined a a cohorts of adult with diabetes registered in primary care on 01/02/2020, diagnosed age <=50 years, with diabetes type assigned:

```mermaid
graph TD;
    A["<b>CPRD Aurum October 2020 release</b> with linked Set 21 <br> (April 2021) HES APC, patient IMD, and ONS death data"] --> |"Unique patients with a diabetes-related medcode between 01/01/2004-06/11/2020 and >=1 year data prior and after"| B["<b>Our extract</b>: n=1,480,985*"]
    B -->|"Patients with a diabetes-specific code** with >=1 year data prior and after"|C["n=1,314,373"]
    C -->|"Patients registered on 01/02/2020 (all have diabetes code and therefore diabetes diagnosis <br> before this date due to the requirement to have 1 year of data after)"|D["n=779,498"]
    D -->|"Patients who are aged>=18 years at the index date (01/02/2020)"|E["<b>Data quality exploration cohort:</b> n=769,493"]
    E -->|"Patients who don't have a diagnosis date between -30 and +90 days of registration start"|F["n=741,291"]
    F -->|"Patients diagnosed aged <=50 years"|G["<b>Final DePICtion cohort:</b> n=265,175"]
```
\* Extract actually contained n=1,481,294 unique patients (1,481,884 in total but some duplicates) but included n=309 with registration start dates in 2020 (which did not fulfil the extract criteria of having a diabetes-related medcode between 01/01/2004-06/11/2020 and >=1 year of data after this; some of these were also not 'acceptable' by [CPRD's definition](https://cprd.com/sites/default/files/2023-02/CPRD%20Aurum%20Glossary%20Terms%20v2.pdf)). NB: removing those with registration start date in 2020 also removed all of those with a 'patienttypeid' not equal to 3 ('regular'). See next section for further details on the extract.

\** The list of diabetes-related medcode used for the extract (see below) included some which were not specific to diabetes e.g. 'insulin resistance' and 'seen in diabetes clinic***'. The list of 'diabetes-specific codes' used to define the cohort here can be found in our [CPRD-Codelists respository](https://github.com/Exeter-Diabetes/CPRD-Codelists/blob/main/Diabetes/exeter_medcodelist_all_diabetes.txt).

\***  We determined the code 'Seen in diabetes clinic' (medcode 285223014) to be unspecific to diabetes after observing a large number of patients (>100,000) in our extract with this code and no further evidence of diabetes such as other codes for diabetes, high HbA1c test results, or prescriptions for glucose-lowering medications.

&nbsp;

```mermaid
graph TD;
    G["<b>Final DePICtion cohort:</b> n=265,175"] --> |"Unspecific codes<br>only"| H["Unspecified: <br>n=34,118<br>(12.9%)<br>(2,558 have<br>PRIMIS code)"]
    G --> |"T1D codes*"| I["Type 1: <br>n=28,964<br>(10.9%)"]
    G --> |"T2D codes*"| J["Type 2: <br>n=164,866<br>(62.2%)"]
    G --> |"Gestational codes*"| K["Gestational <br>only: <br>n=14,833<br>(5.6%)"]
    G --> |"MODY codes*"| L["MODY: <br>n=52<br>(0.0%)"]
    G --> |"Non-MODY <br>genetic/<br>syndromic <br>codes*"| M["Non-MODY <br>genetic/<br>syndromic: <br>n=96<br>(0.0%)"]
    G --> |"Secondary codes*"| N["Secondary: <br>n=182<br>(0.1%)"]
    G --> |"Other specified<br>type codes*"| P["Other specified<br>type: <br>n=1<br>(0.0%)"]  
    G --> |"Mix of diabetes<br>type codes"| Q["Mix of<br>diabetes types: <br>n=22,063<br>(8.3%)"]
    Q --> |"Type 1 based<br>on latest code"| R["Mixed; Type 1: <br>n=7,316<br>(2.8%)"]
    Q --> |"Type 2 based<br>on latest code"| S["Mixed; Type 2: <br>n=14,109<br>(5.3%)"]
    Q --> |"Other based<br>on latest code"| T["Mixed; other: <br>n=638<br>(0.2%)"]
```
\* Could also have diabetes codes of unspecified type

&nbsp;

Of the final cohort, 3.4% were non-English speaking, and a further 10.5% had a first language which was not English.

&nbsp;

### Extract details
Patients with a diabetes-related medcode ([full list here](https://github.com/Exeter-Diabetes/CPRD-Katie-MASTERMIND-Scripts/blob/main/Extract-details/diab_med_codes_2020.txt)) in the Observation table were extracted from the October 2020 CPRD Aurum release. See below for full inclusion criteria:

<img src="https://github.com/Exeter-Diabetes/CPRD-Cohort-scripts/blob/main/Extract-details/download_details1.PNG" width="370">

&nbsp;

<img src="https://github.com/Exeter-Diabetes/CPRD-Cohort-scripts/blob/main/Extract-details/download_details2.PNG" width="700">

&nbsp;

## MODY calculator (script: 02b_dpctn_mody_calculator)

The MODY calculator cohort consists those with current diagnosis of Type 1 (mixed or otherwise), Type 2 (mixed or otherwise), or unspecified diabetes, diagnosed aged 1-35 years inclusive:

```mermaid
graph TD;
    G["<b>MODY calculator cohort:</b> n=74,141"] --> H["Type 1:<br>n=24,638<br>(33.2%)"]
    G --> I["Type 2:<br>n=24,704<br>(33.3%)"]
    G --> J["Unspecified<br>no PRIMIS code:<br>n=11,548<br>(15.6%)"]
    G --> K["Unspecified<br>with PRIMIS code: <br>n=789<br>(1.1%)"]
    G --> L["Mixed; Type 1:<br>n=4,766<br>(6.4%)"]
    G --> M["Mixed; Type 2:<br>n=7,696<br>(10.4%)"]
    H --> N["Not missing<br>HbA1c or BMI:<br>23,639 (95.9%)"]
    I --> O["Not missing<br>HbA1c or BMI:<br>23,999 (97.1%)"]
    J --> P["Not missing<br>HbA1c or BMI:<br>3,432 (29.7%)"]
    K --> Q["Not missing<br>HbA1c or BMI:<br>562 (71.2%)"]
    L --> R["Not missing<br>HbA1c or BMI:<br>4,733 (99.3%)"]
    M --> S["Not missing<br>HbA1c or BMI:<br>7,631 (99.2%)"]
```
MODY calculator cohort not missing HbA1c or BMI: n=63,996 (86.3% of original MODY calculator cohort).

&nbsp;

Cohort characteristics of those not missing HbA1c or BMI:

| Characteristic | Type 1 | Type 2 | Unspecified with no PRIMIS code | Unspecified with PRIMIS code | Mixed; Type 1 | Mixed; Type 2 | Overall excluding 2 x unspecified groups |
| --- | --- | --- | --- | --- | --- | --- | --- |
| N | 23639 | 23999 | 3432 | 562 | 4733 | 7631 | 60002 |
| Median (IQR) age at diagnosis (years) | 16.5 (14.0) | 31.1 (6.0) | 28.9 (8.4) | 28.3 (10.5) | 22.5 (14.8) | 29.5 (7.0) | 26.6 (14.7) |
| Median (IQR) age at index date (years) | 40.6 (22.0) | 43.6 (15.0) | 34.7 (10.0) | 36.6 (14.0) | 48.6 (21.0) | 44.6 (14.0) | 43.6 (18.0) |
| Median (IQR) HbA1c (mmol/mol) | 66.1 (22.0) | 62.0 (30.0) | 36.0 (6.0) | 49.0 (29.5) | 67.0 (22.0) | 59.8 (24.9) | 64.0 (26.0) |
| Median (IQR) BMI (kg/m2) | 26.1 (6.7) | 31.9 (9.9) | 29.1 (10.8) | 28.4 (9.8) | 27.3 (7.1) | 30.8 (9.0) | 28.8 (9.0) |
| Not on insulin within 6 months of diagnosis | 1995 (8.4%) | 18225 (75.9%) | 3407 (99.3%) | 364 (64.8%) | 792 (16.7%) | 3967 (52.0%) | 24979 (41.6%) |
| On insulin within 6 months of diagnosis | 5244 (22.2%) | 714 (3.0%) | 24 (0.7%) | 79 (14.1%) | 693 (14.6%) | 1162 (15.2%) | 7813 (13.0%) |
| Missing insulin within 6 months of diagnosis | 16400 (69.4%) | 5060 (21.1%) | 1 (0.0%) | 119 (21.2%) | 3248 (68.6%) | 2502 (32.8%) | 27210 (45.3%) |
| Currently on insulin | 22772 (96.3%) | 6699 (27.9%) | 6 (0.2%) | 186 (33.1%) | 4549 (96.1%) | 2665 (34.9%) | 36685 (61.1%) |
| Currently on insulin or OHA | 22825 (96.6%) | 20361 (84.8%) | 89 (2.6%) | 297 (52.8%) | 4594 (97.1%) | 6441 (84.4%) | 54221 (90.4%) |
| With no family history of diabetes | 1965 (8.3%) | 1735 (7.2%) | 375 (10.9%) | 45 (8.0%) | 465 (9.8%) | 689 (9.0%) | 4854 (8.1%) |
| With family history of diabetes | 5666 (24.0%) | 10831 (45.1%) | 974 (28.4%) | 198 (35.2%) | 1360 (28.7%) | 3480 (45.6%) | 21337 (35.6%) |
| Missing family history of diabetes | 16008 (67.7%) | 11433 (47.6%) | 2083 (60.7%) | 319 (56.8%) | 2908 (61.4%) | 3462 (45.4%) | 33811 (56.3%) |
| Mean (SD) unadjusted MODY probability using insulin within 6 months and family history | 48.1 (35.5) | 20.5 (27.9) | 56.5 (34.9) | 46.5 (36.6) | 37.8 (35.4) | 37.4 (35.0) | 27.3 (32.1) |
| Mean (SD) adjusted MODY probability using insulin within 6 months and family history | 19.9 (25.8) | 16.5 (19.1) | 43.1 (26.2) | 31.9 (27.0) | 19.4 (23.5) | 23.3 (21.9) | 18.2 (20.8) |
| Missing above | 22052 (93.3%) | 14282 (59.5%) | 2083 (60.7%) | 359 (63.9%) | 4268 (90.2%) | 4865 (63.8%) | 45467 (75.8%) |
| Mean (SD) unadjusted MODY probability using insulin within 6 months or current insulin and family history | 35.3 (31.3) | 23.9 (28.8) | 56.5 (34.9) | 44.3 (36.0) | 32.1 (30.6) | 37.4 (33.8) | 29.9 (31.1) |
| Mean (SD) adjusted MODY probability using insulin within 6 months or current insulin and family history | 9.3 (17.7) | 14.8 (18.4) | 43.1 (26.2) | 27.9 (26.9) | 9.5 (17.1) | 20.5 (21.9) | 13.8 (19.1) |
| Missing above | 16008 (67.7%) | 11433 (47.6%) | 2083 (60.7%) | 319 (56.8%) | 2908 (61.4%) | 3462 (45.4%) | 33811 (56.3%) |
| Mean (SD) unadjusted MODY probability using insulin within 6 months or current insulin and family history (set to 1 where missing) | 42.1 (31.2) | 24.8 (29.4) | 66.0 (34.0) | 47.8 (35.9) | 36.1 (30.9) | 38.3 (33.9) | 34.2 (31.8) |
| Mean (SD) adjusted MODY probability using insulin within 6 months or current insulin and family history (set to 1 where missing) | 11.3 (19.5) | 15.4 (19.0) | 50.2 (25.7) | 28.0 (27.1) | 10.8 (18.5) | 20.2 (21.6) | 14.1 (19.7) |
| Mean (SD) unadjusted MODY probability using insulin within 6 months or current insulin and family history (set to 0 where missing) | 19.9 (28.3) | 17.1 (25.8) | 54.2 (35.9) | 33.3 (35.2) | 18.9 (27.4) | 26.9 (31.2) | 19.6 (27.8) |
| Mean (SD) adjusted MODY probability using insulin within 6 months or current insulin and family history (set to 0 where missing) | 7.2 (17.6) | 11.9 (16.6) | 41.3 (26.9) | 21.4 (26.0) | 7.2 (16.2) | 15.0 (19.6) | 10.1 (17.6) |

&nbsp;

### Top 10% of patients when current insulin used where insulin within 6 months is missing, and family history set to 0 or 1 when missing

When family history set to 1:
* 90th percentile for adjusted MODY probability = 58%
* 61.9% having missing family history (n=4139/6688)
* 6.9% of the Type 1 cohort; 7.9% of the Type 2 cohort; 56.6% of the unspecified with no PRIMIS code cohort; 23.1% of the unspecified with PRIMIS code cohort; 6.1% of the mixed; Type 1 cohort and 10.4% of the mixed; Type 2 cohort
* Consists of 24.3% Type 1, 28.5% Type 2, 29.0% unspecified with no PRIMIS code, 1.9% unspecified with PRIMIS code, 4.3% mixed; Type 1, and 11.9% mixed; Type 2

When family history set to 0:
* 90th percentile for adjusted MODY probability = 45.5%
* 43.1% having missing family history (n=2870/6657)
* 7.1% of the Type 1 cohort; 7.8% of the Type 2 cohort; 48.2% of the unspecified with no PRIMIS code cohort; 21.7% of the unspecified with PRIMIS code cohort; 6.5% of the mixed; Type 1 cohort and 13.5% of the mixed; Type 2 cohort
* Consists of 25.2% Type 1, 28.1% Type 2, 24.9% unspecified with no PRIMIS code, 1.8% unspecified with PRIMIS code, 4.6% mixed; Type 1, and 15.4% mixed; Type 2

&nbsp;


## T1D/T2D calculator (script: 03b_dpctn_t1dt2d_calculator)

The T1D/T2D calculator cohort consists those with current diagnosis of Type 1 (mixed or otherwise), Type 2 (mixed or otherwise), or unspecified diabetes, diagnosed aged 18-50 years inclusive:

```mermaid
graph TD;
    G["<b>T1D/T2D calculator cohort:</b> n=228,986"] --> H["Type 1:<br>n=14,696<br>(6.4%)"]
    G --> I["Type 2:<br>n=163,158<br>(71.3%)"]
    G --> J["Unspecified<br>no PRIMIS code:<br>n=29,811<br>(13.0%)"]
    G --> K["Unspecified<br>with PRIMIS code: <br>n=2,389<br>(1.0%)"]
    G --> L["Mixed; Type 1:<br>n=5,473<br>(2.4%)"]
    G --> M["Mixed; Type 2:<br>n=13,459<br>(5.9%)"]
    H --> N["Not missing<br>BMI:<br>14,412 (98.1%)"]
    I --> O["Not missing<br>BMI:<br>160,657 (98.5%)"]
    J --> P["Not missing<br>BMI:<br>19,423 (65.2%)"]
    K --> Q["Not missing<br>BMI:<br>2,123 (88.9%)"]
    L --> R["Not missing<br>BMI:<br>5,449 (99.6%)"]
    M --> S["Not missing<br>BMI:<br>13,389 (99.5%)"]
```
T1D/T2D calculator cohort not missing BMI: n=215,453 (94.1% of original T1D/T2D calculator cohort).

&nbsp;

Cohort characteristics of those not missing BMI:

| Characteristic | Type 1 | Type 2 | Unspecified with no PRIMIS code | Unspecified with PRIMIS code | Mixed; Type 1 | Mixed; Type 2 | Overall excluding 2 x unspecified groups |
| --- | --- | --- | --- | --- | --- | --- | --- |
| N | 14412 | 160657 | 19423 | 2123 | 5449 | 13389 | 193907 |
| Median (IQR) age at diagnosis (years) | 28.5 (12.7) | 43.5 (8.6) | 41.3 (12.4) | 41.6 (11.2) | 33.5 (14.0) | 34.5 (10.2) | 42.3 (10.7) |
| Median (IQR) age at index date (years) | 49.6 (20.0) | 53.6 (12.0) | 46.6 (12.0) | 48.7 (13.0) | 54.6 (17.9) | 50.6 (16.0) | 53.6 (13.0) |
| Median (IQR) BMI (kg/m2) | 26.4 (6.5) | 31.2 (8.8) | 29.0 (9.0) | 29.9 (9.0) | 27.4 (7.1) | 30.8 (8.8) | 30.8 (8.8) |
| Median (IQR) total cholesterol (mmol/L) | 4.4 (1.3) | 4.2 (1.5) | 5.0 (1.4) | 4.7 (1.4) | 4.3 (1.3) | 4.4 (1.4) | 4.2 (1.4) |
| Missing total cholesterol | 169 (1.2%) | 2113 (1.3%) | 5261 (27.1%) | 221 (10.4%) | 26 (0.5%) | 69 (0.5%) | 2377 (1.2%) |
| Median (IQR) HDL (mmol/L) | 1.5 (0.6) | 1.1 (0.4) | 1.3 (0.5) | 1.2 (0.5) | 1.4 (0.6) | 1.2 (0.5) | 1.2 (0.4) |
| Missing HDL | 360 (2.5%) | 3235 (2.0%) | 5593 (28.8%) | 269 (12.7%) | 57 (1.0%) | 135 (1.0%) | 3787 (2.0%) |
| Median (IQR) triglycerides (mmol/L) | 1.1 (0.8) | 1.7 (1.3) | 1.4 (1.1) | 1.5 (1.3) | 1.2 (1.0) | 1.5 (1.2) | 1.6 (1.3) |
| Missing triglycerides | 1430 (9.9%) | 13364 (8.3%) | 7681 (39.5%) | 497 (23.4%) | 289 (5.3%) | 785 (5.9%) | 15868 (8.2%) |
| Mean (SD) clinical prediction model probability | 51.0 (30.9) | 10.6 (14.5) | 21.1 (25.3) | 17.8 (22.6) | 37.3 (29.5) | 23.1 (23.3) | 15.2 (20.9) |
| Mean (SD) lipid prediction model probability | 19.1 (21.1) | 1.5 (4.2) | 3.2 (8.3) | 3.5 (9.4) | 11.9 (16.8) | 4.3 (9.1) | 3.3 (9.2) |
| Missing lipid prediction model probability | 1451 (10.1%) | 13509 (8.4%) | 7733 (39.8%) | 505 (23.8%) | 294 (5.4%) | 796 (5.9%) | 16050 (8.3%) |

&nbsp;

Histogram of age and BMI model:

<img src="https://github.com/Exeter-Diabetes/CPRD-Katie-DePICtion-Scripts/blob/main/Images/t1dt2d_age_bmi.png?" width="1000">



