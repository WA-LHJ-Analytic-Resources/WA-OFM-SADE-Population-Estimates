# 2_clean_data.R

# Step 0 : Designate Table Connections -----
raw_upload_tbl <- tbl(con, "RAW_UPLOAD")
geo_cw_tbl <- tbl(con, "GEOGRAPHIC_CROSSWALK")

# Step 1: Create Data Quality Checks -----
## Note: Per WA OFM End User Agreement the Data Quality Check Should Be (4,300+ Overall Population for a Geography - Size of Average Census Tract)

## STATE
raw_upload_tbl %>%
  # Left Join Related State Code (from block20l)
  left_join(
    .,
    geo_cw_tbl %>% select(block20l, state_code = state),
    by = "block20l"
  ) %>%
  # Count Overall Jurisdiction Population
  summarize_pop(df = ., state_code) %>% # Summarize Annual Population Estimates by State
  # Create Data Quality Flag
  create_dq_flags(df = .) %>%
  # Rename DQ Flag Variables
  rename_dq_flags(df = .) %>%
  # Create DQ_STATE DuckDB Table
  compute(name = "DQ_STATE", temporary = TRUE) # (temporary = TRUE) This table will disappear once the connection has been ended (can easily be re-made)

## CONGRESSIONAL_DISTRICT
raw_upload_tbl %>%
  # Left Join Congressional District Codes (from block20l)
  left_join(
    .,
    geo_cw_tbl %>%
      select(
        block20l,
        cd_code = congdist22
      ),
    by = "block20l"
  ) %>%
  # Count Overall Jurisdiction Population
  summarize_pop(df = ., cd_code) %>% # Summarize Annual Population Estimates by Congressional District Code (Congressional Districts are larger than counties and do not neatly encompass multiple counties)
  # Create Data Quality Flag
  create_dq_flags(df = .) %>%
  # Rename DQ Flag Variables
  rename_dq_flags(df = .) %>%
  # Arrange Congressional District Codes
  arrange(cd_code) %>%
  # Create DQ_CONGRESSIONAL_DISTRICT DuckDB Table
  compute(name = "DQ_CONGRESSIONAL_DISTRICT", temporary = TRUE)

## COUNTY
raw_upload_tbl %>%
  # Left Join Related State & County Codes (from block20l)
  left_join(
    .,
    geo_cw_tbl %>%
      select(
        block20l,
        county_name = countyname
      ),
    by = "block20l"
  ) %>%
  # Count Overall Jurisdiction Population
  summarize_pop(df = ., county_name) %>% # Summarize Annual Population Estimates by County
  # Create Data Quality Flag
  create_dq_flags(df = .) %>%
  # Rename DQ Flag Variables
  rename_dq_flags(df = .) %>%
  # Arrange County Names
  arrange(county_name) %>%
  # Create DQ_COUNTY DuckDB Table
  compute(name = "DQ_COUNTY", temporary = TRUE) # (temporary = TRUE) This table will disappear once the connection has been ended (can easily be re-made)

## CENSUS_TRACT
raw_upload_tbl %>%
  # Left Join Related County Names & Census Tract Codes (from block20l)
  left_join(
    .,
    geo_cw_tbl %>%
      select(
        block20l,
        county_name = countyname,
        census_tract_code = tract20l
      ),
    by = "block20l"
  ) %>%
  # Count Overall Jurisdiction Population
  summarize_pop(df = ., county_name, census_tract_code) %>% # Summarize Annual Population Estimates by County & Census Tract
  # Create Data Quality Flag
  create_dq_flags(df = .) %>%
  # Rename DQ Flag Variables
  rename_dq_flags(df = .) %>%
  # Arrange County Name & Census Tract Codes
  arrange(county_name, census_tract_code) %>%
  # Create DQ_CENSUS_TRACT DuckDB Table
  compute(name = "DQ_CENSUS_TRACT", temporary = TRUE) # (temporary = TRUE) This table will disappear once the connection has been ended (can easily be re-made)

## SCHOOL_DISTRICT
raw_upload_tbl %>%
  # Left Join Related School Districts (from block20l)
  left_join(
    .,
    geo_cw_tbl %>%
      select(
        block20l,
        sd_code = sduni,
        sd_name = sduniname
      ),
    by = "block20l"
  ) %>%
  # Count Overall Jurisdiction Population
  summarize_pop(df = ., sd_name) %>% # Summarize Annual Population Estimates by School District (Note: Some School District straddle multiple county boundaries)
  # Create Data Quality Flag
  create_dq_flags(df = .) %>%
  # Rename DQ Flag Variables
  rename_dq_flags(df = .) %>%
  # Arrange School District Names
  arrange(sd_name) %>%
  # Create DQ_SCHOOL_DISTRICT DuckDB Table
  compute(name = "DQ_SCHOOL_DISTRICT", temporary = TRUE)


## CENSUS_BLOCK
raw_upload_tbl %>%
  # Left Join Related County, Census Tract, and Census Block Information (from block20l)
  left_join(
    .,
    geo_cw_tbl %>%
      select(
        block20l,
        county_name = countyname,
        census_tract_code = tract20l
      ),
    by = "block20l"
  ) %>%
  # Rename block20l to census_block_code
  rename(census_block_code = block20l) %>%
  # Count Overall Jurisdiction Population
  summarize_pop(df = ., county_name, census_tract_code, census_block_code) %>% # Summarize Annual Population Estimates by County, Census Tract, and Census Blocks
  # Create Data Quality Flag
  create_dq_flags(df = .) %>%
  # Rename DQ Flag Variables
  rename_dq_flags(df = .) %>%
  # Arrange County Name, Census Tract, & Census Block Codes
  arrange(county_name, census_tract_code, census_block_code) %>%
  # Create DQ_CENSUS_BLOCK DuckDB Table
  compute(name = "DQ_CENSUS_BLOCK", temporary = TRUE) # (temporary = TRUE) This table will disappear once the connection has been ended (can easily be re-made)


# Step 2a: Create STATE DuckDB Table -----

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
  compute(name = "STATE", temporary = FALSE, overwrite = TRUE) # materialize as a real, persistent table; overwrite previously saved tables

# Step 2b: Create COUNTY DuckDB Table -----

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
  compute(name = "COUNTY", temporary = FALSE, overwrite = TRUE) # materialize as a real, persistent table; overwrite previously saved tables

# Step 2c: Create CENSUS_TRACT DuckDB Table -----

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
  compute(name = "CENSUS_TRACT", temporary = FALSE, overwrite = TRUE) # materialize as a real, persistent table; overwrite previously saved tables

# Step 2d: Create CENSUS_BLOCK DuckDB Table -----

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
  compute(name = "CENSUS_BLOCK", temporary = FALSE, overwrite = TRUE) # materialize as a real, persistent table; overwrite previously saved tables

# Step 3: Remove RAW_UPLOAD Table -----

## UNCOMMENT THE R CODE BELOW!
## NOTE: Only run this after you are certain everything is setup as desired! If not you will have to run API Pull code again (takes ~80 minutes to complete)

# dbExecute(con, "DROP TABLE IF EXISTS RAW_UPLOAD")
