# Overview
This project facilitates pulling WA Office of Financial Management (WA OFM) Small Area Demographic (Population) Estimates (SADE) from [data.wa.gov](https://data.wa.gov/), Washington State's Open Data Portal. WA OFM SADE population estimates pulled through this project can be used to support Alone-or-in-Combination (AOIC) Race & Ethnicity categories in population health analyses.

## Motivation
WA OFM provides [publicly available](https://ofm.wa.gov/data-research/population-demographics/estimates/small-area/) and [internal](https://data.wa.gov/en/demographics/Small-Area-Demographic-Estimates-2020-present/3s8k-fvmm/about_data) SADE population estimates. This project aims to support LHJs in sustainably pulling and preparing the internal, detailed SADE population estimates for population health analyses. The internal SADE estimates represent a very large data set (9+ million rows of data) and contain granular AOIC Race-Ethnicity population estimates from 2020-2025 at the State, County, Census Tract, and Census Block geographies. 

## Author(s) & Contributor(s)
- [Tyler Bonnell](mailto:Tyler.Bonnell@co.snohomish.wa.us) (Snohomish County Health Department - Informatics & Data Management Epidemiologist)

## Technology Used
- R
- [Socrata SODA v2.0 API](https://dev.socrata.com/docs/endpoints.html) (used by data.wa.gov)
- [DuckDB](https://borkar.substack.com/p/r-workflows-with-duckdb)

# Optional Sections

## How to use?
LHJs can use this project's code to:

- (`1_pull_data.R`) Pull, prepare, and save WA OFM internal SADE estimates every year when a new data vintage is released.
- (`2_use_data.R`) Extract and use pulled WA OFM internal SADE population estimates for population health analyses. This is an example script meant to highlight how AOIC population estimates can be prepared, and should be adapted to meet the needs of the specific LHJ and population health analysis being conducted!
