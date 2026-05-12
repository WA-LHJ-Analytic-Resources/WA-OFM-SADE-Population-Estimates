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

# fetch_pop = function(dbpath,
#                      geog_level,
#                      geog = 'All',
#                      year = 'All',
#                      age_col = '',
#                      age = 'All',
#                      gender = 'All',
#                      raceeth_col = '',
#                      raceeth = 'All',
#                      groups = NULL) {
  
#   geog_level = DBI::Id(table = geog_level)
  
#   if(inherits(dbpath, 'duckdb_connection')){
#     db <- dbpath
#   } else{
#     db = DBI::dbConnect(duckdb::duckdb(), dbpath, read_only = TRUE)
#     on.exit(DBI::dbDisconnect(db, shutdown = TRUE))
#   }
  
#   if(missing(age_col) || is.null(age_col)) age_col = ''
#   if(missing(raceeth_col) || is.null(raceeth_col)) raceeth_col = ''


#   # Make subsets
#   ## subset by geographies
#   if(all(geog == '53')) geog = 'All'
#   subset_by_geography = make_subset('geo_id', geog)
  
#   ## subset by years
#   subset_by_year = make_subset('year', year)
  
#   ## subset by age
#   subset_by_age = make_subset(age_col, age)
  
#   ## subset by gender
#   subset_by_gender = make_subset('gender', gender)
  
#   ## subset by race/eth
#   ### custom logic when raceeth_col is AIC or AIC-NH
#   if(raceeth_col %in% c('AIC', 'AIC-NH')){
#     aic_opts = c('All', 'wht', 'blk', 'aian', 'as', 'nhpi')
#     if(any(raceeth == 'All')) raceeth = setdiff(aic_opts, 'All')
#     invalid = setdiff(raceeth, aic_opts)
#     if(length(invalid) >0){
#       stop(paste0(
#         'When `raceeth_col` is "AIC" or "AIC-NH", the only valid options for `raceeth` are: ',
#         paste(aic_opts, collapse =', '), '. ',
#         paste(invalid, collapse =', '), ' is/are [an] invalid option(s)'
#       ))
#     }
#     aic_mode = TRUE
#     subset_by_raceeth = make_subset(NULL, NULL) # will be handled differently

#   }else{
#     ### Standard approach
#     subset_by_raceeth = make_subset(raceeth_col, raceeth)
#     aic_mode = FALSE
#   }  

#   # Columns to group by
#   cols = data.table(colname = c('geo_id', 'year', age_col, 'gender', raceeth_col),
#                     coltype = c('Geography', 'Year' , 'Age', 'Gender', "Race/Eth"))
  
#   # Groups and population aggregations
#   groups = unique(c('Geography', groups))
#   grp_cols = cols[coltype %in% groups, colname]

#   if(any(grp_cols %in% '')){
#     stop('You cannot group by Age or Race/Eth without specifying `age_col` or `raceeth_col`, respectively')
#   }

#   grp_cols = setdiff(grp_cols, c('All'))


#   if(length(grp_cols)>0){
#     grp_cols = glue_collapse(grp_cols, ',')
#     group_vars = glue('GROUP BY {grp_cols}')
#     compute_pop = ('sum(pop) as pop')
#   }else{
#     group_vars = ''
#     compute_pop = 'pop'
#   }
  
  
#   # selection
#   select_me = glue_collapse(c(grp_cols, compute_pop), sep = ',' )
#   subs = c(subset_by_geography,
#            subset_by_year,
#            subset_by_age,
#            subset_by_gender,
#            subset_by_raceeth)
#   subs = subs[subs != '']
#   subset_me = glue_sql_collapse(subs, sep = ' AND ')
#   if(!subset_me == '') subset_me = glue('WHERE {subset_me}')
  
#   select_me = DBI::SQL(select_me)
#   subset_me = DBI::SQL(subset_me)
#   group_vars = DBI::SQL(group_vars)
  
#   q = glue::glue_sql(
#     'select
#     {select_me}
#     from {`geog_level`}
#     {subset_me} 
#     {group_vars}', .con = db
#   )
  
#   if(aic_mode){
#     browser()
#   }

#   r = dbGetQuery(db, q)
#   setDT(r)
#   if(nrow(r) == 0){
#     return(data.table())
#   }
#   # clean up the names
#   colsindat = cols[colname %in% names(r)]
#   if(nrow(colsindat)>0){
#     setnames(r, colsindat[, colname], colsindat[, coltype])
#   }
  
#   # if it doesn't exist, add year column
#   if(!'Year' %in% names(r)){
#     r[, Year := clean_list(as.numeric(year))]
#   }
  
#   # Add age
#   if(!'Age' %in% names(r)){
#     if(age_col == 'All'){
#       r[, Age := 'All']
#     }else{
#       r[, Age := clean_list((age))]
      
#     }
#   }
  
