#' Validate and repair geometries
#'
#' @param layer An sf object
#' @return An sf object with only valid geometries
#' @noRd
validate_geometry <- function(layer) {
  layer <- sf::st_make_valid(layer)
  layer[sf::st_is_valid(layer), ]
}

#' Convert leaflet draw toolbar GeoJSON to sf polygon
#'
#' @param feature The feature object from input$map_draw_new_feature
#' @return An sf polygon object in WGS84
#' @noRd
drawn_feature_to_sf <- function(feature) {
  coords <- feature$geometry$coordinates[[1]]
  coords_mat <- do.call(rbind, lapply(coords, function(c) c(c[[1]], c[[2]])))
  poly <- sf::st_polygon(list(coords_mat))
  sf::st_sfc(poly, crs = 4326) |> sf::st_sf()
}
