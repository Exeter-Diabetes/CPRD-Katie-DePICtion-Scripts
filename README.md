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
| Diabetes diagnosis date 1 | Diagnosis date is determined as the earliest code for diabetes, excluding those before the date of birth | There is a minimal time difference (see Initial data quality exploration) if the earliest of a code, an elevated HbA1c, or an OHA/insulin script is used instead | We have implemented this rule |
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
    E -->|"Patients diagnosed aged <=50 years"|F["<b>Final DePICtion cohort:</b> n=276,623"]
```
\* Extract actually contained n=1,481,294 unique patients (1,481,884 in total but some duplicates) but included n=309 with registration start dates in 2020 (which did not fulfil the extract criteria of having a diabetes-related medcode between 01/01/2004-06/11/2020 and >=1 year of data after this; some of these were also not 'acceptable' by [CPRD's definition](https://cprd.com/sites/default/files/2023-02/CPRD%20Aurum%20Glossary%20Terms%20v2.pdf)). NB: removing those with registration start date in 2020 also removed all of those with a 'patienttypeid' not equal to 3 ('regular'). See next section for further details on the extract.

\** The list of diabetes-related medcode used for the extract (see below) included some which were not specific to diabetes e.g. 'insulin resistance' and 'seen in diabetes clinic***'. The list of 'diabetes-specific codes' used to define the cohort here can be found in our [CPRD-Codelists respository](https://github.com/Exeter-Diabetes/CPRD-Codelists/blob/main/Diabetes/exeter_medcodelist_all_diabetes.txt).

\***  We determined the code 'Seen in diabetes clinic' (medcode 285223014) to be unspecific to diabetes after observing a large number of patients (>100,000) in our extract with this code and no further evidence of diabetes such as other codes for diabetes, high HbA1c test results, or prescriptions for glucose-lowering medications.

&nbsp;

```mermaid
graph TD;
    G["<b>Final DePICtion cohort:</b> n=276,623"] --> |"Unspecific codes<br>only"| H["Unspecified: <br>n=34,621<br>(12.5%)<br>(2,711 have<br>PRIMIS code)"]
    G --> |"T1D codes*"| I["Type 1: <br>n=30,338<br>(11.0%)"]
    G --> |"T2D codes*"| J["Type 2: <br>n=173,277<br>(62.6%)"]
    G --> |"Gestational codes*"| K["Gestational <br>only: <br>n=15,033<br>(5.4%)"]
    G --> |"MODY codes*"| L["MODY: <br>n=56<br>(0.0%)"]
    G --> |"Non-MODY <br>genetic/<br>syndromic <br>codes*"| M["Non-MODY <br>genetic/<br>syndromic: <br>n=101<br>(0.0%)"]
    G --> |"Secondary codes*"| N["Secondary: <br>n=186<br>(0.1%)"]
    G --> |"Other specified<br>type codes*"| P["Other specified<br>type: <br>n=1<br>(0.0%)"]  
    G --> |"Mix of diabetes<br>type codes"| Q["Mix of<br>diabetes types: <br>n=23,010<br>(8.3%)"]
    Q --> |"Type 1 based<br>on latest code"| R["Mixed; Type 1: <br>n=7,627<br>(2.8%)<br>34 have MODY<br>code ever"]
    Q --> |"Type 2 based<br>on latest code"| S["Mixed; Type 2: <br>n=14,726<br>(5.3%)<br>107 have MODY<br>code ever"]
    Q --> |"MODY based<br>on latest code"| T["Mixed; MODY: <br>n=85<br>(0.0%)"]
    Q --> |"Other based<br>on latest code"| U["Mixed; other<br>n=572<br>(0.2%)"]
    U --> |"Has a MODY<br>code ever"|V["n=16<br>(0.0%)"]
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

The MODY calculator cohort consists those with current diagnosis of Type 1 (mixed or otherwise), Type 2 (mixed or otherwise), or unspecified diabetes, diagnosed aged 18-35 years inclusive:

