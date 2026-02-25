# 1_pull_data.R
## Date: 2/20/2026

rm(list = ls())

params <- list()
params$pull_new_data <- TRUE

# Process -----

# Step 0: Setup -- Load Packages, Load Custom Functions, data.wa.gov credentials
# Step 1a: Set up DuckDB file (where the WA OFM SADE Population estimate will be stored and referenced for future use)
# Step 1b: Load tigris::fips_crosswalk into DuckDB table (fips_crosswalk) to convert state and county codes into names.
# Step 2a: Pull the initial data (~1 page worth of data) via streaming using the SODA v2.0 CSV API to initialize the RAW DuckDB table
# Step 2b: Pull the remaining data (a vast majority) and insert/append it into the RAW DuckDB table
# Step 3: Generate Data Quality Flags (DQ Flag == TRUE if overall jurisidiction population is less than 4,300 people --> would cause estimates to be unstable)
# Step 4: Generate clean, derived DuckDB tables (STATE, COUNTY, CENSUS_TRACT, CENSUS_BLOCK) to minimize the amount of cleaning needed. GEOID Information Source: (See data.wa.gov documentation as well) https://www.census.gov/programs-surveys/geography/guidance/geo-identifiers.html
# Step 5: Delete the RAW DuckDB table
# Step 6: Disconnect from DuckDB

# Step 0: Install/Load Packages -----
pacman::p_load(
  base64enc,
  DBI,
  duckdb,
  glue,
  here,
  keyring,
  tictoc,
  tidyverse,
  tigris
)

# Step 0: Load Custom Functions -----
list.files(
  path = here::here("Scripts", "Custom_Functions"),
  pattern = "\\.R$",
  full.names = TRUE,
  recursive = TRUE
) %>%
  lapply(source) # source() all R scripts within Support_Code subfolder (including children subfolders)

# Step 0: API Credentials -----
params$username <- keyring::key_get("DATA_WA_GOV_USERNAME")
params$password <- keyring::key_get("DATA_WA_GOV_PASSWORD")
params$app_token <- keyring::key_get("WA_OFM_APP_TOKEN")
params$basic_b64 <- base64enc::base64encode(charToRaw(paste0(
  params$username,
  ":",
  params$password
))) # Convert data.wa.gov password into base64 encoded raw bytes (the format that Socrata/data.wa.gov expects authentication credentials in)

# Step 1a: Set up DuckDB File -----
params$duckdb_filepath <- here(
  Sys.getenv("DUCKDB_FILEPATH"),
  "WA_OFM_SADE_Population_Data.duckdb"
)
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

# Step 1b: Add FIPS Crosswalk to DuckDB Table -----

## Format fips_crosswalk
fips_crosswalk <- tigris::fips_codes %>%
  mutate(
    censuscountycode2020 = paste0(state_code, county_code),
    censuscountycode2020 = as.integer(censuscountycode2020),
    county = stringr::str_remove_all(county, " County")
  ) %>%
  filter(state == "WA") %>%
  select(county_code, county, state_code, state = state_name)

## Upload fips_crosswalk to DuckDB
if (params$pull_new_data == TRUE) {
  DBI::dbWriteTable(con, "FIPS_CROSSWALK", fips_crosswalk, overwrite = TRUE)
}

# Step 2a: API Pull - Initialize DuckDB Table -----
# Step 2a: API Pull - Initialize DuckDB Table -----
if (params$pull_new_data == TRUE) {
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

  # Step 2b: API Pull - Pull remaining data until a page returns 0 rows -----
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

    ## Step 3: Check the number of rows in the pulled page's data.
    n_rows <- dbGetQuery(con, "SELECT COUNT(*) AS n FROM _page_view")$n[1]

    tictoc::toc() # Timer for individual page API pull

    ### If n_rows == 0, stop API pull workflow.
    if (n_rows == 0) {
      message("No more rows; stopping.")
      dbExecute(con, "DROP VIEW IF EXISTS _page_view;")
      break
    } ###  If n_rows >= 1, continue API pull workflow (append current page's data and move on to the next one)

    ## Step 4: Append Pulled API Page's Data into Existing DuckDB Table
    dbExecute(con, "INSERT INTO RAW_UPLOAD SELECT * FROM _page_view;")
    dbExecute(con, "DROP VIEW IF EXISTS _page_view;") # Drop _page_view (was used to evaluate/count rows for Step #3)
  }

  message(glue(
    "API pull workflow completed. Census Block data stored at: {params$duckdb_filepath}"
  ))

  tictoc::toc() # Timer for the entire API pull
}

# Step 3: Create Data Quality Checks -----
## Note: Per WA OFM End User Agreement the Data Quality Check Should Be (4,300+ Overall Population for a Geography - Size of Average Census Tract)

