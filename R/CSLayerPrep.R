### Preparing the goat resistance layer for CS ###
rm(list=ls())

library(rgdal)
library(tidyverse)
library(raster)
library(sf)
library(fasterize)
library(sp)

lc_full <- raster("../Circuitscape/CS_Input/Landcover/NLCD_2016_Land_Cover_L48_20190424/NLCD_2016_Land_Cover_L48_20190424.img")

roi <- read_sf("../Circuitscape/CS_Input/ROI/roi.shp") %>% 
  st_transform(.,crs(lc_full))

## Crop, mask, and resample land cover raster
lc <- mask(raster::crop(x = lc_full,y = extent(roi)),mask = roi)

ras <- raster()
extent(ras) <- extent(roi)
res(ras)<-90
crs(ras) <- crs(lc)

lc_res <- resample(x = lc,y = ras,method = "ngb")
writeRaster(lc_res,"../Circuitscape/CS_Output/landcover90.tif",overwrite=TRUE)

## Crop, mask, and resample imperviousness raster
imp <- raster("../Circuitscape/CS_Input/Landcover/NLCD_2016_Impervious_L48_20190405/NLCD_2016_Impervious_L48_20190405.img")
imp <- mask(raster::crop(x = imp,y = roi),mask = roi)
imp_res <- resample(x = imp, y = ras, method = "ngb")
writeRaster(imp_res,"../Circuitscape/CS_Output/imperviousness90.tif",overwrite=TRUE)

## Goat polygons
# habitat <- read_sf("../Circuitscape/CS_Input/Habitat/MountainGoat_Or/mMOGOx_CONUS_Range_2001v1.shp") %>% 
#   st_transform(.,crs(lc)) %>% 
#   st_intersection(.,roi) %>% 
#   as(.,"Spatial") %>% 
#   disaggregate(.) %>% 
#   st_as_sf() %>% 
#   mutate(core_id=1:3)
# 
# writeOGR(obj = as(habitat,'Spatial'),
#          dsn = "../Circuitscape/CS_Output/CO_habitat",
#          layer = "co_habitat",
#          driver = "ESRI Shapefile",
#          overwrite_layer = T)

# Focal nodes in ascii format--don't need after all
# nodes_shp <- read_sf("../Circuitscape/CS_Output/focal_nodes/nodes.shp") %>% 
#   st_transform(.,crs(lc))
# 
# nodes_ras <- rasterize(nodes_shp,ras,field='id')
# nodes_ras[is.na(nodes_ras)] <- -9999
# writeRaster(nodes_ras,"../Circuitscape/CS_Output/focal_nodes/core_nodes.asc",format="ascii")


major_roads <- read_sf("../Circuitscape/CS_Input/Roads/MAJOR_ROADS.shp") %>% 
  filter(ADMINCLASS=="1  Arterial Service") %>% 
  st_zm() %>% 
  st_transform(.,crs(lc)) %>%
  st_buffer(.,100) %>% 
  st_intersection(.,roi) 

roads_ras <- fasterize(major_roads,ras,background = -9999)
roads_ras <- mask(raster::crop(x = roads_ras,y = roi),mask = roi)
writeRaster(roads_ras,"../Circuitscape/CS_Output/roads/major_roads.tif",overwrite=T)
# plot(roads_ras)

co_highways <- read_sf("../Circuitscape/CS_Input/Roads/colorado_highway.shp") %>% 
  filter(TYPE%in%c("primary","secondary")) %>% 
  st_transform(.,crs(lc)) %>% 
  st_buffer(.,200) %>% 
  st_intersection(.,roi) 

# writeOGR(obj = co_highways,
#          dsn = "../Circuitscape/CS_Output/roads/",
#          layer = 'highways',
#          driver = 'ESRI Shapefile')

co_highway_ras <- fasterize(co_highways,ras,background = -9999)
co_highway_ras <- mask(raster::crop(x = co_highway_ras,y = roi),mask = roi)
writeRaster(co_highway_ras,"../Circuitscape/CS_Output/roads/highways.tif",overwrite=T)

nhs <- read_sf("../Circuitscape/CS_Input/Roads/NHS/intrstat.shp") %>% 
  st_transform(.,crs(lc_full)) %>% 
  st_buffer(.,250) %>% 
  st_intersection(.,roi) 

nhs_ras <- fasterize(nhs,ras,background = -9999)
nhs_ras <- mask(raster::crop(x = nhs_ras,y = roi),mask = roi)
writeRaster(nhs_ras,"../Circuitscape/CS_Output/roads/nhs.tif",overwrite=T)
