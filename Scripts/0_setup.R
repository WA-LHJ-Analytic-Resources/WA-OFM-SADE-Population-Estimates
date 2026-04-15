# 0_setup.R

# Setup -----

## Install/Load R Packages
pacman::p_load(
  base64enc,
  DBI,
  duckdb,
  glue,
  here,
  keyring,
  tictoc,
  tidyverse,
  tigris,
  writexl
)

## Load Custom Functions
list.files(
  path = here::here("Scripts", "Custom_Functions"),
  pattern = "\\.R$",
  full.names = TRUE,
  recursive = TRUE
) %>%
  lapply(source) # source() all R scripts within Support_Code subfolder (including children subfolders)

# Define Parameters -----
params <- list()

## On/Off Switch to Pull New Data via API (activates 1_pull_data.R)
params$pull_new_data <- TRUE
params$output_folder <- Sys.getenv("OUTPUT_FILEPATH")

## Define county_of_interest (for formatting data extracts in 3_use_data.R)
params$county_of_interest <- "Snohomish" # EDIT as needed. Do not include "County"

## Define custom age groups (for formatting data extracts in 3_use_data.R)
params$age_labels <- c(
  "<4",
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

# Load API Credentials ------
params$username <- keyring::key_get("DATA_WA_GOV_USERNAME")
params$password <- keyring::key_get("DATA_WA_GOV_PASSWORD")
params$app_token <- keyring::key_get("WA_OFM_APP_TOKEN")
params$basic_b64 <- base64enc::base64encode(charToRaw(paste0(
  params$username,
  ":",
  params$password
))) # Convert data.wa.gov password into base64 encoded raw bytes (the format that Socrata/data.wa.gov expects authentication credentials in)

# Setup DuckDB -----

## Note: DuckDB will be the preferred file format to store the pulled data at it is uniquely tailored to handle large data sets in an efficient, simple, and streamlined way.
## DuckDB Resource: https://borkar.substack.com/p/r-workflows-with-duckdb

## Create DuckDB filepath
params$duckdb_filepath <- here(
  params$output_folder,
  "WA_OFM_SADE_Population_Data.duckdb"
)

## Create DuckDB connection
con <- dbConnect(duckdb::duckdb(), params$duckdb_filepath)

## Install & Loadd HTTPFS extension to enable streaming
dbExecute(con, "INSTALL httpfs;")
dbExecute(con, "LOAD httpfs;")

## Add Temporary Secrets (API Credentials) to DuckDB to enable Streaming
dbExecute(
  con,
  glue(
    "
  CREATE OR REPLACE SECRET socrata_http (
    TYPE http,
    EXTRA_HTTP_HEADERS MAP {{
      'X-App-Token': '{params$app_token}',
      'Authorization': 'Basic {params$basic_b64}'
    }}
  );
"
  ) # X-App-Token is the data.wa.gov App Token
)

# Add WA OFM Geographic Crosswalk DuckDB -----
geo_cw <- RSocrata::read.socrata(
  url = "https://data.wa.gov/resource/pvty-6zcu.csv", # Source: https://data.wa.gov/demographics/OFM-Geographic-Crosswalk/pvty-6zcu/about_data
  app_token = params$app_token
) %>%
  # Convert all variables to character data type
  mutate(across(everything(), ~ as.character(.x)))

## Upload fips_crosswalk to DuckDB
DBI::dbWriteTable(con, "GEOGRAPHIC_CROSSWALK", geo_cw, overwrite = TRUE)

# rm(geo_cw)
# gc()
