# break <img src="man/figures/logo.png" align="right" height="139" alt="break hex sticker"/>

**Interactive watershed break point delineation** — a Shiny app for clicking stream networks to place break points, delineating upstream watersheds, and exporting sub-basins via pairwise subtraction.

Given a stream network and an area of interest, break lets you place points on streams, snap them to the FWA network, delineate the upstream watershed for each, and compute non-overlapping sub-basins by subtracting upstream catchments from downstream ones. Upload a CSV with extra columns — they're preserved through snap and export.

<br>

<p align="center">
  <img src="man/figures/screenshot.png" width="90%" alt="break app screenshot showing sub-basins delineated along the Neexdzii Kwah watershed"/>
</p>

## Install

```r
# install.packages("pak")
pak::pak("NewGraphEnvironment/break")
```

## Quick Start

```r
# Requires PostgreSQL with fwapg (via fresh)
# Set PG_*_SHARE env vars for database connection
break_app <- break::run_app
break_app()
```

Note: `break` is a reserved word in R, so `break::run_app()` won't parse directly. Use the assignment workaround above, or:

```r
pkgload::load_all()
run_app()
```

## How It Works

1. **Define AOI** — three methods:
   - Type-ahead dropdown of BC watershed groups
   - Click the map to delineate an upstream watershed
   - Upload a GeoPackage or GeoJSON
   - Draw a polygon on the map

2. **Place break points** — click streams to place points (or upload a CSV with `lon`/`lat` columns). Each point snaps to the nearest FWA stream segment.

3. **Compute sub-basins** — delineate the upstream watershed for each break point, then subtract upstream catchments from downstream ones (largest-first pairwise subtraction).

4. **Export** — download `break_points.csv` (all columns preserved) and `subbasins.gpkg` (EPSG:3005).

## Requires

- PostgreSQL with [fwapg](https://github.com/smnorris/fwapg) (accessed via [fresh](https://github.com/NewGraphEnvironment/fresh))
- SSH tunnel or direct connection to the database
- `PG_*_SHARE` environment variables configured

## Part of the Ecosystem

break is one piece of a larger watershed analysis workflow:

| Package | Role |
|---------|------|
| [fresh](https://github.com/NewGraphEnvironment/fresh) | FWA-referenced spatial hydrology (data layer) |
| **break** | Delineate sub-basins from break points on stream networks |
| [flooded](https://github.com/NewGraphEnvironment/flooded) | Delineate floodplain extents from DEMs and stream networks |
| [drift](https://github.com/NewGraphEnvironment/drift) | Track land cover change within floodplains over time |

Pipeline: fresh (network data) &rarr; break (sub-basins) &rarr; flooded (floodplains) &rarr; drift (land cover change).
