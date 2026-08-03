# Overview
This project facilitates pulling WA Office of Financial Management (WA OFM) Small Area Demographic (Population) Estimates (SADE) from [data.wa.gov](https://data.wa.gov/), Washington State's Open Data Portal. WA OFM SADE population estimates pulled through this project can be used to support Alone-or-in-Combination (AOIC) Race & Ethnicity categories in population health analyses.

## Motivation
WA OFM provides [publicly available](https://ofm.wa.gov/data-research/population-demographics/estimates/small-area/) and [internal](https://data.wa.gov/en/demographics/Small-Area-Demographic-Estimates-2020-present/3s8k-fvmm/about_data) SADE population estimates. This project aims to support LHJs in sustainably pulling and preparing the internal, detailed SADE population estimates for population health analyses. The internal SADE estimates represent a very large data set (9+ million rows of data) and contain granular AOIC Race-Ethnicity population estimates from 2020-2025 at the State, County, Census Tract, and Census Block geographies. 

## Author(s) & Contributor(s)
- [Daniel Casey](mailto:dcasey@kingcounty.gov) (Public Health - Seattle King County - Epidemiologist)
- [Tyler Bonnell](mailto:Tyler.Bonnell@co.snohomish.wa.us) (Snohomish County Health Department - Informatics & Data Management Epidemiologist)
- [Jacob Armitage](mailto:jacob.armitage@co.thurston.wa.us) (Thurston County Public Health & Social Services Deparmtent - Assessment & Evaluation Epidemiologist)
- [Neil Panlasigui](mailto:neilp@co.skagit.wa.us) (Skagit County Public Health - Epidemiologist)

## Technology Used
- R
- [Shiny](https://shiny.posit.co/) (creates application user interface)
- [DuckDB](https://borkar.substack.com/p/r-workflows-with-duckdb)

# Workflow

**Note(s)**:
1. Only 1 team member is needed to facilitate `Pre-Requisites` and `Processing the Data` steps. All other team members should be able to work with WA OFM Internal Population Estimates by following the `Accessing the Data Steps` included below.
2. Users will need to numerous R packages from CRAN (via `install.packages()`) as well as the Public Health Seattle King County's `rads` R package (see instructions [here](https://github.com/PHSKC-APDE/rads) to install). 

## Pre-Requisites
1. Request access to the internal WA OFM SADE Population Estimates by reaching out to the [WA OFM Forecasting team](mailto:ofmforecasting@ofm.wa.gov) (this process will require signing an End User Agreement detailing responsible use policies). For more information, click [here](https://github.com/OFMPop/ofm_opendata_portal_info/?tab=readme-ov-file).
2. Set up a [data.wa.gov](https://data.wa.gov/) account and navigate to the [Internal WA OFM SADE Population Estimates](https://data.wa.gov/en/demographics/Small-Area-Demographic-Estimates-2020-present/3s8k-fvmm/about_data) page.
3a. Export the [Internal WA OFM SADE Population Estimates](https://data.wa.gov/en/demographics/Small-Area-Demographic-Estimates-2020-present/3s8k-fvmm/about_data) as a `.csv` file. **Note: This is a large file and takes 30 minutes to 1 hour to download.**
3b. Export the [OFM Geographic Crosswalk](https://data.wa.gov/demographics/OFM-Geographic-Crosswalk/pvty-6zcu/about_data) as a `.csv` file.
4. Move the Internal WA OFM SADE Population Estimate and OFM Geographic Crosswalks to your organization's preferred storage location.

## Processing the Data
1. Create/edit an [`.Renviron`](https://docs.posit.co/ide/user/ide/guide/environments/r/managing-r.html#renviron) file in the root project directory. [Add:]{.underline}
  -  `SADE_FILEPATH` - The file path where your Internal WA OFM SADE Population Estimates file is stored.
  -  `OFM_GEO_CROSSWALK_FILEPATH` - The file path where your OFM Geographic Crosswalk file is stored.
  -  `OUTPUT_FILEPATH` - The file path where you would like to store cleaned, processed results generated through this workflow.
  -  **Note:** After editing `.Renviron` it is recommended you either: 1) run `readRenviron(".Renviron")` or restart your R project to ensure your updates populate in your environment
2. Run `process_data.R` - This will process Internal WA OFM SADE Population estimates (**needs to only be run once per Internal WA OFM SADE Population estimates data refresh**).

## Accessing the Data
There are 2 options to access and use WA OFM's Internal SADE Population Estimates: 1) **Shiny App** (includes a user interface) or 2) **R Code**. The only difference is that the R code option allows users to pull population estimates at the Census Block and Census Block Group levels (*these geographies are rarely used*). 

### Shiny App
- Run `shiny::runApp('Scripts/PopPIE/app.R')`
- Provide with the presented Shiny App with your desired parameters to receive population estimates of interest.

### R Code
- WA OFM Internal SADE Population Estimates can be extracted using the `fetch_pop()` custom R function.
- See `example.R` for examples on how this function is utilized.
