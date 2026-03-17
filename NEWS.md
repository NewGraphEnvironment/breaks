# breaks 0.3.0

- Add editable `name_basin` column to break points table (#5)
- Migrate sub-basin computation to `fresh::frs_watershed_split()` (#6)
- Pass `name_basin` through to sub-basin output and map popups
- Sub-basin popups now show area and basin name
- Remove internal watershed cache (fresh handles delineation)
- Migrate to fresh conn-first API — single shared DB connection per session (#10)
- Fix download buttons not working inside bslib sidebar

# breaks 0.2.0

- Rename package from `break` to `breaks` (`break` is a reserved word in R)
- Update all URLs and references for repo rename
- Fix CSV upload overwriting snap results with stale values from previous exports

# breaks 0.1.0

Initial release. Interactive Shiny app for watershed break point delineation on BC's FWA stream network.
