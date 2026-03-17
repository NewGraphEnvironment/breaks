# Changelog

## breaks 0.3.0

- Add editable `name_basin` column to break points table
  ([\#5](https://github.com/NewGraphEnvironment/breaks/issues/5))
- Migrate sub-basin computation to
  [`fresh::frs_watershed_split()`](https://newgraphenvironment.github.io/fresh/reference/frs_watershed_split.html)
  ([\#6](https://github.com/NewGraphEnvironment/breaks/issues/6))
- Pass `name_basin` through to sub-basin output and map popups
- Sub-basin popups now show area and basin name
- Remove internal watershed cache (fresh handles delineation)
- Migrate to fresh conn-first API — single shared DB connection per
  session
  ([\#10](https://github.com/NewGraphEnvironment/breaks/issues/10))
- Fix download buttons not working inside bslib sidebar

## breaks 0.2.0

- Rename package from [`break`](https://rdrr.io/r/base/Control.html) to
  `breaks` ([`break`](https://rdrr.io/r/base/Control.html) is a reserved
  word in R)
- Update all URLs and references for repo rename
- Fix CSV upload overwriting snap results with stale values from
  previous exports

## breaks 0.1.0

Initial release. Interactive Shiny app for watershed break point
delineation on BC’s FWA stream network.
