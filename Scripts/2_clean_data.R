# 2_clean_data.R

# Connect to DuckDB -----
con <- dbConnect(duckdb::duckdb(), params$duckdb_filepath)

# Step 0: Create CLEAN_UPLOAD Table (Clean Variables & Join RAW_UPLOAD & GEOGRAPHIC_CROSSWALK) -----
tbl(con, "RAW_UPLOAD") %>%
  # Convert Variables to Proper Data Types
  mutate(
    block20l = as.character(block20l),
    hispanic = as.character(hispanic),
    race97 = as.character(race97)
  ) %>%
  # Rename Census Block Code variable
  rename(census_block_code = block20l) %>%
  # Recode Sex
  mutate(
    sex = case_when(
      sex == "F" ~ "Female",
      sex == "M" ~ "Male",
      TRUE ~ NA_character_
    )
  ) %>%
  # Left Join GEOGRAPHIC_CROSSWALK To RAW_UPLOAD
  left_join(
    .,
    geo_cw_tbl %>%
      # Subset & Rename select Geographies
      select(
        state_code = state,
        cd_code = congdist22,
        county_name = countyname,
        sd_name = sduniname,
        census_tract_code = tract20l,
        census_block_group_code = blkgrp20l,
        census_block_code = block20l,
        zcta = zcta5
      ),
    by = "census_block_code"
  ) %>%
  # Recode state_code to state
  mutate(state = ifelse(state_code == "53", "WA", NA)) %>%
  relocate(state, .before = "cd_code") %>%
  select(-state_code) %>%
  # Save as CLEAN_UPLOAD DuckDB Table
  compute(name = "CLEAN_UPLOAD", temporary = FALSE, overwrite = TRUE) # materialize as a real, persistent table; overwrite previously saved tables

# Step 1: Designate Table Connections -----
geo_cw_tbl <- tbl(con, "GEOGRAPHIC_CROSSWALK")
raw_upload_tbl <- tbl(con, "RAW_UPLOAD")
clean_upload_tbl <- tbl(con, "CLEAN_UPLOAD")

# Step 2: Create Data Quality Checks -----
## Note: Per WA OFM End User Agreement the Data Quality Check Should Be (4,300+ Overall Population for a Geography - Size of Average Census Tract)

## 2a: STATE -----
clean_upload_tbl %>%
  # Count Overall Jurisdiction Population
  summarize_pop(df = ., state) %>% # Summarize Annual Population Estimates by State
  # Create Data Quality Flag
  create_dq_flags(df = .) %>%
  # Rename DQ Flag Variables
  rename_dq_flags(df = .) %>%
  # Create DQ_STATE DuckDB Table
  compute(name = "DQ_STATE", temporary = TRUE) # (temporary = TRUE) This table will disappear once the connection has been ended (can easily be re-made)

## 2b: CONGRESSIONAL_DISTRICT -----
clean_upload_tbl %>%
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

## 2c: COUNTY -----
clean_upload_tbl %>%
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

## 2d: SCHOOL_DISTRICT -----
clean_upload_tbl %>%
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

## 2e: CENSUS_TRACT -----
clean_upload_tbl %>%
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

## 2f: CENSUS_BLOCK_GROUP -----
clean_upload_tbl %>%
  # Count Overall Jurisdiction Population
  summarize_pop(
    df = .,
    county_name,
    census_tract_code,
    census_block_group_code
  ) %>% # Summarize Annual Population Estimates by County & Census Block Group
  # Create Data Quality Flag
  create_dq_flags(df = .) %>%
  # Rename DQ Flag Variables
  rename_dq_flags(df = .) %>%
  # Arrange County Name, Census Tract, & Census Block Group Codes
  arrange(county_name, census_tract_code, census_block_group_code) %>%
  # Create DQ_CENSUS_BLOCK_GROUP DuckDB Table
  compute(name = "DQ_CENSUS_BLOCK_GROUP", temporary = TRUE) # (temporary = TRUE) This table will disappear once the connection has been ended (can easily be re-made)

## 2g: CENSUS_BLOCK -----
clean_upload_tbl %>%
  # Count Overall Jurisdiction Population
  summarize_pop(
    df = .,
    county_name,
    census_tract_code,
    census_block_group_code,
    census_block_code
  ) %>% # Summarize Annual Population Estimates by County, Census Tract, Census Block Group, and Census Blocks
  # Create Data Quality Flag
  create_dq_flags(df = .) %>%
  # Rename DQ Flag Variables
  rename_dq_flags(df = .) %>%
  # Arrange County Name, Census Tract, & Census Block Codes
  arrange(
    county_name,
    census_tract_code,
    census_block_group_code,
    census_block_code
  ) %>%
  # Create DQ_CENSUS_BLOCK DuckDB Table
  compute(name = "DQ_CENSUS_BLOCK", temporary = TRUE) # (temporary = TRUE) This table will disappear once the connection has been ended (can easily be re-made)

