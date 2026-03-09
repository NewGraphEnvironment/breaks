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

    # Base map
    output$map <- leaflet::renderLeaflet({
      leaflet::leaflet() |>
        leaflet::addProviderTiles("OpenTopoMap", group = "Topo") |>
        leaflet::addProviderTiles("Esri.WorldImagery", group = "Satellite") |>
        leaflet::addProviderTiles("OpenStreetMap", group = "OSM") |>
        leaflet::setView(lng = -125, lat = 54, zoom = 6) |>
        leaflet.extras::addDrawToolbar(
          targetGroup = "Drawn",
          polylineOptions = FALSE,
          circleOptions = FALSE,
          rectangleOptions = FALSE,
          markerOptions = FALSE,
          circleMarkerOptions = FALSE,
          editOptions = leaflet.extras::editToolbarOptions(
            edit = FALSE, remove = TRUE
          )
        ) |>
        leaflet::addLayersControl(
          baseGroups = c("Topo", "Satellite", "OSM"),
          overlayGroups = c("AOI", "Streams", "Break Points", "Sub-Basins"),
          position = "topright"
        ) |>
        leaflet::addScaleBar(position = "bottomleft")
    })

    # Forward map clicks for break point placement
    observeEvent(input$map_click, {
      map_click(input$map_click)
    })

    # Forward drawn polygon as AOI
    observeEvent(input$map_draw_new_feature, {
      drawn <- drawn_feature_to_sf(input$map_draw_new_feature)
      if (!is.null(drawn) && nrow(drawn) > 0) {
        # Access the parent aoi reactiveVal via the passed reference
        aoi(drawn)
      }
    })

    # Display AOI polygon
    observe({
      proxy <- leaflet::leafletProxy("map")
      proxy |> leaflet::clearGroup("AOI")
      aoi_data <- aoi()
      if (!is.null(aoi_data)) {
        proxy |>
          leaflet::addPolygons(
            data = aoi_data,
            color = "#ff7800", weight = 2,
            fillColor = "#ff7800", fillOpacity = 0.1,
            group = "AOI"
          ) |>
          leaflet::fitBounds(
            lng1 = sf::st_bbox(aoi_data)[["xmin"]],
            lat1 = sf::st_bbox(aoi_data)[["ymin"]],
            lng2 = sf::st_bbox(aoi_data)[["xmax"]],
            lat2 = sf::st_bbox(aoi_data)[["ymax"]]
          )
      }
    })

    # Display streams
    observe({
      proxy <- leaflet::leafletProxy("map")
      proxy |> leaflet::clearGroup("Streams")
      streams_data <- streams()
      if (!is.null(streams_data) && nrow(streams_data) > 0) {
        proxy |>
          leaflet::addPolylines(
            data = streams_data,
            color = "#3388ff", weight = 2,
            popup = ~paste0(
              "<b>", gnis_name, "</b><br>",
              "Order: ", stream_order, "<br>",
              "BLK: ", blue_line_key
            ),
            group = "Streams"
          )
      }
    })

    # Display break point markers
    observe({
      proxy <- leaflet::leafletProxy("map")
      proxy |> leaflet::clearGroup("Break Points")
      pts <- breaks_rv$points
      if (nrow(pts) > 0) {
        for (i in seq_len(nrow(pts))) {
          proxy |>
            leaflet::addCircleMarkers(
              lng = pts$lon[i], lat = pts$lat[i],
              radius = 8, color = "red", fillColor = "yellow",
              fillOpacity = 0.9, weight = 2,
              label = paste0("#", pts$id[i], ": ", pts$gnis_name[i],
                             " (", pts$dist_m[i], "m)"),
              group = "Break Points",
              layerId = paste0("break_", pts$id[i])
            )
        }
      }
    })

    # Display sub-basins
    observe({
      proxy <- leaflet::leafletProxy("map")
      proxy |> leaflet::clearGroup("Sub-Basins")
      sb <- breaks_rv$subbasins
      if (!is.null(sb) && nrow(sb) > 0) {
        pal <- leaflet::colorFactor("Set2", sb$break_id)
        proxy |>
          leaflet::addPolygons(
            data = sb,
            color = ~pal(break_id), weight = 2,
            fillColor = ~pal(break_id), fillOpacity = 0.3,
            popup = ~paste0(
              "<b>Sub-basin #", break_id, "</b><br>",
              gnis_name, "<br>",
              "BLK: ", blk, "<br>",
              "DRM: ", round(drm, 1)
            ),
            group = "Sub-Basins"
          )
      }
    })

    # Forward marker clicks for break point removal
    observeEvent(input$map_marker_click, {
      click <- input$map_marker_click
      if (!is.null(click$id) && grepl("^break_", click$id)) {
        map_click(click)
      }
    })
  })
}
