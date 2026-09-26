# Load a serialized database

Reads files written by
[`hs_save()`](https://pedrobtz.github.io/vectorscan/reference/hs_save.md),
and also plain Vectorscan or Hyperscan serialized databases (for which
`from` behaves as described in
[`hs_deserialize()`](https://pedrobtz.github.io/vectorscan/reference/hs_deserialize.md)).

## Usage

``` r
hs_load(path)
```

## Arguments

- path:

  File path to read.

## Value

A compiled `hs_database` object.
