# Overview
This project facilitates pulling WA Office of Financial Management (WA OFM) Small Area Demographic (Population) Estimates (SADE) from [data.wa.gov](https://data.wa.gov/), Washington State's Open Data Portal. WA OFM SADE population estimates pulled through this project can be used to support Alone-or-in-Combination (AOIC) Race & Ethnicity categories in population health analyses.

## Motivation
WA OFM provides [publicly available](https://ofm.wa.gov/data-research/population-demographics/estimates/small-area/) and [internal](https://data.wa.gov/en/demographics/Small-Area-Demographic-Estimates-2020-present/3s8k-fvmm/about_data) SADE population estimates. This project aims to support LHJs in sustainably pulling and preparing the internal, detailed SADE population estimates for population health analyses. The internal SADE estimates represent a very large data set (9+ million rows of data) and contain granular AOIC Race-Ethnicity population estimates from 2020-2025 at the State, County, Census Tract, and Census Block geographies. 

## Author(s) & Contributor(s)
- [Tyler Bonnell](mailto:Tyler.Bonnell@co.snohomish.wa.us) (Snohomish County Health Department - Informatics & Data Management Epidemiologist)
- [Jacob Armitage](mailto:jacob.armitage@co.thurston.wa.us) (Thurston County Public Health & Social Services Deparmtent - Assessment & Evaluation Epidemiologist)
- [Neil Panlasigui](mailto:neilp@co.skagit.wa.us) (Skagit County Public Health - Epidemiologist)

## Technology Used
- R
- [Socrata SODA v2.0 API](https://dev.socrata.com/docs/endpoints.html) (used by data.wa.gov)
- [DuckDB](https://borkar.substack.com/p/r-workflows-with-duckdb)

# Data Processing Workflow

## How to Run the Code
1. Request access to the internal WA OFM SADE population estimates by reaching out to the [WA OFM Forecasting team](ofmforecasting@ofm.wa.gov) (this process will require signing an End User Agreement detailing responsible use policies). For more information, click [here](https://github.com/OFMPop/ofm_opendata_portal_info/?tab=readme-ov-file).
2. Set up a [data.wa.gov](https://data.wa.gov/) account and navigate to the [internal WA OFM SADE Population Estimates](https://data.wa.gov/en/demographics/Small-Area-Demographic-Estimates-2020-present/3s8k-fvmm/about_data) page.
3. Generate a WA OFM SADE Population Estimate - Application Token in data.wa.gov by following these [instructions](https://github.com/OFMPop/ofm_opendata_portal_info/blob/main/guides/data_interaction.md) (see the "Accessing the data and queries with the API" chapter).
4. Provide data.wa.gov API credentials and local filepath to store pulled WA OFM data by following `Scripts/credentials_setup.R`. **Note: You will only have to run this script one time (when setting up the project)**, and will not need to re-run this script for updating the data in the future.
5. Run `Scripts/0_setup.R` to install/load all R packages, define all needed parameters (such as custom age groupings), and set up the DuckDB file (which will store the large WA OFM SADE data pull which is over 9 million rows).
6. Run `Scripts/1_pull_data.R` to pull all of WA OFM's internal SADE population estimates and save it locally (to the `params$duckdb_filepath` defined in `0_setup.R`). **Note: This script takes approximately 80 minutes to complete the API pull (it's a lot of data)**
7. Run `Scripts/2_clean_data.R` to perform data quality checks on the pulled data and to partition the data into cleaned `STATE`, `COUNTY`, `CENSUS_TRACT`, and `CENSUS_BLOCK` tables.
8. Run `Scripts/3_use_data.R` to summarize/aggregate the line-level WA OFM SADE estimate tables into population denominators for 1) a county of interest (via `params$county_of_interest` defined in `0_setup.R`) and 2) Washington state. The population denominators will then be saved to `params$output_file` as an excel and .rds file for use with population health analyses. 