## 2h: ZCTA -----

clean_upload_tbl %>%
  # Count Overall Jurisdiction Population
  summarize_pop(
    df = .,
    zcta
  ) %>% # Summarize Annual Population Estimates by ZCTA
  # Create Data Quality Flag
  create_dq_flags(df = .) %>%
  # Rename DQ Flag Variables
  rename_dq_flags(df = .) %>%
  # Arrange County Name, Census Tract, & Census Block Codes
  arrange(
    zcta
  ) %>%
  # Create DQ_ZCTA DuckDB Table
  compute(name = "DQ_ZCTA", temporary = TRUE) # (temporary = TRUE) This table will disappear once the connection has been ended (can easily be re-made)

# Step 3: Create Population Aggregate Summary Tables -----

## 3a: STATE -----

clean_upload_tbl %>%
  # Aggregate Age-Sex-Race/Ethnicity Population Counts at the State Level
  summarize_pop(df = ., state, age, sex, hispanic, race97) %>%
  # Generate & Evaluate 0/1 Race-Ethnicity Indicators
  create_race_eth_indicators(df = .) %>%
  evaluate_race_eth_indicators(df = .) %>%
  # Left Join to Add Data Quality Indicators
  left_join(
    tbl(con, "DQ_STATE") %>% select(state, starts_with("DQ_FLAG")),
    by = "state"
  ) %>%
  # Order Rows
  arrange(
    state,
    age,
    sex,
    hispanic,
    race97
  ) %>%
  # Order Columns
  select(
    state,
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

## 3b: CONGRESSIONAL_DISTRICT -----

clean_upload_tbl %>%
  # Aggregate Age-Sex-Race/Ethnicity Population Counts at the Congressional District Level
  summarize_pop(df = ., cd_code, age, sex, hispanic, race97) %>%
  # Generate & Evaluate 0/1 Race-Ethnicity Indicators
  create_race_eth_indicators(df = .) %>%
  evaluate_race_eth_indicators(df = .) %>%
  # Left Join to Add Data Quality Indicators
  left_join(
    tbl(con, "DQ_CONGRESSIONAL_DISTRICT") %>%
      select(cd_code, starts_with("DQ_FLAG")),
    by = "cd_code"
  ) %>%
  # Order Rows
  arrange(
    cd_code,
    age,
    sex,
    hispanic,
    race97
  ) %>%
  # Order Columns
  select(
    cd_code,
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
  compute(name = "CONGRESSIONAL_DISTRICT", temporary = FALSE, overwrite = TRUE) # materialize as a real, persistent table; overwrite previously saved tables

## 3c: COUNTY -----

clean_upload_tbl %>%
  # Aggregate Age-Sex-Race/Ethnicity Population Counts at the County Level
  summarize_pop(df = ., county_name, age, sex, hispanic, race97) %>%
  # Generate & Evaluate 0/1 Race-Ethnicity Indicators
  create_race_eth_indicators(df = .) %>%
  evaluate_race_eth_indicators(df = .) %>%
  # Left Join to Add Data Quality Indicators
  left_join(
    tbl(con, "DQ_COUNTY") %>%
      select(county_name, starts_with("DQ_FLAG")),
    by = "county_name"
  ) %>%
  # Order Rows
  arrange(
    county_name,
    age,
    sex,
    hispanic,
    race97
  ) %>%
  # Order Columns
  select(
    county_name,
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

## 3d: SCHOOL_DISTRICT -----

clean_upload_tbl %>%
  # Aggregate Age-Sex-Race/Ethnicity Population Counts at the School District Level
  summarize_pop(df = ., sd_name, age, sex, hispanic, race97) %>%
  # Generate & Evaluate 0/1 Race-Ethnicity Indicators
  create_race_eth_indicators(df = .) %>%
  evaluate_race_eth_indicators(df = .) %>%
  # Left Join to Add Data Quality Indicators
  left_join(
    tbl(con, "DQ_SCHOOL_DISTRICT") %>%
      select(sd_name, starts_with("DQ_FLAG")),
    by = "sd_name"
  ) %>%
  # Order Rows
  arrange(
    sd_name,
    age,
    sex,
    hispanic,
    race97
  ) %>%
  # Order Columns
  select(
    sd_name,
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
  compute(name = "SCHOOL_DISTRICT", temporary = FALSE, overwrite = TRUE) # materialize as a real, persistent table; overwrite previously saved tables

## 3e: CENSUS_TRACT -----

clean_upload_tbl %>%
  # Aggregate Age-Sex-Race/Ethnicity Population Counts at the Census Tract Level
  summarize_pop(
    df = .,
    county_name,
    census_tract_code,
    age,
    sex,
    hispanic,
    race97
  ) %>%
  # Generate & Evaluate 0/1 Race-Ethnicity Indicators
  create_race_eth_indicators(df = .) %>%
  evaluate_race_eth_indicators(df = .) %>%
  # Left Join to Add Data Quality Indicators
  left_join(
    tbl(con, "DQ_CENSUS_TRACT") %>%
      select(
        county_name,
        census_tract_code,
        starts_with("DQ_FLAG")
      ),
    by = c("county_name", "census_tract_code")
  ) %>%
  # Order Rows
  arrange(
    county_name,
    census_tract_code,
    age,
    sex,
    hispanic,
    race97
  ) %>%
  # Order Columns
  select(
    county_name,
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

## 3f: CENSUS_BLOCK_GROUP -----

clean_upload_tbl %>%
  # Aggregate Age-Sex-Race/Ethnicity Population Counts at the Census Tract Level
  summarize_pop(
    df = .,
    county_name,
    census_tract_code,
    census_block_group_code,
    age,
    sex,
    hispanic,
    race97
  ) %>%
  # Generate & Evaluate 0/1 Race-Ethnicity Indicators
  create_race_eth_indicators(df = .) %>%
  evaluate_race_eth_indicators(df = .) %>%
  # Left Join to Add Data Quality Indicators
  left_join(
    tbl(con, "DQ_CENSUS_BLOCK_GROUP") %>%
      select(
        county_name,
        census_tract_code,
        census_block_group_code,
        starts_with("DQ_FLAG")
      ),
    by = c("county_name", "census_tract_code", "census_block_group_code")
  ) %>%
  # Order Rows
  arrange(
    county_name,
    census_tract_code,
    census_block_group_code,
    age,
    sex,
    hispanic,
    race97
  ) %>%
  # Order Columns
  select(
    county_name,
    census_tract_code,
    census_block_group_code,
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
  # Create CENSUS_BLOCK_GROUP DuckDB table
  compute(name = "CENSUS_BLOCK_GROUP", temporary = FALSE, overwrite = TRUE) # materialize as a real, persistent table; overwrite previously saved tables

## 3g: CENSUS_BLOCK -----

clean_upload_tbl %>%
  # Aggregate Age-Sex-Race/Ethnicity Population Counts at the Census Block Level
  summarize_pop(
    df = .,
    county_name,
    census_tract_code,
    census_block_group_code,
    census_block_code,
    age,
    sex,
    hispanic,
    race97
  ) %>%
  # Generate & Evaluate 0/1 Race-Ethnicity Indicators
  create_race_eth_indicators(df = .) %>%
  evaluate_race_eth_indicators(df = .) %>%
  # Left Join to Add Data Quality Indicators
  left_join(
    tbl(con, "DQ_CENSUS_BLOCK") %>%
      select(
        county_name,
        census_tract_code,
        census_block_group_code,
        census_block_code,
        starts_with("DQ_FLAG")
      ),
    by = c(
      "county_name",
      "census_tract_code",
      "census_block_group_code",
      "census_block_code"
    )
  ) %>%
  # Order Rows
  arrange(
    county_name,
    census_tract_code,
    census_block_group_code,
    census_block_code,
    age,
    sex,
    hispanic,
    race97
  ) %>%
  # Order Columns
  select(
    county_name,
    census_tract_code,
    census_block_group_code,
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

## 3h: ZCTA -----

clean_upload_tbl %>%
  # Aggregate Age-Sex-Race/Ethnicity Population Counts at the ZCTA Level
  summarize_pop(
    df = .,
    zcta,
    age,
    sex,
    hispanic,
    race97
  ) %>%
  # Generate & Evaluate 0/1 Race-Ethnicity Indicators
  create_race_eth_indicators(df = .) %>%
  evaluate_race_eth_indicators(df = .) %>%
  # Left Join to Add Data Quality Indicators
  left_join(
    tbl(con, "DQ_ZCTA") %>%
      select(
        zcta,
        starts_with("DQ_FLAG")
      ),
    by = "zcta"
  ) %>%
  # Order Rows
  arrange(
    zcta,
    age,
    sex,
    hispanic,
    race97
  ) %>%
  # Order Columns
  select(
    zcta,
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
  # Create ZCTA DuckDB table
  compute(name = "ZCTA", temporary = FALSE, overwrite = TRUE) # materialize as a real, persistent table; overwrite previously saved tables
