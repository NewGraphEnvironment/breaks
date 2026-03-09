# Findings

## Architecture Decisions

### CSV column preservation (Phase 5)
The original picker (`lulc_watershed-picker.R`) drops all CSV columns except lon/lat — it builds a hardcoded schema. Break preserves extras by:
1. Reading full CSV
2. Building core row (id, lon, lat, blk, drm, gnis_name, dist_m)
3. Appending all extra columns from CSV row
4. Using `dplyr::bind_rows()` which auto-fills NA for missing cols when map-clicked points are added

### fresh API for break
- `frs_point_snap(x, y)` — returns sf with blue_line_key, downstream_route_measure, gnis_name, distance_to_stream
- `frs_watershed_at_measure(blk, drm)` — returns sf polygon of upstream watershed
- `frs_watershed_at_measure(blk, drm, upstream_measure=...)` — already supports pairwise subtraction natively
- `frs_stream_fetch(bbox=...)` — fetch streams within bounding box
- `frs_db_query(sql)` — general SQL query returning sf

### golem pattern (from diggs)
- `app.R`: `pkgload::load_all()` + `run_app()`
- `app_config.R`: `app_sys()` + `get_golem_config()` — copy verbatim, change package name
- Module pattern: `mod_*_ui(id)` + `mod_*_server(id, ...)`, return list of reactives
- bslib `page_sidebar` layout with `golem_add_external_resources()`

### Data flow
```
mod_aoi → aoi() reactive
  ↓
app_server fetches streams via frs_stream_fetch(bbox)
  ↓
mod_map displays streams, forwards clicks → map_click()
  ↓
mod_breaks snaps, manages points, computes subbasins
  ↓
mod_export reads breaks_rv for download
```

## Reference Files

| File | Key takeaway |
|------|-------------|
| `diggs/R/app_ui.R` | bslib page_sidebar + golem_add_external_resources pattern |
| `diggs/R/utils_geo.R` | drawn_feature_to_sf() — 6 lines, converts leaflet draw GeoJSON to sf |
| `fresh/R/frs_watershed_at_measure.R` | Supports upstream_measure param for subbasin between two points |
| `lulc_watershed-picker.R:416-473` | Pairwise subtraction: sort by area desc, subtract upstream intersectors |
