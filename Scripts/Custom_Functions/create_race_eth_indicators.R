# create_race_eth_indicators.R

## Helper function to create 0/1 Race-Ethnicity Indicator variables
create_race_eth_indicators <- function(df) {
  df_indicators <- df %>%
    mutate(
      WHITE_01 = if_else(str_sub(race97, 1, 1) == "1", 1L, 0L),
      BLACK_01 = if_else(str_sub(race97, 2, 2) == "1", 1L, 0L),
      AIAN_01 = if_else(str_sub(race97, 3, 3) == "1", 1L, 0L),
      ASIAN_01 = if_else(str_sub(race97, 4, 4) == "1", 1L, 0L),
      NHPI_01 = if_else(str_sub(race97, 5, 5) == "1", 1L, 0L),
      OTHER_01 = 0L,
      HISP_01 = if_else(hispanic == "1", 1L, 0L)
    )

  return(df_indicators)
}
