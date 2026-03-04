# 3_use_data.R

rm(list = ls())
params <- list()

# Step 0: Install/Load Packages -----
pacman::p_load(
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

# Step 0: Connect to DuckDB File -----
params$duckdb_filepath <- here(
  Sys.getenv("DUCKDB_FILEPATH"),
  "WA_OFM_SADE_Population_Data.duckdb"
)
con <- dbConnect(duckdb::duckdb(), params$duckdb_filepath)

## Install & Load HTTPFS extension to enable streaming
# dbExecute(con, "INSTALL httpfs;")
# dbExecute(con, "LOAD httpfs;")

# Step 1: Define Parameters -----

## Define custom age groups
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

## Extract AOIC 0/1 Indicator & Data Quality Variable Names
params$aoic_cols <- tbl(con, "STATE") %>%
  select(ends_with("_01")) %>%
  colnames()

params$dq_cols <- tbl(con, "STATE") %>%
  select(starts_with("DQ_FLAG")) %>%
  colnames()

# Step 2a: Extract 2020-2025 Washington State SADE Estimates ------

WA <- tbl(con, "STATE") %>%
  # Create Custom Age Groups
  create_custom_age_groups(
    df = .,
    breaks = params$age_breaks,
    labels = params$age_labels
  ) %>%
  # Aggregate Population Estimates by State, Age Categories, and Race-Ethnicity (including 0/1 indicators)
  group_by(
    state,
    age_group,
    sex,
    hispanic,
    race97,
    race_eth_number,
    race_eth_combination,
    !!!syms(params$dq_cols), # takes a string vector of variable names and evaluates it as dplyr non-standard notation
    !!!syms(params$aoic_cols)
  ) %>%
  summarize(
    across(starts_with("pop_"), ~ sum(.x, na.rm = TRUE)),
    .groups = "drop"
  ) %>%
  # Collect the Data in Memory (RAM)
  collect() %>%
  # Factor age_group variable (to arrange proper row-ordering of the data)
  mutate(age_group = factor(age_group, levels = params$age_labels)) %>%
  arrange(
    state,
    age_group,
    sex,
    race_eth_number,
    race_eth_combination
  ) %>%
  # Pivot Longer (1 Row --> A Groups Single Year SADE Estimate; Instead of A Groups Multiple Years of SADE)
  ## This code pivots (and maintains a link) between population estimates and DQ Flags
  pivot_longer(
    cols = matches("^(pop|DQ_FLAG)_\\d{4}$"), # For this function, select all columns that look like <measure>_<year>. Ex: pop_2025, DQ_FLAG_2025
    names_to = c(".value", "year"), # Puts 1st capture group into column names (flexibly provided by .value); Puts 2nd capture group into "Year"
    names_pattern = "^(pop|DQ_FLAG)_(\\d{4})$", # Split each column name into 2 capture groups: 1st capture group becomes data columns (.value); 2nd capture group becomes "Year"
    # (optional) convert Year to integer
    names_transform = list(year = as.integer)
  ) %>%
  rename(population = pop) %>%
  # Reorder columns (Year to front, params$aoic_cols to back)
  relocate(year, .before = everything()) %>%
  relocate(ends_with("_01"), .after = everything())
# Filter Rows
# filter(year == 2024) # EDIT HERE TO FILTER TO YEARS OF DATA OR SADE ESTIMATES FOR SPECIFIC POPULATION GROUPS

# Step 2b: Extract 2020-2025 Snohomish County SADE Estimates -----

SNOCO <- tbl(con, "COUNTY") %>%
  # Create Custom Age Groups
  create_custom_age_groups(
    df = .,
    breaks = params$age_breaks,
    labels = params$age_labels
  ) %>%
  # Aggregate Population Estimates by State, County, Age Categories, and Race-Ethnicity (including 0/1 indicators)
  group_by(
    state,
    county,
    age_group,
    sex,
    hispanic,
    race97,
    race_eth_number,
    race_eth_combination,
    !!!syms(params$dq_cols), # takes a string vector of variable names and evaluates it as dplyr non-standard notation
    !!!syms(params$aoic_cols)
  ) %>%
  summarize(
    across(starts_with("pop_"), ~ sum(.x, na.rm = TRUE)),
    .groups = "drop"
  ) %>%
  # Collect the Data in Memory (RAM)
  collect() %>%
  # Factor age_group variable (to arrange proper row-ordering of the data)
  mutate(age_group = factor(age_group, levels = params$age_labels)) %>%
  arrange(
    state,
    county,
    age_group,
    sex,
    race_eth_number,
    race_eth_combination
  ) %>%
  # Pivot Longer (1 Row --> A Groups Single Year SADE Estimate; Instead of A Groups Multiple Years of SADE)
  ## This code pivots (and maintains a link) between population estimates and DQ Flags
  pivot_longer(
    cols = matches("^(pop|DQ_FLAG)_\\d{4}$"), # For this function, select all columns that look like <measure>_<year>. Ex: pop_2025, DQ_FLAG_2025
    names_to = c(".value", "year"), # Puts 1st capture group into column names (flexibly provided by .value); Puts 2nd capture group into "Year"
    names_pattern = "^(pop|DQ_FLAG)_(\\d{4})$", # Split each column name into 2 capture groups: 1st capture group becomes data columns (.value); 2nd capture group becomes "Year"
    # (optional) convert Year to integer
    names_transform = list(year = as.integer)
  ) %>%
  rename(population = pop) %>%
  # Reorder columns (year to front)
  relocate(year, .before = everything()) %>%
  relocate(ends_with("_01"), .after = everything()) %>%
  # Filter Rows
  filter(county == "Snohomish") # EDIT HERE TO FILTER TO YEARS OF DATA OR SADE ESTIMATES FOR OTHER COUNTIES/SPECIFIC POPULATION GROUPS

# Step 3a: Create Washington State AOIC Summary Tables -----

## Create WA AOIC TABLE
WA_TABLE <- WA %>%
  pivot_longer(
    cols = all_of(params$aoic_cols),
    names_to = "Race_Ethnicity_AOIC",
    values_to = "Indicator"
  ) %>%
  mutate(
    Race_Ethnicity_AOIC = str_remove_all(Race_Ethnicity_AOIC, "_01"),
  ) %>%
  filter(Indicator == 1) # This filters only to the rows (Race-Eth categories) that an AOIC category applies to. (Ex: 1 AOIC Category; 3 White-Black-Hispanic --> would be filter to the rows where 1) Race_Ethnicity_AOIC  == "White", 2) Race_Ethnicity_AOIC== "Black", and 3) Race_Ethnicity_AOIC == "Hispanic")

## Create WA SUMMARY (list of summaries)
WA_SUMMARY <- list()

## [2] By Year & AOIC Race-Eth
WA_SUMMARY[['Year_Race_Eth']] <- WA_TABLE %>%
  # Calculate Yearly AOIC Population Estimates
  group_by(year, Race_Ethnicity_AOIC, DQ_FLAG) %>%
  summarize(population = sum(population, na.rm = TRUE), .groups = "drop") %>%
  # Round population estimate to whole number
  mutate(population = round(population, 0)) %>%
  # Calculate Population Total (Non-Mutually Exclusive)
  group_by(year) %>%
  mutate(total_non_me_population = sum(population)) %>%
  ungroup() %>%
  # Calculate Proportion
  mutate(
    proportion = population / total_non_me_population,
    percentage = paste0(round(proportion * 100, 1), "%")
  )

## [3] By Year, Sex, & AOIC Race-Eth
WA_SUMMARY[['Year_Sex_Race_Eth']] <- WA_TABLE %>%
  # Calculate Yearly AOIC Population Estimates
  group_by(year, sex, Race_Ethnicity_AOIC, DQ_FLAG) %>%
  summarize(population = sum(population, na.rm = TRUE), .groups = "drop") %>%
  # Round population estimate to whole number
  mutate(population = round(population, 0)) %>%
  # Calculate Population Total (Non-Mutually Exclusive)
  group_by(year) %>%
  mutate(total_non_me_population = sum(population)) %>%
  ungroup() %>%
  # Calculate Proportion
  mutate(
    proportion = population / total_non_me_population,
    percentage = paste0(round(proportion * 100, 1), "%")
  )

## [3] By Year, Age Group, & AOIC Race-Eth
WA_SUMMARY[['Year_AgeGroup_Race_Eth']] <- WA_TABLE %>%
  # Calculate Yearly AOIC Population Estimates
  group_by(year, age_group, Race_Ethnicity_AOIC, DQ_FLAG) %>%
  summarize(population = sum(population, na.rm = TRUE), .groups = "drop") %>%
  # Round population estimate to whole number
  mutate(population = round(population, 0)) %>%
  # Calculate Population Total (Non-Mutually Exclusive)
  group_by(year) %>%
  mutate(total_non_me_population = sum(population)) %>%
  ungroup() %>%
  # Calculate Proportion
  mutate(
    proportion = population / total_non_me_population,
    percentage = paste0(round(proportion * 100, 1), "%")
  )

## [4] By Year, Sex, Age Group, & AOIC Race-Eth
WA_SUMMARY[['Year_Sex_AgeGroup_Race_Eth']] <- WA_TABLE %>%
  # Calculate Yearly AOIC Population Estimates
  group_by(year, sex, age_group, Race_Ethnicity_AOIC, DQ_FLAG) %>%
  summarize(population = sum(population, na.rm = TRUE), .groups = "drop") %>%
  # Round population estimate to whole number
  mutate(population = round(population, 0)) %>%
  # Calculate Population Total (Non-Mutually Exclusive)
  group_by(year) %>%
  mutate(total_non_me_population = sum(population)) %>%
  ungroup() %>%
  # Calculate Proportion
  mutate(
    proportion = population / total_non_me_population,
    percentage = paste0(round(proportion * 100, 1), "%")
  )

# Step 3b: Create Snohomish County AOIC Summary Tables -----

## Create SNOCO AOIC TABLE
SNOCO_TABLE <- SNOCO %>%
  pivot_longer(
    cols = all_of(params$aoic_cols),
    names_to = "Race_Ethnicity_AOIC",
    values_to = "Indicator"
  ) %>%
  mutate(
    Race_Ethnicity_AOIC = str_remove_all(Race_Ethnicity_AOIC, "_01"),
  ) %>%
  filter(Indicator == 1)

## Create SNOCO SUMMARY (list of summaries)
SNOCO_SUMMARY <- list()

## [2] By Year & AOIC Race-Eth
SNOCO_SUMMARY[['Year_Race_Eth']] <- SNOCO_TABLE %>%
  # Calculate Yearly AOIC Population Estimates
  group_by(year, Race_Ethnicity_AOIC, DQ_FLAG) %>%
  summarize(population = sum(population, na.rm = TRUE), .groups = "drop") %>%
  # Round population estimate to whole number
  mutate(population = round(population, 0)) %>%
  # Calculate Population Total (Non-Mutually Exclusive)
  group_by(year) %>%
  mutate(total_non_me_population = sum(population)) %>%
  ungroup() %>%
  # Calculate Proportion
  mutate(
    proportion = population / total_non_me_population,
    percentage = paste0(round(proportion * 100, 1), "%")
  )

## [3] By Year, Sex, & AOIC Race-Eth
SNOCO_SUMMARY[['Year_Sex_Race_Eth']] <- SNOCO_TABLE %>%
  # Calculate Yearly AOIC Population Estimates
  group_by(year, sex, Race_Ethnicity_AOIC, DQ_FLAG) %>%
  summarize(population = sum(population, na.rm = TRUE), .groups = "drop") %>%
  # Round population estimate to whole number
  mutate(population = round(population, 0)) %>%
  # Calculate Population Total (Non-Mutually Exclusive)
  group_by(year) %>%
  mutate(total_non_me_population = sum(population)) %>%
  ungroup() %>%
  # Calculate Proportion
  mutate(
    proportion = population / total_non_me_population,
    percentage = paste0(round(proportion * 100, 1), "%")
  )

## [3] By Year, Age Group, & AOIC Race-Eth
SNOCO_SUMMARY[['Year_AgeGroup_Race_Eth']] <- SNOCO_TABLE %>%
  # Calculate Yearly AOIC Population Estimates
  group_by(year, age_group, Race_Ethnicity_AOIC, DQ_FLAG) %>%
  summarize(population = sum(population, na.rm = TRUE), .groups = "drop") %>%
  # Round population estimate to whole number
  mutate(population = round(population, 0)) %>%
  # Calculate Population Total (Non-Mutually Exclusive)
  group_by(year) %>%
  mutate(total_non_me_population = sum(population)) %>%
  ungroup() %>%
  # Calculate Proportion
  mutate(
    proportion = population / total_non_me_population,
    percentage = paste0(round(proportion * 100, 1), "%")
  )

## [4] By Year, Sex, Age Group, & AOIC Race-Eth
SNOCO_SUMMARY[['Year_Sex_AgeGroup_Race_Eth']] <- SNOCO_TABLE %>%
  # Calculate Yearly AOIC Population Estimates
  group_by(year, sex, age_group, Race_Ethnicity_AOIC, DQ_FLAG) %>%
  summarize(population = sum(population, na.rm = TRUE), .groups = "drop") %>%
  # Round population estimate to whole number
  mutate(population = round(population, 0)) %>%
  # Calculate Population Total (Non-Mutually Exclusive)
  group_by(year) %>%
  mutate(total_non_me_population = sum(population)) %>%
  ungroup() %>%
  # Calculate Proportion
  mutate(
    proportion = population / total_non_me_population,
    percentage = paste0(round(proportion * 100, 1), "%")
  )


# Disconnect from DuckDB -----
dbDisconnect(con) # Close database connection after finishing run all of R script
