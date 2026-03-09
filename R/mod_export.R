#' Export module UI
#'
#' @param id Module namespace id
#' @noRd
mod_export_ui <- function(id) {
  ns <- NS(id)
  tagList(
    h4("Export")
  )
}

#' Export module server
#'
#' @param id Module namespace id
#' @param breaks_rv ReactiveValues for break points and subbasins
#' @noRd
mod_export_server <- function(id, breaks_rv) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns
  })
}