```mermaid
graph TD;
    A["<b>Final DePICtion cohort</b> (with diabetes codes, <br>aged >=18 years, diagnosed aged <=50 years):<br>276,623"] --> |"Diagnosed aged 1-35 years (inclusive)"| B["n=87,708"]
    B --> |"Unspecified diabetes type codes only<br>suggesting no diabetes"| C["n=12,544 (14.3%)"]
    B --> |"Assigned diabetes type based on codes"| D["n=75,164 (85.7%)"]
    D --> |"Assigned Type 1 or Type 2"| E["n=64,919 (86.4%)<br>30,692 Type 1 and 34,227 Type 2"]
    E --> |"Without valid diagnosis date<br>(between -30 and +90 days of registration start)"| F["n=2,874 (4.4%)<br>1,140 Type 1 and 1,734 Type 2"]
    E --> G["n=62,045 (95.6%)<br>29,552 Type 1 and 32,493 Type 2"]
    G --> |"Missing HbA1c or BMI<br>before diagnosis"|H["n=1,802 (2.9%)<br>1,032 Type 1 and 770 Type 2"]
    G --> I["<b>MODY calculator cohort</b>: n=60,243 (97.1%)<br>28,520 Type 1 and 31,723 Type 2"]
```

&nbsp;

### MODY calculator variables

#### HbA1c

Distribution of time between HbA1c and current (index) date (01/02/2020):

<img src="https://github.com/Exeter-Diabetes/CPRD-Katie-DePICtion-Scripts/blob/main/Images/final_mody_time_to_hba1c.png?" width="1000">

| Proportion with HbA1c within time period | Type 1 | Type 2 | Mixed; Type 1 | Mixed; Type 2 | Overall |
| --- | --- | --- | --- | --- | --- |
| 6 months | 54.2% | 60.6% | 61.4% | 63.4% | 58.5% |
| 1 year | 80.1% | 84.5% | 85.7% | 87.5% | 83.2% |
| 2 years | 94.1% | 95.1% | 96.5% | 96.5% | 95.0% |
| 5 years | 99.1% | 99.1% | 99.7% | 99.6% | 99.2% |

&nbsp;

#### BMI

Distribution of time between BMI and current (index) date (01/02/2020):

<img src="https://github.com/Exeter-Diabetes/CPRD-Katie-DePICtion-Scripts/blob/main/Images/final_mody_time_to_bmi.png?" width="1000">

| Proportion with BMI within time period | Type 1 | Type 2 | Mixed; Type 1 | Mixed; Type 2 | Overall |
| --- | --- | --- | --- | --- | --- |
| 6 months | 42.7% | 48.9% | 47.8% | 51.2% | 46.7% |
| 1 year | 67.6% | 75.1% | 73.9% | 76.8% | 72.3% |
| 2 years | 85.2% | 90.1% | 89.5% | 91.7% | 88.3% |
| 5 years | 96.8% | 98.1% | 98.1% | 98.5% | 97.7% |

&nbsp;

#### Current insulin treatment

|  | Type 1 | Type 2 | Mixed; Type 1 | Mixed; Type 2 | Overall |
| --- | --- | --- | --- | --- | --- |
| Current insulin (within last 6 months) | 96.3% | 28.0% | 96.1% | 35.0% | 61.2% |

&nbsp;

Time from diagnosis to earliest insulin script for currently insulin treated patients:

By diabetes type:

<img src="https://github.com/Exeter-Diabetes/CPRD-Katie-DePICtion-Scripts/blob/main/Images/final_mody_time_to_ins_by_diabetes_type.png?" width="1000">

By whether diagnosed under age 18 or not:

<img src="https://github.com/Exeter-Diabetes/CPRD-Katie-DePICtion-Scripts/blob/main/Images/final_mody_time_to_insulin_diag_age.png?" width="1000"> 

&nbsp;

#### Family history of diabetes

|  | Type 1 | Type 2 | Mixed; Type 1 | Mixed; Type 2 | Overall |
| --- | --- | --- | --- | --- | --- |
| Family history of diabetes = 1 of non-missing | 74.2% | 86.2% | 74.6% | 83.5% | 81.5% |
| Missing family history of diabetes | 67.7% | 47.7% | 61.5% | 45.4% | 56.4% |

