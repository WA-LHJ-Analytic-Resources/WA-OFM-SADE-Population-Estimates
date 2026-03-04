# credentials_setup.R
## Note: This script will only need to be ran once when users are initially setting up the project in their jurisdiction. It will NOT need to be run each time a data refresh occurs.

## Install/Load packages
pacman::p_load(keyring) # Keyring securely stores all entered credentials in the Windows Credential Manager

# API Credentials ------
keyring::key_set("DATA_WA_GOV_USERNAME") # Enter information in the RStudio/Positron IDE popup window.
keyring::key_set("DATA_WA_GOV_PASSWORD")
keyring::key_set("WA_OFM_APP_TOKEN")

# .REnviron File -----
file.edit(".Renviron") # Add DUCKDB_FILEPATH="INSERT YOUR FILEPATH" to the .Renviron file (this masks any sensitive filepaths from GitHub, as this file is blocked from being uploaded). Restart R interpreter session before running 1_pull_data.R so that Sys.getevn() can see the change to the .Renviron file.
