# CPRD-Katie-DePICtion-Scripts

### Introduction

This repository contains the R scripts used to implement the Exeter Diabetes MODY calculator and T1D/T2D calculator in a CPRD Aurum dataset as part of the DePICtion project. Our [CPRD-Cohort-scripts respository](https://github.com/Exeter-Diabetes/CPRD-Cohort-scripts) has similar scripts for defining different cohorts in this same dataset.

The below diagram outlines the data processing steps involved in creating a cohort of adults with diabetes registered in primary care on 01/02/2020 which was used for this work:

```mermaid
graph TD;
    A["<b>CPRD Aurum October 2020 release</b> with linked Set 21 <br> (April 2021) HES APC, patient IMD, and ONS death data"] --> |"Unique patients with a diabetes-related medcode between 01/01/2004-06/11/2020 and >=1 year data prior and after"| B["<b>Our extract</b>: n=1,480,985*"]
    B -->|"Patients with a diabetes-specific code** with a year of >=1 year data prior'"|C["n=1,480,395"]
    C -->|"Patients registered on 01/02/2020 (all have diabetes code and therefore diabetes diagnosis <br> before this date due to the requirement to have 1 year of data after)"|D["n=905,049"]
    D -->|"Patients who are aged>=18 years at the index date (01/02/2020)"|E["n=886,734"]
    E -->|"Patients with no HbA1cs>=48 mmol/mol or scripts <br> for glucose-lowering medication or diabetes codes <br> other than 'Seen in diabetes clinic' (medcode 285223014)***"|G["n=108,054"]
    E --> F["<b>DePICtion cohort</b>: n=778,680"]
```

\* Extract actually contained n=1,481,294 unique patients (1,481,884 in total but some duplicates) but included n=309 with registration start dates in 2020 (which did not fulfil the extract criteria of having a diabetes-related medcode between 01/01/2004-06/11/2020 and >=1 year of data after this; some of these were also not 'acceptable' by [CPRD's definition](https://cprd.com/sites/default/files/2023-02/CPRD%20Aurum%20Glossary%20Terms%20v2.pdf)). NB: removing those with registration start date in 2020 also removed all of those with a 'patienttypeid' not equal to 3 ('regular'). See next section for further details on the extract.

&nbsp;

\** The list of diabetes-related medcode used for the extract (see below) included some which were not specific to diabetes e.g. 'insulin resistance'. The list of 'diabetes-specific codes' used to define the cohort here can be found in our [CPRD-Codelists respository](https://github.com/Exeter-Diabetes/CPRD-Codelists/blob/main/Diabetes/exeter_medcodelist_all_diabetes.txt).

&nbsp;

\*** We excluded these people as they constituted a large proportion of the cohort but did not have sufficient evidence of actually having diabetes. We postulate that the code 'Seen in diabetes clinic' (medcode 285223014) is used for some other purpose in people without diabetes. NB: 348,475 (45%) of the final cohort have at least one instance of this code.

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

### 01_dpctn_cohort
Defines the cohort as per the flowchart above, except for the final step of removing those with only 'Seen in diabetes clinic' codes and no high HbA1cs/scripts for glucose-lowering medication.

### 02_dpctn_diabetes_type_all_time
Uses diabetes type codes for the final step in defining the cohort (removing those with only 'Seen in diabetes clinic' codes and no high HbA1cs/scripts for gluocse-lowering medication) and to define diabetes type as per the below flowchart

```mermaid
graph TD;
    A["<b>DePICtion cohort</b>: n=778,680"] --> |"Unspecific codes <br>only"| B["Unspecified: <br>n="]
    A --> |"T1D codes*"| C["Type 1: <br>n="]
    A --> |"T2D codes*"| D["Type 2: <br>n="]
    A --> |"Gestational codes*"| E["Gestational <br>only: <br>n="]
    A --> |"Gestational and <br>later T2D codes*"| F["Gestational <br>then Type 2: <br>n="]
    A --> |"MODY codes*"| G["MODY: <br>n="]
    A --> |"Non-MODY <br>genetic/<br>syndromic <br>codes*"| H["Non-MODY <br>genetic/<br>syndromic: <br>n="]
    A --> |"Secondary codes*"| I["Secondary: <br>n="]
    A --> |"Malnutrition-<br>related codes*"| J["Malnutrition-<br>related: <br>n="]
    A --> |"Other including mix <br>of diabetes types and/<br>or codes for 'other <br>specific diabetes'"| K["Coding errors <br>or type changes<br> over time: <br>n="]
```

\* Could also have diabetes codes of unspecified type.

&nbsp;

This script also looks at how many diabetes codes, high HbA1cs and scripts for glucose-lowering medication occur have dates before the patient's birth (and so need to be cleaned). 





