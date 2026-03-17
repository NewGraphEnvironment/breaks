#' AOI selection module UI
#'
#' Three methods for defining the area of interest: watershed group dropdown,
#' click-to-delineate, or upload a gpkg/geojson file. Drawing on the map is
#' handled in mod_map via the draw toolbar.
#'
#' Controls collapse once AOI is set (app switches to break point mode).
#' "Reset AOI" clears everything and returns to AOI selection.
#'
#' @param id Module namespace id
#' @noRd
mod_aoi_ui <- function(id) {
  ns <- NS(id)
  tagList(
    h4("Area of Interest"),
    uiOutput(ns("aoi_controls"))
  )
}

#' AOI selection module server
#'
#' @param id Module namespace id
#' @param aoi ReactiveVal for the AOI polygon
#' @param aoi_meta ReactiveVal for AOI metadata (method, blk, drm, wsg_code)
#' @param app_mode ReactiveVal for app mode ("aoi" or "breaks")
#' @param map_click ReactiveVal for map click events
#' @noRd
mod_aoi_server <- function(id, conn, aoi, aoi_meta, app_mode, map_click) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Store click coords for delineation
    click_coords <- reactiveVal(NULL)
    wsg_lookup <- reactiveVal(NULL)

    # Dynamic UI: show controls or summary based on app_mode
    output$aoi_controls <- renderUI({
      if (app_mode() == "breaks" && !is.null(aoi())) {
        # AOI is set — show summary and reset button
        meta <- aoi_meta()
        method_label <- switch(meta$method %||% "unknown",
          wsg = paste("Watershed Group:", meta$wsg_code),
          click = paste("Delineated: blk=", meta$blk),
          upload = "Uploaded file",
          draw = "Drawn polygon",
          "Unknown"
        )
        tagList(
          tags$p(tags$strong("AOI set"), tags$br(),
                 tags$small(method_label)),
          actionButton(ns("reset_aoi"), "Reset AOI",
                       class = "btn-sm btn-outline-danger")
        )
      } else {
        # AOI selection mode
        tagList(
          radioButtons(ns("aoi_method"), NULL,
            choices = c(
              "Watershed Group" = "wsg",
              "Click to Delineate" = "click",
              "Upload File" = "upload"
            ),
            selected = "upload", inline = TRUE
          ),
          conditionalPanel(
            condition = sprintf("input['%s'] == 'wsg'", ns("aoi_method")),
            selectizeInput(ns("wsg_name"), "Watershed Group",
              choices = NULL,
              options = list(placeholder = "Type to search..."))
          ),
          conditionalPanel(
            condition = sprintf("input['%s'] == 'click'", ns("aoi_method")),
            helpText("Click the map to place a point, then delineate its upstream watershed as AOI."),
            actionButton(ns("delineate_aoi"), "Delineate AOI",
                         class = "btn-sm btn-primary")
          ),
          conditionalPanel(
            condition = sprintf("input['%s'] == 'upload'", ns("aoi_method")),
            fileInput(ns("upload_aoi"), "Upload AOI (gpkg or geojson)",
              accept = c(".gpkg", ".geojson", ".json")),
            helpText("Or draw a polygon on the map.")
          )
        )
      }
    })

    # Reset AOI — clear everything and return to AOI mode
    observeEvent(input$reset_aoi, {
      aoi(NULL)
      aoi_meta(NULL)
      app_mode("aoi")
      showNotification("AOI cleared", type = "message")
    })

    # Populate watershed group dropdown server-side
    observe({
      req(app_mode() == "aoi")
      if (!is.null(wsg_lookup())) return()
      result <- tryCatch({
        fresh::frs_db_query(conn,
          "SELECT DISTINCT watershed_group_code, watershed_group_name
           FROM whse_basemapping.fwa_watershed_groups_poly
           ORDER BY watershed_group_name"
        )
      }, error = function(e) {
        showNotification(paste("Could not load watershed groups:", e$message),
                         type = "warning")
        NULL
      })
      if (!is.null(result)) {
        wsg_lookup(result)
      }
    })

    # Update selectize when lookup is ready and UI is showing
    observe({
      req(app_mode() == "aoi", !is.null(wsg_lookup()))
      updateSelectizeInput(session, "wsg_name",
        choices = wsg_lookup()$watershed_group_name, server = TRUE)
    })

    # Method 1: Watershed group selection
    observeEvent(input$wsg_name, {
      req(app_mode() == "aoi", input$aoi_method == "wsg", input$wsg_name != "")
      withProgress(message = "Loading watershed group...", {
        lookup <- wsg_lookup()
        wsg_code <- lookup$watershed_group_code[
          lookup$watershed_group_name == input$wsg_name
        ]
        if (length(wsg_code) == 0) {
          showNotification("Watershed group not found", type = "error")
          return()
        }
        result <- tryCatch(
          fresh::frs_db_query(conn, sprintf(
            "SELECT ST_Transform(geom, 4326) as geom
             FROM whse_basemapping.fwa_watershed_groups_poly
             WHERE watershed_group_code = '%s'",
            wsg_code[1]
          )),
          error = function(e) {
            showNotification(paste("Watershed group query failed:", e$message),
                             type = "error")
            NULL
          }
        )
        if (!is.null(result) && nrow(result) > 0) {
          aoi_meta(list(method = "wsg", wsg_code = wsg_code[1]))
          aoi(sf::st_union(result) |> sf::st_sf())
          showNotification(paste("AOI set:", input$wsg_name), type = "message")
        }
      })
    })

    # Method 2: Click-to-delineate — capture click (only in AOI mode)
    observe({
      req(app_mode() == "aoi")
      click <- map_click()
      req(!is.null(click), is.null(click$id))
      isolate({
        req(input$aoi_method == "click")
        click_coords(click)
        showNotification(
          paste0("Click captured: ", round(click$lng, 4), ", ", round(click$lat, 4),
                 ". Press 'Delineate AOI' to proceed."),
          type = "message"
        )
      })
    })

    # Method 2: Delineate watershed from click
    observeEvent(input$delineate_aoi, {
      req(click_coords())
      click <- click_coords()
      withProgress(message = "Snapping and delineating...", {
        snap <- tryCatch(
          fresh::frs_point_snap(conn, click$lng, click$lat),
          error = function(e) {
            showNotification(paste("Snap failed:", e$message), type = "error")
            NULL
          }
        )
        if (is.null(snap) || nrow(snap) == 0) {
          showNotification("No stream found nearby", type = "warning")
          return()
        }
        ws <- tryCatch(
          fresh::frs_watershed_at_measure(conn,
            snap$blue_line_key[1],
            snap$downstream_route_measure[1]
          ),
          error = function(e) {
            showNotification(paste("Delineation failed:", e$message),
                             type = "error")
            NULL
          }
        )
        if (!is.null(ws) && nrow(ws) > 0) {
          ws <- sf::st_transform(ws, 4326)
          aoi_meta(list(
            method = "click",
            blk = snap$blue_line_key[1],
            drm = snap$downstream_route_measure[1]
          ))
          aoi(ws)
          showNotification(
            paste0("AOI delineated: ", snap$gnis_name[1],
                   " (blk=", snap$blue_line_key[1], ")"),
            type = "message"
          )
        }
      })
      click_coords(NULL)
    })

    # Method 3: Upload file
    observeEvent(input$upload_aoi, {
      req(input$upload_aoi)
      result <- tryCatch({
        layer <- sf::st_read(input$upload_aoi$datapath, quiet = TRUE)
        layer <- sf::st_transform(layer, 4326)
        layer <- validate_geometry(layer)
        sf::st_union(layer) |> sf::st_sf()
      }, error = function(e) {
        showNotification(paste("Upload failed:", e$message), type = "error")
        NULL
      })
      if (!is.null(result) && nrow(result) > 0) {
        aoi_meta(list(method = "upload"))
        aoi(result)
        showNotification("AOI loaded from file", type = "message")
      }
    })
  })
}
