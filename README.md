# Overview
WA Office of Financial Management (WA OFM) publishes Small Area Demographic Estimates (SADE), which are population estimates for small geographical areas (as granular as census blocks) with robust demographic stratifications including age, sex, race, and ethnicity. SADE can be utilized as denominators for population-based rate in population health analyses. 

## Author(s) & Contributor(s)
- [Daniel Casey](mailto:dcasey@kingcounty.gov) - (Public Health Seattle King County - Epidemiologist)
- [Tyler Bonnell](mailto:Tyler.Bonnell@co.snohomish.wa.us) (Snohomish County Health Department - Informatics & Data Management Epidemiologist)
- [Jacob Armitage](mailto:jacob.armitage@co.thurston.wa.us) (Thurston County Public Health & Social Services Deparmtent - Assessment & Evaluation Epidemiologist)
- [Neil Panlasigui](mailto:neilp@co.skagit.wa.us) (Skagit County Public Health - Epidemiologist)

## Motivation
SADE include robust demographic stratifications that can be applied to population estimates, making it a very flexible data source for generating population-based rates for population health analyses. SADE include the following demographic stratifications (which can be combined as needed):

- **Geography**: Population estimates by state, county, census tract, school district, and congressional district are available
- **Age**: Population estimates by single year age are available
- **Sex**: Population estimates by male or female sex at birth.
- **Race/Ethnicity**: SADE contain various frameworks for reporting race/ethnicity, with options to include Hispanic as a race category or report it separately as an ethnicity. Additionally, SADE supports 2 different frameworks for reporting population estimates by race:
  1) **Mutually Exclusive**: Example: AIAN, Asian, Black, NHPI, White, and **Multiple Races**
  2) **Mutually Inclusive** or **Alone-or-In-Combination (AOIC)**: Example: AIAN AOIC, Asian AOIC, Black AOIC, NHPI AOIC, White AOIC. Individuals who identify as multiple races would be counted within each category they identify with, instead of being rolled into a single **Multiple Races** category.
   
# Getting Started

## Workflow Summary
This diagram summarizes all required steps (detailed below) to access, process, and utilize WA OFM SADE for population health analyses at your local health jurisdiction.

![](Resources/WA%20OFM%20SADE%20Population%20Estimates%20Workflow%20Diagram.png)

