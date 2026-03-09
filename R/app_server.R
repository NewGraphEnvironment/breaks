#' The application server-side
#'
#' @param input,output,session Internal parameters for `{shiny}`.
#' @import shiny
#' @noRd
app_server <- function(input, output, session) {
  # Shared reactive values

  aoi <- reactiveVal(NULL)
  streams <- reactiveVal(NULL)
  breaks_rv <- reactiveValues(
    points = data.frame(
      id = integer(), lon = numeric(), lat = numeric(),
      blk = integer(), drm = numeric(), gnis_name = character(),
      dist_m = numeric(),
      stringsAsFactors = FALSE
    ),
    watersheds = list(),
    subbasins = NULL
  )
  map_click <- reactiveVal(NULL)

  # Wire modules
  mod_aoi_server("aoi", aoi = aoi, map_click = map_click)
  mod_map_server("map", aoi = aoi, streams = streams,
                 breaks_rv = breaks_rv, map_click = map_click)
  mod_breaks_server("breaks", aoi = aoi, streams = streams,
                    breaks_rv = breaks_rv, map_click = map_click)
  mod_export_server("export", breaks_rv = breaks_rv)

  # Fetch streams when AOI changes
  observeEvent(aoi(), {
    req(aoi())
    withProgress(message = "Fetching streams...", {
      bbox_3005 <- sf::st_bbox(sf::st_transform(aoi(), 3005))
      result <- tryCatch(
        fresh::frs_stream_fetch(bbox = as.numeric(bbox_3005)),
        error = function(e) {
          showNotification(paste("Stream fetch failed:", e$message),
                           type = "error")
          NULL
        }
      )
      if (!is.null(result)) {
        streams(sf::st_transform(result, 4326))
      }
    })
  })
}