&nbsp;

#### MODY code history

|  | Type 1 | Type 2 | Mixed; Type 1 | Mixed; Type 2 | Overall |
| --- | --- | --- | --- | --- | --- |
| MODY code ever | 0 (0.0%) | 0 (0.0%) | 15 (0.3%) | 36 (0.4%) | 51 (0.1%) |

&nbsp;

### MODY calculator results (for those with missing family history of diabetes, this is assumed to be 0)

|  | Type 1 | Type 2 | Mixed; Type 1 | Mixed; Type 2 | Overall |
| --- | --- | --- | --- | --- | --- |
| Mean adjusted probability | 8.1% | 15.2% | 7.2% | 18.6% | 12.2% |
| Mean adjusted probability for those of White ethnicity | 7.9% (n=21,617) | 14.1% (n=13,932) | 6.7% (n=4,179) | 16.6% (n=4,411) | 10.6% (n=44,139) |
| Mean adjusted probability for those of non-White ethnicity | 11.1% (n=1,745) | 16.7% (n=9,657) | 11.1% (n=521) | 21.5% (n=3,186) | 16.9% (n=15,109) |

&nbsp;

Distribution of unadjusted probabilities:

By diabetes type:

<img src="https://github.com/Exeter-Diabetes/CPRD-Katie-DePICtion-Scripts/blob/main/Images/final_mody_distribution_by_diabetes_type.png?" width="1000">

By whether diagnosed under age 18 or not:

<img src="https://github.com/Exeter-Diabetes/CPRD-Katie-DePICtion-Scripts/blob/main/Images/final_mody_distribution_by_diag_agediabetes_type.pngg?" width="1000"> 

&nbsp;

#### Looking at those with highest predicted risk (>95%)

* 1,989/60,243 (3.3%) of MODY calculator cohort
* Of the different diabetes classes, 3.4% of Type 1s, 3.2 of Type 2s, 2.5% of mixed; Type 1 and 3.9% of the mixed; Type 2s have MODY probability>95%

&nbsp;

High probability cohort characteristics:
|  | Type 1 | Type 2 | Mixed; Type 1 | Mixed; Type 2 | Overall |
| --- | --- | --- | --- | --- | --- |
| MODY code ever | 0 (0.0%) | 0 (0.0%) | 2 (2.8%) | 15 (7.5%) | 17 (1.3%) |

##### Missing family history
* Of the 1,989 identified, 0% have missing family history


Those with (non-missing) family history of diabetes (48% of whole MODY calculator cohort):
* 554/21,149 (2.5%) have MODY probability >95%
* 102 (18.4%) Type 1, 206 (37.2%) Type 2, 24 (4.3%) mixed; Type 1, 222 (40.1%) mixed; Type 2
* Of the different diabetes classes, 2.7% of Type 1s, 1.7% of Type 2s, 2.0% of mixed; Type 1 and 5.6% of the mixed; Type 2s have MODY probability>95%

Those with missing family history of diabetes:
* 70/22,883 (0.3%) have MODY probability >95% when family history set to 0 (or 1)
    * 26 (37.1%) Type 1, 31 (44.3%) Type 2, 2 (1.4%) mixed; Type 1, 11 (15.7%) mixed; Type 2
    * Of the different diabetes classes, 0.4% of Type 1s, 0.3% of Type 2s, 0.1% of mixed; Type 1 and 0.3% of the mixed; Type 2s have MODY probability >95% when family history set to 0 (or 1)
* An additional 683/22,883 (3.0%) have MODY probability >95% when family history set to 1 but not when set to 0
    * 247 (36.2%) Type 1, 201 (29.4%) Type 2, 48 (7.0%) mixed; Type 1, 187 (27.4%) mixed; Type 2
    * Of the different diabetes classes, 3.6% of Type 1s, 1.8% of Type 2s, 2.6% of mixed; Type 1 and 5.9% of the mixed; Type 2s have MODY probability >95% when family history set to 1 but not when set to 0

