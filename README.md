# aviation-accidents-data

This repo contains a scraping function for aviation accident data from the Aviation Safety Network database.

## Aviation Safety Net

Script for automated scraping of the aviation accident data provided in the Aviation Safety Network database (https://aviation-safety.net/database/).

The scraped dataset covers the years 1980-2025 (although you can set these values to whatever you please, as early as 1919) and contains the following variables (see https://aviation-safety.net/database/legend.php for more information):
* **date**: date of occurrence (local time)
* **type**: manufacturer and model of the aircraft
* **registration**: registration mark of the aircaft 	
* **operator**: company, organisation or individual operating the aircraft 	
* **fatalities**: number of fatalities  	
* **location**: location of the accident
* **category**: accident category
