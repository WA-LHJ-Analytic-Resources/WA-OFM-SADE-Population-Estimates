# 1_pull_data.R

# Connect to DuckDB -----
con <- dbConnect(duckdb::duckdb(), params$duckdb_filepath)

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
    census_block_code = as.numeric(block20l),
    ingestion_ts = !!ingestion_ts # A single constant timestamp for all rows
  ) %>%
  select(-block20l) %>%
  compute(
    name = "GEOGRAPHIC_CROSSWALK", # Save cleaned table as GEOGRAPHIC_CROSSWALK
    temporary = FALSE,
    overwrite = TRUE
  )

## Remove GEOGRAPHIC_CROSSWALK_RAW
dbRemoveTable(con, "GEOGRAPHIC_CROSSWALK_RAW")

# Load Small Area Demographic Estimates File into DuckDB -----

## Upload CSV to DuckDB

DBI::dbExecute(
  con,
  "
  CREATE TABLE RAW_UPLOAD AS
  SELECT * FROM read_csv_auto(
    ?,
    types = {'race97':'VARCHAR'}  -- ensure race97 is VARCHAR to maintain leading zeros (important)
  );
  ",
  params = list(params$sade_filepath)
)

# Disconnect from DuckDB -----

## Note: Uncomment and run the R code below to Disconnect when no longer using the DuckDB file.
# DBI::dbDisconnect(con, shutdown = TRUE)
