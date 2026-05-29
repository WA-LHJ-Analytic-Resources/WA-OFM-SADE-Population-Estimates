# rename_dq_flags.R

rename_dq_flags <- function(df) {
  df_renamed <- df %>%
    rename_with(
      .,
      .fn = ~ str_remove_all(.x, "_pop|_sum"), # Remove all of these string patterns from DQ Flag variables
      .cols = starts_with("DQ_FLAG")
    )

  return(df_renamed)
}
