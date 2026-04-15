# 1_pull_data_api.R
params$pull_new_data <- TRUE

# Load API Credentials ------
params$username <- keyring::key_get("DATA_WA_GOV_USERNAME")
params$password <- keyring::key_get("DATA_WA_GOV_PASSWORD")
params$app_token <- keyring::key_get("WA_OFM_APP_TOKEN")
params$basic_b64 <- base64enc::base64encode(charToRaw(paste0(
  params$username,
  ":",
  params$password
))) # Convert data.wa.gov password into base64 encoded raw bytes (the format that Socrata/data.wa.gov expects authentication credentials in)

# Connect to DuckDB -----
con <- dbConnect(duckdb::duckdb(), params$duckdb_filepath)

# Setup DuckDB file (for Streaming API Pull) -----

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

# Pull WA OFM Geographic Crosswalk (via Socrate v2.0 API) -----

geo_cw <- RSocrata::read.socrata(
  url = "https://data.wa.gov/resource/pvty-6zcu.csv", # Source: https://data.wa.gov/demographics/OFM-Geographic-Crosswalk/pvty-6zcu/about_data
  app_token = params$app_token
) %>%
  # Convert all variables to character data type
  mutate(across(everything(), ~ as.character(.x)))

## Upload fips_crosswalk to DuckDB
DBI::dbWriteTable(con, "GEOGRAPHIC_CROSSWALK", geo_cw, overwrite = TRUE)

rm(geo_cw)

# Pull Internal Small Area Demographic Estimates (via Socrata v2.0 API) -----

if (params$pull_new_data == TRUE) {
  # Step 1a: API Pull - Initialize DuckDB Table -----
  tictoc::tic("Entire API Pull")

  # Capture a single ingestion timestamp for this entire API pull
  # Using an ISO-like string; you can replace with format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z") if you prefer strict ISO-8601.
  ingestion_ts <- as.character(Sys.time())

  # Page settings
  page_size <- 500000
  offset <- 0

  # Build first page URL
  first_url <- create_paged_api_url(
    page_size = page_size,
    offset = offset
  )

  message(glue("Fetching first page: limit={page_size}, offset={offset}"))

  # Create table from the first page
  dbExecute(
    con,
    glue(
      "
      CREATE OR REPLACE TABLE RAW_UPLOAD AS
      SELECT
        *,
        '{ingestion_ts}' AS ingestion_ts
      FROM read_csv_auto('{first_url}',
        columns = {{
          'block20l': 'VARCHAR',
          'sex'     : 'VARCHAR',
          'hispanic': 'VARCHAR',
          'race97'  : 'VARCHAR',
          'age'     : 'INTEGER',
          'pop_2020': 'FLOAT',
          'pop_2021': 'FLOAT',
          'pop_2022': 'FLOAT',
          'pop_2023': 'FLOAT',
          'pop_2024': 'FLOAT',
          'pop_2025': 'FLOAT'
        }}
      );
      "
    ) # read_csv_auto() loads the httpfs extension and then reads the .csv file referenced in the API URL
  )

  # Step 1b: API Pull - Pull remaining data until a page returns 0 rows -----
  repeat {
    # Step 1: Create API URL for the page of interest
    offset <- offset + page_size
    page_url <- create_paged_api_url(offset = offset, page_size = page_size)

    offset_message <- format(
      as.integer(offset),
      scientific = FALSE,
      trim = TRUE
    )
    tictoc::tic(glue("API Pull - offset={offset_message}"))
    message(glue("Fetching page at offset={offset_message}"))

    ## Step 2: Load this page's data into a temporary view, so it can be counted (and if n_rows > 0) and then appended to the rest of the pulled data.
    dbExecute(
      con,
      glue(
        "
        CREATE OR REPLACE VIEW _page_view AS
        SELECT
          *,
          '{ingestion_ts}' AS ingestion_ts
        FROM read_csv_auto('{page_url}',
          columns = {{
            'block20l': 'VARCHAR',
            'sex'     : 'VARCHAR',
            'hispanic': 'VARCHAR',
            'race97'  : 'VARCHAR',
            'age'     : 'INTEGER',
            'pop_2020': 'FLOAT',
            'pop_2021': 'FLOAT',
            'pop_2022': 'FLOAT',
            'pop_2023': 'FLOAT',
            'pop_2024': 'FLOAT',
            'pop_2025': 'FLOAT'
          }}
        );
        "
      )
    )

    ## Step 2: Check the number of rows in the pulled page's data.
    n_rows <- dbGetQuery(con, "SELECT COUNT(*) AS n FROM _page_view")$n[1]

    tictoc::toc() # Timer for individual page API pull

    ### If n_rows == 0, stop API pull workflow.
    if (n_rows == 0) {
      message("No more rows; stopping.")
      dbExecute(con, "DROP VIEW IF EXISTS _page_view;")
      break
    } ###  If n_rows >= 1, continue API pull workflow (append current page's data and move on to the next one)

    ## Step 3: Append Pulled API Page's Data into Existing DuckDB Table
    dbExecute(con, "INSERT INTO RAW_UPLOAD SELECT * FROM _page_view;")
    dbExecute(con, "DROP VIEW IF EXISTS _page_view;") # Drop _page_view (was used to evaluate/count rows for Step #3)
  }

  message(glue(
    "API pull workflow completed. Census Block data stored at: {params$duckdb_filepath}"
  ))

  tictoc::toc() # Timer for the entire API pull
}
