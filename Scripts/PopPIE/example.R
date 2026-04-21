library('data.table')
library('DBI')
library('duckdb')
library('glue')
source('Scripts/PopPIE/fetch_data_localdb.R')
dbpath = "INSERT PATH TO DB"

# connect to db
db_ro = dbConnect(duckdb::duckdb(), dbpath, read_only = T)

# Pull the age and race options
age_opts = dbGetQuery(db_ro, 'select * from age_tab')
race_opts = dbGetQuery(db_ro, 'select * from re_grid')
geog_opts = dbGetQuery(db_ro, 'show tables') |> subset(! name %in% c('age_tab', 're_grid', 'geog_xw'))

fetch_pop(
  dbpath = dbpath, # Path to the duckdb. The output of process_data.R
  geog_level = 'county', # one of the geographies prepared by process_data. geog_opts lists the options
  geog = 53035, # Geoid code to subset to. Or "All" / NULL
  year = c(2021, 2025), # 2021 and 2025 only. 2021:2025 would get the years in between.
  age_col = 'age_11g', # one of the column names in age_opts
  age = '25-34', #Some values from the corresponding column in age_opts. "All" or NULL return everything
  gender = 'Male', # One of 'Male', 'Female', 'All', or NULL
  raceeth_col = 'race_code', # One of the columns from race_opts
  raceeth = c(10000, 1), # some values from the corresponding column in race_opts. Or 'All' or NULL return everything
  groups = c('Year', "Race/Eth") # some combination of 'Year' , 'Age', 'Gender', "Race/Eth"
)

fetch_pop(
  dbpath = dbpath, # Path to the duckdb. The output of process_data.R
  geog_level = 'county', # one of the geographies prepared by process_data. geog_opts lists the options
  geog = 53035, # Geoid code to subset to. Or "All" / NULL
  year = 2020:2025, # Between 2020 and 2025
  age_col = 'age_6g', # one of the column names in age_opts
  age = 'All', #Some values from the corresponding column in age_opts. "All" or NULL return everything
  gender = 'All', # One of 'Male', 'Female', 'All', or NULL
  raceeth_col = 'raceeth2', # One of the columns from race_opts
  raceeth = 'Hispanic', # some values from the corresponding column in race_opts. Or 'All' or NULL return everything
  groups = c('Year', "Race/Eth") # some combination of 'Year' , 'Age', 'Gender', "Race/Eth"
)

dbDisconnect(db_ro, shutdown = TRUE)