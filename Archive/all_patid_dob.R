
# Calculate DOB as 15th of month of birth (where month of birth and year of birth available), and 1st July where only year of birth available, or earliest medcode in Observation table if this is earlier (excluding medcodes before mob/yob) as per https://github.com/Exeter-Diabetes/CPRD-Codelists#general-notes-on-implementation

# Uses validDateLookup which has 'min_dob' column - earliest possible patient DOB from MOB/YOB provided by CPRD


############################################################################################

# Setup
library(tidyverse)
library(aurum)
rm(list=ls())

cprd = CPRDData$new(cprdEnv = "test-remote",cprdConf = "~/.aurum.yaml")
codesets = cprd$codesets()
codes = codesets$getAllCodeSetVersion(v = "31/10/2021")

analysis = cprd$analysis("diagnosis_date")


############################################################################################

# Find earliest medcode which is nt before 'minimum DOB' (earliest possible DOB from patient's MOB and YOB)

dob <- cprd$tables$observation %>%
  inner_join(cprd$tables$validDateLookup, by="patid") %>%
  filter(obsdate>=min_dob) %>%
  group_by(patid) %>%
  summarise(earliest_medcode=min(obsdate, na.rm=TRUE)) %>%
  analysis$cached("earliest_medcode", unique_indexes="patid")

### Check count
dob %>% count()
### 1,481,294 - has everyone

### No-one has missing dob or earliest_medcode so pmin (runs as 'LEAST' in MySQL) works
dob <- dob %>%
  inner_join(cprd$tables$patient, by="patid") %>%
  mutate(dob=as.Date(ifelse(is.na(mob), paste0(yob,"-07-01"), paste0(yob, "-",mob,"-15")))) %>%
  mutate(dob=pmin(dob, earliest_medcode, na.rm=TRUE)) %>%
  select(patid, dob, mob, yob, regstartdate) %>%
  analysis$cached("dob", unique_indexes="patid")
