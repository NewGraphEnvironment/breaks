# breaks

**Interactive watershed break point delineation** — a Shiny app for
clicking stream networks to place break points, delineating upstream
watersheds, and exporting sub-basins via pairwise subtraction.

Given a stream network and an area of interest, breaks lets you place
points on streams, snap them to the FWA network, delineate the upstream
watershed for each, and compute non-overlapping sub-basins by
subtracting upstream catchments from downstream ones. Upload a CSV with
extra columns — they’re preserved through snap and export.

  

![breaks app screenshot showing sub-basins delineated along the Neexdzii
Kwah watershed](reference/figures/screenshot.png)

## Install

``` r

# install.packages("pak")
pak::pak("NewGraphEnvironment/breaks")
```

## Quick Start

``` r

# Requires PostgreSQL with fwapg (via fresh)
# Set PG_*_SHARE env vars for database connection
breaks::run_app()
```

## How It Works

1.  **Define AOI** — three methods:

    - Type-ahead dropdown of BC watershed groups
    - Click the map to delineate an upstream watershed
    - Upload a GeoPackage or GeoJSON
    - Draw a polygon on the map

2.  **Place break points** — click streams to place points (or upload a
    CSV with `lon`/`lat` columns). Each point snaps to the nearest FWA
    stream segment. Edit the `name_basin` column in the table to label
    each sub-basin.

3.  **Compute sub-basins** — via
    [`fresh::frs_watershed_split()`](https://github.com/NewGraphEnvironment/fresh):
    delineate, sort by area, pairwise subtract, optionally clip to AOI.

4.  **Export** — download `break_points.csv` (all columns preserved
    including `name_basin`) and `subbasins.gpkg` (EPSG:3005).

## Requires

- PostgreSQL with [fwapg](https://github.com/smnorris/fwapg) (accessed
  via [fresh](https://github.com/NewGraphEnvironment/fresh))
- SSH tunnel or direct connection to the database
- `PG_*_SHARE` environment variables configured

## Part of the Ecosystem

breaks is one piece of a larger watershed analysis workflow:

| Package | Role |
|----|----|
| [link](https://www.newgraphenvironment.com/link/) | Build, compare and test fish habitat and access models, every fish habitat definition editable |
| [fresh](https://www.newgraphenvironment.com/fresh/) | Splits streams at barriers, classifies habitat by species, traces what’s upstream |
| [wet](https://www.newgraphenvironment.com/wet/) | Typical flow in nearly every stream, tested against gauges; station flow and temperature |
| [flooded](https://www.newgraphenvironment.com/flooded/) | Maps floodplains from terrain: the valley floor a river can spread across |
| [drift](https://www.newgraphenvironment.com/drift/) | Maps what changed in land cover, where and when, in a floodplain or any area, from free satellite maps or your own |
| [fly](https://www.newgraphenvironment.com/fly/) | Puts BC’s historic airphotos back on the map from free thumbnails |
| [cd](https://www.newgraphenvironment.com/cd/) | How far any BC watershed’s climate has shifted from your chosen baseline |
| [knowledge](https://www.newgraphenvironment.com/knowledge/) | Starts from each species’ life history and tunes its fish habitat definitions from where sampling did and did not catch it |
| [floodplains](https://www.newgraphenvironment.com/floodplains/) | Maps BC’s floodplains and how the land in them changed, one watershed group at a time |
| [crate](https://www.newgraphenvironment.com/crate/) | Canonical schemas for data that changes shape, and provenance receipts for outputs |
| [stac_floodplains_bc](https://www.newgraphenvironment.com/stac_floodplains_bc/) | Floodplains and land-cover change, a screen for where to look; by watershed group |

Its sibling app, [diggs](https://www.newgraphenvironment.com/diggs/),
chooses the historic airphotos to order for a site.

Pipeline: fresh (network data) → breaks (sub-basins) → flooded
(floodplains) → drift (land cover change).
