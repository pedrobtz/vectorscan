# Is Vectorscan or Hyperscan available?

Reports whether this installation was compiled with native
Vectorscan/Hyperscan support.

## Usage

``` r
hs_available()

hs_version()
```

## Value

A single `TRUE` or `FALSE`.

`hs_version()`: the version string of the Vectorscan library the package
was built with (bundled or system), or `NA` in a build without one.

## Examples

``` r
hs_available()
#> [1] TRUE
hs_version()
#> [1] "5.4.13 2026-09-26"
```
