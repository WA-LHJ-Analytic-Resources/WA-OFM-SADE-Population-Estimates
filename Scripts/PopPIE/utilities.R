# A function to fetch the unique values from a socrata (csv) dataset
get_unique_vals = function(base_url, column, token = NULL, email= NULL, pass = NULL){
  url = glue::glue("{base_url}?$query=select distinct {column}")

  url = RSocrata::validateUrl(url, token)
  url = URLencode(url)
  
  if(!is.null(email) && !is.null(pass)){
    response <- httr::GET(url, 
                          httr::authenticate(email,pass))
  }else{
    response <- httr::GET(url)
  }
  
  r = content(response, as = 'parsed', show_col_types = FALSE)[[column]]
  
  r
}