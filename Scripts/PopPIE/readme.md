# PopPie

## [process_data.R](process_data.R)

Some recipients of OFM SADE data receive access to an MFT link containing a bunch of zip files containing CSV files. This script, by setting the `input_path` and `output_path` (as controlled by the `grid` option) will load, reformat, and save the unzipped CSVs into a [duckdb](https://duckdb.org/docs/stable/clients/r). The saved data (in the duckdb) can then be accessed by the [PopPie shiny app](app.R) and/or via fetch_pop (found in [fetch_data_localdb.R](fetch_data_localdb.R)).

## [example.R](example.R)

A script showing how two basic examples on how to use the fetch_pop function to extract OFM SADE data saved in the duckdb specified by `dbpath`.

## [fetch_data_localdb.R](fetch_data_localdb.R)

Contains the fetch_pop function along with a few helpers. These functions provide a way to query a locally saved version of SADE population data.

## [app.R](app.R)

A shiny app that provides a GUI wrapper around fetch_pop. Less flexible than interacting with the local duckdb (either directly or via fetchpop), but it you get a point-and-click interface.
