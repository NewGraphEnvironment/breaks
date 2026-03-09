#' AOI selection module UI
#'
#' @param id Module namespace id
#' @noRd
mod_aoi_ui <- function(id) {
  ns <- NS(id)
  tagList(
    h4("Area of Interest")
  )
}

#' AOI selection module server
#'
#' @param id Module namespace id
#' @param aoi ReactiveVal for the AOI polygon
#' @param map_click ReactiveVal for map click events
#' @noRd
mod_aoi_server <- function(id, aoi, map_click) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns
  })
}
