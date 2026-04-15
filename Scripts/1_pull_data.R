# 1_pull_data.R

# Create Ingestion Timestamp ----
ingestion_ts <- as.character(Sys.time())

# Load WA OFM Geographic Crosswalk File into DuckDB -----

## Upload CSV file to DuckDB
duckdb::duckdb_read_csv(
  con,
  name = "GEOGRAPHIC_CROSSWALK_RAW",
  files = params$ofm_geo_crosswalk_filepath,
  nrow.check = -1, # Checks all rows to infer variable data types
  lower.case.names = TRUE # Keeps all variable names as lowercase
)

## Perform Light Edits on DuckDB Table
tbl(con, "GEOGRAPHIC_CROSSWALK_RAW") %>%
  mutate(
    across(everything(), as.character), # Cast all columns to character
    ingestion_ts = !!ingestion_ts # A single constant timestamp for all rows
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
  lower.case.names = TRUE # Converts all variable names to lowercase
)
