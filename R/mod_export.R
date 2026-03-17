#' Export module UI
#'
#' @param id Module namespace id
#' @noRd
mod_export_ui <- function(id) {
  ns <- NS(id)
  tagList(
    h4("Export"),
    tags$a(
      id = ns("dl_breaks"),
      class = "btn btn-sm btn-outline-primary shiny-download-link",
      href = "", target = "_blank", download = NA,
      icon("download"), "Break Points CSV"
    ),
    tags$a(
      id = ns("dl_subbasins"),
      class = "btn btn-sm btn-outline-success shiny-download-link",
      href = "", target = "_blank", download = NA,
      icon("download"), "Sub-Basins GPKG"
    )
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
        "break_points.csv"
      },
      content = function(file) {
        write.csv(breaks_rv$points, file, row.names = FALSE)
      }
    )

    output$dl_subbasins <- downloadHandler(
      filename = function() {
        "subbasins.gpkg"
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