Overall these 3 groups represent (554 + 70 + 683) / 44,032 = 3.0% of the MODY calculator cohort.

&nbsp;

## T1D/T2D calculator (script: 03b_dpctn_t1dt2d_calculator)

The T1D/T2D calculator cohort consists those with current diagnosis of Type 1 (mixed or otherwise), Type 2 (mixed or otherwise), or unspecified diabetes, diagnosed aged 18-50 years inclusive:

```mermaid
graph TD;
    A["<b>Final DePICtion cohort</b> (with diabetes codes, <br>aged >=18 years, diagnosed aged <=50 years):<br>n=276,623"] --> |"Diagnosed aged 18-50 years (inclusive)"| B["n=256,690"]
    B --> |"Unspecified diabetes type codes only<br>suggesting no diabetes"| C["n=32,705 (12.7%)"]
    B --> |"Assigned diabetes type based on codes"| D["n=223,985 (87.3%)"]
    D --> |"Assigned Type 1 or Type 2"| E["n=208,236 (93.0%)<br>21,747 Type 1 and 186,489 Type 2"]
    E --> |"Without valid diagnosis date<br>(between -30 and +90 days of registration start)"| F["n=10,952 (5.3%)<br>1,479 Type 1 and 9,473 Type 2"]
    E --> G["n=197,284 (94.7%)<br>20,268 Type 1 and 177,016 Type 2"]
    G --> |"Missing BMI<br>before diagnosis"|H["n=2,880 (1.5%)<br>308 Type 1 and 2,572 Type 2"]
    G --> I["<b>T1D/T2D calculator cohort</b>: n=194,404 (98.5%)<br>19,960 Type 1 and 174,444 Type 2 (10.3% vs 89.7%)"]
    I --> |"With cholesterol, HDL and triglyceride measurements"|J["<b>T1D/T2D lipid calculator cohort</b>: n=178,346 (91.7%)<br>18,212 Type 1 and 160,134 Type 2 (10.2% vs 89.8%)"]
```

&nbsp;

### T1D/T2D calculator variables

#### BMI

Distribution of time between BMI and current (index) date (01/02/2020):

<img src="https://github.com/Exeter-Diabetes/CPRD-Katie-DePICtion-Scripts/blob/main/Images/final_t1dt2d_time_to_bmi.png?" width="1000">

| Proportion with BMI within time period | Type 1 | Type 2 | Mixed; Type 1 | Mixed; Type 2 | Overall |
| --- | --- | --- | --- | --- | --- |
| 6 months | 44.0% | 50.8% | 48.7% | 52.0% | 50.3% |
| 1 year | 69.7% | 78.2% | 75.4% | 78.4% | 77.5% |
| 2 years | 86.4% | 92.0% | 90.2% | 92.3% | 91.6% |
| 5 years | 97.0% | 98.6% | 98.2% | 98.7% | 98.5% |

&nbsp;

#### Lipids

Distribution of time between **total cholesterol** and current (index) date (01/02/2020):

<img src="https://github.com/Exeter-Diabetes/CPRD-Katie-DePICtion-Scripts/blob/main/Images/final_t1dt2d_time_to_total_chol.png?" width="1000">

&nbsp;

Distribution of time between **HDL** and current (index) date (01/02/2020):

<img src="https://github.com/Exeter-Diabetes/CPRD-Katie-DePICtion-Scripts/blob/main/Images/final_t1dt2d_time_to_hdl.png?" width="1000">

&nbsp;

Distribution of time between **triglyceride** and current (index) date (01/02/2020):

<img src="https://github.com/Exeter-Diabetes/CPRD-Katie-DePICtion-Scripts/blob/main/Images/final_t1dt2d_time_to_triglyceride.png?" width="1000">

&nbsp;

### T1D/T2D calculator results