#   # Add gender
#   if(!'Gender' %in% names(r)){
#     if(all(c('Male', 'Female') %in% gender) || is.null(gender)){
#       r[, Gender := 'All']
#     }else{
#       r[, Gender := gender]
#     }
#   }
#   # Race/eth
#   if(!'Race/Eth' %in% names(r)){
#     if(is.null(raceeth) || all(raceeth == 'All')){
#       r[, `Race/Eth` := 'All']
#     }else{

    
#       r[, `Race/Eth` := clean_list(raceeth)]
#     }
#   }


  
#   if(!'Geography' %in% names(r)){
#     r[, Geography := 53]
#   }
  
  
#   setcolorder(r, neworder = c(cols[,coltype], 'pop'))

#   setnames(r, 'Gender', 'Sex')
#   r
  
# }

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


fetch_pop = function(dbpath,
                     geog_level,
                     geog = 'All',
                     year = 'All',
                     age_col = '',
                     age = 'All',
                     gender = 'All',
                     raceeth_col = '',
                     raceeth = 'All',
                     groups = NULL) {
  
  geog_level = DBI::Id(table = geog_level)
  
  if(inherits(dbpath, 'duckdb_connection')){
    db <- dbpath
  } else{
    db = DBI::dbConnect(duckdb::duckdb(), dbpath, read_only = TRUE)
    on.exit(DBI::dbDisconnect(db, shutdown = TRUE))
  }
  
  if(missing(age_col) || is.null(age_col)) age_col = ''
  if(missing(raceeth_col) || is.null(raceeth_col)) raceeth_col = ''


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

  ## Race is handled differently
  if(raceeth_col %in% c('AIC', 'AIC-NH')){
    aic_opts = c('All', 'wht', 'blk', 'aian', 'as', 'nhpi')
    
    invalid = setdiff(raceeth, aic_opts)
    if(length(invalid) >0){
      stop(paste0(
        'When `raceeth_col` is "AIC" or "AIC-NH", the only valid options for `raceeth` are: ',
        paste(aic_opts, collapse =', '), '. ',
        paste(invalid, collapse =', '), ' is/are [an] invalid option(s)'
      ))
    }
    aic_mode = TRUE
    if(any(raceeth %in% 'All')) raceeth = setdiff(aic_opts, 'All')
    subset_by_raceeth = lapply(raceeth, function(r) make_subset(paste0('race_', r), 1)) # will be handled differently

    if(raceeth_col %in% 'AIC-NH') subset_by_raceeth = lapply(subset_by_raceeth, function(sbr) glue::glue_sql(.con = db, "{sbr} AND race_hisp = 0"))
  
  }else{
      ### Standard approach
      subset_by_raceeth = list(make_subset(raceeth_col, raceeth))
      aic_mode = FALSE
  }

  names(subset_by_raceeth) = raceeth

  # Columns to group by
  cols = data.table(colname = c('geo_id', 'year', age_col, 'gender', raceeth_col),
                    coltype = c('Geography', 'Year' , 'Age', 'Gender', "Race/Eth"))
  # Groups and population aggregations
  groups = unique(c('Geography', groups))
  grp_cols = cols[coltype %in% groups, colname]

  if(any(grp_cols %in% '')){
    stop('You cannot group by Age or Race/Eth without specifying `age_col` or `raceeth_col`, respectively')
  }

  grp_cols = setdiff(grp_cols, c('All'))

  queries = lapply(names(subset_by_raceeth), function(rnm){
    sbr = subset_by_raceeth[[rnm]]
    rnm = paste0('race_', rnm)

    if(length(grp_cols)>0){
      if(aic_mode){
        grp_cols[grp_cols %in% c('AIC', 'AIC-NH')] <- rnm
      }
      group_vars = glue_sql(.con = db, 'GROUP BY {`grp_cols`*}')
      
      if(aic_mode){
        grp_cols[grp_cols %in% c(rnm)] <- paste0("'", rnm, "' as race_aic")
      }
      
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
            sbr)
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

    dbGetQuery(db, q)

  })

  r = rbindlist(queries)

  if(nrow(r) == 0){
    return(data.table())
  }

  # clean up the names
  if(aic_mode) cols[coltype == 'Race/Eth', colname := 'race_aic']
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
  }else{
    if(aic_mode){

        aic_names = c(
          race_nhpi = "Pacific Islander", race_as = "Asian", 
          race_aian = "American Indian/Alaska Native", race_blk = "Black", 
          race_wht = "White"
        )

        aic_names = data.table(`Race/Eth` = names(aic_names), new_val = aic_names)
        aic_names[, new_val := paste(new_val, 'AOIC')]

        if(raceeth_col == 'AIC-NH'){
          aic_names[, new_val := paste0(new_val, '-NH')]
        }

        r[aic_names, `Race/Eth` := i.new_val, on = 'Race/Eth']

    }
  }
  
  
  if(!'Geography' %in% names(r)){
    r[, Geography := 53]
  }
  
  
  setcolorder(r, neworder = c(cols[,coltype], 'pop'))

  setnames(r, 'Gender', 'Sex')
  r



}
