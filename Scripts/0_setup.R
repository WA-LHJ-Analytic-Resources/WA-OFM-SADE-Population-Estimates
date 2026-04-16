# 0_setup.R

# Setup -----

## Install/Load R Packages
pacman::p_load(
  DBI,
  duckdb,
  glue,
  here,
  tictoc,
  tidyverse,
  writexl
)

## Load Custom Functions
list.files(
  path = here::here("Scripts", "Custom_Functions"),
  pattern = "\\.R$",
  full.names = TRUE,
  recursive = TRUE
) %>%
  lapply(source) |> invisible() # source() all R scripts within Support_Code subfolder (including children subfolders)

# Define Parameters -----
params <- list()

## Define Output Folder (for WA OFM SADE estimates)
params$output_folder <- Sys.getenv("OUTPUT_FILEPATH")
params$duckdb_filepath <- here(
  params$output_folder,
  "WA_OFM_SADE_Population_Data.duckdb"
)

## Define Filepaths for WA OFM Geographic Crosswalk & Small Area Demographic Estimate Exports

### Note: Define these filepaths in the .Renviron file (this ensures the filepath is protected and not upload to GitHub!)
params$ofm_geo_crosswalk_filepath <- Sys.getenv("OFM_GEO_CROSSWALK_FILEPATH") # Download at (quick): https://data.wa.gov/demographics/OFM-Geographic-Crosswalk/pvty-6zcu/about_data
params$sade_filepath <- Sys.getenv("SADE_FILEPATH") # Download at (takes ~40 minutes): https://data.wa.gov/en/demographics/Small-Area-Demographic-Estimates-2020-present/3s8k-fvmm/about_data


## Define county_of_interest (for formatting data extracts in 3_use_data.R)
params$county_of_interest <- "Snohomish" # EDIT as needed. Do not include "County"

## Define custom age groups (for formatting data extracts in 3_use_data.R)
## '+' and "<=" are special options
## Otherwise age groups should be specified '{start}-{end}', inclusive
params$age_labels <- c(
  "<=4",
  "5-9",
  "10-14",
  "15-19",
  "20-24",
  "25-29",
  "30-34",
  "35-39",
  "40-44",
  "45-49",
  "50-54",
  "55-59",
  "60-64",
  "65-69",
  "70-74",
  "75-79",
  "80-84",
  "85+"
) # EDIT THIS LINE IF YOU WANT DIFFERENT CUSTOM AGE GROUPS! USE THE SAME SYNTAX.

params$age_breaks <- convert_age_labels_to_breaks(params$age_labels)

# Connect to DuckDB -----
con <- dbConnect(duckdb::duckdb(), params$duckdb_filepath)

## Note: DuckDB will be the preferred file format to store the pulled data at it is uniquely tailored to handle large data sets in an efficient, simple, and streamlined way.
## DuckDB Resource: https://borkar.substack.com/p/r-workflows-with-duckdb
