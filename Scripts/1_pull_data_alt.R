# 1_pull_data_alt.R

# Establish DuckDB Connection -----
con <- dbConnect(duckdb::duckdb(), params$duckdb_filepath)

# Create Ingestion Timestamp ----
ingest_ts <- lubridate::now(tzone = "America/Los_Angeles")

# Load WA OFM Geographic Crosswalk File into DuckDB -----

## Upload CSV file to DuckDB
duckdb::duckdb_read_csv(
  con,
  name = "GEOGRAPHIC_CROSSWALK_RAW",
  files = params$ofm_geo_crosswalk_filepath,
  nrow.check = -1,
  lower.case.names = TRUE
)

## Perform Light Edits on DuckDB Table
tbl(con, "GEOGRAPHIC_CROSSWALK_RAW") %>%
  mutate(
    across(everything(), as.character), # Cast all columns to character
    ingestion_ts = !!ingest_ts # A single constant timestamp for all rows
  ) %>%
  compute(
    name = "GEOGRAPHIC_CROSSWALK", # Save cleaned table as GEOGRAPHIC_CROSSWALK
    temporary = FALSE,
    overwrite = TRUE
  )

## Remove GEOGRAPHIC_CROSSWALK_RAW
dbRemoveTable(con, "GEOGRAPHIC_CROSSWALK_RAW")

# Load Small Area Demographic Estimates File into DuckDB -----

## Upload CSV to DuckDB
duckdb::duckdb_read_csv(
  con,
  "RAW_UPLOAD",
  params$sade_filepath,
  lower.case.names = TRUE # Converts all column names to lowercase
)
