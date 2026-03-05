# 3_use_data.R

# Connect to DuckDB file ------
con <- dbConnect(duckdb::duckdb(), params$duckdb_filepath)

# Define Additional Parameters -----

## Extract AOIC 0/1 Indicator & Data Quality Variable Names
params$aoic_cols <- tbl(con, "STATE") %>%
  select(ends_with("_01")) %>%
  colnames()

params$dq_cols <- tbl(con, "STATE") %>%
  select(starts_with("DQ_FLAG")) %>%
  colnames()

# Extract 2020-2025 Washington State SADE Estimates ------

## Output: Data frame where 1 row refers to 1 SADE population estimate (for WA state), for a given year for a specific age group, sex, and AOIC race-ethnicity category subpopulation.

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

## (OPTIONAL) Apply additional filters below to subset SADE Estimates to specific time periods or population subgroups
# WA <- WA %>%
# filter(year == 2024) # EDIT HERE TO FILTER TO YEARS OF DATA OR SADE ESTIMATES FOR SPECIFIC POPULATION GROUPS

# Extract 2020-2025 County of Interest SADE Estimates -----

## Output: Data frame where 1 row refers to 1 SADE population estimate (for 1 county of interest via params$county_of_interest), for a given year for a specific age group, sex, and AOIC race-ethnicity category subpopulation.

COUNTY <- tbl(con, "COUNTY") %>%
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
  filter(county == params$county_of_interest)

# Create Washington & County of Interest Staging Tables -----

## Input: Data frame where 1 row refers to 1 SADE population estimate (for WA state), for a given year for a specific age group, sex, and AOIC race-ethnicity category subpopulation.
## Output: Data frame where 1 row refers to 1 SADE population estimate (for WA state), for a given year for a specific age group, sex, and 1 race-ethnicity category.
## For example, there is 1 row with a SADE estimate of 5,000 for a "Black", "NHPI", and "Hispanic" AOIC race-ethnicity subpopulation (disregarding year, age, and sex) in the input data frame
## in the output data frame, there will be 3 rows (Black == 5,000, NHPI == 5,000, and Hispanic == 5,000).

## Note: These output tables will allow us to summarize the totals across the AOIC non-mutually exclusive categories (in future steps)

## Create WA Staging TABLE
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

## Create County of Interest Staging TABLE
COUNTY_TABLE <- COUNTY %>%
  pivot_longer(
    cols = all_of(params$aoic_cols),
    names_to = "Race_Ethnicity_AOIC",
    values_to = "Indicator"
  ) %>%
  mutate(
    Race_Ethnicity_AOIC = str_remove_all(Race_Ethnicity_AOIC, "_01"),
  ) %>%
  filter(Indicator == 1)


# Create Washington Summary Extracts -----

# fmt: skip
{

## Create WA SUMMARY (list of summary data frames)
WA_SUMMARY <- list()

## [2] 
WA_SUMMARY[['Year_Race_Eth']] <- summarize_sade_estimates(df = WA_TABLE, summary_vars = c("year", "Race_Ethnicity_AOIC")) # By Year & AOIC Race-Eth
WA_SUMMARY[['Year_AgeGroup']] <- summarize_sade_estimates(df = WA_TABLE, summary_vars = c("year", "age_group")) # By Year & Age-Group
WA_SUMMARY[['Year_Sex']] <- summarize_sade_estimates(df = WA_TABLE, summary_vars = c("year", "sex")) # By Year & Sex

## [3]
WA_SUMMARY[['Year_Sex_Race_Eth']] <- summarize_sade_estimates(df = WA_TABLE, summary_vars = c("year", "sex", "Race_Ethnicity_AOIC")) #  By Year, Sex, & AOIC Race-Eth
WA_SUMMARY[['Year_AgeGroup_Race_Eth']] <- summarize_sade_estimates(df = WA_TABLE, summary_vars = c("year", "age_group", "Race_Ethnicity_AOIC")) # By Year, Age Group, & AOIC Race-Eth

## [4]
WA_SUMMARY[['Year_Sex_AgeGroup_Race_Eth']] <- summarize_sade_estimates(df = WA_TABLE, summary_vars = c("year", "sex", "age_group", "Race_Ethnicity_AOIC")) #  By Year, Sex, Age Group, & AOIC Race-Eth
  
## Clean variable names
WA_SUMMARY <- WA_SUMMARY %>% map(~ .x %>% janitor::clean_names()) # apply clean_names() to all data frames in the list
}

# Create County of Interest Summary Extracts -----

# fmt: skip
{

## Create COUNTY_SUMMARY (list of summary data frames)
COUNTY_SUMMARY <- list()

## [2] 
COUNTY_SUMMARY[['Year_Race_Eth']] <- summarize_sade_estimates(df = COUNTY_TABLE, summary_vars = c("year", "Race_Ethnicity_AOIC")) # By Year & AOIC Race-Eth
COUNTY_SUMMARY[['Year_AgeGroup']] <- summarize_sade_estimates(df = COUNTY_TABLE, summary_vars = c("year", "age_group")) # By Year & Age-Group
COUNTY_SUMMARY[['Year_Sex']] <- summarize_sade_estimates(df = COUNTY_TABLE, summary_vars = c("year", "sex")) # By Year & Sex

## [3]
COUNTY_SUMMARY[['Year_Sex_Race_Eth']] <- summarize_sade_estimates(df = COUNTY_TABLE, summary_vars = c("year", "sex", "Race_Ethnicity_AOIC")) #  By Year, Sex, & AOIC Race-Eth
COUNTY_SUMMARY[['Year_AgeGroup_Race_Eth']] <- summarize_sade_estimates(df = COUNTY_TABLE, summary_vars = c("year", "age_group", "Race_Ethnicity_AOIC")) # By Year, Age Group, & AOIC Race-Eth

## [4]
COUNTY_SUMMARY[['Year_Sex_AgeGroup_Race_Eth']] <- summarize_sade_estimates(df = COUNTY_TABLE, summary_vars = c("year", "sex", "age_group", "Race_Ethnicity_AOIC")) #  By Year, Sex, Age Group, & AOIC Race-Eth

## Clean variable names
COUNTY_SUMMARY <- COUNTY_SUMMARY %>% map(~ .x %>% janitor::clean_names()) # apply clean_names() to all data frames in the list
}

# Save Summary Extracts -----

## WA Summary Data Frames
writexl::write_xlsx(
  WA_SUMMARY,
  path = here(params$output_folder, "WA_AOIC_Population_Estimates.xlsx")
)

## County of Interest Summary Data Frames
writexl::write_xlsx(
  COUNTY_SUMMARY,
  path = here(
    params$output_folder,
    paste0(params$county_of_interest, "_AOIC_Population_Estimates.xlsx")
  )
)

# Disconnect from DuckDB -----
dbDisconnect(con) # Close database connection after finishing run all of R script

# Clean Up -----
rm(WA, WA_TABLE, WA_SUMMARY, COUNTY, COUNTY_TABLE, COUNTY_SUMMARY)
