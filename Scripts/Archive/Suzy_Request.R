# Suzy_Request.R

# Request Summary -----

## 2 Sets of Data

## 1st Set = Snohomish County Working Age Adults (25-74)

## Pull AOIC Race/Ethnicity Estimates By:
## Geography = Snohomish County [FILTER]
## Ages = 25-74 [FILTER]
## Years = 2024 & 2025 [GROUPING]
## RE Categories: AIAN, ASIAN, BLACK, HISP, NHPI, WHITE [GROUPING]

## Add CHAT Mutually Exclusive Race/Ethnicity Estimates as a comparison.

## 2nd Set = All Snohomish County Population

## Pull AOIC Race/Ethnicity Estimates By:
## Geography = Snohomish County [FILTER]
## Years = 2024 & 2025 [GROUPING]
## RE Categories: AIAN, ASIAN, BLACK, HISP, NHPI, WHITE [GROUPING]

## Add CHAT Mutually Exclusive Race/Ethnicity Estimates as a comparison.

# Setup -----

## Install/Load R Packages
pacman::p_load(DBI, duckdb, here, tidyverse)

## Load Custom Functions
list.files(
  path = here::here("Scripts", "Custom_Functions"),
  pattern = "\\.R$",
  full.names = TRUE,
  recursive = TRUE
) %>%
  lapply(source) # source() all R scripts within Support_Code subfolder (including children subfolders)


## Setup Parameters
params <- list()

## Extract AOIC 0/1 Indicator & Data Quality Variable Names
params$aoic_cols <- c(
  "WHITE_01",
  "BLACK_01",
  "AIAN_01",
  "ASIAN_01",
  "NHPI_01",
  "OTHER_01",
  "HISP_01"
)
params$dq_cols <- c("DQ_FLAG_2024", "DQ_FLAG_2025") # Only using 2024 & 2025 data

## Connect to DuckDB
params$output_folder <- Sys.getenv("OUTPUT_FILEPATH")
params$duckdb_filepath <- here(
  params$output_folder,
  "WA_OFM_SADE_Population_Data.duckdb"
)
con <- dbConnect(duckdb::duckdb(), params$duckdb_filepath)

# Pull & Prepare Mutually Exclusive CHAT Estimates ------

## 1st Set (Working Age Adults - 25 to 74 years)
CHAT_25_74 <- readr::read_csv("CHAT_SNOCO_2024_2025_25_74.csv") %>% # CHAT Data already filtered to 2024-2025, Snohomish County, and Ages 25-74
  # Convert Year & Population to Integers
  mutate(
    Year = as.integer(Year),
    Population = as.integer(Population)
  ) %>%
  # Prepare ME Race/Eth Category Population Estimates
  group_by(Year, Race) %>%
  summarize(Population = sum(Population, na.rm = TRUE)) %>%
  ungroup() %>%
  # Prepare Total Population Estimates
  group_by(Year) %>%
  mutate(Total_Population = sum(Population, na.rm = TRUE)) %>%
  ungroup() %>%
  # Percent of Total Population
  mutate(
    Percent_Total_Population = paste0(
      round((Population / Total_Population) * 100, 1),
      "%"
    )
  ) %>%
  # Add Age Tag
  mutate(Age = "25-74") %>%
  relocate(Age, .before = everything())

## 2nd Set (All Snohomish County Population)
CHAT_All <- readr::read_csv("CHAT_SNOCO_2024_2025.csv") %>% # CHAT Data already filtered to 2024-2025, Snohomish County
  # Convert Year & Population to Integers
  mutate(
    Year = as.integer(Year),
    Population = as.integer(Population)
  ) %>%
  # Prepare ME Race/Eth Category Population Estimates
  group_by(Year, Race) %>%
  summarize(Population = sum(Population, na.rm = TRUE)) %>%
  ungroup() %>%
  # Prepare Total Population Estimates
  group_by(Year) %>%
  mutate(Total_Population = sum(Population, na.rm = TRUE)) %>%
  ungroup() %>%
  # Percent of Total Population
  mutate(
    Percent_Total_Population = paste0(
      round((Population / Total_Population) * 100, 1),
      "%"
    )
  ) %>%
  # Add Age Tag
  mutate(Age = "All") %>%
  relocate(Age, .before = everything())

## Append each data frame together
CHAT_COMBINED <- bind_rows(CHAT_25_74, CHAT_All)

rm(CHAT_25_74, CHAT_All)

# Pull & Prepare AOIC WA OFM SADE Estimates ----

## Step 1: Filter WA OFM SADE County Level Data to Snohomish County & Ages of Interest

## 1st Data Set
SNOHOMISH_25_74 <- tbl(con, "COUNTY") %>%
  # Filter to Snohomish County
  filter(county == "Snohomish") %>%
  # Filter to Ages 25-74
  filter(age %in% 25:74) %>%
  # Subset Variables (Only Include Years = 2024 & 2025)
  select(
    state,
    county,
    age,
    sex,
    hispanic,
    race97,
    race_eth_number,
    race_eth_combination,
    pop_2024,
    pop_2025,
    DQ_FLAG_2024,
    DQ_FLAG_2025,
    ends_with("_01")
  ) %>%
  collect()

## 2nd Data Set
SNOHOMISH_ALL <- tbl(con, "COUNTY") %>%
  # Filter to Snohomish County
  filter(county == "Snohomish") %>%
  # Subset Variables (Only Include Years = 2024 & 2025)
  select(
    state,
    county,
    age,
    sex,
    hispanic,
    race97,
    race_eth_number,
    race_eth_combination,
    pop_2024,
    pop_2025,
    DQ_FLAG_2024,
    DQ_FLAG_2025,
    ends_with("_01")
  ) %>%
  collect()

