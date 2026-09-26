# Create a Vectorscan database handle

Creates an empty database handle. Compile patterns into the handle with
[`hs_compile()`](https://pedrobtz.github.io/vectorscan/reference/hs_compile.md).

## Usage

``` r
hs_database(mode = HS_MODE_BLOCK, platform = NULL)
```

## Arguments

- mode:

  One compile mode, such as `HS_MODE_BLOCK`, `HS_MODE_STREAM`, or
  `HS_MODE_VECTORED`.

- platform:

  Reserved for future platform-specific compile options.

## Value

An `hs_database` object.

## Examples

``` r
db <- hs_database()
db
#> <hs_database: empty, block mode>
```