## Pre-Requisites
This repository leverages WA OFM's Internal SADE files, which require an End User Agreement (EUA) with WA OFM to access. The Internal SADE files are more granular than WA OFM's [Public SADE Files](https://ofm.wa.gov/data-research/population-demographics/estimates/age-sex-race-and-hispanic-origin/). To receive access to the Internal SADE Files:

1. Email [ofmforecasting@ofm.wa.gov](mailto:ofmforecasting@ofm.wa.gov) to request access and to sign their EUA.
2. Follow WA OFM's [Onboarding Guide](https://github.com/OFMPop/ofm_opendata_portal_info/blob/main/guides/partner_onboarding.md) which explains how to pull the Internal SADE files from data.wa.gov.
3. Download all Internal SADE files and the WA OFM Geographic Crosswalk:
   -  [2000 - 2009](https://data.wa.gov/en/demographics/Small-Area-Demographic-Estimates-2000-2009/g3gh-r5g7/about_data)
   -  [2010 - 2019](https://data.wa.gov/en/demographics/Small-Area-Demographic-Estimates-2010-2019/ivkq-ti7d/about_data)
   -  [2020 - Present](https://data.wa.gov/en/demographics/Small-Area-Demographic-Estimates-2020-present/3s8k-fvmm/about_data)
   -  [WA OFM Geographic Crosswalk](https://data.wa.gov/demographics/OFM-Geographic-Crosswalk/pvty-6zcu/about_data)
   -  **Note:** These are very large files (millions of rows of data). If you download the entire statewide data set, each file could take ~1 hr to download. You could also filter/subset the data on data.wa.gov just to your jurisdiction to reduce the size (see WA OFM's [Data Interaction Guide](https://github.com/OFMPop/ofm_opendata_portal_info/blob/main/guides/data_interaction.md) for instructions on manipulating data in data.wa.gov).
5. In a [`.Renviron`](https://docs.posit.co/ide/user/ide/guide/environments/r/managing-r.html#renviron) file specify:
    - `SADE_FILEPATH` = The folder where your LHJ stores the downloaded, raw Internal SADE files
    - `OFM_GEO_CROSSWALK_FILEPATH` = The folder where your LHJ stores the downloaded WA OFM Geographic Crosswalk file.
    - `OUTPUT_FILEPATH` = The folder where a DuckDB (`.duckdb`) file will store all of the cleaned and processed Internal SADE files.
    - **Note:** After editing the `.Renviron` file, you may need to restart your R session to ensure the entered values can be properly imported by the rest of the R scripts in the repository.

## How to Run the Code

### 1. [process_data.R](https://github.com/WA-LHJ-Analytic-Resources/WA-OFM-SADE-Population-Estimates/blob/main/Scripts/process_data.R)
- **You only need to run this script once (with every data refresh).**
- **Purpose:** Reformats Internal SADE files (intially formatted as census block-level estimates) and computes estimates for aggregate geographies (e.g. tract, ZCTA, school district, etc.) using [WA OFM's Geographic Crosswalk](https://data.wa.gov/demographics/OFM-Geographic-Crosswalk/pvty-6zcu/about_data)
- Install required R packages via:
    - On CRAN: `install.packages(c('data.table', 'DBI', 'glue', 'duckdb', 'remotes'))`
    - PHSKC R package: `remotes::install_github('PHSKC-APDE/rads.data)`
- Run the R script:
    - It loads the Internal SADE files (specified in `.Renviron`'s `SADE_FILEPATH`) and WA OFM Geographic Crosswalk (specified in `.Renviron`'s `OFM_GEO_CROSSWALK_FILEPATH`)
    - Processes and aggregates the census block population estimates
    - Stores processed data into a [Duckdb](https://duckdb.org/docs/stable/clients/r) database (specified in `.Renviron`'s `OUTPUT_FILEPATH`)
- **Output:** This script loads, reformats, and saves the CSVs into a [Duckdb](https://duckdb.org/docs/stable/clients/r) database (`.duckdb` file). This DuckDB file contains 1 table per geographical aggregation (i.e. state, county, census_tract, etc.)

### 2a. [example.R](https://github.com/WA-LHJ-Analytic-Resources/WA-OFM-SADE-Population-Estimates/blob/main/Scripts/example.R)
- **Purpose:** Provides basic **R code examples** on how to retrieve SADE estimates using the custom `fetch_pop()` function, which accesses the DuckDB file (specified by `dbpath`). **This is meant to support users who would prefer running R code instead of a point-and-click interface.**
- **Output:** Population estimate based on the demographic stratification(s) provided to `fetch_pop()`.

  
### 2b. [app.R](https://github.com/WA-LHJ-Analytic-Resources/WA-OFM-SADE-Population-Estimates/blob/main/Scripts/app.R)
- **Purpose:** Provides a **graphic user interface (GUI)** to retrieve SADE estimates using a Shiny app (referred to as PopPIE) which accesses the DuckDB file. **This is meant to support users who would prefer a point-and-click interface instead of running R code.**
- **Output:** Population estimate based on the demographic stratification(s) provided to the Shiny app (referred to as PopPIE). 
- Install required R packages via:
    - On CRAN: `install.packages(c('shiny', 'data.table', 'glue', 'shinyWidgets', 'reactlog', 'shinybusy', 'DBI', 'shinythemes', 'markdown', 'stringr', 'DT'))`

# Additional Documentation
1. [WA OFM SADE Frequently Asked Questions](https://github.com/WA-LHJ-Analytic-Resources/WA-OFM-SADE-Population-Estimates/blob/main/Resources/WA%20OFM%20Population%20SADE%20FAQ.pdf)
2. [WA OFM SADE User Notes & Errata](https://github.com/WA-LHJ-Analytic-Resources/WA-OFM-SADE-Population-Estimates/blob/main/Resources/WA%20OFM%20SADE%20User%20Notes%20%26%20Errata.pdf)
