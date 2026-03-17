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
mod_breaks_server <- function(id, conn, aoi, streams, breaks_rv, app_mode, map_click) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    sf::sf_use_s2(FALSE)

    # --- Helper: snap a point and return a one-row data frame ---
    snap_point <- function(lon, lat, extra = NULL) {
      result <- fresh::frs_point_snap(conn, lon, lat)
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
        name_basin = "",
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
      breaks_rv$subbasins <- NULL
    })

    # --- Clear all ---
    observeEvent(input$clear_all, {
      breaks_rv$points <- breaks_rv$points[0, ]
      breaks_rv$subbasins <- NULL
    })

    # --- Compute sub-basins ---
    observeEvent(input$compute, {
      if (nrow(breaks_rv$points) == 0) {
        showNotification("No break points placed", type = "warning")
        return()
      }

      # Build input for frs_watershed_split — lon/lat plus extra columns
      pts <- breaks_rv$points
      keep_cols <- c("lon", "lat", "name_basin",
                     setdiff(names(pts),
                             c("id", "lon", "lat", "blk", "drm",
                               "gnis_name", "dist_m", "name_basin")))
      pts_input <- pts[, keep_cols, drop = FALSE]

      withProgress(message = "Computing sub-basins...", {
        result <- tryCatch(
          fresh::frs_watershed_split(conn, pts_input, aoi = aoi()),
          error = function(e) {
            showNotification(paste("Sub-basin computation failed:", e$message),
                             type = "error")
            NULL
          }
        )
      })

      if (is.null(result) || nrow(result) == 0) {
        showNotification("No sub-basins computed", type = "error")
        return()
      }

      breaks_rv$subbasins <- result

      showNotification(
        paste(nrow(result), "sub-basins computed"),
        type = "message"
      )
    })

    # --- DT tables ---
    output$points_table <- DT::renderDT({
      req(nrow(breaks_rv$points) > 0)
      breaks_rv$points
    }, editable = list(
      target = "cell",
      disable = list(columns = which(names(breaks_rv$points) != "name_basin") - 1L)
    ), options = list(pageLength = 5, scrollX = TRUE), rownames = FALSE)

    # --- Update name_basin on cell edit ---
    observeEvent(input$points_table_cell_edit, {
      info <- input$points_table_cell_edit
      # DT row/col are 1-indexed when rownames = FALSE
      row_idx <- info$row
      col_name <- names(breaks_rv$points)[info$col + 1L]
      if (!identical(col_name, "name_basin")) return()
      breaks_rv$points[row_idx, "name_basin"] <- info$value
    })

    output$subbasins_table <- DT::renderDT({
      req(!is.null(breaks_rv$subbasins))
      sf::st_drop_geometry(breaks_rv$subbasins)
    }, options = list(pageLength = 5, scrollX = TRUE), rownames = FALSE)
  })
}
