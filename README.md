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
| Additional MODY calculator variable 1 | For whether patient is on insulin within 6 months, use time from diagnosis to earliest insulin script. Set to missing if time to insulin is >6 months and registration start is >6 months after diagnosis date and earliest insulin script is within 6 months of registration start. Where missing, use whether they are on insulin now (script within last 6 months) | Missingness was very high for this variable in our Type 1 cohort (51%) as most were diagnosed prior to registration. We are assuming they are already on insulin at registration if there is a script within 6 months of registration; 6 months was chosen as the optimal time for determining current medication based on previous work in CPRD which showed the 90th percentile for time between consecutive insulin scripts for those with diabetes was ~6 months. We do not set time to insulin to missing if the earliest insulin script is within 6 months of diagnosis, even if this is before registration (for our MODY calculator cohort, 9587/42213 (22.7%) of those with an insulin script had their earliest script before registration start) | We implemented this rule but looked at the level of missingness |
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
    E -->|"Patients diagnosed aged <=50 years"|F["<b>Final DePICtion cohort:</b> n=277,097"]
```
\* Extract actually contained n=1,481,294 unique patients (1,481,884 in total but some duplicates) but included n=309 with registration start dates in 2020 (which did not fulfil the extract criteria of having a diabetes-related medcode between 01/01/2004-06/11/2020 and >=1 year of data after this; some of these were also not 'acceptable' by [CPRD's definition](https://cprd.com/sites/default/files/2023-02/CPRD%20Aurum%20Glossary%20Terms%20v2.pdf)). NB: removing those with registration start date in 2020 also removed all of those with a 'patienttypeid' not equal to 3 ('regular'). See next section for further details on the extract.

\** The list of diabetes-related medcode used for the extract (see below) included some which were not specific to diabetes e.g. 'insulin resistance' and 'seen in diabetes clinic***'. The list of 'diabetes-specific codes' used to define the cohort here can be found in our [CPRD-Codelists respository](https://github.com/Exeter-Diabetes/CPRD-Codelists/blob/main/Diabetes/exeter_medcodelist_all_diabetes.txt).

\***  We determined the code 'Seen in diabetes clinic' (medcode 285223014) to be unspecific to diabetes after observing a large number of patients (>100,000) in our extract with this code and no further evidence of diabetes such as other codes for diabetes, high HbA1c test results, or prescriptions for glucose-lowering medications.

&nbsp;

```mermaid
graph TD;
    G["<b>Final DePICtion cohort:</b> n=277,097"] --> |"Unspecific codes<br>only"| H["Unspecified: <br>n=34,626<br>(12.5%)<br>(2,713 have<br>PRIMIS code)"]
    G --> |"T1D codes*"| I["Type 1: <br>n=30,339<br>(10.9%)"]
    G --> |"T2D codes*"| J["Type 2: <br>n=172,719<br>(62.7%)"]
    G --> |"Gestational codes*"| K["Gestational <br>only: <br>n=15,033<br>(5.4%)"]
    G --> |"MODY codes*"| L["MODY: <br>n=56<br>(0.0%)"]
    G --> |"Non-MODY <br>genetic/<br>syndromic <br>codes*"| M["Non-MODY <br>genetic/<br>syndromic: <br>n=101<br>(0.0%)"]
    G --> |"Secondary codes*"| N["Secondary: <br>n=186<br>(0.1%)"]
    G --> |"Other specified<br>type codes*"| P["Other specified<br>type: <br>n=1<br>(0.0%)"]  
    G --> |"Mix of diabetes<br>type codes"| Q["Mix of<br>diabetes types: <br>n=23,036<br>(8.3%)"]
    Q --> |"Type 1 based<br>on latest code"| R["Mixed; Type 1: <br>n=7,633<br>(2.8%)"]
    Q --> |"Type 2 based<br>on latest code"| S["Mixed; Type 2: <br>n=14,745<br>(5.3%)"]
    Q --> |"Other based<br>on latest code"| T["Mixed; other: <br>n=658<br>(0.2%)"]
