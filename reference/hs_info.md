# Get database information

Get database information

## Usage

``` r
hs_info(database)
```

## Arguments

- database:

  A compiled `hs_database` object.

## Value

A single string reported by Vectorscan/Hyperscan.

## Examples

``` r
if (hs_available()) {
  db <- hs_database()
  hs_compile(db, "foo")
  hs_info(db)
}
#> [1] "Version: 5.4.13 Features: AVX512VBMI Mode: BLOCK"
```
