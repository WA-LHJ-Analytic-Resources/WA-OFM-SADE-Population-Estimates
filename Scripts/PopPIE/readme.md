# PopPie

## [process_data.R](process_data.R)

This script reformats [block level SADE](https://data.wa.gov/en/demographics/Small-Area-Demographic-Estimates-2020-present/3s8k-fvmm/about_data) and computes population estimates for aggregate geographies (e.g. tract, ZCTA, school district, etc.) as informed by [OFM's geographic crosswalk](https://data.wa.gov/demographics/OFM-Geographic-Crosswalk/pvty-6zcu/about_data).

To process the data, users will need to:

1.  Download the [block level population data](https://data.wa.gov/en/demographics/Small-Area-Demographic-Estimates-2020-present/3s8k-fvmm/about_data) and the [geography crosswalk](https://data.wa.gov/demographics/OFM-Geographic-Crosswalk/pvty-6zcu/about_data). If you cannot access those links, reach out to OFM.
2.  Install packages. 4/5 are available via CRAN (i.e., `install.packages()`) while the last, `rads.data`, is a package maintained by PHSKC that is not available on CRAN. To install `rads.data`, use `remotes::install_github('PHSKC-APDE/rads.data)`.
3.  Set `input_path` to the location of the block level population data
4.  Set `geog_xw_path` to the file path location of the geography crosswalk.
5.  Set `output_path` to a directory to store results

This script loads, reformats, and saves the unzipped CSVs into a [duckdb](https://duckdb.org/docs/stable/clients/r). The saved data (in the duckdb) can then be accessed by the [PopPie shiny app](app.R) and/or via fetch_pop (found in [fetch_data_localdb.R](fetch_data_localdb.R)).

## [example.R](example.R)

This script provides two basic examples on how to use the fetch_pop function to extract OFM SADE data saved in the duckdb specified by `dbpath`.

## [fetch_data_localdb.R](fetch_data_localdb.R)

Contains the fetch_pop function along with a few helpers. These functions provide a way to query a locally saved version of SADE population data.

## [app.R](app.R)

A shiny app that provides a GUI wrapper around fetch_pop. Less flexible than interacting with the local duckdb (either directly or via fetchpop), but it you get a point-and-click interface.
