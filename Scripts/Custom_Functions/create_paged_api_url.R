# create_paged_api_url.R

## Helper Function to Build Paged API URL
create_paged_api_url <- function(
  base = "https://data.wa.gov/resource/3s8k-fvmm.csv", # SODA v2.0 API URL BASE
  select = "*", # or omit the $select entirely if you want all columns
  order = "block20l,age,sex,hispanic,race97",
  page_size,
  offset
) {
  # ensure no scientific notation
  page_size_formatted <- format(
    as.integer(page_size),
    scientific = FALSE,
    trim = TRUE
  )
  offset_formatted <- format(
    as.integer(offset),
    scientific = FALSE,
    trim = TRUE
  )

  glue(
    "{base}?$select={select}&$order={order}&$limit={page_size_formatted}&$offset={offset_formatted}"
  )
}
