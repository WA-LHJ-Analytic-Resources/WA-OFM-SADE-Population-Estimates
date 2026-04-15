# 1_pull_data_alt.R

# Establish DuckDB Connection -----
con <- dbConnect(duckdb::duckdb(), params$duckdb_filepath)

# Load WA OFM Geographic Crosswalk File into DuckDB -----
## read_auto_csv() streams the data from the .csv file into a new DuckDB table.

filepath <- ""

sql <- glue(
  "
  CREATE TABLE GEOGRAPHIC_CROSSWALK AS
  SELECT 
    *,
    current_timestamp AS ingestion_ts
  FROM read_csv_auto('{filepath}', HEADER=TRUE);
"
) # current_timestamp logs the date-time the WA OFM SADE data was uploaded to DuckDB

DBI::dbExecute(con, sql)


# Load Small Area Demographic Estimates File into DuckDB -----
## read_auto_csv() streams the data from the .csv file into a new DuckDB table.

filepath <- ""

sql <- glue(
  "
  CREATE TABLE RAW_UPLOAD_NEW AS
  SELECT 
    *,
    current_timestamp AS ingestion_ts
  FROM read_csv_auto('{filepath}', HEADER=TRUE);
"
) # current_timestamp logs the date-time the WA OFM SADE data was uploaded to DuckDB

DBI::dbExecute(con, sql)
