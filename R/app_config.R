#' Access files in the current app
#'
#' @param ... Character vectors, specifying subdirectory and file(s)
#'   within your package. The default, none, returns the root of the app.
#' @noRd
app_sys <- function(...) {
  system.file(..., package = "break")
}

#' Read App Config
#'
#' @param value Value to retrieve from the config file.
#' @param config GOLEM_CONFIG_ACTIVE value. If NULL, defaults to
#'   R_CONFIG_ACTIVE or "default".
#' @param use_parent Logical. If TRUE, will also look in parent configs.
#' @param file Location of the config file.
#' @noRd
get_golem_config <- function(
    value,
    config = Sys.getenv("GOLEM_CONFIG_ACTIVE", Sys.getenv("R_CONFIG_ACTIVE", "default")),
    use_parent = TRUE,
    file = app_sys("golem-config.yml")) {
  config::get(value = value, config = config, file = file, use_parent = use_parent)
}
