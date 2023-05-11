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
Defines the cohort as per the flowchart above.

&nbsp;

### 02_dpctn_diabetes_type_all_time
Uses diabetes type codes to define diabetes type as per the below flowchart:

```mermaid
graph TD;
    A["<b>DePICtion cohort</b>: n=769,841"] --> |"Unspecific codes <br>only"| B["Unspecified: <br>n=122,814 <br>(15.8%)"]
    A --> |"T1D codes*"| C["Type 1: <br>n=32,005 <br>(4.1%)"]
    A --> |"T2D codes*"| D["Type 2: <br>n=576,977 <br>(74.1%)"]
    A --> |"Gestational codes*"| E["Gestational <br>only: <br>n=11,407 <br>(1.5%)"]
    A --> |"Gestational and <br>later T2D codes* **"| F["Gestational <br>then Type 2: <br>n=7,327 <br>(1.0%)"]
    A --> |"MODY codes*"| G["MODY: <br>n=62 <br>(0.0%)"]
    A --> |"Non-MODY <br>genetic/<br>syndromic <br>codes*"| H["Non-MODY <br>genetic/<br>syndromic: <br>n=108 <br>(0.0%)"]
    A --> |"Secondary codes*"| I["Secondary: <br>n=594 <br>(0.1%)"]
    A --> |"Malnutrition-<br>related codes*"| J["Malnutrition-<br>related: <br>n=1 <br>(0.0%)"]
    A --> |"Other including mix <br>of diabetes types and/<br>or codes for 'other <br>specific diabetes'"| K["Coding errors <br>or type changes<br> over time: <br>n=27,385 <br>(3.6%)"]
```

\* Could also have diabetes codes of unspecified type. For gestational diabetes only: earliest and latest codes for unspecified diabetes must be no more than a year prior to earliest gestational diabetes code (excluding 'history of gestational diabetes' codes) and no more than a year after latest gestational diabetes code (excluding 'history of gestational diabetes' codes).

\** All gestational diabetes codes (excluding 'history of gestational diabetes' codes) must be earlier than the earliest Type 2 diabetes code.

&nbsp;

This script also looks at how many diabetes codes, high HbA1cs and scripts for glucose-lowering medication have dates before the patient's birth (and so need to be cleaned). For all code categories, and all high HbA1cs and OHA/insulin scripts, >99.9% were on/after the patient's DOB (and only ~0.3% of cohort (1,995/769,841) are affected). The small proportion of codes/high HbA1c/scripts before DOB were excluded from downstream analysis.

&nbsp;

### 03_dpctn_diabetes_diagnosis_dates
Looks at potential quality issues around diagnosis dates (diabetes codes in year of birth) and determines diagnosis date for patients in the cohort (earliest of diabetes code, high HbA1c or script for glucose-lowering medication).

Patients with diabetes type 'gestational then type 2' or 'other' (as per flowchart above) were excluded (are later analysed in script 04_dpctn_diabetes_type_over_time) as they may have changes in their diagnosed type of diabetes over time. For the remaining cohort, diagnosis date is determined as the earliest diabetes code, high HbA1c or script for glucose-lowering medication. The table below shows which of these occurred earliest. If patients had >1 of a diabetes code, high HbA1c and/or prescription for OHA/insulin on their date of diagnosis, only the highest ranking of these is shown in the table below (rank order: diabetes code > high HbA1c > precription for OHA > prescription for insulin).

| Diabetes type (as per flowchart above) | Diabetes code for unspecified type | Diabetes code for specific type | Unspecified and/or type-specific diabetes code | High HbA1c | OHA prescription | Insulin prescription |
| ---- | ---- | ---- | ---- | ---- | ---- | ---- | 
| Any type* (n=743,968) | 281,466 | 210,454 | 491,920 | 230,740 | 19,361 |1947 |
| Unspecified (n=122814) | 110335 (0.898391062908138) | 0 (0) | 110335 (0.898391062908138) | 8625 (0.0702281498851922) | 3664 (0.0298337323106486) | 190 (0.00154705489602163) | 
| Type 1 (n=32005) | 11880 (0.371192001249805) | 17341 (0.541821590376504) | 29221 (0.913013591626308) | 1658 (0.051804405561631) | 214 (0.00668645524136854) | 912 (0.0284955475706921) | 
| Type 2 (n=576977) | 152717 (0.264684727467473) | 188554 (0.326796388764197) | 341271 (0.59148111623167) | 220182 (0.381613131892606) | 14770 (0.0255989406856772) | 754 (0.00130681119004744) | 
| Gestational only (n=11407) | 6365 (0.557990707460331) | 4252 (0.372753572367844) | 10617 (0.930744279828176) | 47 (0.00412027702288069) | 676 (0.0592618567546244) | 67 (0.00587358639431928) | 
| MODY (n=62) | 15 (0.241935483870968) | 29 (0.467741935483871) | 44 (0.709677419354839) | 15 (0.241935483870968) | 2 (0.032258064516129) | 1 (0.0161290322580645) | 
| Non-MODY genetic/syndromic (n=108) | 35 (0.324074074074074) | 54 (0.5) | 89 (0.824074074074074) | 7 (0.0648148148148148) | 5 (0.0462962962962963) | 7 (0.0648148148148148) | 
| Secondary (n=594) | 118 (0.198653198653199) | 224 (0.377104377104377) | 342 (0.575757575757576) | 206 (0.346801346801347) | 30 (0.0505050505050505) | 16 (0.0269360269360269) | 
| Malnutrition (n=1) | 1 (1) | 0 (0) | 1 (1) | 0 (0) | 0 (0) | 0 (0) | 

\* Excluding 'gestational then type 2' and 'other'



