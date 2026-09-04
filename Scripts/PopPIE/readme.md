# PopPie

## [process_data.R](process_data.R)

This script reformats [block level SADE](https://data.wa.gov/en/demographics/Small-Area-Demographic-Estimates-2020-present/3s8k-fvmm/about_data) and computes population estimates for aggregate geographies (e.g. tract, ZCTA, school district, etc.) as informed by [OFM's geographic crosswalk](https://data.wa.gov/demographics/OFM-Geographic-Crosswalk/pvty-6zcu/about_data).

To process the data, users will need to:

1.  Navigate to the block level population data hosted on data.wa.gov (see links below). Export the data as a csv. These files can be large and take a long time to download (because you are downloading for the whole state). You may want to consider pre-filtering the data before export (e.g. filter on block20l where the first 5 character are the FIPS code for your county of interest). If you cannot access the links below, reach out to OFM.
    1.  [2000 - 2009](https://data.wa.gov/en/demographics/Small-Area-Demographic-Estimates-2000-2009/g3gh-r5g7/about_data)
    2.  [2010 - 2019](https://data.wa.gov/en/demographics/Small-Area-Demographic-Estimates-2010-2019/ivkq-ti7d/about_data)
    3.  [2020+](https://data.wa.gov/en/demographics/Small-Area-Demographic-Estimates-2020-present/3s8k-fvmm/about_data)
2.  Export/download the [geography crosswalk](https://data.wa.gov/demographics/OFM-Geographic-Crosswalk/pvty-6zcu/about_data).
3.  Install R packages. 4/5 are available via CRAN (i.e., `install.packages(c('data.table', 'DBI', 'glue', 'duckdb')`) while the last, `rads.data`, is a package maintained by PHSKC that is not available on CRAN. To install `rads.data`, use `remotes::install_github('PHSKC-APDE/rads.data)`.
4.  Set `input_path` (line 6) to the file path(s) of the downloaded population data. E.g. `c('//path/to/file1.csv', '//path/to/file2.csv')`
5.  Set `geog_xw_path` to the file path location of the geography crosswalk.
6.  Set `output_path` to a directory to store results
7.  Run the script.

This script loads, reformats, and saves the CSVs into a [duckdb](https://duckdb.org/docs/stable/clients/r) database. The saved data (in the duckdb) can then be accessed by the [PopPie shiny app](app.R) and/or via fetch_pop (found in [fetch_data_localdb.R](fetch_data_localdb.R)).

## [example.R](example.R)

This script provides two basic examples on how to use the fetch_pop function to extract OFM SADE data saved in the duckdb specified by `dbpath`.

## [fetch_data_localdb.R](fetch_data_localdb.R)

Contains the fetch_pop function along with a few helpers. These functions provide a way to query a locally saved version of SADE population data.

## [app.R](app.R)

A shiny app that provides a GUI wrapper around fetch_pop. Less flexible than interacting with the local duckdb (either directly or via fetchpop), but it you get a point-and-click interface.