```
\* Could also have diabetes codes of unspecified type

&nbsp;

Of the final cohort, 3.5% were non-English speaking, and a further 10.7% had a first language which was not English.

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
    A["<b>Final DePICtion cohort</b> (with diabetes codes, <br>aged >=18 years, diagnosed aged <=50 years):<br>n=277,097"] --> |"Diagnosed aged 1-35 years (inclusive)"| B["n=87,455"]
    B --> |"Unspecified diabetes type codes only<br>suggesting no diabetes"| C["n=12,538 (14.3%)"]
    B --> |"Assigned diabetes type based on codes"| D["n=74,917 (85.7%)"]
    D --> |"Assigned Type 1 or Type 2"| E["n=64,674 (86.3%)<br>30,543 Type 1 and 34,131 Type 2"]
    E --> |"Without valid diagnosis date<br>(between -30 and +90 days of registration start)"| F["n=2,870 (4.4%)<br>1,139 Type 1 and 1,731 Type 2"]
    E --> G["n=61,804 (95.6%)<br>29,404 Type 1 and 32,400 Type 2"]
    G --> |"Missing HbA1c or BMI<br>before diagnosis"|H["n=1,802 (2.9%)<br>1,032Type 1 and 770 Type 2"]
    G --> I["<b>MODY calculator cohort</b>: n=60,002 (97.1%)<br>28,372 Type 1 and 31,630 Type 2"]
   
   
```

&nbsp;

### MODY calculator variables

#### HbA1c

Distribution of time between HbA1c and current (index) date (01/02/2020):

<img src="https://github.com/Exeter-Diabetes/CPRD-Katie-DePICtion-Scripts/blob/main/Images/final_time_to_hba1c.png?" width="1000">

| Proportion with HbA1c within time period | Type 1 | Type 2 | Mixed; Type 1 | Mixed; Type 2 | Overall |
| --- | --- | --- | --- | --- | --- |
| 6 months | 54.2% | 60.6% | 61.3% | 63.4% | 58.5% |
| 1 year | 80.1% | 84.5% | 85.7% | 87.5% | 83.2% |
| 2 years | 94.1% | 95.1% | 96.5% | 96.5% | 95.0% |
| 5 years | 99.1% | 99.1% | 99.7% | 99.6% | 99.2% |

&nbsp;

#### BMI

Distribution of time between BMI and current (index) date (01/02/2020):

<img src="https://github.com/Exeter-Diabetes/CPRD-Katie-DePICtion-Scripts/blob/main/Images/final_time_to_bmi.png?" width="1000">

| Proportion with HbA1c within time period | Type 1 | Type 2 | Mixed; Type 1 | Mixed; Type 2 | Overall |
| --- | --- | --- | --- | --- | --- |
| 6 months | 42.7% | 49.0% | 47.8% | 51.2% | 46.7% |
| 1 year | 67.6% | 75.1% | 73.9% | 76.7% | 72.3% |
| 2 years | 85.2% | 90.1% | 89.5% | 91.7% | 88.3% |
| 5 years | 96.9% | 98.1% | 98.1% | 98.6% | 97.7% |

&nbsp;

#### Time to insulin (whether within 6 months or not)

|  | Type 1 | Type 2 | Mixed; Type 1 | Mixed; Type 2 | Overall |
| --- | --- | --- | --- | --- | --- |
| Insulin within 6 months = 1 of non-missing | 63.1% | 3.9% | 39.1% | 22.6% | 24.9% |
| Missing insulin within 6 months | 52.3% | 10.7% | 48.4% | 51.2% | 17.4% |
| Current insulin = 1 | 96.3% | 27.9% | 96.1% | 34.9% | 61.1% |
| Insulin within 6 months = 1 or current insulin = 1 if time to insulin missing | 80.6% | 12.4% | 67.1% | 32.1% | 46.0% |

For those with missing insulin within 6 months (i.e. where registration > 6 months after diagnosis) but currently treated with insulin, how long between diagnosis and earliest insulin script?

<img src="https://github.com/Exeter-Diabetes/CPRD-Katie-DePICtion-Scripts/blob/main/Images/final_time_to_ins_for_missing.png?" width="1000">

&nbsp;

#### Family history of diabetes

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



