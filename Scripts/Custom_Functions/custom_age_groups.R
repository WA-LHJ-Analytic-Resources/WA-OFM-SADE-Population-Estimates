# custom_age_groups.R

# Check Age Group Label Formatting -----

## Note: A function designed check that provided custom age groupings are 1)
## mutually exclusive/non-overlapping and 2) do not have gaps (miss ages or
## between groups).

## Parameters:
## age_group_labels = a A string vector containing
## mutually exclusive age groups in the following format:
## c("<4","5-17",...,"#+")

# AI Disclosure Statement: This output was written with the assistance of GPT-4.
# The initial output was created using the following prompt: “Create R code to
# evaluate whether a string vector containing age intervals either 1) overlaps
# (causing errors with mutually exclusive categories), or 2) skips ages between
# age groups". The output was then modified, reviewed, and tested by Tyler
# Bonnell.

check_age_group_labels <- function(age_group_labels) {
  # Extract numeric boundaries from the age_group_labels
  intervals <- purrr::map(age_group_labels, function(label) {
    if (stringr::str_detect(label, "<")) {
      # First group in age_group_labels
      lower <- -Inf
      upper <- as.numeric(stringr::str_remove(label, "<"))
    } else if (stringr::str_detect(label, "\\+")) {
      # Last group in age_group_labels
      lower <- as.numeric(stringr::str_remove(label, "\\+"))
      upper <- Inf
    } else {
      # Middle group(s) in age_group_labels
      range <- as.numeric(stringr::str_split(label, "-")[[1]])
      lower <- range[1]
      upper <- range[2]
    }
    return(c(lower, upper))
  })

  ## Convert Matrix to Tibble
  suppressMessages({
    intervals <- do.call(rbind, intervals) %>%
      dplyr::as_tibble(., .name_repair = "unique")

    names(intervals) <- c("lower", "upper")
  })

  # Step 2: Check for overlapping intervals

  ## Assess Overlap
  intervals <- intervals %>%
    dplyr::mutate(
      next_group_lower = dplyr::lead(lower, 1),
      overlap = dplyr::case_when(
        # Examine if the lower bound of the next age group falls into the prior age group (it would be less than the upper age of the prior group)
        next_group_lower <= upper ~ TRUE,
        next_group_lower > upper ~ FALSE,
        TRUE ~ FALSE
      )
    )

  ## Generate Stop Message (this has to be fixed!)
  if (any(intervals$overlap == TRUE)) {
    stop(
      "Overlapping intervals detected in age_group_labels. Please re-define age_group_labels to be mutually exclusive categories."
    )
  }

  # Step 3: Check for missing age values between intervals

  ## Assess Gaps
  intervals <- intervals %>%
    dplyr::mutate(
      gap = dplyr::case_when(
        upper + 1 != next_group_lower ~ TRUE,
        upper + 1 == next_group_lower ~ FALSE,
        TRUE ~ FALSE
      )
    )

  ## Generate Stop Message (this has to be fixed!)
  if (any(intervals$gap == TRUE)) {
    stop(
      "There are Age gaps detected in age_group_labels. Please re-define age_group_labels capture all Ages."
    )
  }
}


# Convert Age Labels to Breaks ----

# AI Disclosure Statement: This output was written with the assistance of ChatGPT (OpenAI GPT-4o).
# The initial output was created using the following prompt:
# “Build an R function that will take a string vector (in the params$age_labels format) as input,
# and provide a numeric vector in the correct params$age_breaks format as output. Make sure no ages/years are skipped in the interval.
# Use tidyverse syntax in the function: params$age_breaks <- c(-Inf, 17, 35, 50, Inf) params$age_labels <- c("<12", "18-35", "36-50", "51+").”
# The output was then modified, reviewed, and tested by Tyler Bonnell.

convert_age_labels_to_breaks <- function(age_group_labels) {
  check_age_group_labels(age_group_labels)

  age_group_breaks <- age_group_labels %>%
    purrr::map_dbl(
      ~ case_when(
        stringr::str_detect(.x, "<") ~ as.numeric(stringr::str_remove(.x, "<")), # Remove < from first age_label value
        stringr::str_detect(.x, "\\+") ~
          as.numeric(stringr::str_remove(.x, "\\+")), # Remove + from last age_label value
        TRUE ~ as.numeric(stringr::str_split(.x, "-")[[1]][2])
      )
    ) %>%
    # Add -Inf at start of break vector
    c(-Inf, .) %>%
    # Replace last break vector value with +Inf (for right-cut breaks)
    {
      .[length(.)] <- Inf
      .
    }

  return(age_group_breaks)
}


# Create Custom Age Groups ----

create_custom_age_groups <- function(
  df,
  breaks = params$age_breaks,
  labels = params$age_labels
) {
  df %>%
    mutate(
      age_group = coalesce(
        cut(
          age,
          breaks = breaks,
          labels = labels,
          right = TRUE
        ),
        "Unknown" # Converts NA --> Unknown
      )
    )
}
