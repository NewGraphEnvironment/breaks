# Task Plan: Scaffold break golem Shiny app

## Goal
Port the watershed picker from `restoration_wedzin_kwa_2024/scripts/lulc_watershed-picker.R` into a reusable golem Shiny app. Generalize for any BC AOI. Key enhancement: CSV column preservation.

Relates to NewGraphEnvironment/break#1.

## Phases

### Phase 0: Planning with Files setup
- [x] Create `planning/task_plan.md`
- [x] Create `planning/findings.md`
- [x] Create `planning/progress.md`
- [ ] Commit PWF files

### Phase 1: Package scaffold
- [x] `DESCRIPTION` (Package: break, Imports: golem, shiny, bslib, sf, leaflet, leaflet.extras, fresh, DT, dplyr, config, fs)
- [x] `LICENSE` (MIT, New Graph Environment Ltd.)
- [x] `app.R` (golem launcher: pkgload::load_all + run_app)
- [x] `R/run_app.R` (exported run_app with golem_opts)
- [x] `R/app_config.R` (app_sys + get_golem_config — from diggs)
- [x] `R/break-package.R` (package doc, @import shiny, @importFrom golem)
- [x] `inst/golem-config.yml` (golem_name: break)
- [x] `inst/app/www/.gitkeep`
- [x] `.Rbuildignore`, `.gitignore`
- [x] `NAMESPACE` (via devtools::document)
- [ ] Commit

### Phase 2: App skeleton + stub modules
- [x] `R/app_ui.R` (bslib page_sidebar layout)
- [x] `R/app_server.R` (shared reactives: aoi, streams, breaks_rv, map_click; module wiring; stream fetch on AOI change)
- [x] Stub `R/mod_aoi.R` (empty UI + server)
- [x] Stub `R/mod_map.R` (leafletOutput + blank map)
- [x] Stub `R/mod_breaks.R` (empty UI + server)
- [x] Stub `R/mod_export.R` (empty UI + server)
- [x] Commit

### Phase 3: mod_map.R — leaflet basemap + click handling
- [x] Provider tiles: OpenTopoMap, Satellite, OSM
- [x] Layer groups: AOI, Streams, Break Points, Sub-Basins
- [x] Reactive observers for AOI/streams/breaks/subbasins via leafletProxy
- [x] Forward map clicks to map_click() reactive
- [x] Draw toolbar for polygon AOI (leaflet.extras)
- [x] `R/utils_geo.R` (drawn_feature_to_sf, validate_geometry — from diggs)
- [x] Commit

### Phase 4: mod_aoi.R — 3 AOI entry points
- [x] Upload gpkg/geojson -> sf::st_read -> aoi()
- [x] Watershed group dropdown -> frs_db_query -> aoi()
- [x] Click-to-delineate -> frs_point_snap + frs_watershed_at_measure -> aoi()
- [x] Draw polygon on map -> aoi() (via mod_map draw toolbar)
- [x] Commit

### Phase 5: mod_breaks.R — break point management + CSV column preservation
- [ ] CSV load with column preservation (lon/lat required, extras preserved via bind_rows)
- [ ] Map click to add break point (snap via frs_point_snap)
- [ ] Remove by marker click / clear last / clear all
- [ ] Compute sub-basins (delineate via frs_watershed_at_measure, pairwise st_difference)
- [ ] DT tables for break points and sub-basins
- [ ] Commit

### Phase 6: mod_export.R — download handlers
- [ ] downloadHandler for break_points.csv (ALL columns including CSV extras)
- [ ] downloadHandler for subbasins.gpkg (EPSG:3005)
- [ ] Commit

### Phase 7: data-raw/example_neexdzii.R
- [ ] Worked example: Neexdzii Kwa AOI + break points
- [ ] Commit

## Key Design Decisions

1. **`dplyr::bind_rows` for column preservation** — auto-fills NA for missing cols
2. **`breaks_rv` as `reactiveValues`** — multiple sub-fields mutated independently
3. **Streams fetched in app_server** — shared between mod_map and mod_breaks
4. **`sf::sf_use_s2(FALSE)`** — required for reliable pairwise subtraction
5. **EPSG:3005 for area/export, 4326 for display**

## Errors Encountered

| Error | Attempt | Resolution |
|-------|---------|------------|
| (none yet) | | |
