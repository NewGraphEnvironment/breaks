#' Break points module UI
#'
#' @param id Module namespace id
#' @noRd
mod_breaks_ui <- function(id) {
  ns <- NS(id)
  tagList(
    h4("Break Points"),
    radioButtons(ns("mode"), "Click Mode:",
      choices = c("Add" = "add", "Remove" = "remove"),
      selected = "add", inline = TRUE),
    helpText("Add: click streams. Remove: click a break marker."),
    hr(),
    fileInput(ns("load_csv"), "Load Break Points CSV",
      accept = ".csv"),
    helpText("CSV must have 'lon' and 'lat' columns. Extra columns are preserved."),
    hr(),
    actionButton(ns("clear_last"), "Remove Last", class = "btn-sm btn-warning"),
    actionButton(ns("clear_all"), "Clear All", class = "btn-sm btn-danger"),
    hr(),
    actionButton(ns("compute"), "Compute Sub-Basins", class = "btn-sm btn-primary"),
    hr(),
    h5("Break Points"),
    DT::DTOutput(ns("points_table")),
    hr(),
    h5("Sub-Basins"),
    DT::DTOutput(ns("subbasins_table"))
  )
}

#' Break points module server
#'
#' Manages break point placement, snapping, watershed delineation, and
#' pairwise subtraction to compute sub-basins. CSV uploads preserve all
#' extra columns beyond lon/lat.
#'
#' @param id Module namespace id
#' @param aoi ReactiveVal for the AOI polygon
#' @param streams ReactiveVal for stream segments
#' @param breaks_rv ReactiveValues for break points and subbasins
#' @param app_mode ReactiveVal for app mode ("aoi" or "breaks")
#' @param map_click ReactiveVal for map click events
#' @noRd
mod_breaks_server <- function(id, aoi, streams, breaks_rv, app_mode, map_click) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    sf::sf_use_s2(FALSE)

    # --- Helper: snap a point and return a one-row data frame ---
    snap_point <- function(lon, lat, extra = NULL) {
      result <- fresh::frs_point_snap(lon, lat)
      if (is.null(result) || nrow(result) == 0) return(NULL)

      new_id <- if (nrow(breaks_rv$points) == 0) 1L else max(breaks_rv$points$id) + 1L

      row <- data.frame(
        id = new_id,
        lon = lon,
        lat = lat,
        blk = as.integer(result$blue_line_key[1]),
        drm = result$downstream_route_measure[1],
        gnis_name = result$gnis_name[1] %||% "",
        dist_m = round(result$distance_to_stream[1], 1),
        stringsAsFactors = FALSE
      )

      # Append extra columns from CSV
      if (!is.null(extra)) {
        for (col in names(extra)) {
          row[[col]] <- extra[[col]]
        }
      }

      row
    }

    # --- Map click to add break point ---
    observeEvent(map_click(), {
      req(app_mode() == "breaks", input$mode == "add")
      click <- map_click()
      # Skip marker clicks (those have an id starting with "break_")
      if (!is.null(click$id) && grepl("^break_", click$id)) return()

      withProgress(message = "Snapping to stream...", {
        row <- tryCatch(
          snap_point(click$lng, click$lat),
          error = function(e) {
            showNotification(paste("Snap failed:", e$message), type = "error")
            NULL
          }
        )
      })

      if (is.null(row)) {
        showNotification("No stream found nearby", type = "warning")
        return()
      }

      breaks_rv$points <- dplyr::bind_rows(breaks_rv$points, row)
      breaks_rv$subbasins <- NULL

      showNotification(
        paste0("Break #", row$id, ": ", row$gnis_name,
               " (blk=", row$blk, ", drm=", round(row$drm, 1),
               ", snap=", row$dist_m, "m)"),
        type = "message"
      )
    })

    # --- Click to remove nearest break point (Remove mode) ---
    # Circle markers don't reliably fire marker_click/shape_click,
    # so match click coords against existing points by proximity
    observeEvent(map_click(), {
      req(app_mode() == "breaks", input$mode == "remove")
      click <- map_click()
      req(!is.null(click$lng), !is.null(click$lat))
      pts <- breaks_rv$points
      if (nrow(pts) == 0) return()

      # Find nearest break point (simple Euclidean on lon/lat is fine at map scale)
      dists <- sqrt((pts$lon - click$lng)^2 + (pts$lat - click$lat)^2)
      nearest <- which.min(dists)
      # Threshold ~0.01 degrees (~1km) to avoid removing distant points
      if (dists[nearest] > 0.01) return()

      rm_id <- pts$id[nearest]
      breaks_rv$points <- pts[pts$id != rm_id, ]
      breaks_rv$watersheds[[as.character(rm_id)]] <- NULL
      breaks_rv$subbasins <- NULL

      showNotification(paste0("Removed break #", rm_id), type = "message")
    })

    # --- Load break points from CSV ---
    observeEvent(input$load_csv, {
      pts <- tryCatch(
        read.csv(input$load_csv$datapath, stringsAsFactors = FALSE),
        error = function(e) {
          showNotification(paste("CSV read failed:", e$message), type = "error")
          NULL
        }
      )
      if (is.null(pts)) return()

      if (!all(c("lon", "lat") %in% names(pts))) {
        showNotification("CSV must have 'lon' and 'lat' columns", type = "error")
        return()
      }

      snap_cols <- c("lon", "lat", "id", "blk", "drm", "gnis_name", "dist_m")
      extra_cols <- setdiff(names(pts), snap_cols)
      n <- nrow(pts)
      loaded <- 0L

      withProgress(message = "Snapping points to streams...", value = 0, {
        for (i in seq_len(n)) {
          incProgress(1 / n, detail = paste(i, "of", n))

          # Build named list of extra column values for this row
          extra <- if (length(extra_cols) > 0) {
            as.list(pts[i, extra_cols, drop = FALSE])
          } else {
            NULL
          }

          row <- tryCatch(
            snap_point(pts$lon[i], pts$lat[i], extra = extra),
            error = function(e) {
              message("Snap error for point ", i, ": ", e$message)
              NULL
            }
          )
          if (is.null(row)) next

          breaks_rv$points <- dplyr::bind_rows(breaks_rv$points, row)
          loaded <- loaded + 1L
        }
      })

      breaks_rv$subbasins <- NULL
      showNotification(
        paste(loaded, "of", n, "points loaded and snapped"),
        type = "message"
      )
    })

    # --- Remove last point ---
    observeEvent(input$clear_last, {
      if (nrow(breaks_rv$points) == 0) return()
      last_id <- max(breaks_rv$points$id)
      breaks_rv$points <- breaks_rv$points[breaks_rv$points$id != last_id, ]
      breaks_rv$watersheds[[as.character(last_id)]] <- NULL
      breaks_rv$subbasins <- NULL
    })

    # --- Clear all ---
    observeEvent(input$clear_all, {
      breaks_rv$points <- breaks_rv$points[0, ]
      breaks_rv$watersheds <- list()
      breaks_rv$subbasins <- NULL
    })

    # --- Compute sub-basins ---
    observeEvent(input$compute, {
      if (nrow(breaks_rv$points) == 0) {
        showNotification("No break points placed", type = "warning")
        return()
      }

      breaks <- breaks_rv$points

      # Delineate watershed for each break point
      withProgress(message = "Delineating watersheds...", value = 0, {
        for (i in seq_len(nrow(breaks))) {
          incProgress(1 / nrow(breaks),
                      detail = paste("Point", i, "of", nrow(breaks)))
          bid <- as.character(breaks$id[i])
          if (!is.null(breaks_rv$watersheds[[bid]])) next

          ws <- tryCatch(
            fresh::frs_watershed_at_measure(breaks$blk[i], breaks$drm[i]),
            error = function(e) {
              showNotification(
                paste0("Watershed failed for #", breaks$id[i], ": ", e$message),
                type = "error"
              )
              NULL
            }
          )
          if (!is.null(ws)) {
            breaks_rv$watersheds[[bid]] <- sf::st_transform(ws, 4326)
          }
        }
      })

      # Pairwise subtraction
      withProgress(message = "Computing sub-basins...", {
        ws_list <- breaks_rv$watersheds
        valid_ids <- breaks$id[
          sapply(as.character(breaks$id), function(x) !is.null(ws_list[[x]]))
        ]
        breaks_valid <- breaks[breaks$id %in% valid_ids, ]

        if (nrow(breaks_valid) == 0) {
          showNotification("No valid watersheds", type = "error")
          return()
        }

        # Sort by area (largest = most downstream)
        areas <- sapply(as.character(breaks_valid$id), function(x) {
          as.numeric(sf::st_area(sf::st_transform(ws_list[[x]], 3005)))
        })
        breaks_valid <- breaks_valid[order(-areas), ]

        subbasin_list <- list()
        for (i in seq_len(nrow(breaks_valid))) {
          bid <- as.character(breaks_valid$id[i])
          poly <- ws_list[[bid]]

          # Subtract all smaller (upstream) watersheds that intersect
          if (i < nrow(breaks_valid)) {
            for (j in (i + 1):nrow(breaks_valid)) {
              ubid <- as.character(breaks_valid$id[j])
              upstream_poly <- ws_list[[ubid]]
              if (is.null(upstream_poly)) next
              if (!sf::st_intersects(poly, upstream_poly, sparse = FALSE)[1, 1]) next

              poly <- tryCatch({
                d <- sf::st_difference(poly, upstream_poly)
                if (any(sf::st_geometry_type(d) == "GEOMETRYCOLLECTION")) {
                  d <- sf::st_collection_extract(d, "POLYGON")
                }
                if (nrow(d) > 0) {
                  d_union <- sf::st_union(d)
                  sf::st_sf(geometry = d_union)
                } else {
                  poly
                }
              }, error = function(e) poly)
            }
          }

          subbasin_list[[bid]] <- sf::st_sf(
            break_id = breaks_valid$id[i],
            blk = breaks_valid$blk[i],
            drm = breaks_valid$drm[i],
            gnis_name = breaks_valid$gnis_name[i],
            geometry = sf::st_geometry(poly)
          )
        }

        result <- do.call(rbind, subbasin_list)
        sf::st_crs(result) <- 4326
        breaks_rv$subbasins <- sf::st_cast(result, "MULTIPOLYGON")
      })

      showNotification(
        paste(nrow(breaks_rv$subbasins), "sub-basins computed"),
        type = "message"
      )
    })

    # --- DT tables ---
    output$points_table <- DT::renderDT({
      req(nrow(breaks_rv$points) > 0)
      breaks_rv$points
    }, options = list(pageLength = 5, scrollX = TRUE), rownames = FALSE)

    output$subbasins_table <- DT::renderDT({
      req(!is.null(breaks_rv$subbasins))
      sb <- breaks_rv$subbasins
      sb$area_km2 <- round(
        as.numeric(sf::st_area(sf::st_transform(sb, 3005))) / 1e6, 1
      )
      sf::st_drop_geometry(sb)
    }, options = list(pageLength = 5, scrollX = TRUE), rownames = FALSE)
  })
}
