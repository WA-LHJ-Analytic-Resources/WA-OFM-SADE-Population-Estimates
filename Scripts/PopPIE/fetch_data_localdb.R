make_subset = function(var, items = NULL) {
  con = DBI::dbConnect(duckdb::duckdb())
  if (is.null(items) || items[1] == "All") {
    return(DBI::SQL(""))
  }
  else {
    thecol = DBI::Id(column = var)
    subme = glue::glue_sql("{`thecol`} in ({items*})", .con = con)
    return(subme)
  }
}

fetch_pop = function(dbpath,
                     geog_level,
                     geog = 'All',
                     year = 'All',
                     age_col = NULL,
                     age = 'All',
                     gender = 'All',
                     raceeth_col = NULL,
                     raceeth = 'All',
                     groups = NULL) {
  
  geog_level = DBI::Id(table = geog_level)
  
  if(inherits(dbpath, 'duckdb_connection')){
    db <- dbpath
  } else{
    db = DBI::dbConnect(duckdb::duckdb(), dbpath, read_only = TRUE)
    on.exit(DBI::dbDisconnect(db, shutdown = TRUE))
  }
  
  # Make subsets
  ## subset by geographies
  if(all(geog == '53')) geog = 'All'
  subset_by_geography = make_subset('geo_id', geog)
  
  ## subset by years
  subset_by_year = make_subset('year', year)
  
  ## subset by age
  subset_by_age = make_subset(age_col, age)
  
  ## subset by gender
  subset_by_gender = make_subset('gender', gender)
  
  ## subset by race/eth
  subset_by_raceeth = make_subset(raceeth_col, raceeth)
  
  # Columns to group by
  cols = data.table(colname = c('geo_id', 'year', age_col, 'gender', raceeth_col),
                    coltype = c('Geography', 'Year' , 'Age', 'Gender', "Race/Eth"))
  
  # Groups and population aggregations
  groups = unique(c('Geography', groups))
  grp_cols = cols[coltype %in% groups, colname]
  grp_cols = setdiff(grp_cols, 'All')
  
  if(length(grp_cols)>0){
    grp_cols = glue_collapse(grp_cols, ',')
    group_vars = glue('GROUP BY {grp_cols}')
    compute_pop = ('sum(pop) as pop')
  }else{
    group_vars = ''
    compute_pop = 'pop'
  }
  
  
  # selection
  select_me = glue_collapse(c(grp_cols, compute_pop), sep = ',' )
  subs = c(subset_by_geography,
           subset_by_year,
           subset_by_age,
           subset_by_gender,
           subset_by_raceeth)
  subs = subs[subs != '']
  subset_me = glue_sql_collapse(subs, sep = ' AND ')
  if(!subset_me == '') subset_me = glue('WHERE {subset_me}')
  
  select_me = DBI::SQL(select_me)
  subset_me = DBI::SQL(subset_me)
  group_vars = DBI::SQL(group_vars)
  
  q = glue::glue_sql(
    'select
    {select_me}
    from {`geog_level`}
    {subset_me} 
    {group_vars}', .con = db
  )
  
  r = dbGetQuery(db, q)
  setDT(r)
  if(nrow(r) == 0){
    return(data.table())
  }
  # clean up the names
  colsindat = cols[colname %in% names(r)]
  if(nrow(colsindat)>0){
    setnames(r, colsindat[, colname], colsindat[, coltype])
  }
  
  # if it doesn't exist, add year column
  if(!'Year' %in% names(r)){
    r[, Year := clean_list(as.numeric(year))]
  }
  
  # Add age
  if(!'Age' %in% names(r)){
    if(age_col == 'All'){
      r[, Age := 'All']
    }else{
      r[, Age := clean_list((age))]
      
    }
  }
  
  # Add gender
  if(!'Gender' %in% names(r)){
    if(all(c('Male', 'Female') %in% gender) || is.null(gender)){
      r[, Gender := 'All']
    }else{
      r[, Gender := gender]
    }
  }
  # Race/eth
  if(!'Race/Eth' %in% names(r)){
    if(is.null(raceeth) || all(raceeth == 'All')){
      r[, `Race/Eth` := 'All']
    }else{
      r[, `Race/Eth` := clean_list(raceeth)]
    }
  }
  
  if(!'Geography' %in% names(r)){
    r[, Geography := 53]
  }
  
  
  setcolorder(r, neworder = c(cols[,coltype], 'pop'))

  setnames(r, 'Gender', 'Sex')
  r
  
}

# A function to clean up a list of numerics
clean_list <- function(x){
  
  if(is.character(x)){
    return(paste(sort(x), collapse = ', '))
  }
  
  stopifnot(is.numeric(x))
  #get the unique values
  x <- sort(unique(x))
  
  #find breaks in runs
  breaks = data.table::shift(x, type = 'lead') == (x + 1)
  bps = which(!breaks)
  
  #separate
  if(length(bps)>0){
    seper = split(x, cut(x, c(-Inf, x[bps], Inf)))
  }else{
    seper = list(x)
  }
  
  #format into string
  seper = lapply(seper, function(y){
    
    if(length(y)>1){
      return(paste(min(y), max(y), sep = '-'))
    }else{
      return(paste(y))
    }
    
  })
  
  ret = paste(seper, collapse = ', ')
  
  return(ret)
  
}