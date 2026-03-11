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
mod_map_server <- function(id, aoi, aoi_meta, streams, breaks_rv, map_click) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Base map — no overlay groups until data arrives
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
          position = "topright"
        ) |>
        leaflet::addScaleBar(position = "bottomleft")
    })

    # Track which overlay groups exist so we can rebuild layer control
    active_groups <- reactiveVal(character(0))

    rebuild_layer_control <- function(proxy, groups) {
      proxy |>
        leaflet::removeLayersControl() |>
        leaflet::addLayersControl(
          baseGroups = c("Topo", "Satellite", "OSM"),
          overlayGroups = groups,
          position = "topright"
        )
      # Show all active groups by default
      for (g in groups) {
        proxy |> leaflet::showGroup(g)
      }
    }

    add_group <- function(group_name) {
      current <- active_groups()
      if (!group_name %in% current) {
        active_groups(c(current, group_name))
      }
    }

    # Forward map clicks — tag with timestamp so repeated clicks
    # at the same location still trigger reactivity
    observeEvent(input$map_click, {
      click <- input$map_click
      click$.ts <- Sys.time()
      click$.source <- "map"
      map_click(click)
    })

    # Forward drawn polygon as AOI
    observeEvent(input$map_draw_new_feature, {
      drawn <- drawn_feature_to_sf(input$map_draw_new_feature)
      if (!is.null(drawn) && nrow(drawn) > 0) {
        aoi_meta(list(method = "draw"))
        aoi(drawn)
      }
    })

    # Display AOI polygon
    observeEvent(aoi(), {
      proxy <- leaflet::leafletProxy("map")
      proxy |> leaflet::clearGroup("AOI")
      aoi_data <- aoi()
      if (!is.null(aoi_data) && nrow(aoi_data) > 0) {
        aoi_data <- sf::st_zm(aoi_data, drop = TRUE)
        aoi_data <- aoi_data[!sf::st_is_empty(aoi_data), ]
        if (nrow(aoi_data) == 0) return()
        aoi_data <- sf::st_make_valid(aoi_data)
        proxy |>
          leaflet::addPolygons(
            data = aoi_data,
            color = "#ff7800", weight = 2,
            fillColor = "#ff7800", fillOpacity = 0.1,
            group = "AOI"
          )
        bb <- sf::st_bbox(aoi_data)
        if (!any(is.na(bb))) {
          proxy |>
            leaflet::fitBounds(
              lng1 = bb[["xmin"]], lat1 = bb[["ymin"]],
              lng2 = bb[["xmax"]], lat2 = bb[["ymax"]]
            )
        }
        add_group("AOI")
        rebuild_layer_control(proxy, active_groups())
      }
    })

    # Display streams
    observeEvent(streams(), {
      proxy <- leaflet::leafletProxy("map")
      proxy |> leaflet::clearGroup("Streams")
      streams_data <- streams()
      if (!is.null(streams_data) && nrow(streams_data) > 0) {
        # Drop empty geometries that crash leaflet
        streams_data <- streams_data[!sf::st_is_empty(streams_data), ]
        if (nrow(streams_data) == 0) return()
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
        add_group("Streams")
        rebuild_layer_control(proxy, active_groups())
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
        add_group("Break Points")
        rebuild_layer_control(proxy, active_groups())
      }
    })

    # Display sub-basins
    observe({
      proxy <- leaflet::leafletProxy("map")
      proxy |> leaflet::clearGroup("Sub-Basins")
      sb <- breaks_rv$subbasins
      if (!is.null(sb) && nrow(sb) > 0) {
        sb$label <- ifelse(nzchar(sb$name_basin), sb$name_basin, sb$gnis_name)
        pal <- leaflet::colorFactor("Set2", sb$label)
        proxy |>
          leaflet::addPolygons(
            data = sb,
            color = ~pal(label), weight = 2,
            fillColor = ~pal(label), fillOpacity = 0.3,
            popup = ~paste0(
              "<b>", gnis_name, "</b><br>",
              ifelse(nzchar(name_basin), paste0("Basin: ", name_basin, "<br>"), ""),
              "BLK: ", blk, "<br>",
              "DRM: ", round(drm, 1), "<br>",
              "Area: ", area_km2, " km\u00b2"
            ),
            group = "Sub-Basins"
          )
        add_group("Sub-Basins")
        rebuild_layer_control(proxy, active_groups())
      }
    })

  })
}
