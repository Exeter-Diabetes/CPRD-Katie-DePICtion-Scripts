# CPRD-Katie-DePICtion-Scripts

### Introduction

This repository contains the R scripts used to implement the Exeter Diabetes MODY calculator and T1D/T2D calculator in a CPRD Aurum dataset as part of the DePICtion project. Our [CPRD-Cohort-scripts respository](https://github.com/Exeter-Diabetes/CPRD-Cohort-scripts) has similar scripts for defining different cohorts in this same dataset.

The below diagram outlines the data processing steps involved in creating a cohort of adults with diabetes registered in primary care on 01/02/2020 which was used for this work:

```mermaid
graph TD;
    A["<b>CPRD Aurum October 2020 release</b> with linked Set 21 <br> (April 2021) HES APC, patient IMD, and ONS death data"] --> |"Unique patients with a diabetes-related medcode between 01/01/2004-06/11/2020 and >=1 year data prior and after"| B["<b>Our extract</b>: n=1,480,985*"]
    B -->|"Patients with a diabetes-specific code** with a year of >=1 year data prior'"|C["n=1,314,857"]
    C -->|"Patients registered on 01/02/2020 (all have diabetes code and therefore diabetes diagnosis <br> before this date due to the requirement to have 1 year of data after)"|D["n=779,870"]
    D -->|"Patients who are aged>=18 years at the index date (01/02/2020)"|E["<b>DePICtion cohort</b>: n=769,841"]
```

\* Extract actually contained n=1,481,294 unique patients (1,481,884 in total but some duplicates) but included n=309 with registration start dates in 2020 (which did not fulfil the extract criteria of having a diabetes-related medcode between 01/01/2004-06/11/2020 and >=1 year of data after this; some of these were also not 'acceptable' by [CPRD's definition](https://cprd.com/sites/default/files/2023-02/CPRD%20Aurum%20Glossary%20Terms%20v2.pdf)). NB: removing those with registration start date in 2020 also removed all of those with a 'patienttypeid' not equal to 3 ('regular'). See next section for further details on the extract.

\** The list of diabetes-related medcode used for the extract (see below) included some which were not specific to diabetes e.g. 'insulin resistance' and 'seen in diabetes clinic***'. The list of 'diabetes-specific codes' used to define the cohort here can be found in our [CPRD-Codelists respository](https://github.com/Exeter-Diabetes/CPRD-Codelists/blob/main/Diabetes/exeter_medcodelist_all_diabetes.txt).

\***  We determined the code 'Seen in diabetes clinic' (medcode 285223014) to be unspecific to diabetes after observing a large number of patients (>100,000) in our extract with this code and no further evidence of diabetes such as other codes for diabetes, high HbA1c test results, or prescriptions for glucose-lowering medications.

&nbsp;

## Extract details
Patients with a diabetes-related medcode ([full list here](https://github.com/Exeter-Diabetes/CPRD-Katie-MASTERMIND-Scripts/blob/main/Extract-details/diab_med_codes_2020.txt)) in the Observation table were extracted from the October 2020 CPRD Aurum release. See below for full inclusion criteria:

<img src="https://github.com/Exeter-Diabetes/CPRD-Cohort-scripts/blob/main/Extract-details/download_details1.PNG" width="370">

&nbsp;

<img src="https://github.com/Exeter-Diabetes/CPRD-Cohort-scripts/blob/main/Extract-details/download_details2.PNG" width="700">

&nbsp;


## Scripts

Data from CPRD was provided as raw text files which were imported into a MySQL database using a custom-built package ([aurum](https://github.com/Exeter-Diabetes/CPRD-analysis-package)) built by Dr Robert Challen. This package also includes functions to allow easy querying of the MySQL tables from R, using the 'dbplyr' tidyverse package. Codelists used for querying the data (denoted as 'codes${codelist_name}' in scripts) can be found in our [CPRD-Codelists repository](https://github.com/Exeter-Diabetes/CPRD-Codelists). 

Our [CPRD-Codelists repository](https://github.com/Exeter-Diabetes/CPRD-Codelists) also contains more details on the algorithms used to define variables such as ethnicity and diabetes type - see individual scripts for links to the appropriate part of the CPRD-Codelists repository.

&nbsp;

### 01_dpctn_cohort
Defines the cohort as per the flowchart above, and adds in patient characteristics (e.g. sex, ethnicity, age at index date) as well as biomarkers values at/prior to index date (BMI, HDL, triglycerides, total cholesterol, HbA1c, GAD/IA2 antibodies, and C-peptide) and family history of diabetes.

&nbsp;

### 02_dpctn_diabetes_type_all_time
Uses diabetes type codes to define diabetes type as per the below flowchart:

```mermaid
graph TD;
    A["<b>DePICtion cohort</b>: n=769,841"] --> |"Unspecific codes <br>only"| B["Unspecified: <br>n=122,814 <br>(15.8%)"]
    A --> |"T1D codes*"| C["Type 1: <br>n=32,005 <br>(4.1%)"]
    A --> |"T2D codes*"| D["Type 2: <br>n=576,977 <br>(74.1%)"]
    A --> |"Gestational codes*"| E["Gestational <br>only: <br>n=15,718 <br>(2.0%)"]
    A --> |"MODY codes*"| G["MODY: <br>n=62 <br>(0.0%)"]
    A --> |"Non-MODY <br>genetic/<br>syndromic <br>codes*"| H["Non-MODY <br>genetic/<br>syndromic: <br>n=108 <br>(0.0%)"]
    A --> |"Secondary codes*"| I["Secondary: <br>n=594 <br>(0.1%)"]
    A --> |"Malnutrition-<br>related codes*"| J["Malnutrition-<br>related: <br>n=1 <br>(0.0%)"]
    A --> |"Other including mix <br>of diabetes types and/<br>or codes for 'other <br>specific diabetes'"| K["Coding errors <br>or type changes<br> over time: <br>n=30,401 <br>(3.9%)"]
```

\* Could also have diabetes codes of unspecified type. For gestational diabetes only: earliest and latest codes for unspecified diabetes must be no more than a year prior to earliest gestational diabetes code (excluding 'history of gestational diabetes' codes) and no more than a year after latest gestational diabetes code (excluding 'history of gestational diabetes' codes).

\** All gestational diabetes codes (excluding 'history of gestational diabetes' codes) must be earlier than the earliest Type 2 diabetes code.

&nbsp;

This script also looks at how many diabetes codes, high HbA1cs and scripts for glucose-lowering medication have dates before the patient's birth (and so need to be cleaned). For all code categories, and all high HbA1cs and OHA/insulin scripts, >99.9% were on/after the patient's DOB (and only ~0.3% of cohort (1,995/769,841) are affected). The small proportion of codes/high HbA1c/scripts before DOB were excluded from downstream analysis.

&nbsp;

### 03_dpctn_diabetes_diagnosis_dates
Looks at potential quality issues around diagnosis dates (diabetes codes in year of birth) and determines diagnosis date for patients in the cohort (earliest of diabetes code, high HbA1c or script for glucose-lowering medication). Also looks at implications of using diabetes codes only to determine diagnosis dates.

Patients with diabetes type 'other' (as per flowchart above) were excluded (are later analysed in script 04_dpctn_diabetes_type_over_time) as they may have changes in their diagnosed type of diabetes over time. For the remaining cohort, diagnosis date is determined as the earliest diabetes code, high HbA1c or script for glucose-lowering medication. 

To investigate data quality issues, date of diagnosis by calendar year relative to year of birth was analysed:

<img src="https://github.com/Exeter-Diabetes/CPRD-Katie-DePICtion-Scripts/blob/main/Images/year_relative_to_birth.png?" width="1000">

Clearly there are data quality issues since we would not expect any patients with Type 2 diabetes to be diagnosed in their year of birth. Subsequent analysis ignored diabetes codes in the year of birth for those with Type 2 diabetes, using the next code/high HbA1c/prescription for glucose-lowering medication. This constitutes only 0.3% of those with Type 2 diabetes.

&nbsp;

Also to investigate data quality issues, date of diagnosis by calendar year relative to year of registration start was analysed:

<img src="https://github.com/Exeter-Diabetes/CPRD-Katie-DePICtion-Scripts/blob/main/Images/year_relative_to_reg_start.png?" width="1000">

Again, clearly there are data quality issues with more patients than expected being diagnosed in the year where they register with their primary care practice. This probably reflects old diagnoses (prior to registration) being recorded as if they were new. When diagnoses within 3 months (<91 days) of registration start are excluded as per [https://bmjopen.bmj.com/content/7/10/e017989](https://bmjopen.bmj.com/content/7/10/e017989), the data appear more as expected:

<img src="https://github.com/Exeter-Diabetes/CPRD-Katie-DePICtion-Scripts/blob/main/Images/year_relative_to_reg_start_clean.png?" width="1000">

Patients with diagnoses within 3 months (<91 days) of registration start were therefore treated as having missing diagnosis dates.

&nbsp;

The table below shows which out of a diagnosis code, high HbA1c, or prescription for glucose-lowering medication occurred earliest for patients and was therefore used as the date of diagnosis (after codes in the year of birth were removed for those with Type 2 diabetes. 'Missing' indicates patients with a diagnosis within 3 months (<91 days) of registration start. If patients had >1 of a diabetes code, high HbA1c and/or prescription for OHA/insulin on their date of diagnosis, only the highest ranking of these is shown in the table (rank order: diabetes code > high HbA1c > precription for OHA > prescription for insulin).

| Diabetes type (as per flowchart above) | Diabetes code for unspecified type | Diabetes code for specific type | Unspecified and/or type-specific diabetes code | High HbA1c | OHA prescription | Insulin prescription | Missing |
| ---- | ---- | ---- | ---- | ---- | ---- | ---- | ---- |
| Any type* (n=743968) | 271616 (36.5%) | 203998 (27.4%) | 475614 (63.9%) | 222676 (29.9%) | 16557 (2.2%) | 1660 (0.2%) | 27461 (3.7%) |
| Unspecified (n=122814) | 109166 (88.9%) |  (0.0%) | 109166 (88.9%) | 8435 (6.9%) | 3292 (2.7%) | 176 (0.1%) | 1745 (1.4%) |
| Type 1 (n=32005) | 11318 (35.4%) | 16875 (52.7%) | 28193 (88.1%) | 1574 (4.9%) | 189 (0.6%) | 753 (2.4%) | 1296 (4.0%) |
| Type 2 (n=576977) | 144635 (25.1%) | 182636 (31.7%) | 327271 (56.7%) | 212396 (36.8%) | 12414 (2.2%) | 642 (0.1%) | 24254 (4.2%) |
| Gestational only (n=11407) | 6335 (55.5%) | 4185 (36.7%) | 10520 (92.2%) | 44 (0.4%) | 627 (5.5%) | 65 (0.6%) | 151 (1.3%) |
| MODY (n=62) | 12 (19.4%) | 28 (45.2%) | 40 (64.5%) | 15 (24.2%) | 2 (3.2%) | 1 (1.6%) | 4 (6.5%) |
| Non-MODY genetic/syndromic (n=108) | 34 (31.5%) | 52 (48.1%) | 86 (79.6%) | 6 (5.6%) | 5 (4.6%) | 7 (6.5%) | 4 (3.7%) |
| Secondary (n=594) | 115 (19.4%) | 222 (37.4%) | 337 (56.7%) | 206 (34.7%) | 28 (4.7%) | 16 (2.7%) | 7 (1.2%) |
| Malnutrition (n=1) | 1 (100.0%) | 0 (0.0%) | 1 (100.0%) | 0 (0.0%) | 0 (0.0%) | 0 (0.0%) | 0 (0.0%) |

\* Excluding 'gestational then type 2' and 'other'

&nbsp;

The table below shows what the impact would be of using diabetes code (unspecified type and type-specific) alone to determine diagnosis dates (i.e. not also using high HbA1c and prescriptions for glucose-lowering medication).

| Diabetes type (as per flowchart above) | Median difference in diagnosis date if only diabetes codes used (days) | Median difference in diagnosis date if only diabetes codes used (days) in patients with a high HbA1c/prescription for glucose-lowering medication earlier than a diabetes code |
| ---- | ---- | ---- |
| Any type* (n=715216 with non-missing diagnosis date) | 0 | 26 |
| Unspecified (n=121017 with non-missing diagnosis date) | 0 | 283 |
| Type 1 (n=30664 with non-missing diagnosis date) | 0 | 7 |
| Type 2 (n=551531 with non-missing diagnosis date)| 0 | 24 |
| Gestational only (n=11256 with non-missing diagnosis date) | 0 | 589 |
| MODY (n=57 with non-missing diagnosis date) | 0 | 251 |
| Non-MODY genetic/syndromic (n=104 with non-missing diagnosis date) | 0 | 422 |
| Secondary (n=586 with non-missing diagnosis date) | 0 | 31 |
| Malnutrition (n=1 with non-missing diagnosis date) | 0 | NA |

&nbsp;

### 04_dpctn_diabetes_type_over_time





