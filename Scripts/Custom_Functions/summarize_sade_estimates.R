# summarize_sade_estimates.R

summarize_sade_estimates <- function(df, summary_vars) {
  # Add DQ_FLAG variable
  vars <- unique(c(summary_vars, "DQ_FLAG"))

  df_summarized <- df %>%
    # Group by all requested variables (including DQ_FLAG)
    group_by(across(all_of(vars))) %>%
    # Aggregate to get population sums
    summarize(
      population = sum(.data$population, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    # Round population estimate to whole number
    mutate(population = round(population, 0)) %>%
    # Compute totals and proportions by year
    group_by(year) %>%
    mutate(
      total_non_me_population = sum(population, na.rm = TRUE),
      proportion = population / total_non_me_population,
      percentage = paste0(round(proportion * 100, 1), "%")
    ) %>%
    ungroup()

  return(df_summarized)
}
