#' The application User-Interface
#'
#' @param request Internal parameter for `{shiny}`.
#' @import shiny
#' @noRd
app_ui <- function(request) {
  tagList(
    golem_add_external_resources(),
    bslib::page_sidebar(
      title = "break",
      sidebar = bslib::sidebar(
        width = 350,
        mod_aoi_ui("aoi"),
        tags$hr(),
        mod_breaks_ui("breaks"),
        tags$hr(),
        mod_export_ui("export")
      ),
      mod_map_ui("map")
    )
  )
}

#' Add external resources to the application
#'
#' @import shiny
#' @importFrom golem add_resource_path activate_js favicon bundle_resources
#' @noRd
golem_add_external_resources <- function() {
  add_resource_path("www", app_sys("app/www"))

  tags$head(
    favicon(),
    bundle_resources(
      path = app_sys("app/www"),
      app_title = "break"
    )
  )
}
