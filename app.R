# Launch the ShinyApp
# This file is used by shiny::runApp() and rsconnect for deployment.
# Do not remove.
pkgload::load_all(
  export_all = FALSE,
  helpers = FALSE,
  attach_testthat = FALSE
)

breaks::run_app()
