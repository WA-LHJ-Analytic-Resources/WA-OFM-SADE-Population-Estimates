# 2_clean_data.R

# Step 1: Create Data Quality Checks -----
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
