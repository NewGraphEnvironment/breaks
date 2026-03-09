#' Break points module UI
#'
#' @param id Module namespace id
#' @noRd
mod_breaks_ui <- function(id) {
  ns <- NS(id)
  tagList(
    h4("Break Points")
  )
}

#' Break points module server
#'
#' @param id Module namespace id
#' @param aoi ReactiveVal for the AOI polygon
#' @param streams ReactiveVal for stream segments
#' @param breaks_rv ReactiveValues for break points and subbasins
#' @param map_click ReactiveVal for map click events
#' @noRd
mod_breaks_server <- function(id, aoi, streams, breaks_rv, map_click) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns
  })
}
