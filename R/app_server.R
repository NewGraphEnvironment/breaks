#' The application server-side
#'
#' @param input,output,session Internal parameters for `{shiny}`.
#' @import shiny
#' @noRd
app_server <- function(input, output, session) {
  # Database connection — shared across all modules
  conn <- fresh::frs_db_conn()
  session$onSessionEnded(function() DBI::dbDisconnect(conn))

  # Shared reactive values

  app_mode <- reactiveVal("aoi")  # "aoi" or "breaks"
  aoi <- reactiveVal(NULL)
  aoi_meta <- reactiveVal(NULL)  # list(method, blk, drm, wsg_code)
  streams <- reactiveVal(NULL)
  breaks_rv <- reactiveValues(
    points = data.frame(
      id = integer(), lon = numeric(), lat = numeric(),
      blk = integer(), drm = numeric(), gnis_name = character(),
      dist_m = numeric(), name_basin = character(),
      stringsAsFactors = FALSE
    ),
    subbasins = NULL
  )
  map_click <- reactiveVal(NULL)

  # Auto-switch to breaks mode when AOI is set
  observeEvent(aoi(), {
    if (!is.null(aoi())) {
      app_mode("breaks")
    }
  })

  # Wire modules
  mod_aoi_server("aoi", conn = conn, aoi = aoi, aoi_meta = aoi_meta,
                 app_mode = app_mode, map_click = map_click)
  mod_map_server("map", aoi = aoi, aoi_meta = aoi_meta, streams = streams,
                 breaks_rv = breaks_rv, map_click = map_click)
  mod_breaks_server("breaks", conn = conn, aoi = aoi, streams = streams,
                    breaks_rv = breaks_rv, app_mode = app_mode,
                    map_click = map_click)
  mod_export_server("export", breaks_rv = breaks_rv)

  # Clean streams for leaflet display
  clean_streams <- function(result) {
    result <- sf::st_transform(result, 4326)
    result <- sf::st_zm(result, drop = TRUE)
    result <- result[!sf::st_is_empty(result), ]
    sf::st_cast(result, "MULTILINESTRING")
  }

  # Fetch streams when AOI changes — method-aware
  observeEvent(aoi(), {
    req(aoi())
    meta <- aoi_meta()
    method <- if (!is.null(meta)) meta$method else "spatial"

    withProgress(message = "Fetching streams...", {
      result <- tryCatch({
        if (method == "wsg" && !is.null(meta$wsg_code)) {
          fresh::frs_stream_fetch(conn, watershed_group_code = meta$wsg_code)

        } else if (method == "click" && !is.null(meta$blk) && !is.null(meta$drm)) {
          fresh::frs_network(conn,
            blue_line_key = meta$blk,
            downstream_route_measure = meta$drm,
            direction = "upstream"
          )

        } else {
          aoi_clean <- sf::st_zm(aoi(), drop = TRUE)
          aoi_3005 <- sf::st_transform(aoi_clean, 3005)
          bbox_3005 <- sf::st_bbox(aoi_3005)
          fetched <- fresh::frs_stream_fetch(conn, bbox = as.numeric(bbox_3005))
          fetched <- sf::st_zm(fetched, drop = TRUE)
          hits <- sf::st_intersects(fetched, aoi_3005, sparse = FALSE)[, 1]
          fetched[hits, ]
        }
      }, error = function(e) {
        showNotification(paste("Stream fetch failed:", e$message),
                         type = "error")
        NULL
      })

      if (!is.null(result) && nrow(result) > 0) {
        streams(clean_streams(result))
      }
    })
  })
}
