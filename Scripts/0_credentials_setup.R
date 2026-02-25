# 0_credentials_setup.R

pacman::p_load(keyring) # Keyring securely stores all entered credentials in the Windows Credential Manager

# API Credentials ------
keyring::key_get("DATA_WA_GOV_USERNAME") # Enter information in the RStudio/Positron IDE popup window.
keyring::key_get("DATA_WA_GOV_PASSWORD")
keyring::key_get("WA_OFM_APP_TOKEN")

# .REnviron File -----
file.edit(".Renviron") # Add DUCKDB_FILEPATH="INSERT YOUR FILEPATH" to the .Renviron file (this masks any sensitive filepaths from GitHub, as this file is blocked from being uploaded)
