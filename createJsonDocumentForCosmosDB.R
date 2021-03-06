# Author: Bryan Carlson
# Contact: bryan.carlson@ars.usda.gov
# Purpose: Remove projection from georef points, clean data, create json document for import into CosmosDB

library(rgdal)
library(geojsonio)
library(plyr)
library(jqr) #https://cran.r-project.org/web/packages/jqr/vignettes/jqr_vignette.html
library(jsonlite)

setwd("C:\\Dev\\Projects\\CookEastGeospatialGeoreferencePoints\\R")

# ---- Create geojson document ----
# Load and check projection
georef <- readOGR("Input/All_CookEast", "All_CookEast")
proj4string(georef)

# Remove projection
WGS84 <- CRS("+proj=longlat +ellps=WGS84 +datum=WGS84 +no_defs")
georef.wgs84 <- spTransform(georef, WGS84)

# Clean unwanted columns
drops <- c("FID_1", "ROW", "COL_ROW", "COL_ROW2", 
           "EASTING", "NORTHING", "CROP", "AREA", "PERIMETER", 
           "AREA_AC", "TARGET")
georef.wgs84.clean <- georef.wgs84[,!(names(georef.wgs84) %in% drops)]

# Rename columns
georef.wgs84.clean.rename <- rename(georef.wgs84.clean, c("COLUMN"="Column", "ROW2"="Row2", "STRIP"="Strip", "FIELD"="Field"))

# Order values
georef.wgs84.clean.rename.order <- georef.wgs84.clean.rename[order(georef.wgs84.clean.rename$ID2),]

# Reset index
row.names(georef.wgs84.clean.rename.order@data) <- NULL

# Output as geojson
date.today <- format(Sys.Date(), "%y%m%d")
gj.path <- paste("Output/CookEastGeoreferencePoints_", date.today,".geojson", sep = "")
geojson_write(georef.wgs84.clean.rename.order, file=gj.path, precision = 8)

# ---- Create JSON for DocumentDB ----
# Load geojson file as text
geoJsonString <- readLines(gj.path)

jstring <- paste('{
                 "partitionKey": "CookEast_SurveyPoint_GeoreferencePoints",
                 "id":           "CookEast_GeoreferencePoints_',date.today,'",
                 "type":         "SurveyPoint",
                 "name":         "GeoreferencePoints",
                 "schemaVersion":"1.0.0",
                 "metadataId":   "CookEastGeospatialGeoreferencePoints",
                 "fieldId":      "CookEast",
                 "location":     ',minify(geoJsonString),'
                 }', sep = "")

j <- jq(jstring, ".")
validate(j)

# Write the file
j.path <- paste("Output/CookEastGeoreferencePointsDocument_", date.today,".json", sep = "")
write(j, j.path)
