# Save a serialized database

Writes the database together with its pattern ids and flags, so that
[`hs_load()`](https://pedrobtz.github.io/vectorscan/reference/hs_load.md)
restores it exactly. The file starts with the 8-byte tag `VSCANRDB`, a
format version and the pattern metadata, followed by the bytes
[`hs_serialize()`](https://pedrobtz.github.io/vectorscan/reference/hs_serialize.md)
returns.

## Usage

``` r
hs_save(database, path)
```

## Arguments

- database:

  A compiled `hs_database`.

- path:

  File path to write.

## Value

`path`, invisibly.