|  | Type 1 | Type 2 | Mixed; Type 1 | Mixed; Type 2 | Overall |
| --- | --- | --- | --- | --- | --- |
| Mean clinical prediction model probability | 51.0% (n=14486) | 10.6% (n=161010) | 37.3% (n=5474) | 23.1% (n=13434) | 15.2% (n=194404) 
| Mean clinical prediction model probability for those of White ethnicity |51.0% (n=13064) | 8.1% (n=102775) | 37.3% (n=4731) | 20.9% (n=7875) | 14.3% (n=128445) 
| Mean clinical prediction model probability for those of non-White ethnicity | 51.2% (n=1129) | 15.3% (n=54633) | 38.0% (n=658) | 26.4% (n=5438) | 17.2% (n=61858) 
| Mean lipid prediction model probability | 19.1% (n=13033) | 1.5% (n=147496) | 11.9% (n=5179) | 4.3% (n=12638) | 3.3% (n=178346) 
| Mean lipid prediction model probability for those of White ethnicity | 19.2% (n=11760) | 1.1% (n=93715) | 12.2% (n=4467) | 4.2% (n=7337) | 3.5% (n=117279) 
| Mean lipid prediction model probability for those of non-White ethnicity | 18.3% (n=1025) | 2.4% (n=50682) | 10.6% (n=635) | 4.4% (n=5186) | 2.9% (n=57528) 
| Missing lipid prediction model probability | 0.7% | 7.0% | 0.2% | 0.4% | 8.3% |

&nbsp;

**Clinical prediction model**

Distribution of probabilities:
<img src="https://github.com/Exeter-Diabetes/CPRD-Katie-DePICtion-Scripts/blob/main/Images/final_t1dt2d_clinical_histogram.png?" width="1000">

| Clinical prediction model probability | Proportion on insulin within 6 months of diagnosis |
| --- | --- | 
| 0-10% | 32.8% |
| >10-20% | 16.0% |
| >20-30% | 9.8% |
| >30-40% | 7.5% |
| >40-50% | 5.6% |
| >50-60% | 5.5% |
| >60-70% | 4.9% |
| >70-80% | 5.3% |
| >80-90% | 5.7% |
| >90% | 6.8% |

&nbsp;

Characteristics of those scoring >90% and <10% (Type 1 = those with only Type 1 specific codes; Type 2 = those with only Type 2 specific codes):

| | Concordant Type 1 (probability >90%) | Discordant Type 2 (probability >90%) | Concordant Type 2 (probability <10%) | Discordant Type 1 (probability <10%) |
| --- | --- | --- | --- | --- |
| N | 1867 (86.6% of those with probability >90%) | 290 (13.4% of those with probability >90%) | 111342 (98.4% of those with probability <10%) | 1763 (1.6% of those with probability <10%) |
| Median (IQR) age at diagnosis (years) | 20.5 (3.5) | 21.6 (5.4) | 45.1 (6.5) | 41.5 (9.1) |
| Median (IQR) BMI (kg/m2) | 21.9 (3.5) | 21.2 (4.1) | 33.7 (8.2) | 32.6 (7.0) |
| Currently on insulin (last 6 months) | 1757 (94.1%) | 83 (28.6%) | 22212 (19.9%) | 1695 (96.1%) |
| Currently on bolus/mix insulin (last 6 months) | 1688 (90.4%) | 56 (19.3%) | 15282 (13.7%) | 1636 (92.8%) |
| Median (IQR) highest HbA1c ever (mmol/mol) | 88.0 (41.0) | 82.9 (46.0) | 84.0 (39.0) | 92.2 (31.0) |
| No HbA1c ever | 16 (0.9%) | 0 (0.0%) | 123 (0.1%) | 5 (0.3%) |
| On insulin within 6 months of diagnosis (in those where this is not missing) | 738 (74.8%) | 16 (6.3%) | 1841 (1.7%) | 859 (71.3%) |
| Hospitalisation with hypoglycaemia as the primary cause ever (in those with linked inpatient hospital records) | 181 (9.8%) | 4 (1.4%) | 897 (0.8%) | 105 (6.0%) | 

&nbsp;

**Lipid prediction model distribution:**

<img src="https://github.com/Exeter-Diabetes/CPRD-Katie-DePICtion-Scripts/blob/main/Images/final_t1dt2d_lipid_histogram.png?" width="1000">

&nbsp;

