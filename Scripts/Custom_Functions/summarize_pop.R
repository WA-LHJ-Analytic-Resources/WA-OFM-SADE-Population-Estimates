# summarize_pop.R

summarize_pop <- function(
  df,
  ...
) {
  df %>%
    dplyr::group_by(...) %>%
    dplyr::summarize(
      dplyr::across(
        tidyselect::starts_with("pop_"),
        ~ sum(.x, na.rm = TRUE),
        .names = "{.col}_sum"
      ),
      .groups = "drop"
    )
}