## STATE
tbl(con, "RAW_UPLOAD") %>%
  # Extract State Code segment of GEOID
  mutate(
    state_code = str_sub(block20l, start = 1, end = 2),
  ) %>%
  # Count Overall Jurisdiction Population
  group_by(state_code) %>%
  summarize(
    across(starts_with("pop_"), ~ sum(.x, na.rm = TRUE), .names = "{.col}_sum"),
    .groups = "drop"
  ) %>%
  # Create Data Quality Flag
  mutate(
    across(
      ends_with("_sum"),
      ~ ifelse(.x < 4300, TRUE, FALSE),
      .names = "DQ_FLAG_{.col}"
    ),
  ) %>%
  # Rename DQ Flag Variables
  rename_with(
    .,
    .fn = ~ str_remove_all(.x, "_pop|_sum"),
    .cols = starts_with("DQ_FLAG")
  ) %>%
  # Create DQ_STATE DuckDB Table
  compute(name = "DQ_STATE", temporary = TRUE) # (temporary = TRUE) This table will disappear once the connection has been ended (can easily be re-made)

## COUNTY
tbl(con, "RAW_UPLOAD") %>%
  # Extract State Code segment of GEOID
  mutate(
    state_code = str_sub(block20l, start = 1, end = 2),
    county_code = str_sub(block20l, start = 3, end = 5),
  ) %>%
  # Count Overall Jurisdiction Population
  group_by(state_code, county_code) %>%
  summarize(
    across(starts_with("pop_"), ~ sum(.x, na.rm = TRUE), .names = "{.col}_sum"),
    .groups = "drop"
  ) %>%
  # Create Data Quality Flag
  mutate(
    across(
      ends_with("_sum"),
      ~ ifelse(.x < 4300, TRUE, FALSE),
      .names = "DQ_FLAG_{.col}"
    ),
  ) %>%
  # Rename DQ Flag Variables
  rename_with(
    .,
    .fn = ~ str_remove_all(.x, "_pop|_sum"),
    .cols = starts_with("DQ_FLAG")
  ) %>%
  # Arrange County Codes
  arrange(county_code) %>%
  # Create DQ_COUNTY DuckDB Table
  compute(name = "DQ_COUNTY", temporary = TRUE) # (temporary = TRUE) This table will disappear once the connection has been ended (can easily be re-made)

## CENSUS_TRACT
tbl(con, "RAW_UPLOAD") %>%
  # Extract State Code segment of GEOID
  mutate(
    state_code = str_sub(block20l, start = 1, end = 2),
    county_code = str_sub(block20l, start = 3, end = 5),
    census_tract_code = str_sub(block20l, start = 6, end = 11),
  ) %>%
  # Count Overall Jurisdiction Population
  group_by(state_code, county_code, census_tract_code) %>%
  summarize(
    across(starts_with("pop_"), ~ sum(.x, na.rm = TRUE), .names = "{.col}_sum"),
    .groups = "drop"
  ) %>%
  # Create Data Quality Flag
  mutate(
    across(
      ends_with("_sum"),
      ~ ifelse(.x < 4300, TRUE, FALSE),
      .names = "DQ_FLAG_{.col}"
    ),
  ) %>%
  # Rename DQ Flag Variables
  rename_with(
    .,
    .fn = ~ str_remove_all(.x, "_pop|_sum"),
    .cols = starts_with("DQ_FLAG")
  ) %>%
  # Arrange County & Census Tract Codes
  arrange(county_code, census_tract_code) %>%
  # Create DQ_CENSUS_TRACT DuckDB Table
  compute(name = "DQ_CENSUS_TRACT", temporary = TRUE) # (temporary = TRUE) This table will disappear once the connection has been ended (can easily be re-made)

## CENSUS_BLOCK
tbl(con, "RAW_UPLOAD") %>%
  # Extract State Code, County Code, Census Tract, and Census Block segments of GEOID
  mutate(
    state_code = str_sub(block20l, start = 1, end = 2),
    county_code = str_sub(block20l, start = 3, end = 5),
    census_tract_code = str_sub(block20l, start = 6, end = 11),
    census_block_code = str_sub(block20l, start = 12, end = -1)
  ) %>%
  # Count Overall Jurisdiction Population
  group_by(state_code, county_code, census_tract_code, census_block_code) %>%
  summarize(
    across(starts_with("pop_"), ~ sum(.x, na.rm = TRUE), .names = "{.col}_sum"),
    .groups = "drop"
  ) %>%
  # Create Data Quality Flag
  mutate(
    across(
      ends_with("_sum"),
      ~ ifelse(.x < 4300, TRUE, FALSE),
      .names = "DQ_FLAG_{.col}"
    ),
  ) %>%
  # Rename DQ Flag Variables
  rename_with(
    .,
    .fn = ~ str_remove_all(.x, "_pop|_sum"),
    .cols = starts_with("DQ_FLAG")
  ) %>%
  # Arrange County, Census Tract, & Census Block Codes
  arrange(county_code, census_tract_code, census_block_code) %>%
  # Create DQ_CENSUS_BLOCK DuckDB Table
  compute(name = "DQ_CENSUS_BLOCK", temporary = TRUE) # (temporary = TRUE) This table will disappear once the connection has been ended (can easily be re-made)