## Step 2: Format the data to enable summing of population values for each Race/Ethnicity value in Non-Mutually Exclusive (NME) Categories
## Example: I want NHPI AOIC Denominator --> Look at all NME Categories that mention NHPI --> sum up all of the population values for those NME Categories. Repeat for other AOIC Denominators (White, Black, AIAN, Asian, etc.)
## Essentially 1 person originally listed as "Multi-Race" --> will contribute 1 population to each of their respective identity AOIC denominators (ex: "Multi-Race" person --> 1 population count to "Black" and 1 population count to "Asian")

## 1st Set
SNOHOMISH_25_74_TABLE <- SNOHOMISH_25_74 %>%
  pivot_longer(
    cols = all_of(params$aoic_cols),
    names_to = "Race_Ethnicity_AOIC",
    values_to = "Indicator"
  ) %>%
  mutate(
    Race_Ethnicity_AOIC = str_remove_all(Race_Ethnicity_AOIC, "_01"),
  ) %>%
  filter(Indicator == 1)

## 2nd Set
SNOHOMISH_ALL_TABLE <- SNOHOMISH_ALL %>%
  pivot_longer(
    cols = all_of(params$aoic_cols),
    names_to = "Race_Ethnicity_AOIC",
    values_to = "Indicator"
  ) %>%
  mutate(
    Race_Ethnicity_AOIC = str_remove_all(Race_Ethnicity_AOIC, "_01"),
  ) %>%
  filter(Indicator == 1)

## Step 3: Generate Easy to Use Denominator Summaries

## 1st Set
WA_OFM_SADE_25_74 <- SNOHOMISH_25_74_TABLE %>%
  # Summarize AOIC Category Populations (Non-Mutually Exclusive)
  group_by(Race_Ethnicity_AOIC) %>%
  summarize(
    pop_2024 = sum(pop_2024, na.rm = TRUE),
    pop_2025 = sum(pop_2025, na.rm = TRUE)
  ) %>%
  # Pivot Longer (Easier to evaluate population over time)
  pivot_longer(
    data = .,
    cols = c("pop_2024", "pop_2025"),
    names_to = "Year",
    values_to = "Population_AOIC"
  ) %>%
  # Round Population to nearest digit
  mutate(
    Population_AOIC = round(Population_AOIC, 0),
    Population_AOIC = as.integer(Population_AOIC)
  ) %>% # Note: This rounding needs to happen as WA OFM SADE are population estimates (from statistical models) -- not exact counts!
  mutate(Year = str_remove(Year, "pop_"), Year = as.integer(Year)) %>%
  # Prepare Total Population Estimates
  group_by(Year) %>%
  mutate(Total_Population_AOIC = sum(Population_AOIC, na.rm = TRUE)) %>%
  ungroup() %>%
  # Percent of Total Population
  mutate(
    Percent_Total_Population_AOIC = paste0(
      round((Population_AOIC / Total_Population_AOIC) * 100, 1),
      "%"
    )
  ) %>%
  # Arrange the rows
  arrange(Year, Race_Ethnicity_AOIC) %>%
  # Reorder the Year column
  relocate(Year, .before = everything()) %>%
  # Add Age Tag
  mutate(Age = "25-74") %>%
  relocate(Age, .before = everything())

## 2nd Set
WA_OFM_SADE_ALL <- SNOHOMISH_ALL_TABLE %>%
  # Summarize AOIC Category Populations (Non-Mutually Exclusive)
  group_by(Race_Ethnicity_AOIC) %>%
  summarize(
    pop_2024 = sum(pop_2024, na.rm = TRUE),
    pop_2025 = sum(pop_2025, na.rm = TRUE)
  ) %>%
  # Pivot Longer (Easier to evaluate population over time)
  pivot_longer(
    data = .,
    cols = c("pop_2024", "pop_2025"),
    names_to = "Year",
    values_to = "Population_AOIC"
  ) %>%
  # Round Population to nearest digit
  mutate(
    Population_AOIC = round(Population_AOIC, 0),
    Population_AOIC = as.integer(Population_AOIC)
  ) %>% # Note: This rounding needs to happen as WA OFM SADE are population estimates (from statistical models) -- not exact counts!
  mutate(Year = str_remove(Year, "pop_"), Year = as.integer(Year)) %>%
  # Prepare Total Population Estimates
  group_by(Year) %>%
  mutate(Total_Population_AOIC = sum(Population_AOIC, na.rm = TRUE)) %>%
  ungroup() %>%
  # Percent of Total Population
  mutate(
    Percent_Total_Population_AOIC = paste0(
      round((Population_AOIC / Total_Population_AOIC) * 100, 1),
      "%"
    )
  ) %>%
  # Arrange the rows
  arrange(Year, Race_Ethnicity_AOIC) %>%
  # Reorder the Year column
  relocate(Year, .before = everything()) %>%
  # Add Age Tag
  mutate(Age = "All") %>%
  relocate(Age, .before = everything())

WA_OFM_SADE_COMBINED <- bind_rows(WA_OFM_SADE_25_74, WA_OFM_SADE_ALL)

rm(WA_OFM_SADE_25_74, WA_OFM_SADE_ALL)

# Export Data -----

## Combined Data Sets
CHAT_COMBINED %>%
  write_csv(x = ., file = "CHAT_SNOCO_2024_2025_POPULATION_ESTIMATES.csv")

WA_OFM_SADE_COMBINED %>%
  write_csv(
    x = .,
    file = "WA_OFM_SADE_2024_2025_AOIC_POPULATION_ESTIMATES.csv"
  )
