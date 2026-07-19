# Clinical Trial Programming Portfolio (SAS | CDISC SDTM | ADaM | TLF)

## Overview

This repository demonstrates an end-to-end clinical programming workflow following CDISC standards using SAS. The project showcases the complete lifecycle of clinical trial data, beginning with the creation and validation of SDTM datasets, followed by derivation of ADaM analysis datasets, and culminating in the generation of Tables, Listings, and Figures (TLFs) used for statistical reporting.

The purpose of this project is to demonstrate practical experience in clinical data programming, regulatory reporting, and SAS programming techniques commonly used in the pharmaceutical, biotechnology, and CRO industries.

> **Disclaimer:** This repository is intended solely for educational and portfolio purposes. All datasets used are simulated or training datasets and do not contain confidential clinical trial information, Protected Health Information (PHI), or Personally Identifiable Information (PII).

---

# Clinical Data Workflow

```text
Raw Clinical Data
        │
        ▼
SDTM Dataset Creation
        │
        ▼
SDTM Validation
        │
        ▼
ADaM Dataset Creation
        │
        ▼
ADaM Validation
        │
        ▼
Tables, Listings & Figures (TLFs)
        │
        ▼
Clinical Study Outputs
```

---

# Repository Structure

```text
Clinical-Trial-Programming-Portfolio/
│
├── SDTM/
│   ├── DM.sas
│   ├── EX.sas
│   ├── MH.sas
│   ├── DS.sas
│   ├── VS.sas
│
├── ADaM/
│   ├── ADSL.sas
│   ├── ADAE.sas
│   ├── ADLBSI.sas
│   ├── ADTTE.sas
│   ├── ADEX.sas
│
├── TLF/
│   ├── Demographic_Table.sas
│   ├── Adverse_Event_Table.sas
│   ├── Kaplan_Meier_Curve.sas
│   ├── Forest_Plot.sas
│   ├── ORR_Table.sas
│   ├── ORR_Bar_Chart.sas
│
├── Validation/
├── Logs/
└── README.md
```

---

# SDTM Domains

The following Study Data Tabulation Model (SDTM) domains were developed according to CDISC standards.

| Domain | Description |
|---------|-------------|
| DM | Demographics |
| EX | Exposure |
| MH | Medical History |
| DS | Disposition |
| VS | Vital Signs |

### SDTM Programming Highlights

- CDISC-compliant dataset structure
- Variable derivation
- Controlled terminology implementation
- ISO 8601 date conversion
- Subject-level dataset creation
- Sequence variable generation
- Dataset merging
- Sorting and validation
- Metadata-driven programming

---

# ADaM Datasets

The following Analysis Data Model (ADaM) datasets were created from SDTM domains.

| Dataset | Description |
|----------|-------------|
| ADSL | Subject-Level Analysis Dataset |
| ADAE | Adverse Events Analysis Dataset |
| ADLBSI | Laboratory Analysis Dataset |
| ADTTE | Time-to-Event Analysis Dataset |
| ADEX | Exposure Analysis Dataset |

### ADaM Programming Highlights

- Analysis population flags
- Treatment variable derivation
- Baseline flag creation
- Relative study day calculations
- Time-to-event derivations
- Analysis-ready variables
- SDTM-to-ADaM traceability

---

# Tables, Listings & Figures (TLFs)

This project includes the development of commonly used clinical trial outputs.

## Tables

- Demographic Summary
- Adverse Events by System Organ Class and Preferred Term
- Overall Response Rate (ORR)
- Progression-Free Survival Summary

## Figures

- Kaplan–Meier Survival Curve
- Hazard Ratio Forest Plot
- ORR Bar Chart

---

# Validation

Independent validation was performed to ensure programming accuracy and reproducibility.

Validation activities included:

- PROC COMPARE
- Dataset structure comparison
- Variable attribute verification
- Record count verification
- Log review
- Output comparison
- Metadata validation

---

# SAS Procedures Used

## Data Management

- DATA Step
- PROC SORT
- PROC SQL
- PROC COPY
- PROC TRANSPOSE
- PROC DATASETS
- PROC FORMAT

## Statistical Analysis

- PROC FREQ
- PROC MEANS
- PROC REPORT
- PROC PHREG
- PROC LIFETEST
- PROC SGPLOT

## Validation

- PROC COMPARE

---

# Programming Concepts Demonstrated

- Clinical data transformation
- SDTM to ADaM traceability
- Variable derivation
- Dataset merging
- Conditional logic
- BY-group processing
- Date handling
- Relative study day calculation
- Arrays
- RETAIN statements
- Macro variables
- Efficient SAS programming
- Independent validation workflows

---

# Statistical Methods

- Descriptive Statistics
- Survival Analysis
- Kaplan–Meier Estimation
- Cox Proportional Hazards Model
- Hazard Ratio Estimation
- Time-to-Event Analysis

---

# Skills Demonstrated

## Clinical Programming

- CDISC SDTM
- CDISC ADaM
- Clinical Trial Programming
- Regulatory Reporting
- Clinical Data Standards

## SAS Programming

- Base SAS
- DATA Step
- PROC SQL
- PROC REPORT
- PROC TRANSPOSE
- PROC PHREG
- PROC LIFETEST
- PROC SGPLOT
- PROC COMPARE

## Data Analysis

- Clinical Data Validation
- Statistical Reporting
- Data Transformation
- Data Quality Assessment

---

# Software

- SAS 9.4
- Base SAS
- SAS/STAT

---

# Learning Outcomes

Through this project, I gained hands-on experience in:

- Developing CDISC-compliant SDTM domains
- Creating ADaM analysis datasets
- Performing independent dataset validation
- Producing regulatory-style Tables, Listings, and Figures (TLFs)
- Applying SAS programming best practices
- Building traceable clinical trial data workflows

---

# About the Author

**Sai Sidharth Manikandan**

- MS Statistics – Florida State University
- MSc Biostatistics & Demography
- Data Scientist | Biostatistician | Clinical Programmer
---

## License

This repository is provided for educational and portfolio purposes only. Any reuse should comply with applicable licensing and confidentiality requirements.
