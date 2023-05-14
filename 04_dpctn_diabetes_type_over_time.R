
# Look at those with changes in diabetes type over time and/or 'other unspecified diabetes'

# Calculate diagnosis dates

# Add diagnosis dates and time to insulin for all to main cohort table

############################################################################################

# Setup
library(tidyverse)
library(aurum)
library(EHRBiomarkr)
rm(list=ls())

cprd = CPRDData$new(cprdEnv = "test-remote",cprdConf = "~/.aurum.yaml")

analysis = cprd$analysis("dpctn")


############################################################################################

# Gestational then Type 2
## A lot of these people don't have clear cut diagnosis of gestational then Type 2 - will pool with others


# Define Type 2 diabetes diagnosis date:
## earliest code/HbA1c/script for glucose-lowering medication >1 year after latest gestational code excluding gestational history codes

cohort_classification <- cohort_classification %>% analysis$cached("cohort_classification")

gest_type_2 <- cohort_classification %>%
  filter(class=="gestational then type 2") %>%
  


  
  
  
  
  
  