##----------------------------------------------------------------------------------------------------##
##                     SCRAPER FOR THE AVIATION SAFETY NETWORK ACCIDENT DATABASE                      ##
##----------------------------------------------------------------------------------------------------##

## R version 4.3.1 (2023-06-16)

## Author: Lisa Hehnke (dataplanes.org | @DataPlanes)
## Modified & extended by: Alexander Szeremeta (@aszeremeta1)

## Data source: https://aviation-safety.net/database/

#-------#
# Setup #
#-------#

options(repos = "https://cloud.r-project.org")
if (!requireNamespace("pacman", quietly = TRUE)) install.packages("pacman")
library(pacman)

# Load required packages including httr and purrr
p_load(httr, data.table, magrittr, rvest, stringi, tidyverse, purrr)

# Add delay between requests to avoid blocking
REQUEST_DELAY <- 5  # Increased delay for safety

#--------------------------#
# Create URLs for scraping #
#--------------------------#

year <- seq(from = 1980, to = 2025, 1)
base_url <- paste0("https://aviation-safety.net/database/dblist.php?Year=", year)

get_pagenumber <- function(url) {
  tryCatch({
    message("\n[", format(Sys.time(), "%T"), "] Processing year: ", sub(".*Year=", "", url))
    Sys.sleep(REQUEST_DELAY)
    
    s <- session(
      url,
      httr::user_agent("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")
    )
    
    message("[", format(Sys.time(), "%T"), "] Fetching page numbers for year: ", sub(".*Year=", "", url))
    
    pages <- s %>%
      html_nodes("div.pagenumbers") %>%
      html_nodes("a") %>%
      html_attr("href") %>%
      unlist() %>%
      stri_sub(-1) %>%
      as.numeric() %>%
      sort() %>%
      tail(1)
    
    final_pages <- ifelse(purrr::is_empty(pages), 1, pages)
    message("[", format(Sys.time(), "%T"), "] Found ", final_pages, " pages for year: ", sub(".*Year=", "", url))
    
    return(final_pages)
    
  }, error = function(e) {
    message("[", format(Sys.time(), "%T"), "] ERROR retrieving page numbers for ", url, ": ", e$message)
    return(1)
  })
}

# Get pagenumbers with error handling
message("\n[", format(Sys.time(), "%T"), "] Starting page number collection for ", length(year), " years")
pagenumbers <- map_int(base_url, get_pagenumber)

accidents_year <- data.frame(year, pagenumbers) %>% 
  uncount(pagenumbers, .remove = FALSE) %>%
  group_by(year) %>%
  mutate(pagenumbers = row_number())

urls <- paste0("https://aviation-safety.net/database/dblist.php?Year=", 
              accidents_year$year, "&lang=&page=", accidents_year$pagenumbers)

#-----------------#
# Scrape database #
#-----------------#

get_table <- function(url) {
  tryCatch({
    message("\n[", format(Sys.time(), "%T"), "] Scraping page: ", url)
    Sys.sleep(REQUEST_DELAY)
    
    response <- session(
      url,
      httr::user_agent("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")
    )
    
    status <- response$response$status_code
    message("[", format(Sys.time(), "%T"), "] HTTP Status: ", status)
    
    if (status != 200) {
      warning("HTTP error ", status, " for URL: ", url)
      return(NULL)
    }
    
    html_content <- read_html(response)
    tables <- html_table(html_content, header = TRUE, fill = TRUE)
    
    if (length(tables) < 1) {
      message("[", format(Sys.time(), "%T"), "] No tables found on page: ", url)
      return(NULL)
    }
    
    df <- tables[[1]] %>% 
      select(date, type, registration, operator, fat., location, cat) %>%
      rename(fatalities = fat., category = cat)
    
    message("[", format(Sys.time(), "%T"), "] Successfully parsed ", nrow(df), " rows")
    return(df)
    
  }, error = function(e) {
    message("[", format(Sys.time(), "%T"), "] ERROR processing ", url, ": ", e$message)
    return(NULL)
  })
}

# Scrape with enhanced progress reporting
message("\n[", format(Sys.time(), "%T"), "] Starting main scraping of ", length(urls), " pages")
aviationsafetynet_accident_data <- map(urls, function(x) {
    result <- get_table(x)
    message("[", format(Sys.time(), "%T"), "] Completed: ", 
           which(urls == x), "/", length(urls), 
           " (", round(which(urls == x)/length(urls)*100, 1), "%)")
    result
  }, .progress = TRUE)

# Filter and combine results
message("\n[", format(Sys.time(), "%T"), "] Combining results...")
aviationsafetynet_accident_data <- compact(aviationsafetynet_accident_data) %>% 
  bind_rows() %>% 
  distinct()

message("[", format(Sys.time(), "%T"), "] Final dataset contains ", 
       nrow(aviationsafetynet_accident_data), " rows and ", 
       ncol(aviationsafetynet_accident_data), " columns")

#-------------------------#
# Save cleaned data       #
#-------------------------#
message("[", format(Sys.time(), "%T"), "] Saving data...")
saveRDS(aviationsafetynet_accident_data, "aviationsafetynet_accident_data.rds")

# Optional: CSV export
if (requireNamespace("data.table", quietly = TRUE)) {
  fwrite(aviationsafetynet_accident_data, "aviationsafetynet_accident_data.csv")
}

message("\n[", format(Sys.time(), "%T"), "] Script completed successfully!")