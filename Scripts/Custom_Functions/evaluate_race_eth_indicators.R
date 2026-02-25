# evaluate_race_eth_indicators.R

## Helper function to county & evaluate 0/1 Race-Ethnicity Indicator variables
evaluate_race_eth_indicators <- function(df) {
  df_evaluated <- df %>%
    # Count Race-Ethnicity Indicators
    mutate(
      race_eth_number = WHITE_01 +
        BLACK_01 +
        AIAN_01 +
        ASIAN_01 +
        NHPI_01 +
        OTHER_01 +
        HISP_01
    ) %>%
    # Generate Alphabetized Combination Label of Applicable Race-Ethnicity Indicators
    mutate(
      race_eth_combination = na_if(
        stringr::str_remove(
          paste0(
            if_else(AIAN_01 == 1L, "AIAN, ", ""),
            if_else(ASIAN_01 == 1L, "ASIAN, ", ""),
            if_else(BLACK_01 == 1L, "BLACK, ", ""),
            if_else(HISP_01 == 1L, "HISP, ", ""),
            if_else(NHPI_01 == 1L, "NHPI, ", ""),
            if_else(WHITE_01 == 1L, "WHITE, ", "")
          ),
          ", $"
        ),
        ""
      )
    )

  return(df_evaluated)
}
