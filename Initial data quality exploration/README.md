# Initial data quality exploration

## Introduction

The scripts in this directory use a cohort of adults with diabetes registered in primary care on 01/02/2020 to explore data quality issues, particularly around diabetes type coding and diagnosis dates, and determine rules to identify those with poor quality data. The below diagram shows the contruction of this cohort:

```mermaid
graph TD;
    A["<b>CPRD Aurum October 2020 release</b> with linked Set 21 <br> (April 2021) HES APC, patient IMD, and ONS death data"] --> |"Unique patients with a diabetes-related medcode between 01/01/2004-06/11/2020 and >=1 year data prior and after"| B["<b>Our extract</b>: n=1,480,985*"]
    B -->|"Patients with a diabetes-specific code** with >=1 year data prior and after"|C["n=1,314,373"]
    C -->|"Patients registered on 01/02/2020 (all have diabetes code and therefore diabetes diagnosis <br> before this date due to the requirement to have 1 year of data after)"|D["n=779,498"]
    D -->|"Patients who are aged>=18 years at the index date (01/02/2020)"|E["<b>DePICtion cohort</b>: n=769,493"]
```

\* Extract (see upper level of repository for full details) actually contained n=1,481,294 unique patients (1,481,884 in total but some duplicates) but included n=309 with registration start dates in 2020 (which did not fulfil the extract criteria of having a diabetes-related medcode between 01/01/2004-06/11/2020 and >=1 year of data after this; some of these were also not 'acceptable' by [CPRD's definition](https://cprd.com/sites/default/files/2023-02/CPRD%20Aurum%20Glossary%20Terms%20v2.pdf)). NB: removing those with registration start date in 2020 also removed all of those with a 'patienttypeid' not equal to 3 ('regular'). See next section for further details on the extract.

\** The list of diabetes-related medcode used for the extract (see below) included some which were not specific to diabetes e.g. 'insulin resistance' and 'seen in diabetes clinic***'. The list of 'diabetes-specific codes' used to define the cohort here can be found in our [CPRD-Codelists respository](https://github.com/Exeter-Diabetes/CPRD-Codelists/blob/main/Diabetes/exeter_medcodelist_all_diabetes.txt).

\***  We determined the code 'Seen in diabetes clinic' (medcode 285223014) to be unspecific to diabetes after observing a large number of patients (>100,000) in our extract with this code and no further evidence of diabetes such as other codes for diabetes, high HbA1c test results, or prescriptions for glucose-lowering medications.

&nbsp;

## Scripts

See upper level of this repository for notes on the aurum package and codelists used in these scripts.

&nbsp;

### 01_dpctn_cohort
Defines the cohort as per the flowchart above, and adds in patient characteristics (e.g. sex, ethnicity, age at index date) as well as biomarkers values at/prior to index date (BMI, HDL, triglycerides, total cholesterol, HbA1c, GAD/IA2 antibodies, and C-peptide) and family history of diabetes.

&nbsp;

### 02_dpctn_diabetes_type_all_time
Uses diabetes type codes to define diabetes type as per the below flowchart:

```mermaid
graph TD;
    A["<b>DePICtion cohort</b>: n=769,493"] --> |"Unspecific codes <br>only"| B["Unspecified: <br>n=114,955 <br>(14.9%)"]
    A --> |"T1D codes*"| C["Type 1: <br>n=31,922 <br>(4.1%)"]
    A --> |"T2D codes*"| D["Type 2: <br>n=576,418 <br>(74.9%)"]
    A --> |"Gestational codes*"| E["Gestational <br>only: <br>n=15,070 <br>(2.0%)"]
    A --> |"MODY codes*"| G["MODY: <br>n=61 <br>(0.0%)"]
    A --> |"Non-MODY <br>genetic/<br>syndromic <br>codes*"| H["Non-MODY <br>genetic/<br>syndromic: <br>n=108 <br>(0.0%)"]
    A --> |"Secondary codes*"| I["Secondary: <br>n=584 <br>(0.1%)"]
    A --> |"Malnutrition-<br>related codes*"| J["Malnutrition-<br>related: <br>n=1 <br>(0.0%)"]
    A --> |"Other including mix <br>of diabetes types and/<br>or codes for 'other <br>specific diabetes'"| K["Coding errors <br>or type changes<br> over time: <br>n=30,374 <br>(3.9%)"]
```

\* Could also have diabetes codes of unspecified type. For gestational diabetes only: earliest and latest codes for unspecified diabetes must be no more than a year prior to earliest gestational diabetes code (excluding 'history of gestational diabetes' codes) and no more than a year after latest gestational diabetes code (excluding 'history of gestational diabetes' codes).

\** All gestational diabetes codes (excluding 'history of gestational diabetes' codes) must be earlier than the earliest Type 2 diabetes code.

&nbsp;

This script also looks at how many diabetes codes, high HbA1cs and scripts for glucose-lowering medication have dates before the patient's birth (and so need to be cleaned). For all code categories, and all high HbA1cs and OHA/insulin scripts, >99.9% were on/after the patient's DOB (and only ~0.3% of cohort (1,994/769,493) are affected). The small proportion of codes/high HbA1c/scripts before DOB were excluded from downstream analysis.

&nbsp;

### 03_dpctn_diabetes_qof_primis_codelist
Looks at effect of restricting the cohort to those with a diabetes QOF code / medcode which maps to SNOMED code in pre-existing PRIMIS diabetes codelist (https://www.opencodelists.org/codelist/primis-covid19-vacc-uptake/diab/v.1.5.3/).

&nbsp;

Diabetes QOF codes: the QOF codelist was constructed from Read codes from version 38 and SNOMED codes from version 44 of the QOF, which include all codes from previous versions. Have only included medcodes which map to Read codes from version 38 and SNOMED codes from version 44 - i.e. haven't mapped between SNOMED and Read codes. Includes some codes for non-Type 1/Type 2 types of diabetes, but not gestational (or malnutrition). Not sure about QOF usage 2020 onwards (doesn't affect this dataset).

Number in each class with QOF code:
* Unspecified: 3,652/114,955 (3.2%)
* Type 1: 31,832/31,922 (99.7%)
* Type 2: 574,340/576,418 (99.6%)
* Gestational only: 167/15,070 (1.1%)
* MODY: 61/61 (100.0%)
* Non-MODY genetic/syndromic: 87/108 (80.6%)
* Secondary: 142/584 (24.3%)
* Malnutrition: 1/1 (100.0%)
* Other: 30,289/30,374 (99.7%)

Median time between most recent QOF code and index date:
* Unspecified: 551 days
* Type 1: 319 days
* Type 2: 295 days
* Gestational only: 911 days
* MODY: 666 days
* Non-MODY genetic/syndromic: 493 days
* Secondary: 513 days
* Malnutrition: 458 days
* Other: 262 days

&nbsp;

PRIMIS diabetes codelist: contains 545 SNOMED codes; 187 are in 05/2020 CPRD Medical Dictionary and match to 753 medcodes (NB: numbers are much higher (458 SNOMED codes matching to 1,415 medcodes) if use more recent medical dictionary BUT none of the new codes are in our download).

Our diabetes codelist (including all types of diabetes) is 1,361 medcodes. 711 of PRIMIS medcodes are in this list, but PRIMIS contains extra 42 medcodes - most are infrequently used ^ESCT codes but these aren't:
| | CPRD Term description |  Original Read code |
| ---- | ---- | ---- |
| 1 | O/E - right eye clinically significant macular oedema | 2BBm |
| 2 | O/E - left eye clinically significant macular oedema | 2BBn |
| 3 | Loss of hypoglycaemic warning | 66AJ2 |
| 4 | Hypoglycaemic warning absent | 66AJ4 |
| 5 | Insulin autoimmune syndrome | C10J |
| 6 | Insulin autoimmune syndrome without complication | C10J0 |
| 7 | Achard - Thiers syndrome | C152-1 |
| 8 | Leprechaunism | C1zy3 |
| 9 | Donohue's syndrome | C1zy3-1 |
| 10 | Mauriac's syndrome | EMISNQMA111 |
| 11 | Ballinger-Wallace syndrome | ESCTDI21-1 |
| 12 | HHS - Hyperosmolar hyperglycaemic syndrome | ESCTDI23-1 |
| 13 | HHS - Hyperosmolar hyperglycemic syndrome | ESCTDI23-2 |
| 14 | Rogers syndrome | ESCTME15-1 |
| 15 | Herrmann syndrome | ESCTPH1-1 |
| 16 | Kimmelstiel - Wilson disease | K01x1-1 |

In PRIMIS codelist, some the term descriptions for these codes contain 'diabetes mellitus' but don't in the CPRD Medical Dictionary. We can't really investigate whether these codes would pick up more people than our codelist as our extract relied on our codelist (although could look in full download).

Number in each category with any of the 753 PRIMIS medcodes:
* Unspecified: 9,592/114,955 (8.3%)
* Type 1: 31,913/31,922 (100.0%)
* Type 2: 575,677/576,418 (99.9%)
* Gestational only: 393/15,070 (2.6%)
* MODY: 61/61 (100.0%)
* Non-MODY genetic/syndromic: 87/108 (80.6%)
* Secondary: 584/584 (100.0%)
* Malnutrition: 1/1 (100.0%)
* Other: 30,357/30,374 (99.9%)

&nbsp;

The top diabetes medcodes (from our codelist of 1,361) most frequently used by those in the 'unspecified' group are as below:
* (13,964 (12.1%) have a high HbA1c measurement)
* 12,140 (10.6%) have 216201011 'Diabetic retinopathy screening'
* 11,592 (10.1%) have 616731000006114 **'Diabetes monitoring first letter'**
* 9,255 (8.1%) have 264676010 **'Diabetic monitoring'**
* 9,142 (8.0%) have 1488393013 'O/E - Right diabetic foot at low risk'
* 9,110 (7.9%) have 2533110014 **'Referral to diabetes structured education programme'**
* 9,108 (7.9%) have 1488397014 'O/E - Left diabetic foot at low risk'
* 8,005 (7.0%) have 200111000006116 **'Diabetes mellitus diet education'**
Next most popular are 'Diabetic annual review' and 'Seen in diabetic eye clinic' codes

If we look in the 91.7% (105,363) without a PRIMIS diabetes code, the top diabetes medcodes are:
* (9,359 (8.9%) have a high HbA1c measurement)
* 8,924 (8.5%) have 616731000006114 **'Diabetes monitoring first letter'**
* 8,192 (7.8%) have 216201011 'Diabetic retinopathy screening'
* 7,460 (7.1%) have 2533110014 **'Referral to diabetes structured education programme'**
* 7,428 (7.0%) have 200111000006116 **'Diabetes mellitus diet education'**
* 5,939 (5.6%) have 264676010 **'Diabetic monitoring'**
* 5,511 (5.2%) have 21631000000117 **'Diabetes monitoring administration'**
* 5,207 (4.9%) have 546471000000114 **'Diabetes structured education programme declined'**
* 5,122 (4.9%) have 616741000006116 **'Diabetes monitoring second letter'**
* 4,601 (4.4%) have 457231013 'Seen in diabetic eye clinic'

59,950/105,363 (56.9%) of those without a PRIMIS diabetes code have a single diabetes medcode only (and no high HbA1c measurements or OHA/insulin scripts). Their top medcodes are:
* 4,156 (6.9%) have 616731000006114 **'Diabetes monitoring first letter'**
* 4,151 (6.9%) have 216201011 'Diabetic retinopathy screening'
* 4,118 (6.9%) have 200111000006116 **'Diabetes mellitus diet education'**
* 3,926 (6.5%) have 2533110014 **'Referral to diabetes structured education programme'**
* 3,831 (6.4%) have 616741000006116 **'Diabetes monitoring second letter'**
* 3,235 (5.4%) have 546471000000114 **'Diabetes structured education programme declined'**
* 2,682 (4.5%) have 21631000000117 **'Diabetes monitoring administration'**
* 2,397 (4.0%) have 264676010 **'Diabetic monitoring'**
* 2,328 (3.9%) have 457231013 'Seen in diabetic eye clinic'
* 2,092 (3.5%) have 283027015 **'Diabetic leaflet given'**
* 1,906 (3.2%) have 1946701000006110 **'Provision of written information about diabetes and high haemoglobin A1c level'**

Bolded codes look like they may be used in those without diabetes.

&nbsp;


🔴 **Rule 1: For those with no diabetes type-specific codes, clinicians need to investigate what type of diabetes (if any) the patient has been diagnosed with. The number of people with this issue depends on the codelist used to identify those with diabetes; it seems likely that some codes which appear to be diabetes-specific are also used in those without diabetes.**

For downstream data processing we have separated those in the 'unspecified' group with and without a PRIMIS diabetes code.

&nbsp;

### 04_dpctn_diabetes_diagnosis_dates
Looks at potential quality issues around diagnosis dates (diabetes codes in year of birth) and determines diagnosis date for patients in the cohort (earliest of diabetes code, high HbA1c or script for glucose-lowering medication). Also looks at implications of using diabetes codes only to determine diagnosis dates.

Patients with diabetes type 'other' (as per flowchart above) were excluded (are later analysed in script 05_dpctn_diabetes_type_over_time) as they may have changes in their diagnosed type of diabetes over time. For the remaining cohort, diagnosis date is determined as the earliest diabetes code, high HbA1c or script for glucose-lowering medication. 

To investigate data quality issues, date of diagnosis by calendar year relative to year of birth was analysed:

<img src="https://github.com/Exeter-Diabetes/CPRD-Katie-DePICtion-Scripts/blob/main/Images/year_relative_to_birth.png?" width="1000">

Clearly there are data quality issues since we would not expect any patients with Type 2 diabetes to be diagnosed in their year of birth. Subsequent analysis ignored diabetes codes in the year of birth for those with Type 2 diabetes, using the next code/high HbA1c/prescription for glucose-lowering medication. This constitutes only 0.3% of those with Type 2 diabetes.

&nbsp;

🔴 **Rule 2: Clinicians should check diabetes diagnoses before or in the year of birth, especially for those with Type 2 diabetes, although this is expected to affect <1% of the cohort. Diagnoses which are incorrectly coded as being in/before the year of birth will reduce the age of diagnosis compared to the true value, and therefore increase the probability of having MODY in the MODY calculator, or of having Type 1 diabetes rather than Type 2 diabetes in the T1DT2D calculator.  For the MODY calculator clinicians can therefore just focus on individuals who are diagnosed with Type 1 or Type 2 diabetes and have been flagged as being high MODY risk for this rule. For the T1DT2D calculator it may be worth checking both those with Type 2 who have been flagged as having high Type 1 diabetes risk, and all those with Type 1 and apparent diagnoses in the year of birth.**

For downstream data processing we have ignore diabetes diagnosis codes in the year of birth for those in the Type 2 group.

&nbsp;

Also to investigate data quality issues, date of diagnosis by calendar year relative to year of registration start was analysed:

<img src="https://github.com/Exeter-Diabetes/CPRD-Katie-DePICtion-Scripts/blob/main/Images/year_relative_to_reg_start.png?" width="1000">

To look at this in further detail, we then looked at diagnosis by week relative to registration start:

<img src="https://github.com/Exeter-Diabetes/CPRD-Katie-DePICtion-Scripts/blob/main/Images/week_relative_to_reg_start.png?" width="1000">

And looked at the time between diagnosis and first treatment (earliest OHA/insulin script) by week of diagnosis relative to registration start:

<img src="https://github.com/Exeter-Diabetes/CPRD-Katie-DePICtion-Scripts/blob/main/Images/time_to_treatment.png?" width="1000">

Again, clearly there are data quality issues with more patients than expected being diagnosed close to when they register with their primary care practice (primarily after but some shortly before). This probably reflects old diagnoses (prior to registration) being recorded as if they were new, and hence the shorter time to first treatment for those diagnosed closer to registration. In previous work ([https://bmjopen.bmj.com/content/7/10/e017989](https://bmjopen.bmj.com/content/7/10/e017989)) we removed diagnoses within 3 months (<91 days) of registration start, but using the above plot we have decided to extend this window to -1 to +3 months.

&nbsp;

🔴 **Rule 3: Clinicians should check diabetes diagnosis dates which are -30 to +90 days (-1 to +3 months) relative to registration start (expected to affect ~4% of cohort). Those with diagnosis dates incorrectly coded as being close to registration when the true date was actually earlier will have a reduced risk of MODY in the MODY calculator and a reduced risk of T1 in the T1DT2D calculator. For the MODY calculator it is important to check individuals with diagnosis dates close to registration as otherwise high risk individuals may be missed. For the T1DT2D calculator it may be worth checking both those with Type 1 who have been flagged as having high Type 2 diabetes risk, and all those with Type 2 and apparent diagnoses close to registration.**

For downstream data processing we have removed those with diagnosis dates between -1 to +3 months relative to registration start.

&nbsp;

The table below shows which out of a diagnosis code, high HbA1c, or prescription for glucose-lowering medication occurred earliest for patients and was therefore used as the date of diagnosis (after codes in the year of birth were removed for those with Type 2 diabetes). 'Missing' indicates patients with a diagnosis within -1 to +3 months of registration start. If patients had >1 of a diabetes code, high HbA1c and/or prescription for OHA/insulin on their date of diagnosis, only the highest ranking of these is shown in the table (rank order: diabetes code > high HbA1c > precription for OHA > prescription for insulin). Note that all HbA1cs prior to 1990 were exclude due to data quality concerns as HbA1c wasn't widely used at this time.

| Diabetes type (as per flowchart above) | Diabetes code for unspecified type | Diabetes code for specific type | Unspecified and/or type-specific diabetes code | High HbA1c | OHA prescription | Insulin prescription | Missing |
| ---- | ---- | ---- | ---- | ---- | ---- | ---- | ---- |
| Any type* (n=739119) | 274125 (37.1%) | 210504 (28.5%) | 484629 (65.6%) | 226638 (30.7%) | 17069 (2.3%) | 1836 (0.2%) | 8947 (1.2%) |
| Unspecified with no PRIMIS code (n=105363) | 98539 (93.5%) | 0 (0.0%) | 98539 (93.5%) | 5041 (4.8%) | 1346 (1.3%) | 65 (0.1%) | 372 (0.4%) |
| Unspecified with PRIMIS code (n=9592) | 6615 (69.0%) | 0 (0.0%) | 6615 (69.0%) | 2418 (25.2%) | 359 (3.7%) | 59 (0.6%) | 141 (1.5%) |
| Type 1 (n=31922) | 11731 (36.7%) | 17202 (53.9%) | 28933 (90.6%) | 1630 (5.1%) | 204 (0.6%) | 858 (2.7%) | 297 (0.9%) |
| Type 2 (n=576418) | 149328 (25.9%) | 186835 (32.4%) | 336163 (58.3%) | 217252 (37.7%) | 14268 (2.5%) | 730 (0.1%) | 8005 (1.4%) |
| Gestational only (n=15070) | 7751 (51.4%) | 6164 (40.9%) | 13915 (92.3%) | 71 (0.5%) | 856 (5.7%) | 100 (0.7%) | 128 (0.8%) |
| MODY (n=61) | 14 (23.0%) | 28 (45.9%) | 42 (68.9%) | 14 (23.0%) | 2 (3.3%) | 1 (1.6%) | 2 (3.3%) |
| Non-MODY genetic/syndromic (n=108) | 35 (32.4%) | 54 (50.0%) | 89 (82.4%) | 7 (6.5%) | 5 (4.6%) | 7 (6.5%) | 0 (0.0%) |
| Secondary (n=584) | 111 (19.0%) | 221 (37.8%) | 332 (56.8%) | 205 (35.1%) | 29 (5.0%) | 16 (2.7%) | 2 (0.3%) |
| Malnutrition (n=1) | 1 (100.0%) | 0 (0.0%) | 1 (100.0%) | 0 (0.0%) | 0 (0.0%) | 0 (0.0%) | 0 (0.0%) |

\* Excluding 'other'

&nbsp;

The table below shows what the impact would be of using diabetes code (unspecified type and type-specific) alone to determine diagnosis dates (i.e. not also using high HbA1c and prescriptions for glucose-lowering medication).

| Diabetes type (as per flowchart above) | Median difference in diagnosis date if only diabetes codes used (days) | Median difference in diagnosis date if only diabetes codes used (days) in patients with a high HbA1c/prescription for glucose-lowering medication earlier than a diabetes code |
| ---- | ---- | ---- |
| Any type* (n=727396 with non-missing diagnosis date) | 0 | 25 |
| Unspecified with no PRIMIS code (n=104963 with non-missing diagnosis date) | 0 | 301 |
| Unspecified with PRIMIS code (n=9396 with non-missing diagnosis date) | 0 | 33 |
| Type 1 (n=31568 with non-missing diagnosis date) | 0 | 7 |
| Type 2 (n=565781 with non-missing diagnosis date)| 0 | 24 |
| Gestational only (n=14940 with non-missing diagnosis date) | 0 | 577 |
| MODY (n=59 with non-missing diagnosis date) | 0 | 204 |
| Non-MODY genetic/syndromic (n=107 with non-missing diagnosis date) | 0 | 422 |
| Secondary (n=581 with non-missing diagnosis date) | 0 | 32 |
| Malnutrition (n=1 with non-missing diagnosis date) | 0 | NA |

&nbsp;

🔴 **Rule 4: Diabetes codes alone can be used to determine diagnosis dates, as including high HbA1cs and OHA/insulin scripts in the diagnosis date definition makes little difference.**

For downstream data processing we have used diagnosis dates as determined by diabetes codes alone.

&nbsp;

### 05_dpctn_diabetes_type_over_time
Looks at patients with codes for >1 type of diabetes (n=30,401; classified as 'other' as per above flowchart) to determine diagnosis dates and when changes in diagnosis occurred.

These are the most popular combinations of diabetes type codes in this group:
* 18,695 (61.6%) Type 1 and Type 2
* 8,695 (28.6%) Type 2 and gestational
* 1,324 (4.4%) Type 2 and secondary
* 352 (1.2%) Type 1 and gestational
* 342 (1.1%) Type 1, Type 2 and gestational
Together these account for 96.8% of those with codes for >1 type of diabetes; all remaining combinations are <1% each.

&nbsp;

For the mixed Type 1/Type 2 group, our gold-standard classification algorithm is to classify those with a prescription for insulin (ever) and at least twice as many Type 1 codes as Type 2 codes as Type 1, and everyone else as Type 2. If we use the most recent type-specific code for classification instead:
* 14,407 (77.1%) are classified 'correctly' i.e. as per the gold-standard algorithm
    * Of those misclassified: 71% are Type 1 by latest code, and 29% are Type 2 by latest code. Median time to previous code of the other type = 
* If we use latest code + current insulin treatment (insulin script within the last 6 months; i.e. classify as Type 2 if not currently insulin treated), 14,789 (79.1%) are classified correctly
    * Of those misclassified: 63% are Type 1 by latest code, and 37% are Type 2 by latest code
* If we use latest code + insulin treatment ever (i.e. classify as Type 2 if never insulin treated), 14,851 (79.4%) are classified correctly
    * Of those misclassified: 67% are Type 1 by latest code, and 33% are Type 2 by latest code

For those missclassified by using the most recent code, the median time from the index date back to the most recent code of the correct type was 3-3.5 years.

&nbsp;

🔴 **Rule 5: Use the most recent diabetes code to assign type, but check those with codes of both types within the last 5 years**

We have implemented this rule but kept patients separate to those with only Type 1 or only Type 2 codes for further analysis downstream.

&nbsp;

For the other mixed groups: we have assigned diabetes type using the latest code, ignoring gestational codes. Diabetes diagnosis date has been set as the earliest diabetes code, which may underestimate the age of diagnosis, especially for those with gestational diabetes who then develop Type 2 diabetes. Underetsimates of the age of diagnosis will lead to patients having a higher predicted risk of MODY and of Type 1 in the MODy and T1DT2D calculators, so we will look at the effect of this downstream.

&nbsp;

### 06_dpctn_diabetes_type_issues

Go back to only including those diagnosed <50


Looks at potential miscoding/misclassification of diabetes/diabetes type, including:
* Those coded as Type 1:
    * With no prescriptions for insulin (could look further at type of insulin e.g. must have basal and bolus; for NDA they exclude from Type 1 if long-acting insulin only)
    * With insulin but also taking an OHA other than metformin/SGLT2-inhibitor (as per NDA)
    * With more than 3 years between diagnosis and initiating insulin treatment
* Those coded as Type 2:
    * With less than 6 months between diagnosis and initiating insulin treatment
    * With no OHA prescriptions prior to insulin initiation
    * With no OHA/insulin prescriptions or high HbA1c measurements
* Those coded as gestational only:
    * With unspecified diabetes codes >1 prior to earliest / >1 year after latest gestational diabetes code (excluding history of gestational diabetes), implying possible Type 1/2 diabetes
(All to do + can compare frequencies to de Luisignan paper)

&nbsp;

### 07_dpctn_mody_calculator
Defines MODY calculator cohort: those with current diagnosis of Type 1, Type 2, or unspecified diabetes, diagnosed aged 1-35 years inclusive.

**Not done yet: exploring whether separate weight/height measurements could help with missing BMI**

&nbsp;

Cohort characteristics:
| Characteristic |  Class: Type 1 |  Class: Type 2 | Class: Unspecified | Class: Type 1/Type 2 | Class: Type 2/gestational |
| ---- | ---- | ---- | ---- | ---- | ---- |
| N | 24946 | 26379 | 12646 |||
| Median (IQR) age at diagnosis (years) | 16.2 (13.8) | 30.9 (6.2) | 27.0 (10.7) |||
| Median (IQR) current age (years) | 39.6 (23.0) | 42.9 (14.0) | 32.6 (10.9) |||
| Median (IQR) BMI within 2 years (kg/m2) | 26.2 (6.7) | 32.0 (10.1) | 28.5 (10.6) |||
| Missing BMI within 2 years | 4256 (17.06%) | 2920 (11.07%) | 7303 (57.75%) |||
| Median (IQR) time from BMI within 2 years to index date (days) | 184.0 (258.0) | 164.0 (231.0) | 242.0 (322.0) |||
| Median (IQR) BMI any time >=diagnosis (kg/m2) | 26.0 (6.6) | 32.0 (10.0) | 28.0 (10.3) |||
| Missing BMI >=diagnosis | 441 (1.77%) | 391 (1.48%) | 5215 (41.24%) |||
| Median (IQR) time from BMI any time >=diagnosis to index date (days) | 232.0 (398.0) | 187.0 (287.0) | 380.0 (795.0) |||
| Median (IQR) HbA1c within 2 years (mmol/mol) | 66.0 (21.1) | 61.9 (29.0) | 37.0 (8.0) |||
| Missing (IQR) HbA1c within 2 years | 1756 (7.04%) | 1434 (5.44%) | 8083 (63.92%) |||
| Median time from HbA1c within 2 years to index date (days) | 151.0 (212.0) | 131.0 (176.0) | 263.0 (314.0) |||
| Median (IQR)  HbA1c any time >=diagnosis (mmol/mol) | 67.0 (22.0) | 61.9 (29.1) | 36.0 (6.8) |||
| Missing HbA1c >=diagnosis | 180 (0.72%) | 115 (0.44%) | 6961 (55.05%) |||
| Median (IQR) time from HbA1c any time >=diagnosis to index date (days) | 165.0 (250.0) | 141.0 (207.0) | 353.0 (606.0) |||
| With negative family history of diabetes | 2024 (8.11%) | 1933 (7.33%) | 1074 (8.49%) |||
| With positive family history of diabetes | 5845 (23.43%) | 11765 (44.60%) | 2492 (19.71%) |||
| Missing family history of diabetes | 17077 (68.46%) | 12681 (48.07%) | 9080 (71.80%) |||
| Not on insulin <= 6 months after diagnosis | 2220 (8.90%) | 20382 (77.27%) | 12349 (97.65%) |||
| On insulin <= 6 months after diagnosis | 5879 (23.57%) | 736 (2.79%) | 158 (1.25%) |||
| Missing whether on insulin <= 6 months after diagnosis | 16847 (67.53%) | 5261 (19.94%) | 139 (1.10%) |||
| On OHA or ins (script in last 6 months) | 24021 (96.29%) | 22040 (83.55%) | 529 (4.18%) ||| 
| Missing any variable required for MODY calculator if use BMI and HbA1c back to diagnosis | 23266 (93.27%) | 15779 (59.81%) | 10913 (86.30%)|||

&nbsp;

Characteristics of those with no missing MODY calculator variables:
| Characteristic | Class: Unspecified |  Class: Type 1 |  Class: Type 2 | Class: Type 1/Type 2 | Class: Type 2/gestational |
| ---- | ---- | ---- | ---- | ---- | ---- |
| N | 1680 | 10600 | 1733
| Median age at diagnosis | 23.1 (15.3) | 31.3 (5.7) | 30.1 (7.4) |||
| Median (IQR) current age (years | 36.6 (19.0) | 41.6 (11.0) | 36.6 (9.0) |||
| Median BMI any time >=diagnosis | 26.2 (6.8) | 31.9 (9.9) | 30.2 (10.8) |||
| Median HbA1c any time >=diagnosis | 69.0 (25.0) | 59.0 (27.5) | 37.7 (8.0) |||
| With negative family history of diabetes | 493 (29.35%) | 1566 (14.77%) | 456 (26.31%) |||
| With positive family history of diabetes | 1187 (70.65%) | 9034 (85.23%) | 1277 (73.69%) |||
| Not on insulin <= 6 months after diagnosis | 550 (32.74%) | 10291 (97.08%) | 1696 (97.86%) |||
| On insulin <= 6 months after diagnosis | 1130 (67.26%) | 309 (2.92%) | 37 (2.14%) |||
| On OHA or ins (script in last 6 months) | 1613 (96.01%) | 8651 (81.61%) | 137 (7.91%) |||

&nbsp;

Adjusted MODY probabilities for complete cases:

<img src="https://github.com/Exeter-Diabetes/CPRD-Katie-DePICtion-Scripts/blob/main/Images/mody_calc_adjusted.png?" width="1000">

&nbsp;

### 08_dpctn_t1dt2d_calculator
Defines T1DT2D calculator cohort: those with current diagnosis of Type 1, Type 2, or unspecified diabetes, diagnosed aged 18-50 years inclusive.

**Not done yet: exploring whether separate weight/height measurements could help with missing BMI**

&nbsp;

Cohort characteristics:
| Characteristic |  Class: Type 1 |  Class: Type 2 | Class: Unspecified | Class: Type 1/Type 2 | Class: Type 2/gestational |
| ---- | ---- | ---- | ---- | ---- | ---- |
| N | 14887 | 167485 | 32609 |||
| Median (IQR) age at diagnosis (years) | 28.5 (12.8) | 43.5 (8.7) | 40.3 (13.4) |||
| Median (IQR) current age (years | 49.6 (20.7) | 53.8 (12.0) | 45.6 (13.0) |||
| Median (IQR) BMI within 2 years (kg/m2) | 26.5 (6.5) | 31.2 (8.7) | 29.7 (9.4) |||
| Missing BMI within 2 years | 2242 (15.06%) | 14944 (8.92%) | 15710 (48.18%) |||
| Median (IQR) time from BMI within 2 years to index date (days) | 178.0 (249.0) | 158.0 (222.0) | 242.0 (316.0) |||
| Median (IQR) BMI any time >=diagnosis (kg/m2) | 26.4 (6.5) | 31.2 (8.8) | 29.1 (9.1) |||
| Missing BMI >=diagnosis | 273 (1.83%) | 1970 (1.18%) | 10263 (31.47%) |||
| Median (IQR) time from BMI any time >=diagnosis to index date (days) | 215.0 (355.0) | 178.0 (262.0) | 358.0 (715.0) |||
| Median (IQR) total cholesterol within 2 years (mmol/L) | 4.4 (1.3) | 4.2 (1.4) | 4.9 (1.3) |||
| Missing total cholesterol within 2 years | 1284 (8.62%) | 7150 (4.27%) | 16455 (50.46%) |||
| Median (IQR) time from total cholesterol within 2 years to index date (days) | 182.0 (231.0) | 165.0 (194.0) | 256.0 (305.0) |||
| Median (IQR) total cholesterol any time >=diagnosis (mmol/L) | 4.4 (1.3) | 4.2 (1.5) | 4.9 (1.4) |||
| Missing total cholesterol >=diagnosis | 229 (1.54%) | 967 (0.58%) | 12848 (39.40%) |||
| Median (IQR) time from total cholesterol any time >=diagnosis to index date (days) | 199.0 (262.0) | 172.0 (207.0) | 340.0 (623.0) |||
| Median (IQR) HDL within 2 years (mmol/L) | 1.5 (0.6) | 1.1 (0.4) | 1.3 (0.4) |||
| Missing HDL within 2 years | 2054 (13.80%) | 11539 (6.89%) | 16919 (51.88%) |||
| Median (IQR) time from HDL within 2 years to index date (days) | 190.0 (244.0) | 171.0 (198.0) | 260.0 (304.0) |||
| Median (IQR) HDL any time >=diagnosis (mmol/L)| 1.5 (0.6) | 1.1 (0.4) | 1.3 (0.5) |||
| Missing HDL >=diagnosis | 423 (2.84%) | 1880 (1.12%) | 13313(40.83%) |||
| Median (IQR) time from HDL any time >=diagnosis to index date (days) | 219.0 (313.0) | 183.0 (225.0) | 346.0 (637.2 |||
| Median (IQR) triglyceride within 2 years (mmol/L) | 1.1 (0.8) | 1.7 (1.3) | 1.4 (1.1) |||
| Missing triglyceride within 2 years | 5462 (36.69%) | 48337 (28.86%) | 20386 (62.52%) |||
| Median (IQR) time from triglyceride within 2 years to index date (days) | 208.0 (263.0) | 190.0 (227.0) | 270.0 (311.5) |||
| Median (IQR) triglyceride any time >=diagnosis (mmol/L) | 1.1 (0.8) | 1.7 (1.3) | 1.4 (1.1) |||
| Missing triglyceride >=diagnosis | 1531 (10.28%) | 11115 (6.64%) | 16128 (49.46%) |||
| Median (IQR) time from triglyceride any time >=diagnosis to index date (days) | 337.0 (802.0) | 261.0 (570.0) | 416.0 (839.0) |||
| Missing any variable required for MODY calculator if use biomarkers back to diagnosis | 1693 (11.37%) | 12588 (7.52%) | 18342 (56.25%) |||

&nbsp;

Number with measured GAD and/or IA2 antibodies is very small:
* GAD: 127 (0.9%) of Type 1, 431 (0.03%) of Type 2, 35 (0.1%) of unspecified
* IA2: 4 (0.03%) of Type 1, 9 (0.005%) of Type 2, 0 (0.0%) of unspecified

&nbsp;

T1D probability using age and BMI only:

<img src="https://github.com/Exeter-Diabetes/CPRD-Katie-DePICtion-Scripts/blob/main/Images/t1dt2d_age_bmi.png?" width="1000">


&nbsp;

T1D probability using age, BMI and lipids:

<img src="https://github.com/Exeter-Diabetes/CPRD-Katie-DePICtion-Scripts/blob/main/Images/t1dt2d_lipids.png?" width="1000">

&nbsp;

### Other bits discussed and not implemented:
* Working out whether patients (especially those with Type 1) are being treated in secondary care (and that's why we have missing info)
* Further work on those without any type-specific codes to remove those without diabetes
* Integrating other features which might aid classification:
    * At diagnosis:
        * Polydipsia
        * Ketones
        * Glucose
        * Capillary glucose
        * Weight loss
        * DKA
    * And longitudinally:
        * C-peptide
        * Islet Abs
        * Autoimmune tests e.g. thyroid function, TTG (coeliac) - Lancet paper
        * Type changing over time
        * Referral to endo?
* Later: outcomes affected by misclassification including infection
* Checking small % with remission codes - compare to 2x papers and possibly UKBB
