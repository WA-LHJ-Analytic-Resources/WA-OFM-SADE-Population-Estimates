# create_dq_flag.R

create_dq_flags <- function(df) {
  df_flagged <- df %>%
    mutate(
      across(
        ends_with("_sum"),
        ~ ifelse(.x < 4300, TRUE, FALSE), # Checks all population summed values for the geography. If the geography's total population is less than dq_threshold (4300 - average pop size of Census Tract), estimates are too unstable to utilize.
        .names = "DQ_FLAG_{.col}"
      ),
    )

  return(df_flagged)
}
