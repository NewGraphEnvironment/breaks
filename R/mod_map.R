#' Map module UI
#'
#' @param id Module namespace id
#' @noRd
mod_map_ui <- function(id) {
  ns <- NS(id)
  leaflet::leafletOutput(ns("map"), height = "85vh")
}

#' Map module server
#'
#' @param id Module namespace id
#' @param aoi ReactiveVal for the AOI polygon
#' @param streams ReactiveVal for stream segments
#' @param breaks_rv ReactiveValues for break points and subbasins
#' @param map_click ReactiveVal for forwarding map click events
#' @noRd
mod_map_server <- function(id, aoi, streams, breaks_rv, map_click) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    output$map <- leaflet::renderLeaflet({
      leaflet::leaflet() |>
        leaflet::addProviderTiles("OpenTopoMap", group = "Topo") |>
        leaflet::addProviderTiles("Esri.WorldImagery", group = "Satellite") |>
        leaflet::addProviderTiles("OpenStreetMap", group = "OSM") |>
        leaflet::setView(lng = -125, lat = 54, zoom = 6) |>
        leaflet::addLayersControl(
          baseGroups = c("Topo", "Satellite", "OSM"),
          overlayGroups = c("AOI", "Streams", "Break Points", "Sub-Basins"),
          position = "topright"
        ) |>
        leaflet::addScaleBar(position = "bottomleft")
    })
  })
}