# Step 4: Create State Table -----

tbl(con, "RAW_UPLOAD") %>%
  # Recode Sex
  mutate(
    sex = case_when(
      sex == "F" ~ "Female",
      sex == "M" ~ "Male",
      TRUE ~ NA_character_
    )
  ) %>%
  # Extract State Code segment of GEOID
  mutate(
    state_code = str_sub(block20l, start = 1, end = 2),
  ) %>%
  # Aggregate Population Counts at the State Level
  group_by(
    state_code,
    age,
    sex,
    hispanic,
    race97
  ) %>%
  summarise(
    across(starts_with("pop_"), ~ sum(.x, na.rm = TRUE)),
    .groups = "drop"
  ) %>%
  # Generate & Evaluate 0/1 Race-Ethnicity Indicators
  create_race_eth_indicators(df = .) %>%
  evaluate_race_eth_indicators(df = .) %>%
  # Left Join to Add Data Quality Indicators
  left_join(
    tbl(con, "DQ_STATE") %>% select(state_code, starts_with("DQ_FLAG")),
    by = "state_code"
  ) %>%
  # Left Join FIPS CROSSWALK Information to Add a State Label
  left_join(
    tbl(con, "FIPS_CROSSWALK") %>% distinct(state_code, state),
    by = "state_code"
  ) %>%
  # Order Rows
  arrange(
    state_code,
    age,
    sex,
    hispanic,
    race97
  ) %>%
  # Order Columns
  select(
    state,
    state_code,
    age,
    sex,
    hispanic,
    race97,
    race_eth_number,
    race_eth_combination,
    starts_with("pop"),
    ends_with("_01"),
    starts_with("DQ_FLAG")
  ) %>%
  # Create STATE DuckDB Table
  compute(name = "STATE", temporary = FALSE) # materialize as a real, persistent table

# Step 4: Create County Table -----

tbl(con, "RAW_UPLOAD") %>%
  # Recode Sex
  mutate(
    sex = case_when(
      sex == "F" ~ "Female",
      sex == "M" ~ "Male",
      TRUE ~ NA_character_
    )
  ) %>%
  # Extract State Code & County Code segments of GEOID
  mutate(
    state_code = str_sub(block20l, start = 1, end = 2),
    county_code = str_sub(block20l, start = 3, end = 5),
  ) %>%
  # Aggregate Population Counts at the County Level
  group_by(
    state_code,
    county_code,
    age,
    sex,
    hispanic,
    race97
  ) %>%
  summarise(
    across(starts_with("pop_"), ~ sum(.x, na.rm = TRUE)),
    .groups = "drop"
  ) %>%
  # Generate & Evaluate 0/1 Race-Ethnicity Indicators
  create_race_eth_indicators(df = .) %>%
  evaluate_race_eth_indicators(df = .) %>%
  # Left Join to Add Data Quality Indicators
  left_join(
    tbl(con, "DQ_COUNTY") %>%
      select(state_code, county_code, starts_with("DQ_FLAG")),
    by = c("state_code", "county_code")
  ) %>%
  # Left Join FIPS CROSSWALK Information to Add a State and County Labels
  left_join(
    tbl(con, "FIPS_CROSSWALK"),
    by = c("state_code", "county_code")
  ) %>%
  # Order Rows
  arrange(
    state_code,
    county_code,
    age,
    sex,
    hispanic,
    race97
  ) %>%
  # Order Columns
  select(
    state,
    state_code,
    county,
    county_code,
    age,
    sex,
    hispanic,
    race97,
    race_eth_number,
    race_eth_combination,
    starts_with("pop"),
    ends_with("_01"),
    starts_with("DQ_FLAG")
  ) %>%
  # Create COUNTY DuckDB Table
  compute(name = "COUNTY", temporary = FALSE) # materialize as a real, persistent table

# Step 4: Create Census Tract Table -----

