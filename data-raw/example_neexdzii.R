#!/usr/bin/env Rscript
#
# example_neexdzii.R
#
# Worked example: Neexdzii Kwa (Upper Bulkley) AOI with break points.
# Demonstrates the full break workflow programmatically:
#   1. Define AOI via watershed delineation
#   2. Fetch streams within AOI
#   3. Snap break points to FWA
#   4. Delineate upstream watersheds
#   5. Compute sub-basins via pairwise subtraction
#
# Requires:
#   - SSH tunnel or direct connection to fwapg database
#   - PG_*_SHARE env vars configured (via fresh)
#   - R packages: fresh, sf, dplyr

library(fresh)
library(sf)
library(dplyr)

sf_use_s2(FALSE)

# --- 1. Define AOI: Neexdzii Kwa / Wedzin Kwa confluence ---
# Snap the confluence point to the Bulkley River mainstem
confluence <- frs_point_snap(-126.2492, 54.46086)
message("Confluence snap: ", confluence$gnis_name,
        " blk=", confluence$blue_line_key,
        " drm=", round(confluence$downstream_route_measure, 1))

# Delineate upstream watershed as AOI
aoi <- frs_watershed_at_measure(
  confluence$blue_line_key,
  confluence$downstream_route_measure
)
aoi_4326 <- st_transform(aoi, 4326)
message("AOI area: ", round(as.numeric(st_area(aoi)) / 1e6, 1), " km2")

# --- 2. Fetch streams within AOI ---
bbox_3005 <- st_bbox(aoi)
streams <- frs_stream_fetch(bbox = as.numeric(bbox_3005))
streams_4326 <- st_transform(streams, 4326)
message("Streams: ", nrow(streams), " segments")

# --- 3. Define break points ---
# Example break points along the Neexdzii Kwa and major tributaries
break_coords <- data.frame(
  lon = c(-126.2492, -126.3500, -126.4500),
  lat = c(54.46086, 54.42000, 54.38000),
  site_name = c("Confluence", "Mid Neexdzii", "Upper Neexdzii"),
  stringsAsFactors = FALSE
)

# Snap each to FWA
breaks <- do.call(rbind, lapply(seq_len(nrow(break_coords)), function(i) {
  snap <- frs_point_snap(break_coords$lon[i], break_coords$lat[i])
  data.frame(
    id = i,
    lon = break_coords$lon[i],
    lat = break_coords$lat[i],
    blk = as.integer(snap$blue_line_key),
    drm = snap$downstream_route_measure,
    gnis_name = snap$gnis_name %||% "",
    dist_m = round(snap$distance_to_stream, 1),
    site_name = break_coords$site_name[i],
    stringsAsFactors = FALSE
  )
}))

message("Break points:")
print(breaks[, c("id", "site_name", "gnis_name", "blk", "drm", "dist_m")])

# --- 4. Delineate watersheds ---
watersheds <- lapply(seq_len(nrow(breaks)), function(i) {
  ws <- frs_watershed_at_measure(breaks$blk[i], breaks$drm[i])
  st_transform(ws, 4326)
})
names(watersheds) <- breaks$id

# --- 5. Pairwise subtraction ---
# Sort by area (largest first = most downstream)
areas <- sapply(watersheds, function(ws) as.numeric(st_area(st_transform(ws, 3005))))
order_idx <- order(-areas)

subbasins <- list()
for (i in order_idx) {
  poly <- watersheds[[i]]
  for (j in order_idx[order_idx != i]) {
    if (areas[j] >= areas[i]) next
    if (!st_intersects(poly, watersheds[[j]], sparse = FALSE)[1, 1]) next
    d <- st_difference(poly, watersheds[[j]])
    if (any(st_geometry_type(d) == "GEOMETRYCOLLECTION")) {
      d <- st_collection_extract(d, "POLYGON")
    }
    if (nrow(d) > 0) poly <- st_union(d) |> st_sf()
  }
  subbasins[[as.character(breaks$id[i])]] <- st_sf(
    break_id = breaks$id[i],
    site_name = breaks$site_name[i],
    gnis_name = breaks$gnis_name[i],
    geometry = st_geometry(poly)
  )
}

result <- do.call(rbind, subbasins)
st_crs(result) <- 4326
result <- st_cast(result, "MULTIPOLYGON")
result$area_km2 <- round(as.numeric(st_area(st_transform(result, 3005))) / 1e6, 1)

message("\nSub-basins:")
print(st_drop_geometry(result))

message("\nDone. Use break::run_app() for the interactive version.")
