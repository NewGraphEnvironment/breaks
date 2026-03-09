#' Export module UI
#'
#' @param id Module namespace id
#' @noRd
mod_export_ui <- function(id) {
  ns <- NS(id)
  tagList(
    h4("Export"),
    downloadButton(ns("dl_breaks"), "Break Points CSV",
                   class = "btn-sm btn-outline-primary"),
    downloadButton(ns("dl_subbasins"), "Sub-Basins GPKG",
                   class = "btn-sm btn-outline-success")
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

    output$dl_breaks <- downloadHandler(
      filename = function() {
        paste0("break_points_", format(Sys.Date(), "%Y%m%d"), ".csv")
      },
      content = function(file) {
        write.csv(breaks_rv$points, file, row.names = FALSE)
      }
    )

    output$dl_subbasins <- downloadHandler(
      filename = function() {
        paste0("subbasins_", format(Sys.Date(), "%Y%m%d"), ".gpkg")
      },
      content = function(file) {
        req(breaks_rv$subbasins)
        sf::st_write(
          sf::st_transform(breaks_rv$subbasins, 3005),
          file, delete_dsn = TRUE, quiet = TRUE
        )
      }
    )
  })
}