tbl(con, "RAW_UPLOAD") %>%
  # Recode Sex
  mutate(
    sex = case_when(
      sex == "F" ~ "Female",
      sex == "M" ~ "Male",
      TRUE ~ NA_character_
    )
  ) %>%
  # Extract State Code, County Code, and Census Tract segments of GEOID
  mutate(
    state_code = str_sub(block20l, start = 1, end = 2),
    county_code = str_sub(block20l, start = 3, end = 5),
    census_tract_code = str_sub(block20l, start = 6, end = 11),
  ) %>%
  # Aggregate Population Counts at the Census Tract Level
  group_by(
    state_code,
    county_code,
    census_tract_code,
    age,
    sex,
    hispanic,
    race97
  ) %>%
  summarise(
    across(starts_with("pop_"), ~ sum(.x, na.rm = TRUE)),
    .groups = "drop"
  ) %>%
  # Generate & Evaluate 0/1 Race-Ethnicity Indicators
  create_race_eth_indicators(df = .) %>%
  evaluate_race_eth_indicators(df = .) %>%
  # Left Join to Add Data Quality Indicators
  left_join(
    tbl(con, "DQ_CENSUS_TRACT") %>%
      select(
        state_code,
        county_code,
        census_tract_code,
        starts_with("DQ_FLAG")
      ),
    by = c("state_code", "county_code", "census_tract_code")
  ) %>%
  # Left Join FIPS CROSSWALK Information to Add a State and County Labels
  left_join(
    tbl(con, "FIPS_CROSSWALK"),
    by = c("state_code", "county_code")
  ) %>%
  # Order Rows
  arrange(
    state_code,
    county_code,
    census_tract_code,
    age,
    sex,
    hispanic,
    race97
  ) %>%
  # Order Columns
  select(
    state,
    state_code,
    county,
    county_code,
    census_tract_code,
    age,
    sex,
    hispanic,
    race97,
    race_eth_number,
    race_eth_combination,
    starts_with("pop"),
    ends_with("_01"),
    starts_with("DQ_FLAG")
  ) %>%
  # Create CENSUS_TRACT DuckDB table
  compute(name = "CENSUS_TRACT", temporary = FALSE) # materialize as a real, persistent table

# Step 4: Create Census Block Table -----

tbl(con, "RAW_UPLOAD") %>%
  # Recode Sex
  mutate(
    sex = case_when(
      sex == "F" ~ "Female",
      sex == "M" ~ "Male",
      TRUE ~ NA_character_
    )
  ) %>%
  # Extract State Code, County Code, Census Tract, and Census Block segments of GEOID
  mutate(
    state_code = str_sub(block20l, start = 1, end = 2),
    county_code = str_sub(block20l, start = 3, end = 5),
    census_tract_code = str_sub(block20l, start = 6, end = 11),
    census_block_code = str_sub(block20l, start = 12, end = -1)
  ) %>%
  # Aggregate Population Counts at the Census Block Level
  group_by(
    state_code,
    county_code,
    census_tract_code,
    census_block_code,
    age,
    sex,
    hispanic,
    race97
  ) %>%
  summarise(
    across(starts_with("pop_"), ~ sum(.x, na.rm = TRUE)),
    .groups = "drop"
  ) %>%
  # Generate & Evaluate 0/1 Race-Ethnicity Indicators
  create_race_eth_indicators(df = .) %>%
  evaluate_race_eth_indicators(df = .) %>%
  # Left Join to Add Data Quality Indicators
  left_join(
    tbl(con, "DQ_CENSUS_BLOCK") %>%
      select(
        state_code,
        county_code,
        census_tract_code,
        census_block_code,
        starts_with("DQ_FLAG")
      ),
    by = c(
      "state_code",
      "county_code",
      "census_tract_code",
      "census_block_code"
    )
  ) %>%
  # Left Join FIPS CROSSWALK Information to Add a State and County Labels
  left_join(
    tbl(con, "FIPS_CROSSWALK"),
    by = c("state_code", "county_code")
  ) %>%
  # Order Rows
  arrange(
    state_code,
    county_code,
    census_tract_code,
    census_block_code,
    age,
    sex,
    hispanic,
    race97
  ) %>%
  # Order Columns
  select(
    state,
    state_code,
    county,
    county_code,
    census_tract_code,
    census_block_code,
    age,
    sex,
    hispanic,
    race97,
    race_eth_number,
    race_eth_combination,
    starts_with("pop"),
    ends_with("_01"),
    starts_with("DQ_FLAG")
  ) %>%
  # Create CENSUS_BLOCK DuckDB table
  compute(name = "CENSUS_BLOCK", temporary = FALSE) # materialize as a real, persistent table


# Step 5: Remove RAW_UPLOAD Table -----
# dbExecute(con, "DROP TABLE IF EXISTS RAW_UPLOAD") # Only run this after you are certain everything is setup as desired! If not you will have to run API Pull code again (takes ~80 minutes to complete)

# Step 6: Disconnect from DuckDB -----
dbDisconnect(con) # Close database connection after finishing run all of R script
