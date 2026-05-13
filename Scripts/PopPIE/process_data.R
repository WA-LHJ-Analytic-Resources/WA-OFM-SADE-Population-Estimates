library('data.table')
library('DBI')
library('glue')
library('duckdb')
library('rads.data') # A PHSKC package: https://github.com/PHSKC-APDE/rads.data/issues. Download via the remotes package with `remotes::install_github('PHSKC-APDE/rads.data')`
input_path = Sys.getenv("SADE_FILEPATH") #Replace with the file path of your download (~40min) of  https://data.wa.gov/en/demographics/Small-Area-Demographic-Estimates-2020-present/3s8k-fvmm/about_data
geog_xw_path = Sys.getenv("OFM_GEO_CROSSWALK_FILEPATH") # replace with file path to download of https://data.wa.gov/demographics/OFM-Geographic-Crosswalk/pvty-6zcu/about_data
output_path = Sys.getenv("OUTPUT_FILEPATH") # Replace with a path to a directory to store output
dir.create(output_path)
outdb = DBI::dbConnect(duckdb::duckdb(), file.path(output_path, 'popdb.duckdb'))

# Create a crosswalk to convert Census Blocks into other geographies (tracts, school districts, etc.)
gxw = fread(geog_xw_path, integer64 = 'character' )
gxw = gxw[,.(
  block = BLOCK20L,
  county = as.numeric(substr(BLOCK20L, 1, 5)),
  tract = as.numeric(substr(BLOCK20L, 1, 11)),
  block_group = as.numeric(substr(BLOCK20L, 1, 12)),
  schooldist = as.numeric(substr(SDUNI, 3, nchar(SDUNI))),
  congdist22 = CONGDIST22,
  ZCTA = ZCTA5 #,
  #place = PLACE
)

]

# Create a table for common/precomputed age groupings
age_tab = data.table(AgeGroup = c(0:100,105,110))
age_6g = list(c(0,0), c(1,14), c(15,24), c(25,44), c(45,64), c(65,Inf))
age_11g = rads.data::population_wapop_codebook_values[varname=='age11', as.integer(code_label)]
age_11g = c(age_11g, Inf)
age_11g = lapply(2:length(age_11g), function(i) c(age_11g[i-1], age_11g[i]-1))
age_20g = rads.data::population_wapop_codebook_values[varname=='age20', as.integer(code_label)]
age_20g = c(age_20g, Inf)
age_20g = lapply(2:length(age_20g), function(i) c(age_20g[i-1], age_20g[i]-1))
age_5yr = seq(0,85, 5)
age_5yr = lapply(age_5yr, function(x) c(x, x+4))
age_5yr[[length(age_5yr)]] <- c(85,Inf)
ags = list('age_6g' = age_6g, 'age_11g' = age_11g, 'age_20g' = age_20g, 'age_5yr' = age_5yr)
for(ag in seq_along(ags)){
  
  grp = ags[[ag]]
  grpnm = names(ags)[ag]
  
  for(a in grp){
    age_tab[AgeGroup>= a[1] & AgeGroup <= a[2], (grpnm) := paste0(a[1], '-', a[2])]
    
  }
  age_tab[, (grpnm) := gsub('-Inf','+', get(grpnm),fixed = T)]
  
}
setnames(age_tab, 'AgeGroup', 'age')

# Set up a grouping table for Race/Ethnicity
race = c('White', 'Black', 'AIAN', 'Asian', 'NHPI')
re_grid = lapply(race, function(x) c(0,1))
re_grid = do.call(CJ, re_grid)
setnames(re_grid, race)
re_grid[, nrace := rowSums(.SD), .SDcols = race]
re_grid = re_grid[nrace>0]
for(rrr in race){
  re_grid[get(rrr) == 1 & nrace == 1, race6 := rrr]
}
re_grid[nrace>1, race6 := 'Multiple']
re_grid[, RaceMars97 := do.call(paste0, .SD), .SDcols = race]
re_grid = re_grid[, .(RaceMars97 = as.integer(RaceMars97), race6, Hispanic = 0)]
re_grid = rbind(re_grid, re_grid[, .(RaceMars97, race6, Hispanic = 1)])
re_grid[, raceeth2 := as.character(factor(Hispanic, 0:1, c('Not Hispanic', 'Hispanic')))]
re_grid[, raceeth7 := paste0(race6, '-NH')]
re_grid[Hispanic == 1, raceeth7 := 'Hispanic']
setnames(re_grid, 'RaceMars97', 'race_code')

# fix the columns to match chat outputs
re_grid[,race6 := factor(race6,
                         c(race, 'Multiple'),
                         c('White Only', 'Black Only', 'American Indian/Alaska Native Only',
                           'Asian Only', 'Native Hawaiian and Pacific Islander Only', 'Multi Race'))]
re_grid[Hispanic == 0, raceeth7:= paste0(race6,'-NH')]
re_grid[raceeth7 == 'Multi Race-NH', raceeth7 := 'Multi-Race-NH']
re_grid[Hispanic == 1, raceeth7 := 'Hispanic as Race']
re_grid[, race_code := stringr::str_pad(race_code,5,'left', 0)]
re_grid[, (race) := lapply(seq_along(race), function(x) substr(race_code, x,x))]
setnames(re_grid, race, c('race_wht', 'race_blk', 'race_aian', 'race_as', 'race_nhpi'))

# Write the race and age grids to the duckdb
dbWriteTable(outdb, 're_grid', value = re_grid, overwrite = T)
dbWriteTable(outdb, 'age_tab', value = age_tab, overwrite = T)
dbWriteTable(outdb, 'geog_xw', value = gxw, overwrite = T, field.types = c(block = 'BIGINT'))

# Load the block data to the duckdb
## Identify input column names
colnames = fread(input_path, nrow = 0) |> names()
pvars = grep('pop', (colnames), value = T)
re_cols = setdiff(names(re_grid), c('Hispanic',colnames))
at_cols = setdiff(names(age_tab), (colnames))

## Load the csv file into the db, do some gentle cleaning along the way
dbExecute(outdb, glue::glue_sql(.con = outdb,
"
  create or replace table block as (

  with blk_long as (
    unpivot {`input_path`}
    on {`pvars`*}
    into 
      NAME year
      value pop
  )
      select
      block20l as geo_id,
      case when sex = 'M' then 'Male' when sex = 'F' then 'Female' else 'X' end as gender,
      bl.age,
      cast(substr(year,5,9) as INT) as year,
      pop,
      {`re_cols`*},
      bl.hispanic as race_hisp,
      {`at_cols`*},
      from blk_long as bl
      left join re_grid as re on bl.race97 = re.race_code AND bl.hispanic = re.Hispanic
      left join age_tab as aa on bl.age = aa.age
      --limit 10
  )
"
))

# Get the column names from the block table
bcols = names(dbGetQuery(outdb, 'select * from block limit 0'))

# For each geography level
for(g in setdiff(names(gxw), 'block')){

  new_gi = DBI::Id(table = 'r', column = g)
  scols = setdiff(bcols, c('geo_id', 'pop'))
  
  # create a geography (i.e., g) specific table aggregated from block level
  dbExecute(outdb, glue::glue_sql(.con = outdb,
  "
    create or replace table {`g`} as (
      select {`new_gi`} as geo_id,
      {`scols`*},
      sum(pop) as pop
      from block as l
      left join geog_xw as r on l.geo_id = r.block
      group by {`c(g, scols)`*}
    )
  "
  ))
  
}

dbDisconnect(outdb, shutdown = T)
