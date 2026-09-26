# Vectorscan and Hyperscan constants

Integer constants used when compiling Vectorscan/Hyperscan databases.

## Usage

``` r
HS_FLAG_NONE

HS_FLAG_CASELESS

HS_FLAG_DOTALL

HS_FLAG_MULTILINE

HS_FLAG_SINGLEMATCH

HS_FLAG_ALLOWEMPTY

HS_FLAG_UTF8

HS_FLAG_UCP

HS_FLAG_PREFILTER

HS_FLAG_SOM_LEFTMOST

HS_FLAG_COMBINATION

HS_FLAG_QUIET

HS_MODE_BLOCK

HS_MODE_STREAM

HS_MODE_VECTORED

HS_MODE_SOM_HORIZON_LARGE

HS_MODE_SOM_HORIZON_MEDIUM

HS_MODE_SOM_HORIZON_SMALL
```

## Details

Combine flags with [`bitwOr()`](https://rdrr.io/r/base/bitwise.html),
not `|` (which is a logical "or" in R).

In stream mode, patterns compiled with `HS_FLAG_SOM_LEFTMOST` need a
start-of-match horizon, which bounds how far back a start offset is
kept: `HS_MODE_SOM_HORIZON_LARGE` (the whole stream), `_MEDIUM` (32 bits
of offset) or `_SMALL` (16 bits), as in
`hs_database(bitwOr(HS_MODE_STREAM, HS_MODE_SOM_HORIZON_LARGE))`. A
start beyond the horizon is reported as `NA`.

## Examples

``` r
HS_FLAG_CASELESS
#> [1] 1
HS_MODE_BLOCK
#> [1] 1
```
